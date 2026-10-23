import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import '../../local_store.dart';
import '../../models.dart';
import '../../playback_session.dart';
import '../app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_image.dart';
import '../widgets/focus_ring.dart';
import 'player_surface.dart';

const _columns = 5;
const _cellHeight = 48.0;
const _cellGap = 8.0;
const _rowExtent = _cellHeight + _cellGap;
const _listTop = 14.0;
const _panelWidth = 360.0;

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.store,
    required this.detail,
    required this.index,
    this.position = 0,
  });
  final LocalStore store;
  final DramaDetail detail;
  final int index;
  final double position;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  final _player = Player(
    configuration: const PlayerConfiguration(
      bufferSize: 32 * 1024 * 1024,
      logLevel: MPVLogLevel.error,
    ),
  );
  late final _video = VideoController(_player);
  final _focus = FocusNode(debugLabel: 'player');
  final _surfaceKey = GlobalKey();
  final _scroll = ScrollController();
  final _hint = ValueNotifier('');
  final _selected = <int>{};
  Timer? _hintTimer;
  PlaybackSession? _session;
  late bool _wide = widget.store.playerWide;
  bool _fullscreen = false;
  bool _seekHeld = false;
  bool _selecting = false;
  bool? _dragAdds;
  int _dragAnchor = 0;
  Set<int> _dragBase = const {};
  Offset? _dragPoint;
  Timer? _autoScroll;
  double _gridWidth = 0;
  double _gridHeight = 0;
  int _revealed = -1;

  PlaybackSession get _playback => _session!;
  Drama get _drama => widget.detail.drama;
  List<Episode> get _episodes => widget.detail.episodes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _session ??= PlaybackSession(
      repository: AppScope.of(context).repository,
      store: widget.store,
      detail: widget.detail,
      player: _player,
      index: widget.index,
      position: widget.position,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hintTimer?.cancel();
    _hint.dispose();
    _autoScroll?.cancel();
    _scroll.dispose();
    _focus.dispose();
    _session?.dispose();
    if (_fullscreen) unawaited(_setFullScreen(false));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _session?.setForeground(
      state == AppLifecycleState.resumed ||
          defaultTargetPlatform == TargetPlatform.windows &&
              state == AppLifecycleState.inactive,
    );
  }

  bool get _canDownload =>
      AppScope.of(context).repository.supportsDownloads &&
      widget.store.canDownload;

  bool get _roomy => MediaQuery.sizeOf(context).width - 32 >= 840;

  Future<void> _setFullScreen(bool value) =>
      windowManager.setFullScreen(value).catchError((Object _) {});

  Future<void> _toggleFullscreen() async {
    final next = !_fullscreen;
    setState(() => _fullscreen = next);
    _focus.requestFocus();
    await _setFullScreen(next);
  }

  void _toggleWide() {
    setState(() => _wide = !_wide);
    _focus.requestFocus();
    unawaited(widget.store.setPlayerWide(_wide).catchError((Object _) {}));
  }

  void _back() {
    if (_fullscreen) {
      unawaited(_toggleFullscreen());
    } else if (_selecting) {
      _endSelection();
    } else {
      unawaited(Navigator.maybePop(context));
    }
  }

  void _startSelection() {
    setState(() {
      _selecting = true;
      _selected.clear();
    });
    _focus.requestFocus();
  }

  void _endSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
      _dragAdds = null;
    });
    _focus.requestFocus();
  }

  void _download() {
    _endSelection();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('下载正在重建，暂时不能下载')));
  }

  void _say(String text) {
    _hintTimer?.cancel();
    _hint.value = text;
    _hintTimer = Timer(const Duration(milliseconds: 1200), () {
      _hint.value = '';
    });
  }

  void _seek(int seconds) {
    final target = _playback.seekBy(seconds);
    if (target == null) return;
    _say('${seconds > 0 ? '快进至' : '后退至'} ${formatClock(target)}');
  }

  void _volume(double volume) =>
      _say(volume == 0 ? '已静音' : '音量 ${volume.round()}%');

  void _episode(int direction) {
    final target = _playback.index + direction;
    if (target < 0) return _say('已经是第一集');
    if (target >= _episodes.length) return _say('已经是最后一集');
    unawaited(_playback.play(target));
    _say('第 ${_episodes[target].number} 集');
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;
    final down = event is KeyDownEvent;
    final repeat = down || event is KeyRepeatEvent;
    if (key == LogicalKeyboardKey.arrowRight && event is KeyUpEvent) {
      if (!_seekHeld) return KeyEventResult.ignored;
      _seekHeld = false;
      if (!_playback.endBoost()) _seek(5);
      return KeyEventResult.handled;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isAltPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      if (down) _back();
      return KeyEventResult.handled;
    }
    if (!_focus.hasPrimaryFocus) return KeyEventResult.ignored;
    switch (key) {
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        if (down) unawaited(_toggleFullscreen());
      case LogicalKeyboardKey.space || LogicalKeyboardKey.mediaPlayPause:
        if (down) _playback.togglePlayback();
      case LogicalKeyboardKey.arrowRight:
        if (down) {
          _seekHeld = true;
          _playback.beginBoost();
        }
      case LogicalKeyboardKey.arrowLeft:
        if (down) _seek(-5);
      case LogicalKeyboardKey.arrowUp:
        if (repeat) _volume(_playback.changeVolume(5));
      case LogicalKeyboardKey.arrowDown:
        if (repeat) _volume(_playback.changeVolume(-5));
      case LogicalKeyboardKey.keyM:
        if (down) _volume(_playback.toggleMute());
      case LogicalKeyboardKey.mediaTrackNext:
        if (down) _episode(1);
      case LogicalKeyboardKey.mediaTrackPrevious:
        if (down) _episode(-1);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark
        ? theme
        : AppTheme.build(
            theme.colorScheme.primary,
            Brightness.dark,
            television: false,
          );
    final surface = Theme(
      data: dark,
      child: ClipRRect(
        key: _surfaceKey,
        borderRadius: BorderRadius.circular(_fullscreen ? 0 : 16),
        child: ColoredBox(
          color: Colors.black,
          child: PlayerSurface(
            session: _playback,
            video: _video,
            hint: _hint,
            fullscreen: _fullscreen,
            wide: _wide,
            onFullscreen: () => unawaited(_toggleFullscreen()),
            onWide: _toggleWide,
            onSurface: _focus.requestFocus,
          ),
        ),
      ),
    );
    final panel = _roomy && (!_wide || _selecting);
    if (!panel) _revealed = -1;
    return PopScope(
      canPop: !_fullscreen && !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: KeyboardControls(
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _key,
          child: Scaffold(
            backgroundColor: _fullscreen
                ? Colors.black
                : theme.colorScheme.surface,
            body: _fullscreen
                ? surface
                : SafeArea(
                    child: ListenableBuilder(
                      listenable: _playback,
                      builder: (context, _) => Column(
                        children: [
                          _header(),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: surface),
                                  if (panel) ...[
                                    const SizedBox(width: 16),
                                    SizedBox(
                                      width: _panelWidth,
                                      child: _panel(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
        child: Row(
          spacing: 8,
          children: [
            IconButton(
              onPressed: _back,
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(fixedSize: const Size.square(44)),
            ),
            Expanded(
              child: Text(
                '${_drama.title} · 第 ${_playback.episode.number} 集',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_selecting) ...[
              Text(
                '已选 ${_selected.length} 集',
                style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
              ),
              TextButton(onPressed: _endSelection, child: const Text('取消')),
              TextButton(
                onPressed: () => setState(() {
                  _selected.length == _episodes.length
                      ? _selected.clear()
                      : _selected.addAll(
                          List.generate(_episodes.length, (index) => index),
                        );
                }),
                child: Text(
                  _selected.length == _episodes.length ? '取消全选' : '全选',
                ),
              ),
              FilledButton.icon(
                onPressed: _selected.isEmpty ? null : _download,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('下载'),
              ),
            ] else
              Semantics(
                label: '下载选集',
                button: true,
                excludeSemantics: true,
                child: IconButton(
                  onPressed: _canDownload && _roomy ? _startSelection : null,
                  icon: const Icon(Icons.download_rounded),
                  style: IconButton.styleFrom(fixedSize: const Size.square(44)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _panel() {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: colors.surfaceContainerLow,
        child: _episodeList(),
      ),
    );
  }

  double get _cellWidth =>
      (_gridWidth - 32 - _cellGap * (_columns - 1)) / _columns;

  int? _hit(Offset point, {bool exact = false}) {
    if (_episodes.isEmpty || !_scroll.hasClients) return null;
    final pitch = _cellWidth + _cellGap;
    final x = point.dx - 16;
    final y = point.dy + _scroll.offset - _listTop;
    if (exact &&
        (x < 0 ||
            y < 0 ||
            x >= pitch * _columns ||
            x % pitch > _cellWidth ||
            y % _rowExtent > _cellHeight)) {
      return null;
    }
    final rows = (_episodes.length / _columns).ceil();
    final column = (x / pitch).floor().clamp(0, _columns - 1);
    final row = (y / _rowExtent).floor().clamp(0, rows - 1);
    final index = row * _columns + column;
    if (index < _episodes.length) return index;
    return exact ? null : _episodes.length - 1;
  }

  void _mark(int index) {
    final adds = _dragAdds;
    if (adds == null) return;
    final first = index < _dragAnchor ? index : _dragAnchor;
    final last = index < _dragAnchor ? _dragAnchor : index;
    final range = [for (var item = first; item <= last; item++) item];
    setState(() {
      _selected
        ..clear()
        ..addAll(_dragBase);
      adds ? _selected.addAll(range) : _selected.removeAll(range);
    });
  }

  void _dragStart(Offset point) {
    final index = _hit(point, exact: true);
    if (index == null) return;
    _dragAdds = !_selected.contains(index);
    _dragAnchor = index;
    _dragBase = Set.of(_selected);
    _dragPoint = point;
    _mark(index);
  }

  void _dragMove(Offset point) {
    if (_dragAdds == null) return;
    _dragPoint = point;
    final index = _hit(point);
    if (index != null) _mark(index);
    if (_edgeSpeed(point.dy) != 0) {
      _autoScroll ??= Timer.periodic(
        const Duration(milliseconds: 16),
        (_) => _autoScrollTick(),
      );
    }
  }

  void _dragEnd() {
    _dragAdds = null;
    _dragPoint = null;
    _autoScroll?.cancel();
    _autoScroll = null;
  }

  double _edgeSpeed(double y) {
    const zone = 64.0;
    final depth = y < zone
        ? y - zone
        : y > _gridHeight - zone
        ? y - (_gridHeight - zone)
        : 0.0;
    if (depth == 0) return 0;
    final t = (depth.abs() / zone).clamp(0.0, 2.0) / 2;
    return depth.sign * (120 + 1700 * t * t);
  }

  void _autoScrollTick() {
    final point = _dragPoint;
    final speed = point == null ? 0.0 : _edgeSpeed(point.dy);
    if (speed == 0 || !_scroll.hasClients) {
      _autoScroll?.cancel();
      _autoScroll = null;
      return;
    }
    final position = _scroll.position;
    final next = (position.pixels + speed * .016).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == position.pixels) return;
    _scroll.jumpTo(next);
    final index = _hit(point!);
    if (index != null) _mark(index);
  }

  void _reveal({required bool animate}) {
    if (!mounted || !_scroll.hasClients) return;
    final top = _listTop + _playback.index ~/ _columns * _rowExtent;
    final position = _scroll.position;
    final view = position.viewportDimension;
    if (top >= position.pixels && top + _cellHeight <= position.pixels + view) {
      return;
    }
    final target = (top - (view - _cellHeight) / 3).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (animate) {
      unawaited(
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  Widget _episodeList() => LayoutBuilder(
    builder: (context, constraints) {
      _gridWidth = constraints.maxWidth;
      _gridHeight = constraints.maxHeight;
      if (_revealed != _playback.index) {
        final animate = _revealed >= 0;
        _revealed = _playback.index;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _reveal(animate: animate),
        );
      }
      return Listener(
        onPointerDown: _selecting
            ? (event) => _dragStart(event.localPosition)
            : null,
        onPointerMove: _selecting
            ? (event) => _dragMove(event.localPosition)
            : null,
        onPointerUp: (_) => _dragEnd(),
        onPointerCancel: (_) => _dragEnd(),
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, _listTop, 16, 8),
          itemExtent: _rowExtent,
          itemCount: (_episodes.length / _columns).ceil(),
          itemBuilder: (context, row) => Padding(
            padding: const EdgeInsets.only(bottom: _cellGap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: _cellGap,
              children: [
                for (
                  var index = row * _columns;
                  index < (row + 1) * _columns;
                  index++
                )
                  Expanded(
                    child: index < _episodes.length
                        ? _EpisodeCell(
                            episode: _episodes[index],
                            current: index == _playback.index,
                            watched: index < _playback.index,
                            selected: _selecting
                                ? _selected.contains(index)
                                : null,
                            onPressed: _selecting
                                ? null
                                : () {
                                    if (index != _playback.index) {
                                      unawaited(_playback.play(index));
                                    }
                                  },
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _EpisodeCell extends StatelessWidget {
  const _EpisodeCell({
    required this.episode,
    required this.current,
    required this.watched,
    required this.selected,
    required this.onPressed,
  });
  final Episode episode;
  final bool current;
  final bool watched;
  final bool? selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = current
        ? colors.onPrimaryContainer
        : watched
        ? colors.onSurfaceVariant
        : colors.onSurface;
    final radius = BorderRadius.circular(12);
    return Semantics(
      button: true,
      selected: selected ?? current,
      label: '第 ${episode.number} 集${episode.vip ? '，VIP' : ''}',
      excludeSemantics: true,
      child: Material(
        color: current
            ? colors.primaryContainer
            : theme.brightness == Brightness.dark
            ? colors.surfaceContainerHigh
            : colors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: selected == true
              ? BorderSide(color: colors.primary, width: 2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 4,
                children: [
                  if (current)
                    Icon(Icons.equalizer_rounded, size: 14, color: foreground),
                  Text(
                    '${episode.number}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                      color: foreground,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              if (episode.vip)
                const Positioned(
                  right: 0,
                  top: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: vipGold,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(6),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      child: Text(
                        'VIP',
                        style: TextStyle(
                          fontSize: 9,
                          height: 12 / 9,
                          fontWeight: FontWeight.w800,
                          color: onVipGold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
