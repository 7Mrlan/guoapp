import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 应用内「日记」日志服务 — 实时记录播放与系统事件，方便在电视与手机端快速排查问题。
class DiaryService {
  static final List<String> _entries = <String>[];
  static const int maxEntries = 500;
  static String? nativeLogPath;
  static String _nativeText = '';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// 记录一条日记
  static void add(String message) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${(now.millisecond ~/ 100)}';
    final entry = '[$timeStr] $message';
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    revision.value++;
    debugPrint('[Diary] $message');
  }

  /// 获取当前所有日记副本
  static List<String> get entries => List<String>.unmodifiable([
    ..._entries,
    if (_nativeText.isNotEmpty) ..._nativeText.split('\n'),
  ]);

  /// 清空日记
  static void clear() {
    _entries.clear();
    _nativeText = '';
    revision.value++;
  }

  /// 获取合并后的完整日志文本
  static String get fullText => [_entries.join('\n'), _nativeText].join('\n');

  static Future<void> refreshNativeLogs() async {
    final path = nativeLogPath;
    if (path == null) return;
    final lines = <String>[];
    for (final name in ['$path.1', path]) {
      RandomAccessFile? file;
      try {
        file = await File(name).open();
        final size = await file.length();
        final start = size > 128 * 1024 ? size - 128 * 1024 : 0;
        await file.setPosition(start);
        final text = utf8.decode(
          await file.read(size - start),
          allowMalformed: true,
        );
        for (final line in text.split('\n').skip(start > 0 ? 1 : 0)) {
          try {
            final event = jsonDecode(line) as Map<String, dynamic>;
            if ((event['event'] as String? ?? '').startsWith('stream.')) {
              lines.add(line);
            }
          } catch (_) {}
        }
      } on FileSystemException {
        continue;
      } finally {
        await file?.close();
      }
    }
    _nativeText = lines
        .skip(lines.length > 500 ? lines.length - 500 : 0)
        .join('\n');
  }
}
