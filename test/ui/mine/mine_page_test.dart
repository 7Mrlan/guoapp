import 'package:duanju_app/local_store.dart';
import 'package:duanju_app/models.dart';
import 'package:duanju_app/ui/detail/detail_page.dart';
import 'package:duanju_app/ui/settings/settings_page.dart';
import 'package:duanju_app/ui/users/users_view.dart';
import 'package:duanju_app/ui/widgets/drama_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fakes.dart';

FakeRepository _downloading() => FakeRepository()
  ..jobs = [
    downloadJob(drama('a', title: '剧甲'), 1, bytes: 1536 << 20),
    downloadJob(
      drama('b', title: '剧乙'),
      5,
      state: 'downloading',
      progress: .45,
    ),
    downloadJob(drama('b', title: '剧乙'), 6, state: 'queued', progress: 0),
  ];

Future<void> _watchMany(LocalStore store, int count) async {
  for (var index = 0; index < count; index++) {
    await store.saveWatch(
      watching(drama('w$index', title: '看过$index'), episode: index + 1),
    );
  }
}

void main() {
  testWidgets('phone shows the user, recent dramas and downloads', (
    tester,
  ) async {
    await pumpApp(
      tester,
      repository: _downloading(),
      prepare: (store) => store.saveWatch(
        watching(drama('a', title: '剧甲', episodes: 60), episode: 3),
      ),
    );
    expect(
      find.descendant(of: navItem('mine'), matching: find.text('2')),
      findsOneWidget,
    );

    await openTab(tester, 'mine');
    expect(find.text('管理员'), findsOneWidget);
    expect(find.text('看到第 3 集'), findsOneWidget);
    expect(find.text('红果'), findsOneWidget);
    expect(find.text('剧乙 · 第 5 集'), findsOneWidget);
    expect(find.text('45%'), findsOneWidget);
    expect(find.text('另有 1 个任务排队中'), findsOneWidget);
    expect(find.text('已完成 1 集 · 占用 1.5 GB'), findsOneWidget);

    await tester.tap(find.text('剧甲'));
    await settle(tester);
    expect(find.byType(DetailPage), findsOneWidget);
  });

  testWidgets('users without download permission see no downloads', (
    tester,
  ) async {
    final repository = _downloading();
    await pumpApp(tester, repository: repository, initial: viewerPreferences);
    await openTab(tester, 'mine');

    expect(find.text('访客'), findsOneWidget);
    expect(find.text('下载'), findsNothing);
    expect(find.text('还没有观看记录'), findsOneWidget);
    expect(repository.downloadRequests, 0);
  });

  testWidgets('the user card and the section links open their pages', (
    tester,
  ) async {
    await pumpApp(tester, repository: _downloading());
    await openTab(tester, 'mine');

    await tester.tap(find.text('管理员'));
    await settle(tester);
    expect(find.byType(UsersView), findsOneWidget);
    await systemBack(tester);

    await tester.tap(find.text('全部').last);
    await settle(tester);
    expect(find.text('「下载」正在重建'), findsOneWidget);
    await systemBack(tester);

    await tester.tap(find.text('设置'));
    await settle(tester);
    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets('television shows one row of recent above the entry cards', (
    tester,
  ) async {
    await pumpApp(
      tester,
      size: televisionSize,
      mode: 'television',
      repository: _downloading(),
      prepare: (store) async {
        await _watchMany(store, 8);
        await store.saveWatch(
          WatchEntry(
            drama: drama('end', title: '看完的剧', episodes: 5),
            episode: 5,
            position: 100,
            duration: 100,
            updatedAt: DateTime(2026, 10, 21),
          ),
        );
      },
    );
    await openTab(tester, 'mine');

    final posters = find.byType(ProgressPoster);
    expect(posters, findsNWidgets(6));
    expect(find.text('已看完'), findsOneWidget);
    expect(find.text('9 部'), findsOneWidget);
    expect(find.text('2 集下载中 · 45%'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('管理员')).dy,
      greaterThan(tester.getBottomLeft(posters.first).dy),
    );

    tabFocus(tester, 'mine').requestFocus();
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    expect(focusHolds(tester, find.text('看完的剧')), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    expect(focusHolds(tester, find.text('管理员')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await settle(tester);
    final titles = find.descendant(of: posters, matching: find.byType(Text));
    expect([
      for (var index = 0; index < titles.evaluate().length; index++)
        focusHolds(tester, titles.at(index)),
    ], contains(true));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await settle(tester);
    expect(
      [
        'explore',
        'follow',
        'mine',
      ].any((tab) => tabFocus(tester, tab).hasPrimaryFocus),
      isTrue,
    );
  });

  testWidgets('television without history or downloads keeps two entries', (
    tester,
  ) async {
    await pumpApp(
      tester,
      size: televisionSize,
      mode: 'television',
      repository: _downloading(),
      initial: viewerPreferences,
    );
    await openTab(tester, 'mine');
    expect(find.text('还没有观看记录'), findsOneWidget);
    expect(find.text('下载'), findsNothing);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('wide splits into columns and keeps two rows of recent', (
    tester,
  ) async {
    await pumpApp(
      tester,
      size: wideSize,
      repository: _downloading(),
      prepare: (store) => _watchMany(store, 30),
    );
    await openTab(tester, 'mine');

    final posters = find.byType(ProgressPoster);
    final count = posters.evaluate().length;
    expect(count, inInclusiveRange(2, 29));
    expect(count.isEven, isTrue);
    expect(
      tester.getTopLeft(find.text('最近观看')).dx,
      greaterThan(tester.getTopRight(find.text('管理员')).dx),
    );
    expect(
      tester.getTopLeft(posters.first).dy,
      lessThan(tester.getTopLeft(find.text('设置')).dy),
    );

    tester.view.physicalSize = const Size(720, 800);
    await settle(tester);
    expect(
      tester.getTopLeft(find.text('最近观看')).dy,
      greaterThan(tester.getTopLeft(find.text('设置')).dy),
    );
  });
}
