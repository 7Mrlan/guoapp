import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

void main() {
  testWidgets('display mode changes only when an option is confirmed', (
    tester,
  ) async {
    final store = await pumpApp(
      tester,
      size: televisionSize,
      mode: 'television',
    );
    await openAppearance(tester);
    await tester.tap(find.text('界面模式'));
    await settle(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    expect(store.displayMode, 'television');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(store.displayMode, 'standard');
    expect(find.text('手机 / 电脑'), findsOneWidget);
  });

  testWidgets('theme mode and colors apply right away', (tester) async {
    final store = await pumpApp(tester);
    await openAppearance(tester);

    await tester.tap(find.text('主题模式'));
    await settle(tester);
    await tester.tap(find.text('深色'));
    await settle(tester);
    expect(store.themeMode, 'dark');
    expect(find.text('深色'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == '青绿',
        ),
        matching: find.byType(InkWell),
      ),
    );
    await settle(tester);
    expect(store.themeColor.label, '青绿');
  });
}
