import 'package:flutter/material.dart';

import '../../local_store.dart';
import '../app_scope.dart';
import '../settings/appearance_screen.dart';
import '../widgets/group_card.dart';
import '../widgets/page_header.dart';
import '../widgets/status_view.dart';
import 'app_shell.dart';

class PendingTabPage extends StatelessWidget {
  const PendingTabPage({super.key, required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          if (!AppScope.of(context).television) PageHeader(title: label),
          Expanded(
            child: StatusView(title: '「$label」正在重建', icon: icon),
          ),
        ],
      ),
    ),
  );
}

class PendingPage extends StatelessWidget {
  const PendingPage({super.key, required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: StatusView(title: '「$title」正在重建', icon: icon),
  );
}

class PendingSettingsPage extends StatelessWidget {
  const PendingSettingsPage({super.key, required this.store});
  final LocalStore store;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('设置')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        GroupCard(
          children: [
            SettingsTile(
              icon: Icons.palette_outlined,
              title: '外观',
              onTap: () => openPage<void>(
                context,
                (_) => ListenableBuilder(
                  listenable: store,
                  builder: (context, _) => AppearanceScreen(
                    store: store,
                    systemColorAvailable: AppScope.of(
                      context,
                    ).systemColorAvailable,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
