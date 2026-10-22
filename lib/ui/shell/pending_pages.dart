import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../widgets/page_header.dart';
import '../widgets/status_view.dart';

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
