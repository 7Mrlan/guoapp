import 'package:duanju_app/ui/app.dart';
import 'package:duanju_app/ui/mine/mine_page.dart';
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
  }
}
