import 'package:duanju_app/ui/app_scope.dart';
import 'package:duanju_app/ui/widgets/category_tabs.dart';
import 'package:duanju_app/ui/widgets/choice_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

Widget _tabs(
  int count, {
  ValueChanged<String>? onSelected,
  bool television = false,
}) => MaterialApp(
  home: AppScope(
    repository: FixtureRepository(),
    television: television,
    child: Scaffold(
      body: SizedBox(
        width: 390,
        child: CategoryTabs<String>(
          options: [
            for (var index = 0; index < count; index++)
              ChoiceOption('c$index', '分类$index'),
          ],
          selected: 'c0',
          onSelected: onSelected ?? (_) {},
          onShowAll: (_) {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('all categories button appears only when tabs overflow', (
    tester,
  ) async {
    await tester.pumpWidget(_tabs(3));
    await tester.pump();
    expect(find.byTooltip('全部分类'), findsNothing);

    await tester.pumpWidget(_tabs(24));
    await tester.pump();
    expect(find.byTooltip('全部分类'), findsOneWidget);
    expect(
      tester.getCenter(find.byTooltip('全部分类')).dx,
      greaterThan(tester.getCenter(find.text('分类0')).dx),
    );
  });

  testWidgets('television puts all categories before the tabs', (tester) async {
    await tester.pumpWidget(_tabs(24, television: true));
    await tester.pump();
    expect(
      tester.getCenter(find.byTooltip('全部分类')).dx,
      lessThan(tester.getCenter(find.text('分类0')).dx),
    );
  });

  testWidgets('tapping a tab reports its value', (tester) async {
    String? picked;
    await tester.pumpWidget(_tabs(3, onSelected: (value) => picked = value));
    await tester.tap(find.text('分类2'));
    expect(picked, 'c2');
  });

  testWidgets('underline sits on the bottom edge, away from the label', (
    tester,
  ) async {
    await tester.pumpWidget(_tabs(3));
    final bar = tester.getRect(find.byType(AnimatedContainer).first);
    final tabs = tester.getRect(find.byType(CategoryTabs<String>));
    final label = tester.getRect(find.text('分类0'));
    expect(bar.bottom, tabs.bottom - 1);
    expect(bar.top - label.bottom, greaterThan(8));
  });
}
