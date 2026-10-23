import 'package:duanju_app/app_build.dart';
import 'package:duanju_app/local_store.dart';
import 'package:duanju_app/models.dart';
import 'package:duanju_app/ui/detail/detail_page.dart';
import 'package:duanju_app/ui/history/history_page.dart';
import 'package:duanju_app/ui/widgets/group_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fakes.dart';

WatchEntry _at(Drama drama, DateTime time, {int episode = 3}) => WatchEntry(
  drama: drama,
  episode: episode,
  position: 10,
  duration: 100,
  updatedAt: time,
);

Future<void> _watch(LocalStore store) async {
  final now = DateTime.now();
  await store.saveWatch(_at(drama('c', title: '早先的剧'), DateTime(2026, 1, 1)));
  await store.saveWatch(
    _at(
      drama('b', title: '昨天的剧'),
      DateTime(now.year, now.month, now.day - 1, 12),
    ),
  );
  await store.saveWatch(_at(drama('a', title: '今天的剧'), now));
}

Future<LocalStore> _open(
  WidgetTester tester, {
  Size size = phoneSize,
  String mode = 'standard',
  Future<void> Function(LocalStore store) prepare = _watch,
}) async {
  final store = await pumpApp(tester, size: size, mode: mode, prepare: prepare);
  await openTab(tester, 'mine');
  final section = find.ancestor(
    of: find.text('最近观看'),
    matching: find.byType(SectionHeader),
  );
  await tester.tap(
    section.evaluate().isEmpty
        ? find.text('全部')
        : find.descendant(of: section, matching: find.text('全部')),
  );
  await settle(tester);
  expect(find.byType(HistoryPage), findsOneWidget);
  return store;
}

List<String> _ids(LocalStore store) => [
  for (final entry in store.history) entry.drama.id,
];

void main() {
  testWidgets('records are grouped by day and filtered by title', (
    tester,
  ) async {
    await _open(tester);

    final today = tester.getTopLeft(find.text('今天')).dy;
    final yesterday = tester.getTopLeft(find.text('昨天')).dy;
    final earlier = tester.getTopLeft(find.text('更早')).dy;
    expect(today, lessThan(yesterday));
    expect(yesterday, lessThan(earlier));
    expect(find.text('看到第 3 集'), findsNWidgets(3));

    await tester.enterText(find.byType(TextField), '昨天');
    await settle(tester);
    expect(find.text('昨天的剧'), findsOneWidget);
    expect(find.text('今天的剧'), findsNothing);

    await tester.enterText(find.byType(TextField), '王爷');
    await settle(tester);
    expect(find.text('没有匹配的记录'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await settle(tester);
    await tester.tap(find.text('今天的剧'));
    await settle(tester);
    expect(find.byType(DetailPage), findsOneWidget);
  });

  testWidgets('edit mode deletes the selected records after confirming', (
    tester,
  ) async {
    final store = await _open(tester);

    await tester.tap(find.text('编辑'));
    await settle(tester);
    expect(find.text('已选择 0 部'), findsOneWidget);
    await tester.tap(find.text('今天的剧'));
    await tester.tap(find.text('昨天的剧'));
    await settle(tester);
    expect(find.text('已选择 2 部'), findsOneWidget);
    expect(find.byType(DetailPage), findsNothing);

    await systemBack(tester);
    expect(find.text('观看记录'), findsOneWidget);
    expect(find.byType(HistoryPage), findsOneWidget);

    await tester.tap(find.text('编辑'));
    await settle(tester);
    await tester.tap(find.text('全选'));
    await settle(tester);
    expect(find.text('已选择 3 部'), findsOneWidget);
    await tester.tap(find.text('取消全选'));
    await tester.tap(find.text('昨天的剧'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await settle(tester);
    expect(find.text('删除 1 条观看记录？'), findsOneWidget);
    await tester.tap(find.text('删除').last);
    await settle(tester);

    expect(_ids(store), ['hongguo:a', 'hongguo:c']);
    expect(find.text('昨天的剧'), findsNothing);
    expect(find.text('观看记录'), findsOneWidget);
  });

  testWidgets('clear removes only the records listed', (tester) async {
    final store = await _open(tester);

    await tester.enterText(find.byType(TextField), '剧');
    await settle(tester);
    await tester.enterText(find.byType(TextField), '昨天');
    await settle(tester);
    await tester.tap(find.text('清空'));
    await settle(tester);
    expect(find.textContaining('当前列出的 1 条'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await settle(tester);
    expect(_ids(store), hasLength(3));

    await tester.tap(find.text('清空'));
    await settle(tester);
    await tester.tap(find.text('清空').last);
    await settle(tester);
    expect(_ids(store), ['hongguo:a', 'hongguo:c']);
  });

  testWidgets('source chips filter and limit clearing to one source', (
    tester,
  ) async {
    final store = await _open(
      tester,
      prepare: (store) async {
        await _watch(store);
        await store.saveWatch(
          _at(drama('k', source: 'hanxiaoquan', title: '韩剧'), DateTime.now()),
        );
      },
    );

    await tester.tap(find.byKey(const ValueKey('history-source-hanxiaoquan')));
    await settle(tester);
    expect(find.text('韩剧'), findsOneWidget);
    expect(find.text('今天的剧'), findsNothing);

    await tester.tap(find.text('清空'));
    await settle(tester);
    await tester.tap(find.text('清空').last);
    await settle(tester);
    expect(_ids(store), ['hongguo:a', 'hongguo:b', 'hongguo:c']);
    expect(find.byKey(const ValueKey('history-source-')), findsNothing);
  }, skip: !allSourcesEnabled);

  testWidgets('television selects with the remote and back leaves editing', (
    tester,
  ) async {
    await _open(tester, size: televisionSize, mode: 'television');
    expect(focusHolds(tester, find.text('今天的剧')), isTrue);
    expect(find.byType(BackButton), findsNothing);

    Focus.of(tester.element(find.text('编辑'))).requestFocus();
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.text('已选择 0 部'), findsOneWidget);
    expect(focusHolds(tester, find.text('今天的剧')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.text('已选择 1 部'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.text('观看记录'), findsOneWidget);
    expect(focusHolds(tester, find.text('今天的剧')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(HistoryPage), findsNothing);
  });

  testWidgets('wide screens keep the side bar beside the page', (tester) async {
    await _open(tester, size: wideSize);
    expect(find.byKey(const ValueKey('side-bar')), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.byType(HistoryPage), findsNothing);
    expect(find.text('最近观看'), findsOneWidget);
  });
}
