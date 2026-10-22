import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_build.dart';
import '../../local_store.dart';
import '../widgets/focus_ring.dart';

Future<String?> exportBackupFile(LocalStore store) async {
  final content = await store.exportBackup();
  final saved = await FilePicker.saveFile(
    fileName:
        '$appSlug-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json',
    bytes: Uint8List.fromList(utf8.encode(content)),
    mimeType: 'application/json',
  );
  return saved == null ? null : '备份已保存';
}

Future<String?> restoreBackupFile(
  BuildContext context,
  LocalStore store,
) async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (file == null || !context.mounted) return null;
  final size = await file.length();
  if (size == null || size > 8 * 1024 * 1024) {
    throw const FormatException('备份文件过大或无法读取');
  }
  final content = utf8.decode(await file.readAsBytes());
  final data = store.validateBackup(content);
  if (!context.mounted) return null;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('恢复备份？'),
      content: Text(
        '包含 ${(data['profiles'] as List).length} 个用户。将替换本机的用户、追剧、观看记录和偏好设置；已下载视频保留。恢复后使用备份内的管理员密码登录。',
      ),
      actions: [
        FocusRing(
          radius: 20,
          child: TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
        ),
        FocusRing(
          radius: 20,
          child: FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('恢复'),
          ),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) return null;
  final navigator = Navigator.of(context);
  await store.importBackup(content);
  navigator.popUntil((route) => route.isFirst);
  return null;
}
