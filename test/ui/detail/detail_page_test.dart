import 'package:duanju_app/local_store.dart';
import 'package:duanju_app/models.dart';
import 'package:duanju_app/ui/app_scope.dart';
import 'package:duanju_app/ui/detail/detail_page.dart';
import 'package:duanju_app/ui/shell/pending_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fakes.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeRepository repository,
  LocalStore store,
  Drama drama, {
  Size size = phoneSize,
  bool television = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    AppScope(
      repository: repository,
      television: television,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DetailPage(store: store, drama: drama),
              ),
            ),
            child: const Text('打开详情'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开详情'));
  await settle(tester);
}

void main() {
  final first = drama('a', title: '剧甲');

  testWidgets('shows groups and resumes the watched episode', (tester) async {
    final repository = FakeRepository()
      ..jobs = const []
      ..details[first.id] = dramaDetail(first, vip: {80});
    final store = await openStore();
    await store.saveWatch(watching(first, episode: 12));
    await _pump(tester, repository, store, first);

    expect(find.text('剧甲'), findsOneWidget);
    expect(find.text('80 集 · 当前第 12 集'), findsOneWidget);
    expect(find.text('继续播放 · 第 12 集'), findsOneWidget);
    expect(find.byTooltip('下载选集'), findsOneWidget);
    expect(find.byKey(const ValueKey('episode-30')), findsOneWidget);
    expect(find.byKey(const ValueKey('episode-31')), findsNothing);

    await tester.tap(find.text('61-80'));
    await settle(tester);
    expect(find.byKey(const ValueKey('episode-61')), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);

    await tester.tap(find.text('定位当前'));
    await settle(tester);
    expect(find.byKey(const ValueKey('episode-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('detail-play')));
    await settle(tester);
    expect(find.byType(PendingPage), findsOneWidget);
  });

  testWidgets('viewers without download permission see no download', (
    tester,
  ) async {
    final repository = FakeRepository()
      ..jobs = const []
      ..details[first.id] = dramaDetail(first, count: 5);
    await _pump(tester, repository, await openStore(viewerPreferences), first);

    expect(find.text('立即播放'), findsOneWidget);
    expect(find.byTooltip('下载选集'), findsNothing);
  });

  testWidgets('failed loads offer a retry', (tester) async {
    final repository = FakeRepository()..detailFailure = '站源超时';
    await _pump(tester, repository, await openStore(), first);

    expect(find.text('剧集信息暂时不可用'), findsOneWidget);
    repository
      ..detailFailure = ''
      ..details[first.id] = dramaDetail(first, count: 3, warning: '部分集数需要登录');
    await tester.tap(find.text('重试'));
    await settle(tester);

    expect(find.byKey(const ValueKey('episode-3')), findsOneWidget);
    expect(find.text('部分集数需要登录'), findsOneWidget);
  });

  testWidgets('wide screens put actions beside the episodes', (tester) async {
    final repository = FakeRepository()
      ..jobs = const []
      ..details[first.id] = dramaDetail(first);
    await _pump(tester, repository, await openStore(), first, size: wideSize);

    expect(find.text('下载选集'), findsOneWidget);
    expect(find.byTooltip('下载选集'), findsNothing);
    final play = tester.getRect(find.byKey(const ValueKey('detail-play')));
    final grid = tester.getRect(find.byKey(const ValueKey('episode-1')));
    expect(grid.left, greaterThan(play.right));
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('episode-1')),
        matching: find.byType(Scrollable),
      ),
      findsOneWidget,
    );
  });

  testWidgets('television uses the phone layout for now', (tester) async {
    final repository = FakeRepository()
      ..jobs = const []
      ..details[first.id] = dramaDetail(first, count: 5);
    await _pump(
      tester,
      repository,
      await openStore(),
      first,
      size: televisionSize,
      television: true,
    );

    expect(find.byTooltip('下载选集'), findsOneWidget);
    expect(find.text('立即播放'), findsOneWidget);
  });
}
