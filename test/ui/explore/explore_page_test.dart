import 'package:duanju_app/ranking_models.dart';
import 'package:duanju_app/ui/explore/explore_hero.dart';
import 'package:duanju_app/ui/shell/pending_pages.dart';
import 'package:duanju_app/ui/widgets/cover_image.dart';
import 'package:duanju_app/ui/widgets/drama_tile.dart';
import 'package:duanju_app/ui/widgets/focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fakes.dart';

void main() {
  testWidgets('picks lead with a hero, categories switch the grid', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('红果'), findsOneWidget);
    expect(find.text('今日推荐'), findsOneWidget);
    expect(find.text('推荐剧一'), findsOneWidget);
    expect(find.text('推荐剧二'), findsOneWidget);

    await tester.tap(find.text('真人剧'));
    await settle(tester);
    expect(find.byType(ExploreHero), findsNothing);
    expect(find.text('分类short_play'), findsOneWidget);

    await tester.tap(find.text('分类short_play'));
    await settle(tester);
    expect(find.byType(PendingDetailPage), findsOneWidget);
  });

  testWidgets('recent watching on this source takes the hero', (tester) async {
    await pumpApp(
      tester,
      prepare: (store) => store.saveWatch(
        watching(drama('w', title: '看过的剧'), episode: 12, position: 100),
      ),
    );
    expect(find.text('继续观看'), findsOneWidget);
    expect(find.text('看到第 12 集 · 共 80 集'), findsOneWidget);
    expect(find.text('继续第 13 集'), findsOneWidget);
    expect(find.text('推荐剧一'), findsOneWidget);
  });

  testWidgets('a ranking tab shows ranks on the covers', (tester) async {
    final repository = FakeRepository()
      ..boardList = const [
        RankingBoard(id: 'hongguo-hot', source: 'hongguo', name: '总热播榜'),
      ];
    await pumpApp(tester, repository: repository);
    expect(find.byType(RankBadge), findsNothing);

    await tester.tap(find.text('总热播榜'));
    await settle(tester);
    expect(find.byType(ExploreHero), findsNothing);
    expect(find.text('hongguo-hot第1名'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RankBadge).first,
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a failed load offers a retry', (tester) async {
    final repository = FakeRepository()..failure = '合成网络错误';
    await pumpApp(tester, repository: repository);
    await tester.tap(find.text('真人剧'));
    await settle(tester);
    expect(find.text('暂时无法加载'), findsOneWidget);

    repository.failure = '';
    await tester.tap(find.text('重试'));
    await settle(tester);
    expect(find.text('分类short_play'), findsOneWidget);
  });

  testWidgets('the hero scales with the drama tiles', (tester) async {
    await pumpApp(tester, size: televisionSize, mode: 'television');
    final tile = tester.getSize(find.byType(DramaTile).first).width;
    expect(tester.getSize(find.byType(ExploreHero)).height, 196);

    tester.view.physicalSize = const Size(1920, 1080);
    await settle(tester);
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
    await pumpApp(tester, size: televisionSize, mode: 'television');
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

  testWidgets('television back refreshes from content, exits from the top', (
    tester,
  ) async {
    final repository = FakeRepository();
    await pumpApp(
      tester,
      size: televisionSize,
      mode: 'television',
      repository: repository,
    );
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<ExploreHero>(),
      isNotNull,
    );
    expect(repository.recommendRequests, [(more: false, force: false)]);

    expect(await systemBack(tester), isTrue);
    expect(repository.recommendRequests.last, (more: false, force: true));
    expect(tabFocus(tester, 'explore').hasPrimaryFocus, isTrue);

    expect(await systemBack(tester), isFalse);
    expect(repository.recommendRequests, hasLength(2));
  });
}
