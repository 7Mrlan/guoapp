import 'package:flutter/material.dart';

import '../widgets/status_view.dart';

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
