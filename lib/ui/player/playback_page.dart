import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../local_store.dart';
import '../../playback_session.dart';
import '../app_scope.dart';
import 'landscape_player_page.dart';
import 'playback_handle.dart';
import 'player_page.dart';
import 'portrait_player_page.dart';

/// 播放页外壳：持有播放器，按当前宽度和视频宽高选用版式，改变窗口大小时不中断播放。
class PlaybackPage extends StatefulWidget {
  const PlaybackPage({super.key, required this.store, required this.handle});
  final LocalStore store;
  final PlaybackHandle handle;

  @override
  State<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends State<PlaybackPage> {
  late bool _wideVideo = _measure();

  PlaybackSession get _session => widget.handle.session;

  bool _measure() => _session.aspectKnown && _session.aspectRatio >= 1;

  @override
  void initState() {
    super.initState();
    _session.addListener(_changed);
  }

  @override
  void dispose() {
    _session.removeListener(_changed);
    widget.handle.dispose();
    super.dispose();
  }

  void _changed() {
    final wide = _measure();
    if (wide != _wideVideo) setState(() => _wideVideo = wide);
  }

  // 平板和电视的播放版式还没做，先用竖屏页。手机按最短边判断，转成横屏也仍是手机。
  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return AppScope.formFactorOf(context) == FormFactor.phone
          ? PortraitPlayerPage(store: widget.store, handle: widget.handle)
          : PlayerPage(store: widget.store, handle: widget.handle);
    }
    final phone =
        !AppScope.of(context).television &&
        MediaQuery.sizeOf(context).shortestSide < 600;
    return phone && _wideVideo
        ? LandscapePlayerPage(store: widget.store, handle: widget.handle)
        : PortraitPlayerPage(store: widget.store, handle: widget.handle);
  }
}
