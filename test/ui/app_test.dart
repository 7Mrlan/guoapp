import 'package:duanju_app/ui/settings/appearance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
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
      expect(find.byType(AppearanceScreen), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(AppearanceScreen), findsNothing);
      expect(find.text('外观'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.text('外观'), findsOneWidget);
    });
  }
}
