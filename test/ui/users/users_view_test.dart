import 'package:duanju_app/ui/settings/settings_page.dart';
import 'package:duanju_app/ui/users/unlock_page.dart';
import 'package:duanju_app/ui/users/user_editor.dart';
import 'package:duanju_app/ui/users/users_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fakes.dart';

final _family = <String, Object>{
  ...viewerPreferences,
  'activeProfile': 'default',
  'forceLogin': false,
};

Future<String> _hasher(String pin, String salt) async => 'f' * 64;

Finder _tile(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(ListTile));

Finder _field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

Future<void> _openUsers(WidgetTester tester) async {
  await openSettings(tester);
  await openSettingsGroup(tester, '用户');
}

void main() {
  testWidgets('an admin without a password must set one before adding users', (
    tester,
  ) async {
    final store = await pumpApp(tester, size: wideSize, pinHasher: _hasher);
    await _openUsers(tester);
    expect(find.text('当前'), findsOneWidget);
    expect(find.text('需要先为管理员设置密码'), findsOneWidget);
    expect(tester.widget<ListTile>(_tile('添加用户')).enabled, isFalse);

    await tester.tap(find.byTooltip('编辑 管理员'));
    await settle(tester);
    expect(find.text('编辑管理员'), findsOneWidget);
    expect(find.text('允许访问的站源'), findsNothing);
    expect(find.text('删除用户'), findsNothing);

    await tester.enterText(_field('设置密码'), '123456');
    await tester.enterText(_field('再次输入密码'), '654321');
    await tester.tap(find.text('保存'));
    await settle(tester);
    expect(find.text('两次输入的密码不一致'), findsOneWidget);
    expect(store.profile.protected, isFalse);

    await tester.enterText(_field('再次输入密码'), '123456');
    await tester.tap(find.text('保存'));
    await settle(tester);
    expect(store.profile.protected, isTrue);
    expect(find.byType(UserEditor), findsNothing);
    expect(tester.widget<ListTile>(_tile('添加用户')).enabled, isTrue);
  });

  testWidgets('an admin adds, edits and deletes a user', (tester) async {
    final store = await pumpApp(
      tester,
      size: wideSize,
      initial: _family,
      pinHasher: _hasher,
    );
    await _openUsers(tester);

    await tester.tap(find.text('添加用户'));
    await settle(tester);
    await tester.enterText(_field('用户名'), '小满');
    await tester.tap(find.text('允许下载'));
    await settle(tester);
    await tester.tap(find.text('保存'));
    await settle(tester);
    final added = store.profiles.firstWhere((p) => p.name == '小满');
    expect(added.download, isFalse);
    expect(added.protected, isFalse);
    expect(added.sources, contains('hongguo'));
    expect(find.text('小满'), findsOneWidget);

    await tester.tap(find.byTooltip('编辑 访客'));
    await settle(tester);
    await tester.tap(find.text('删除用户'));
    await settle(tester);
    await tester.tap(find.text('删除'));
    await settle(tester);
    expect(store.profiles.map((p) => p.name), isNot(contains('访客')));
    expect(find.byType(UserEditor), findsNothing);
  });

  testWidgets('switching users resets the app to the first tab', (
    tester,
  ) async {
    final store = await pumpApp(tester, initial: _family);
    await _openUsers(tester);
    expect(find.byTooltip('编辑 访客'), findsOneWidget);

    await tester.tap(find.text('访客'));
    await settle(tester);
    await settle(tester);
    expect(store.profile.id, 'viewer');
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.byType(UsersView), findsNothing);
  });

  testWidgets('a protected user asks for the password', (tester) async {
    final store = await pumpApp(
      tester,
      initial: {..._family, 'activeProfile': 'viewer'},
    );
    await _openUsers(tester);
    expect(find.byTooltip('编辑 访客'), findsNothing);
    expect(find.text('添加用户'), findsNothing);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
    expect(find.text('锁定当前用户'), findsNothing);

    await tester.tap(find.text('管理员'));
    await settle(tester);
    expect(find.text('登录 管理员'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'wrong-pin');
    await tester.tap(find.text('登录'));
    for (var i = 0; i < 100 && find.text('密码不正确').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(find.text('密码不正确'), findsOneWidget);
    expect(store.profile.id, 'viewer');
  });

  testWidgets('a protected user can lock the app', (tester) async {
    final store = await pumpApp(tester, size: wideSize, initial: _family);
    await _openUsers(tester);
    await tester.tap(find.text('锁定当前用户'));
    await settle(tester);
    expect(store.locked, isTrue);
    expect(find.byType(UnlockPage), findsOneWidget);
    expect(find.text('选择用户'), findsOneWidget);
  });

  testWidgets('the user card opens the users page', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'mine');
    await tester.tap(find.text('管理员'));
    await settle(tester);
    expect(find.byType(UsersView), findsOneWidget);
    expect(find.byType(SettingsPage), findsNothing);
  });
}
