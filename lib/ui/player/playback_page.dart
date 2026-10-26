import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../app_device.dart';
import '../../local_store.dart';
import '../../playback_session.dart';
import '../app_scope.dart';
import 'landscape_player_page.dart';
import 'playback_handle.dart';
import 'player_page.dart';
import 'portrait_player_page.dart';

class PlaybackPage extends StatefulWidget {
  const PlaybackPage({super.key, required this.store, required this.handle});
  final LocalStore store;
  final PlaybackHandle handle;

  @override
  State<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends State<PlaybackPage> {
  final _padFullscreen = ValueNotifier(false);
  late bool _wideVideo = _measure();

  PlaybackSession get _session => widget.handle.session;

  bool _measure() => _session.aspectKnown && _session.aspectRatio >= 1;

  @override
  void initState() {
    super.initState();
    _session.addListener(_changed);
    _padFullscreen.addListener(_padFullscreenChanged);
  }

  @override
  void dispose() {
    _session.removeListener(_changed);
    if (_padFullscreen.value) _applyPadFullscreen(false);
    _padFullscreen.dispose();
    widget.handle.dispose();
    super.dispose();
  }

  void _changed() {
    final wide = _measure();
    if (wide != _wideVideo) setState(() => _wideVideo = wide);
  }

  void _padFullscreenChanged() {
    _applyPadFullscreen(_padFullscreen.value);
    setState(() {});
  }

  void _applyPadFullscreen(bool full) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      unawaited(windowManager.setFullScreen(full).catchError((Object _) {}));
      return;
    }
    unawaited(
      AppDevice.setPlayerOrientation(
        full ? PlayerOrientation.lockedLandscape : PlayerOrientation.auto,
      ),
    );
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        full ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      ).catchError((Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      if (AppScope.formFactorOf(context) == FormFactor.phone) {
        return PortraitPlayerPage(store: widget.store, handle: widget.handle);
      }
      return AppScope.of(context).desktop
          ? PlayerPage(store: widget.store, handle: widget.handle)
          : _padPage(context);
    }
    final touch = !AppScope.of(context).television;
    if (touch && MediaQuery.sizeOf(context).shortestSide >= 600) {
      return _padPage(context);
    }
    return touch && _wideVideo
        ? LandscapePlayerPage(store: widget.store, handle: widget.handle)
        : PortraitPlayerPage(store: widget.store, handle: widget.handle);
  }

  Widget _padPage(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (_padFullscreen.value || size.width > size.height) {
      return PlayerPage(
        store: widget.store,
        handle: widget.handle,
        padFullscreen: _padFullscreen,
      );
    }
    return _wideVideo
        ? LandscapePlayerPage(
            store: widget.store,
            handle: widget.handle,
            onFullscreen: () => _padFullscreen.value = true,
          )
        : PortraitPlayerPage(store: widget.store, handle: widget.handle);
  }
}
