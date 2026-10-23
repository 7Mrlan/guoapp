import 'package:duanju_app/ui/app.dart';
import 'package:duanju_app/ui/mine/mine_page.dart';
import 'package:duanju_app/ui/search/search_page.dart';
import 'package:duanju_app/ui/settings/appearance_settings.dart';
import 'package:duanju_app/ui/settings/settings_page.dart';
import 'package:duanju_app/ui/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

void main() {
  testWidgets('the boot screen gives way to the app once the store opens', (
    tester,
  ) async {
    final repository = FakeRepository();
    await tester.pumpWidget(DuanjuApp(repository: repository));
    await tester.pump();
    expect(find.byType(AppShell), findsNothing);

    final store = await openStore();
    await tester.pumpWidget(DuanjuApp(repository: repository, store: store));
    await settle(tester);
    expect(find.byType(AppShell), findsOneWidget);
  });

  for (final mode in ['standard', 'television']) {
    testWidgets('escape closes the popup, then the page, then stops ($mode)', (
      tester,
    ) async {
      await pumpApp(tester, size: wideSize, mode: mode);
      await openAppearance(tester);
      await tester.tap(find.text('界面模式'));
      await settle(tester);
      expect(find.byType(SimpleDialog), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(SimpleDialog), findsNothing);
      expect(find.byType(AppearanceSettings), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(SettingsPage), findsNothing);
      expect(find.byType(MinePage), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(MinePage), findsOneWidget);
    });

    testWidgets('escape leaves the page from a focused text field ($mode)', (
      tester,
    ) async {
      await pumpApp(tester, size: wideSize, mode: mode);
      await openSettings(tester);
      await openSettingsGroup(tester, '用户');
      await tester.tap(find.byTooltip('编辑 管理员'));
      await settle(tester);
      await tester.tap(_field('设置密码'));
      await settle(tester);
      expect(_typing(), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.text('编辑管理员'), findsNothing);
    });
  }

  testWidgets('television arrows and back move out of the search field', (
    tester,
  ) async {
    await pumpApp(
      tester,
      size: televisionSize,
      mode: 'television',
      prepare: (store) => store.rememberSearch('旧词'),
    );
    await tester.tap(find.byTooltip('在 红果 中搜索'));
    await settle(tester);
    expect(_typing(), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    expect(_typing(), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await settle(tester);
    expect(_typing(), isTrue);

    await tester.sendKeyEvent(
      LogicalKeyboardKey.goBack,
      platform: 'android',
      physicalKey: PhysicalKeyboardKey.escape,
    );
    await settle(tester);
    expect(find.byType(SearchPage), findsNothing);
  });

  testWidgets('television left and right leave a field only at its edges', (
    tester,
  ) async {
    await pumpApp(tester, size: televisionSize, mode: 'television');
    await openSettings(tester);
    await openSettingsGroup(tester, '用户');
    await tester.tap(find.byTooltip('编辑 管理员'));
    await settle(tester);
    await tester.enterText(_field('设置密码'), '12');
    await settle(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    expect(_editing(tester, '设置密码'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(_editing(tester, '再次输入密码'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    expect(_editing(tester, '设置密码'), isTrue);
  });
}

bool _typing() =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorStateOfType<EditableTextState>() !=
    null;

Finder _field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

bool _editing(WidgetTester tester, String label) => tester
    .state<EditableTextState>(
      find.descendant(of: _field(label), matching: find.byType(EditableText)),
    )
    .widget
    .focusNode
    .hasPrimaryFocus;
