import 'package:duanju_app/local_store.dart';
import 'package:duanju_app/ui/app.dart';
import 'package:duanju_app/ui/preview/component_preview.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

Future<LocalStore> _open(WidgetTester tester, {String mode = 'auto'}) async {
  SharedPreferences.setMockInitialValues({});
  final store = testStore(await SharedPreferences.getInstance());
  await store.setDisplayMode(mode);
  await tester.pumpWidget(
    DuanjuApp(repository: FixtureRepository(), store: store),
  );
  await tester.pump();
  return store;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  for (final mode in ['standard', 'television']) {
    testWidgets('escape closes the top popup first, then leaves the page '
        '($mode)', (tester) async {
      final store = await _open(tester, mode: mode);
      await tester.tap(find.byTooltip('组件预览'));
      await _settle(tester);
      expect(find.byType(ComponentPreview), findsOneWidget);

      await tester.tap(find.byTooltip('切换站源'));
      await _settle(tester);
      expect(find.text('11 个'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(find.text('11 个'), findsNothing);
      expect(find.byType(ComponentPreview), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(find.byType(ComponentPreview), findsNothing);
      expect(find.text('外观'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('外观'), findsOneWidget);
      store.dispose();
    });
  }

  testWidgets('display mode changes only when an option is confirmed', (
    tester,
  ) async {
    final store = await _open(tester, mode: 'television');
    await tester.tap(find.text('界面模式'));
    await _settle(tester);
    expect(find.text('手机 / 电脑'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await _settle(tester);
    expect(find.text('手机 / 电脑'), findsOneWidget);
    expect(store.displayMode, 'television');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(find.text('手机 / 电脑'), findsOneWidget);
    expect(store.displayMode, 'standard');
    store.dispose();
  });
}
