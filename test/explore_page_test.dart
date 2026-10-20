import 'package:duanju_app/local_store.dart';
import 'package:duanju_app/models.dart';
import 'package:duanju_app/ui/app.dart';
import 'package:duanju_app/ui/explore/explore_hero.dart';
import 'package:duanju_app/ui/search/search_page.dart';
import 'package:duanju_app/ui/shell/pending_pages.dart';
import 'package:duanju_app/ui/widgets/drama_tile.dart';
import 'package:duanju_app/ui/widgets/focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

Drama _drama(String id, String title) =>
    Drama(id: 'hongguo:$id', source: 'hongguo', title: title, episodes: 80);

class _ExploreRepository extends FixtureRepository {
  final recommendRequests = <bool>[];

  @override
  Future<List<CatalogCategory>> categories(
    String source, {
    bool force = false,
  }) async => const [CatalogCategory.all, CatalogCategory('short_play', '真人剧')];

  @override
  Future<CatalogPage> recommendations(
    String genre, {
    bool more = false,
    bool force = false,
  }) async {
    recommendRequests.add(force);
    return CatalogPage([
      _drama('r1', '推荐剧一'),
      _drama('r2', '推荐剧二'),
      _drama('r3', '推荐剧三'),
    ]);
  }

  @override
  Future<CatalogPage> catalog(
    String source, {
    int page = 1,
    String query = '',
    String category = '',
    bool force = false,
  }) async => CatalogPage([
    query.isEmpty
        ? _drama('c-$category-$page', '分类$category')
        : _drama('s1', '搜到的剧'),
  ], page: page);
}

Future<LocalStore> _open(
  WidgetTester tester,
  Size size, {
  String mode = 'standard',
  WatchEntry? watched,
  _ExploreRepository? repository,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final store = testStore(await SharedPreferences.getInstance());
  addTearDown(store.dispose);
  await store.setDisplayMode(mode);
  if (watched != null) await store.saveWatch(watched);
  await tester.pumpWidget(
    DuanjuApp(repository: repository ?? _ExploreRepository(), store: store),
  );
  await _settle(tester);
  return store;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('recommend tab leads with the first pick and categories load', (
    tester,
  ) async {
    await _open(tester, const Size(390, 844));
    expect(find.text('红果'), findsOneWidget);
    expect(find.text('今日推荐'), findsOneWidget);
    expect(find.text('推荐剧一'), findsOneWidget);
    expect(find.text('推荐剧二'), findsOneWidget);

    await tester.tap(find.text('真人剧'));
    await _settle(tester);
    expect(find.byType(ExploreHero), findsNothing);
    expect(find.text('分类short_play'), findsOneWidget);

    await tester.tap(find.text('分类short_play'));
    await _settle(tester);
    expect(find.byType(PendingDetailPage), findsOneWidget);
  });

  testWidgets('the hero grows with the drama tiles', (tester) async {
    await _open(tester, const Size(960, 540), mode: 'television');
    final design = tester.getSize(find.byType(ExploreHero)).height;
    final tile = tester.getSize(find.byType(DramaTile).first).width;
    expect(design, 196);

    tester.view.physicalSize = const Size(1920, 1080);
    await _settle(tester);
    final grown = tester.getSize(find.byType(DramaTile).first).width / tile;
    expect(grown, greaterThan(1.5));
    expect(
      tester.getSize(find.byType(ExploreHero)).height,
      moreOrLessEquals(196 * grown, epsilon: 1),
    );
  });

  testWidgets('the focus outline follows a resize within the frame', (
    tester,
  ) async {
    await _open(tester, const Size(960, 540), mode: 'television');
    final ring = find.ancestor(
      of: find.text('立即观看'),
      matching: find.byType(FocusOutline),
    );
    final outline = find.descendant(
      of: find.byType(CompositedTransformFollower),
      matching: find.byType(CustomPaint),
    );
    final before = tester.getSize(ring);

    tester.view.physicalSize = const Size(1920, 1080);
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 60));
      final size = tester.getSize(ring);
      expect(
        tester.renderObject(outline),
        paints..rrect(
          rrect: RRect.fromRectAndRadius(
            (Offset.zero & size).inflate(4.5),
            const Radius.circular(999 + 4.5),
          ),
        ),
      );
    }
    expect(tester.getSize(ring).height, greaterThan(before.height * 1.5));
  });

  testWidgets('recent watching on this source takes the hero', (tester) async {
    await _open(
      tester,
      const Size(390, 844),
      watched: WatchEntry(
        drama: _drama('w', '看过的剧'),
        episode: 12,
        position: 100,
        duration: 100,
        updatedAt: DateTime(2026, 10, 20),
      ),
    );
    expect(find.text('继续观看'), findsOneWidget);
    expect(find.text('看到第 12 集 · 共 80 集'), findsOneWidget);
    expect(find.text('继续第 13 集'), findsOneWidget);
    expect(find.text('推荐剧一'), findsOneWidget);
  });

  testWidgets('wide search field opens the search page with results', (
    tester,
  ) async {
    final store = await _open(tester, const Size(1280, 800));
    await tester.enterText(find.byType(TextField), '剧名');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _settle(tester);
    expect(find.byType(SearchPage), findsOneWidget);
    expect(find.text('搜到的剧'), findsOneWidget);
    expect(store.recentSearches, ['剧名']);
  });

  testWidgets('television back refreshes from content, exits from the top', (
    tester,
  ) async {
    final repository = _ExploreRepository();
    await _open(
      tester,
      const Size(960, 540),
      mode: 'television',
      repository: repository,
    );
    expect(find.text('红果'), findsOneWidget);
    expect(find.byTooltip('切换站源'), findsOneWidget);
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(focused?.findAncestorWidgetOfExactType<ExploreHero>(), isNotNull);
    expect(repository.recommendRequests, [false]);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await _settle(tester);
    expect(repository.recommendRequests, [false, true]);
    final explore = tester.widget<InkWell>(
      find.byKey(const ValueKey('nav-explore')),
    );
    expect(explore.focusNode!.hasPrimaryFocus, isTrue);

    expect(await tester.binding.handlePopRoute(), isFalse);
    expect(repository.recommendRequests, [false, true]);
  });
}
