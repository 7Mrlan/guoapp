import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../local_store.dart';
import '../app_scope.dart';
import 'playback_handle.dart';
import 'player_page.dart';
import 'portrait_player_page.dart';

/// 播放页外壳：持有播放器，按当前宽度选用竖屏或宽屏版式，改变窗口大小时不中断播放。
class PlaybackPage extends StatefulWidget {
  const PlaybackPage({super.key, required this.store, required this.handle});
  final LocalStore store;
  final PlaybackHandle handle;

  @override
  State<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends State<PlaybackPage> {
  @override
  void dispose() {
    widget.handle.dispose();
    super.dispose();
  }

  // 手机横屏版式还没做，非 Windows 平台先一律用竖屏页。
  @override
  Widget build(BuildContext context) =>
      defaultTargetPlatform != TargetPlatform.windows ||
          AppScope.formFactorOf(context) == FormFactor.phone
      ? PortraitPlayerPage(store: widget.store, handle: widget.handle)
      : PlayerPage(store: widget.store, handle: widget.handle);
}
