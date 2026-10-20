import 'dart:async';

import 'package:duanju_app/drama_feed.dart';
import 'package:duanju_app/models.dart';
import 'package:duanju_app/source_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

class _CatalogRepository extends FixtureRepository {
  final calls = <String>[];

  @override
  Future<List<CatalogCategory>> categories(
    String source, {
    bool force = false,
  }) async => const [
    CatalogCategory.all,
    CatalogCategory('short_play', '真人剧'),
    CatalogCategory('comic', 'AI成人漫剧'),
  ];

  @override
  Future<CatalogPage> catalog(
    String source, {
    int page = 1,
    String query = '',
    String category = '',
    bool force = false,
  }) async {
    calls.add('$category|$query|$page');
    return CatalogPage(
      [
        Drama(
          id: '$source:p$page',
          source: source,
          title: '第$page页',
          category: category.isEmpty ? '都市' : '甜宠',
        ),
      ],
      page: page,
      hasMore: true,
    );
  }
}

const _a = Drama(id: 'hongguo:a', source: 'hongguo', title: '甲');
const _b = Drama(id: 'hongguo:b', source: 'hongguo', title: '乙');
const _c = Drama(id: 'hongguo:c', source: 'hongguo', title: '丙');

void main() {
  test('categories join normalized remote names with cached topics', () async {
    final repository = _CatalogRepository()
      ..cachedPages['hongguo'] = CatalogPage(const [
        Drama(id: 'hongguo:1', source: 'hongguo', title: '甲', category: '都市'),
        Drama(id: 'hongguo:2', source: 'hongguo', title: '乙', category: '成长'),
        Drama(id: 'hongguo:3', source: 'hongguo', title: '丙', category: 'AI漫剧'),
        Drama(id: 'huangdou:4', source: 'huangdou', title: '丁', category: '甜宠'),
      ]);
    final catalog = SourceCatalog(repository, SourceSite.hongguo);
    await catalog.loadCategories();
    expect(
      [for (final category in catalog.categories) category.id],
      ['', 'short_play', 'comic', 'local:成长', 'local:都市'],
    );
    expect(catalog.categories[2].name, 'AI 漫剧');

    final local = catalog.categories.last;
    final page = await catalog.fetch(local);
    expect(repository.calls, ['||1']);
    expect(
      [for (final drama in page.items) drama.id],
      ['hongguo:1', 'hongguo:p1'],
    );
  });

  test('search pages only where the source searches online by page', () async {
    final repository = _CatalogRepository();
    final hongguo = await SourceCatalog(
      repository,
      SourceSite.hongguo,
    ).search('剧名');
    final sorani = await SourceCatalog(
      repository,
      SourceSite.sorani,
    ).search('剧名', page: 2);
    expect(hongguo.hasMore, isFalse);
    expect(sorani.hasMore, isTrue);
    expect(repository.calls, ['|剧名|1', '|剧名|2']);
  });

  test('stale cache shows first, then the first page replaces it', () async {
    final first = Completer<CatalogPage>();
    final feed = DramaFeed(
      cached: () async => CatalogPage([_a], page: 7, hasMore: true),
      load: (page, force) => first.future,
    );
    addTearDown(feed.dispose);
    final reload = feed.reload();
    await pumpEventQueue();
    expect(feed.items, [_a]);
    expect(feed.loading, isTrue);
    first.complete(CatalogPage([_b], hasMore: true));
    await reload;
    expect(feed.items, [_b]);
    expect(feed.loading, isFalse);
  });

  test('fresh cache continues from its saved page', () async {
    final pages = <int>[];
    final feed = DramaFeed(
      cached: () async =>
          CatalogPage([_a], page: 7, hasMore: true, fresh: true),
      load: (page, force) async {
        pages.add(page);
        return CatalogPage([_b], page: page);
      },
    );
    addTearDown(feed.dispose);
    await feed.reload();
    expect(pages, isEmpty);
    await feed.loadMore();
    expect(pages, [8]);
    expect(feed.items, [_a, _b]);
    expect(feed.hasMore, isFalse);
  });

  test('more pages merge, and a warning retries the same page', () async {
    final pages = <int>[];
    final feed = DramaFeed(
      load: (page, force) async {
        pages.add(page);
        return page == 1
            ? CatalogPage([_a, _b], hasMore: true)
            : CatalogPage([_b, _c], page: 2, warning: '部分失败');
      },
    );
    addTearDown(feed.dispose);
    await feed.reload();
    await feed.loadMore();
    expect(feed.items, [_a, _b, _c]);
    expect(feed.error, '部分失败');
    expect(feed.hasMore, isTrue);
    expect(feed.canLoadMore, isFalse);
    await feed.loadMore();
    expect(pages, [1, 2, 2]);
  });

  test('cumulative feeds replace their items with each answer', () async {
    final feed = DramaFeed(
      cumulative: true,
      load: (page, force) async =>
          CatalogPage(page == 1 ? [_a] : [_a, _b], hasMore: page == 1),
    );
    addTearDown(feed.dispose);
    await feed.reload();
    await feed.loadMore();
    expect(feed.items, [_a, _b]);
  });
}
