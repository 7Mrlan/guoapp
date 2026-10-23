import 'package:duanju_app/ui/shell/app_shell.dart';
import 'package:duanju_app/ui/users/unlock_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fakes.dart';

void main() {
  testWidgets('a forced login opens the unlock page', (tester) async {
    final store = await pumpApp(
      tester,
      initial: {...viewerPreferences, 'activeProfile': 'default'},
    );
    expect(store.locked, isTrue);
    expect(find.byType(UnlockPage), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);

    await tester.tap(find.text('访客'));
    await settle(tester);
    expect(store.locked, isFalse);
    expect(store.profile.id, 'viewer');
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('a broken configuration offers recovery', (tester) async {
    final store = await pumpApp(tester, initial: {'profiles': '[]'});
    expect(store.configurationError, isNotNull);
    expect(find.text('需要恢复本地配置'), findsOneWidget);
    expect(find.text('从备份恢复'), findsOneWidget);
    expect(find.text('导出原始配置'), findsOneWidget);

    await tester.tap(find.text('重新读取'));
    await settle(tester);
    expect(find.byType(UnlockPage), findsOneWidget);
  });
}
