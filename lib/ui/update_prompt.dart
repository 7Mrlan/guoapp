import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_update.dart';
import '../local_store.dart';
import 'app_scope.dart';
import 'widgets/focus_ring.dart';

var _checked = false;

enum _UpdateChoice { mute, skip, dismiss, download }

Future<void> runStartupChecks(BuildContext context, LocalStore store) async {
  if (_checked) return;
  _checked = true;
  final repository = AppScope.of(context).repository;
  final String current;
  final AppUpdate update;
  try {
    current = await currentAppVersion();
    if (store.shareUsage) {
      unawaited(repository.reportUsage(current).catchError((_) {}));
    }
    if (!store.checkUpdates) return;
    final latest = await repository.checkUpdate(current);
    if (latest == null) return;
    update = latest;
  } catch (_) {
    return;
  }
  if (update.version == store.ignoredUpdate || !context.mounted) return;
  final choice = await showDialog<_UpdateChoice>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('发现新版本 ${update.version}'),
      content: Text('当前版本 $current。选「不再提醒」后可在设置 › 关于中重新打开检查更新。'),
      actions: [
        for (final (choice, label) in [
          (_UpdateChoice.mute, '不再提醒'),
          (_UpdateChoice.skip, '忽略此版本'),
          (_UpdateChoice.dismiss, '忽略'),
        ])
          FocusRing(
            radius: 20,
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext, choice),
              child: Text(label),
            ),
          ),
        FocusRing(
          radius: 20,
          child: FilledButton(
            autofocus: true,
            onPressed: () =>
                Navigator.pop(dialogContext, _UpdateChoice.download),
            child: const Text('更新'),
          ),
        ),
      ],
    ),
  );
  switch (choice) {
    case _UpdateChoice.mute:
      await store.setCheckUpdates(false);
    case _UpdateChoice.skip:
      await store.setIgnoredUpdate(update.version);
    case _UpdateChoice.download:
      if (context.mounted) await _openRelease(context, update.url);
    case _UpdateChoice.dismiss || null:
      return;
  }
}

Future<void> _openRelease(BuildContext context, String url) async {
  final opened = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  ).catchError((_) => false);
  if (opened) return;
  await Clipboard.setData(ClipboardData(text: url));
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法打开浏览器，链接已复制')));
  }
}
