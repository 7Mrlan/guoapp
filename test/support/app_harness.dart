import 'package:duanju_app/core_bridge.dart';
import 'package:duanju_app/local_store.dart';
import 'package:duanju_app/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const phoneSize = Size(390, 844);
const wideSize = Size(1280, 800);
const televisionSize = Size(960, 540);

Future<LocalStore> pumpApp(
  WidgetTester tester, {
  Size size = phoneSize,
  String mode = 'standard',
  AppRepository? repository,
  Map<String, Object> initial = const {},
  Future<void> Function(LocalStore store)? prepare,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = await openStore(initial);
  await store.setDisplayMode(mode);
  await prepare?.call(store);
  await tester.pumpWidget(
    DuanjuApp(repository: repository ?? FakeRepository(), store: store),
  );
  await settle(tester);
  return store;
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Finder navItem(String tab) => find.byKey(ValueKey('nav-$tab'));

Future<void> openTab(WidgetTester tester, String tab) async {
  await tester.tap(navItem(tab));
  await settle(tester);
}

Future<void> openSettings(WidgetTester tester) async {
  await openTab(tester, 'mine');
  await tester.tap(find.text('设置'));
  await settle(tester);
}

Future<void> openAppearance(WidgetTester tester) async {
  await openSettings(tester);
  await openSettingsGroup(tester, '外观');
}

Future<void> openSettingsGroup(WidgetTester tester, String label) async {
  final item = find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith('settings-'),
  );
  await tester.tap(
    item.evaluate().isEmpty
        ? find.text(label)
        : find.descendant(of: item, matching: find.text(label)),
  );
  await settle(tester);
}

Future<bool> systemBack(WidgetTester tester) async {
  final handled = await tester.binding.handlePopRoute();
  await tester.pump();
  await settle(tester);
  return handled;
}

FocusNode tabFocus(WidgetTester tester, String tab) =>
    tester.widget<InkWell>(navItem(tab)).focusNode!;

bool focusHolds(WidgetTester tester, Finder finder) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  var inside = false;
  tester.element(finder).visitAncestorElements((element) {
    inside = element == focused;
    return !inside;
  });
  return inside;
}
