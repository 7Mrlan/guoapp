import 'package:duanju_app/ui/app_scope.dart';
import 'package:duanju_app/ui/widgets/category_tabs.dart';
import 'package:duanju_app/ui/widgets/choice_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

Widget _tabs(int count, {bool television = false}) => MaterialApp(
  home: AppScope(
    repository: FakeRepository(),
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
          onSelected: (_) {},
          onShowAll: (_) {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('all categories appears only when the tabs overflow', (
    tester,
  ) async {
    await tester.pumpWidget(_tabs(3));
    await tester.pump();
    expect(find.byTooltip('全部分类'), findsNothing);

    await tester.pumpWidget(_tabs(24));
    await tester.pump();
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
}
