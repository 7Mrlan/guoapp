import 'package:flutter/material.dart';

import '../../local_store.dart';
import '../app_scope.dart';
import '../preview/component_preview.dart';
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
                      SettingsTile(
                        icon: Icons.widgets_outlined,
                        title: '组件预览',
                        subtitle: '临时页面，使用假数据',
                        onTap: () => openPage<void>(
                          context,
                          (_) => const ComponentPreview(),
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
