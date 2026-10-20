import 'package:duanju_app/ui/explore/explore_page.dart';
import 'package:duanju_app/ui/settings/appearance_screen.dart';
import 'package:duanju_app/ui/widgets/focus_ring.dart';
import 'package:duanju_app/ui/widgets/group_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

const _tabs = ['explore', 'follow', 'mine'];

void main() {
  group('phone', () {
    testWidgets('pages cover the bottom bar, back walks home to explore', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.byType(NavigationBar), findsOneWidget);

      await openAppearance(tester);
      expect(find.byType(NavigationBar), findsNothing);

      expect(await systemBack(tester), isTrue);
      expect(find.byType(AppearanceScreen), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);

      expect(await systemBack(tester), isTrue);
      expect(find.byType(ExplorePage), findsOneWidget);
      expect(await systemBack(tester), isFalse);
    });
  });

  group('wide', () {
    testWidgets('pages open beside the side bar and stay in their tab', (
      tester,
    ) async {
      await pumpApp(tester, size: wideSize);
      await openAppearance(tester);
      expect(navItem('explore'), findsOneWidget);

      await openTab(tester, 'explore');
      expect(find.byType(AppearanceScreen), findsNothing);
      await openTab(tester, 'mine');
      expect(find.byType(AppearanceScreen), findsOneWidget);

      await systemBack(tester);
      expect(find.byType(AppearanceScreen), findsNothing);
      expect(find.text('外观'), findsOneWidget);
    });

    testWidgets('the side bar remembers collapsing, narrow windows force it', (
      tester,
    ) async {
      final store = await pumpApp(tester, size: wideSize);
      await tester.tap(find.byTooltip('收起侧栏'));
      await settle(tester);
      expect(store.sideBarExpanded, isFalse);
      expect(find.text('追剧'), findsNothing);

      await tester.tap(find.byTooltip('展开侧栏'));
      await settle(tester);
      expect(store.sideBarExpanded, isTrue);

      tester.view.physicalSize = const Size(720, 800);
      await settle(tester);
      expect(find.text('追剧'), findsNothing);
      expect(find.byTooltip('展开侧栏'), findsNothing);
      expect(find.byTooltip('收起侧栏'), findsNothing);
    });

    for (final mode in ['standard', 'pad']) {
      testWidgets(
        'side bar metrics follow platform and $mode mode, icons stay put',
        (tester) async {
          final desktop =
              defaultTargetPlatform == TargetPlatform.windows &&
              mode == 'standard';
          await pumpApp(tester, size: wideSize, mode: mode);
          final bar = find.byKey(const ValueKey('side-bar'));
          List<Offset> icons() => [
            for (final tab in _tabs)
              tester.getCenter(
                find.descendant(of: navItem(tab), matching: find.byType(Icon)),
              ),
          ];
          final expanded = icons();
          expect(tester.getSize(bar).width, desktop ? 240 : 232);
          expect(tester.getSize(navItem('follow')).height, desktop ? 48 : 56);

          await tester.tap(find.byTooltip('收起侧栏'));
          await settle(tester);
          expect(tester.getSize(bar).width, desktop ? 80 : 88);
          expect(
            tester.getSize(navItem('follow')),
            Size(56, desktop ? 48 : 56),
          );
          expect(icons(), expanded);
          expect(
            tester.getCenter(find.byIcon(Icons.menu_rounded)).dx,
            expanded.first.dx,
          );
        },
        variant: TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.windows,
        }),
      );
    }

    for (final mode in ['television', 'phone']) {
      testWidgets('a page left open covers the $mode navigation', (
        tester,
      ) async {
        final store = await pumpApp(tester, size: wideSize);
        await openAppearance(tester);
        if (mode == 'television') {
          await store.setDisplayMode('television');
        } else {
          tester.view.physicalSize = phoneSize;
        }
        await settle(tester);
        expect(find.byType(AppearanceScreen), findsOneWidget);
        expect(navItem('explore'), findsNothing);

        await systemBack(tester);
        expect(find.byType(AppearanceScreen), findsNothing);
        expect(navItem('explore'), findsOneWidget);
      });
    }
  });

  group('television', () {
    testWidgets('tabs keep focus and the outline when selected', (
      tester,
    ) async {
      await pumpApp(tester, size: televisionSize, mode: 'television');
      tabFocus(tester, 'explore').requestFocus();
      await settle(tester);

      for (final tab in ['mine', 'explore', 'follow']) {
        final from = _tabs.indexWhere(
          (name) => tabFocus(tester, name).hasPrimaryFocus,
        );
        final to = _tabs.indexOf(tab);
        for (var step = 0; step < (to - from).abs(); step++) {
          await tester.sendKeyEvent(
            to > from
                ? LogicalKeyboardKey.arrowRight
                : LogicalKeyboardKey.arrowLeft,
          );
          await settle(tester);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await settle(tester);
        expect(tabFocus(tester, tab).hasPrimaryFocus, isTrue, reason: tab);

        final ring = find.ancestor(
          of: navItem(tab),
          matching: find.byType(FocusOutline),
        );
        expect(tester.widget<FocusOutline>(ring).visible, isTrue, reason: tab);
        expect(
          tester.getTopLeft(
            find.descendant(
              of: find.byType(CompositedTransformFollower),
              matching: find.byType(CustomPaint),
            ),
          ),
          offsetMoreOrLessEquals(tester.getTopLeft(ring), epsilon: 0.5),
          reason: tab,
        );
      }
    });

    testWidgets('focus moves from a page back up to the tabs', (tester) async {
      await pumpApp(tester, size: televisionSize, mode: 'television');
      await openTab(tester, 'mine');
      tabFocus(tester, 'mine').requestFocus();
      await settle(tester);
      expect(
        tester.getTopLeft(find.byType(GroupCard)).dx,
        tester.getTopLeft(navItem('explore')).dx,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
      expect(focusHolds(tester, find.text('外观')), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settle(tester);
      expect(_tabs.any((tab) => tabFocus(tester, tab).hasPrimaryFocus), isTrue);
    });

    testWidgets('back from another tab returns to explore and its tab', (
      tester,
    ) async {
      await pumpApp(tester, size: televisionSize, mode: 'television');
      await openTab(tester, 'mine');

      expect(await systemBack(tester), isTrue);
      expect(find.byType(ExplorePage), findsOneWidget);
      expect(tabFocus(tester, 'explore').hasPrimaryFocus, isTrue);
    });
  });
}
