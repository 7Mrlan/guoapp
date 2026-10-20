import 'package:duanju_app/local_store.dart';
import 'package:duanju_app/ui/app.dart';
import 'package:duanju_app/ui/settings/appearance_screen.dart';
import 'package:duanju_app/ui/widgets/group_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

const _tabs = ['explore', 'rank', 'follow', 'mine'];
const _labels = {'explore': '发现', 'rank': '榜单', 'follow': '追剧', 'mine': '我的'};

Future<LocalStore> _open(
  WidgetTester tester,
  Size size, {
  String mode = 'standard',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final store = testStore(await SharedPreferences.getInstance());
  await store.setDisplayMode(mode);
  await tester.pumpWidget(
    DuanjuApp(repository: FixtureRepository(), store: store),
  );
  await _settle(tester);
  return store;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _tab(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(ValueKey('nav-$name')));
  await _settle(tester);
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await _settle(tester);
}

void main() {
  testWidgets('phone pages cover the bottom bar and back returns to explore', (
    tester,
  ) async {
    final store = await _open(tester, const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);

    await _tab(tester, 'mine');
    await tester.tap(find.text('外观'));
    await _settle(tester);
    expect(find.byType(AppearanceScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await _back(tester);
    expect(find.byType(AppearanceScreen), findsNothing);
    expect(find.text('组件预览'), findsOneWidget);

    await _back(tester);
    expect(find.text('「发现」正在重建'), findsOneWidget);
    store.dispose();
  });

  testWidgets('wide pages open beside the side bar and keep their tab', (
    tester,
  ) async {
    final store = await _open(tester, const Size(1280, 800));
    expect(find.text('榜单'), findsOneWidget);

    await _tab(tester, 'mine');
    await tester.tap(find.text('外观'));
    await _settle(tester);
    expect(find.byType(AppearanceScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-explore')), findsOneWidget);

    await _tab(tester, 'explore');
    expect(find.byType(AppearanceScreen), findsNothing);
    await _tab(tester, 'mine');
    expect(find.byType(AppearanceScreen), findsOneWidget);

    await _back(tester);
    expect(find.byType(AppearanceScreen), findsNothing);
    expect(find.text('组件预览'), findsOneWidget);
    store.dispose();
  });

  testWidgets('side bar remembers collapsing and narrow windows force it', (
    tester,
  ) async {
    final store = await _open(tester, const Size(1280, 800));
    await tester.tap(find.byTooltip('收起侧栏'));
    await _settle(tester);
    expect(store.sideBarExpanded, isFalse);
    expect(find.text('榜单'), findsNothing);
    expect(find.byTooltip('展开侧栏'), findsOneWidget);

    await tester.tap(find.byTooltip('展开侧栏'));
    await _settle(tester);
    expect(store.sideBarExpanded, isTrue);

    tester.view.physicalSize = const Size(720, 800);
    await _settle(tester);
    expect(find.text('榜单'), findsNothing);
    expect(find.byTooltip('展开侧栏'), findsNothing);
    expect(find.byTooltip('收起侧栏'), findsNothing);
    store.dispose();
  });

  for (final mode in ['standard', 'pad']) {
    testWidgets(
      'side bar sizes follow platform and display mode ($mode), '
      'icons stay put when collapsing',
      (tester) async {
        final desktop =
            defaultTargetPlatform == TargetPlatform.windows &&
            mode == 'standard';
        final store = await _open(tester, const Size(1280, 800), mode: mode);
        final bar = find.byKey(const ValueKey('side-bar'));
        Offset icon(String name) => tester.getCenter(
          find.descendant(
            of: find.byKey(ValueKey('nav-$name')),
            matching: find.byType(Icon),
          ),
        );
        final expandedIcons = [for (final name in _tabs) icon(name)];
        final menu = find.byIcon(Icons.menu_rounded);
        expect(tester.getCenter(menu).dx, expandedIcons.first.dx);
        expect(tester.getSize(bar).width, desktop ? 240 : 232);
        expect(
          tester.getSize(find.byKey(const ValueKey('nav-rank'))).height,
          desktop ? 48 : 56,
        );

        await tester.tap(find.byTooltip('收起侧栏'));
        await _settle(tester);
        expect(tester.getSize(bar).width, desktop ? 80 : 88);
        expect(
          tester.getSize(find.byKey(const ValueKey('nav-rank'))),
          desktop ? const Size(56, 48) : const Size(56, 56),
        );
        expect([for (final name in _tabs) icon(name)], expandedIcons);
        expect(tester.getCenter(menu).dx, expandedIcons.first.dx);
        store.dispose();
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.windows,
      }),
    );
  }

  testWidgets('television focus moves from a page back up to the tabs', (
    tester,
  ) async {
    final store = await _open(tester, const Size(960, 540), mode: 'television');
    await _tab(tester, 'mine');
    final mine = tester.widget<InkWell>(find.byKey(const ValueKey('nav-mine')));
    mine.focusNode!.requestFocus();
    await _settle(tester);

    bool focused(Finder finder) {
      final target = FocusManager.instance.primaryFocus?.context;
      var inside = false;
      tester.element(finder).visitAncestorElements((element) {
        inside = element == target;
        return !inside;
      });
      return inside;
    }

    expect(
      tester.getTopLeft(find.byType(GroupCard)).dx,
      tester.getTopLeft(find.byKey(const ValueKey('nav-explore'))).dx,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await _settle(tester);
    expect(focused(find.text('外观')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await _settle(tester);
    expect(_tabs.any((name) => focused(find.text(_labels[name]!))), isTrue);
    store.dispose();
  });

  testWidgets('television back returns to explore and focuses its tab', (
    tester,
  ) async {
    final store = await _open(tester, const Size(960, 540), mode: 'television');
    await _tab(tester, 'mine');
    expect(find.text('组件预览'), findsOneWidget);

    await _back(tester);
    expect(find.text('「发现」正在重建'), findsOneWidget);
    final explore = tester.widget<InkWell>(
      find.byKey(const ValueKey('nav-explore')),
    );
    expect(explore.focusNode!.hasPrimaryFocus, isTrue);
    store.dispose();
  });
}
