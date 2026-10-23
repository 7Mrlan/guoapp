import 'package:duanju_app/ui/explore/explore_page.dart';
import 'package:duanju_app/ui/mine/mine_page.dart';
import 'package:duanju_app/ui/settings/appearance_settings.dart';
import 'package:duanju_app/ui/settings/settings_page.dart';
import 'package:duanju_app/ui/shell/pending_pages.dart';
import 'package:duanju_app/ui/widgets/focus_ring.dart';
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
      expect(find.byType(AppearanceSettings), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);

      expect(await systemBack(tester), isTrue);
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
      expect(find.byType(AppearanceSettings), findsNothing);
      await openTab(tester, 'mine');
      expect(find.byType(AppearanceSettings), findsOneWidget);

      await systemBack(tester);
      expect(find.byType(SettingsPage), findsNothing);
      expect(navItem('explore'), findsOneWidget);
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
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(navItem('explore'), findsNothing);

        await systemBack(tester);
        expect(find.byType(SettingsPage), findsNothing);
        expect(navItem('explore'), findsOneWidget);
      });
    }
  });

  group('television', () {
    testWidgets('moving across the tabs switches pages', (tester) async {
      await pumpApp(tester, size: televisionSize, mode: 'television');
      tabFocus(tester, 'explore').requestFocus();
      await settle(tester);

      Color? fill(String tab) =>
          (tester
                      .widget<AnimatedContainer>(
                        find.ancestor(
                          of: navItem(tab),
                          matching: find.byType(AnimatedContainer),
                        ),
                      )
                      .decoration!
                  as ShapeDecoration)
              .color;
      double scale(String tab) => tester
          .widget<AnimatedScale>(
            find.ancestor(
              of: navItem(tab),
              matching: find.byType(AnimatedScale),
            ),
          )
          .scale;
      final colors = Theme.of(tester.element(navItem('explore'))).colorScheme;
      const pages = {
        'explore': ExplorePage,
        'follow': PendingTabPage,
        'mine': MinePage,
      };

      for (final (key, tab) in [
        (LogicalKeyboardKey.arrowRight, 'follow'),
        (LogicalKeyboardKey.arrowRight, 'mine'),
        (LogicalKeyboardKey.arrowLeft, 'follow'),
        (LogicalKeyboardKey.arrowLeft, 'explore'),
        (LogicalKeyboardKey.arrowRight, 'follow'),
        (LogicalKeyboardKey.arrowRight, 'mine'),
      ]) {
        await tester.sendKeyEvent(key);
        await settle(tester);
        expect(tabFocus(tester, tab).hasPrimaryFocus, isTrue, reason: tab);
        expect(find.byType(pages[tab]!).hitTestable(), findsOneWidget);
        expect(fill(tab), colors.primary, reason: tab);
        expect(scale(tab), 1.06, reason: tab);
        expect(
          find.ancestor(of: navItem(tab), matching: find.byType(FocusOutline)),
          findsNothing,
          reason: tab,
        );
      }

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
      expect(fill('mine'), colors.secondaryContainer);
      expect(scale('mine'), 1);
      expect(fill('explore')?.a, 0);
    });

    testWidgets('entering the tabs from a page lands on the current tab', (
      tester,
    ) async {
      await pumpApp(tester, size: televisionSize, mode: 'television');
      await openTab(tester, 'mine');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
      expect(tabFocus(tester, 'mine').hasPrimaryFocus, isFalse);

      tabFocus(tester, 'explore').requestFocus();
      await settle(tester);
      expect(tabFocus(tester, 'mine').hasPrimaryFocus, isTrue);
      expect(find.byType(MinePage).hitTestable(), findsOneWidget);
    });

    testWidgets('focus moves from a page back up to the tabs', (tester) async {
      await pumpApp(tester, size: televisionSize, mode: 'television');
      await openTab(tester, 'mine');
      tabFocus(tester, 'mine').requestFocus();
      await settle(tester);
      expect(
        tester.getTopLeft(find.text('最近观看')).dx,
        tester.getTopLeft(navItem('explore')).dx,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
      expect(focusHolds(tester, find.text('管理员')), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settle(tester);
      expect(tabFocus(tester, 'mine').hasPrimaryFocus, isTrue);
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
