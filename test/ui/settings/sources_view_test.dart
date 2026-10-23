import 'package:duanju_app/app_build.dart';
import 'package:duanju_app/ui/settings/sources_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fakes.dart';

Finder _switch(String name) => find.descendant(
  of: find.ancestor(of: find.text(name), matching: find.byType(ListTile)),
  matching: find.byType(Switch),
);

Future<void> _openSources(WidgetTester tester) async {
  await openSettings(tester);
  await openSettingsGroup(tester, '站源');
  await tester.tap(find.text('站源管理'));
  await settle(tester);
}

void main() {
  testWidgets('admin switches sources on and off', (tester) async {
    final store = await pumpApp(tester, size: wideSize);
    await _openSources(tester);
    expect(find.byType(SourcesView), findsOneWidget);
    expect(find.text('需要管理员才能开启或关闭站源'), findsNothing);
    expect(tester.widget<Switch>(_switch('黄豆')).value, isFalse);

    await tester.tap(find.text('黄豆'));
    await settle(tester);
    expect(store.sourceEnabled('huangdou'), isTrue);
    expect(tester.widget<Switch>(_switch('黄豆')).value, isTrue);

    await tester.tap(find.text('红果'));
    await settle(tester);
    expect(store.sourceEnabled('hongguo'), isFalse);
    expect(store.source, isNot('hongguo'));
  }, skip: !allSourcesEnabled);

  testWidgets('viewers see the switches greyed out', (tester) async {
    final store = await pumpApp(tester, initial: viewerPreferences);
    await _openSources(tester);
    expect(find.text('需要管理员才能开启或关闭站源'), findsOneWidget);
    expect(tester.widget<Switch>(_switch('黄豆')).onChanged, isNull);

    await tester.tap(find.text('黄豆'));
    await settle(tester);
    expect(store.sourceEnabled('huangdou'), isFalse);
  }, skip: !allSourcesEnabled);
}
