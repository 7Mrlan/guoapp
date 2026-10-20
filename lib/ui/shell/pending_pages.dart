import 'package:flutter/material.dart';

import '../../local_store.dart';
import '../../models.dart';
import '../app_scope.dart';
import '../settings/appearance_screen.dart';
import '../widgets/cover_image.dart';
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

class PendingDetailPage extends StatelessWidget {
  const PendingDetailPage({super.key, required this.drama});
  final Drama drama;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(drama.title)),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            SizedBox(
              width: 120,
              height: 180,
              child: DramaCover(drama: drama, details: false),
            ),
            Text(
              drama.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '「详情」正在重建',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PendingMinePage extends StatelessWidget {
  const PendingMinePage({super.key, required this.store});
  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    final television = AppScope.of(context).television;
    final inset = television ? televisionInset : 16.0;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (!television) const PageHeader(title: '我的'),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(inset, 8, inset, 24),
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
            ),
          ],
        ),
      ),
    );
  }
}
