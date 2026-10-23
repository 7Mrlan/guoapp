import 'package:duanju_app/app_build.dart';
import 'package:duanju_app/ui/settings/appearance_settings.dart';
import 'package:duanju_app/ui/settings/diary_view.dart';
import 'package:duanju_app/ui/settings/settings_page.dart';
import 'package:duanju_app/ui/settings/settings_sections.dart';
import 'package:duanju_app/ui/settings/sources_view.dart';
import 'package:duanju_app/ui/users/users_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fakes.dart';

Finder _groupItem(String name) => find.byKey(ValueKey('settings-$name'));

Finder _tile(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(ListTile));

Future<void> _choose(WidgetTester tester, String row, String option) async {
  await tester.tap(find.text(row));
  await settle(tester);
  await tester.tap(
    find.descendant(of: find.byType(SimpleDialog), matching: find.text(option)),
  );
  await settle(tester);
}

void main() {
  testWidgets('phone lists the groups and opens each one as a page', (
    tester,
  ) async {
    final store = await pumpApp(tester);
    await openSettings(tester);
    for (final label in [
      '外观',
      '播放',
      '下载',
      '站源',
      '代理',
      '用户',
      '关于',
      '诊断',
      '导出备份',
      '恢复备份',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('跟随系统 · 暖橙 · 手机 / 电脑'), findsOneWidget);

    await openSettingsGroup(tester, '下载');
    await _choose(tester, '默认画质', '720P');
    expect(store.downloadPreferences.quality, 720);
    expect(find.text('720P'), findsOneWidget);

    await systemBack(tester);
    await openSettingsGroup(tester, '播放');
    expect(find.text('「播放」正在重建'), findsOneWidget);

    await systemBack(tester);
    await openSettingsGroup(tester, '用户');
    expect(find.byType(UsersView), findsOneWidget);
  });

  testWidgets('restricted rows stay visible but greyed out', (tester) async {
    final repository = FakeRepository();
    await pumpApp(tester, repository: repository, initial: viewerPreferences);
    await openSettings(tester);

    await openSettingsGroup(tester, '下载');
    expect(tester.widget<ListTile>(_tile('默认画质')).enabled, isFalse);
    expect(find.text('当前用户没有下载权限'), findsWidgets);
    expect(find.text('需要管理员'), findsWidgets);
    expect(
      tester
          .widget<SwitchListTile>(
            find.ancestor(
              of: find.text('按站源分类保存'),
              matching: find.byType(SwitchListTile),
            ),
          )
          .onChanged,
      isNull,
    );

    await systemBack(tester);
    expect(tester.widget<ListTile>(_tile('导出备份')).enabled, isFalse);
    expect(tester.widget<ListTile>(_tile('恢复备份')).enabled, isFalse);
    expect(repository.savedResources, isEmpty);
  });

  testWidgets('wide windows split groups and details, subpages stay inside', (
    tester,
  ) async {
    final repository = FakeRepository();
    await pumpApp(tester, size: wideSize, repository: repository);
    await openSettings(tester);
    expect(find.byType(AppearanceSettings), findsOneWidget);
    expect(_groupItem('export'), findsOneWidget);

    await openSettingsGroup(tester, '站源');
    await _choose(tester, '目录请求间隔', '1000 毫秒');
    expect(repository.savedResources.single.catalogIntervalMs, 1000);
    expect(repository.savedResources.single.catalogConcurrency, 3);

    if (allSourcesEnabled) {
      await tester.tap(find.text('站源管理'));
      await settle(tester);
      expect(find.byType(SourcesView), findsOneWidget);
      expect(_groupItem('sources'), findsOneWidget);

      await systemBack(tester);
      expect(find.byType(SourcesView), findsNothing);
      expect(find.text('目录请求间隔'), findsOneWidget);
    } else {
      expect(find.text('站源管理'), findsNothing);
    }

    await systemBack(tester);
    expect(find.byType(SettingsPage), findsNothing);
  });

  testWidgets('television moves between the two columns', (tester) async {
    await pumpApp(tester, size: televisionSize, mode: 'television');
    await openSettings(tester);
    Finder label(String name, String text) =>
        find.descendant(of: _groupItem(name), matching: find.text(text));
    expect(focusHolds(tester, label('appearance', '外观')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    expect(focusHolds(tester, label('download', '下载')), isTrue);
    expect(find.text('默认画质'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(focusHolds(tester, find.text('默认画质')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    expect(focusHolds(tester, label('download', '下载')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(await systemBack(tester), isTrue);
    expect(focusHolds(tester, label('download', '下载')), isTrue);
    expect(find.byType(SettingsPage), findsOneWidget);

    await systemBack(tester);
    expect(find.byType(SettingsPage), findsNothing);
  });

  testWidgets('television subpages close with the back key only', (
    tester,
  ) async {
    await pumpApp(tester, size: televisionSize, mode: 'television');
    await openSettings(tester);
    for (var i = 0; i < SettingsGroup.values.length - 1; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(focusHolds(tester, find.text('播放调试日记')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.byType(DiaryView), findsOneWidget);
    expect(find.byTooltip('返回'), findsNothing);
    expect(focusHolds(tester, find.text('复制全部')), isTrue);

    expect(await systemBack(tester), isTrue);
    expect(find.byType(DiaryView), findsNothing);
    expect(focusHolds(tester, find.text('播放调试日记')), isTrue);
  });
}
