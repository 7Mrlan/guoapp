import 'package:duanju_app/ui/search/search_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fakes.dart';

Future<void> _openSearch(WidgetTester tester) async {
  await tester.tap(find.byTooltip('在 红果 中搜索'));
  await settle(tester);
  expect(find.byType(SearchPage), findsOneWidget);
}

void main() {
  testWidgets('the wide search field opens results and remembers them', (
    tester,
  ) async {
    final store = await pumpApp(tester, size: wideSize);
    await tester.enterText(find.byType(TextField), '剧名');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    expect(find.byType(SearchPage), findsOneWidget);
    expect(find.text('搜到的剧'), findsOneWidget);
    expect(store.recentSearches, ['剧名']);
  });

  testWidgets('recent searches run again and can be cleared', (tester) async {
    final repository = FakeRepository();
    final store = await pumpApp(
      tester,
      repository: repository,
      prepare: (store) async {
        await store.rememberSearch('旧词');
        await store.rememberSearch('新词');
      },
    );
    await _openSearch(tester);
    expect(find.text('最近搜索'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, '旧词'));
    await settle(tester);
    expect(repository.catalogRequests.last, 'hongguo||旧词|1');
    expect(find.text('搜到的剧'), findsOneWidget);
    expect(store.recentSearches, ['旧词', '新词']);

    await systemBack(tester);
    await _openSearch(tester);
    await tester.tap(find.text('清空'));
    await settle(tester);
    expect(store.recentSearches, isEmpty);
    expect(find.text('最近搜索'), findsNothing);
  });

  testWidgets('suggestions follow typing and search when tapped', (
    tester,
  ) async {
    final repository = FakeRepository()..suggestionList = ['联想剧名'];
    await pumpApp(tester, repository: repository);
    await _openSearch(tester);

    await tester.enterText(find.byType(TextField), '联想');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    await tester.tap(find.text('联想剧名'));
    await settle(tester);
    expect(repository.catalogRequests.last, 'hongguo||联想剧名|1');
    expect(find.text('搜到的剧'), findsOneWidget);
  });
}
