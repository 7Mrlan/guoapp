import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../drama_details.dart';
import '../../local_store.dart';
import '../../models.dart';
import '../app_scope.dart';
import '../shell/app_shell.dart';
import '../shell/pending_pages.dart';
import '../widgets/cover_backdrop.dart';
import '../widgets/cover_image.dart';
import '../widgets/focus_ring.dart';
import '../widgets/status_view.dart';

class _Metrics {
  const _Metrics({
    required this.cover,
    required this.coverRadius,
    required this.title,
    required this.meta,
    required this.tag,
    required this.note,
    required this.body,
    required this.bodyHeight,
    required this.button,
    required this.buttonText,
    required this.buttonIcon,
    required this.section,
    required this.summary,
    required this.chip,
    required this.chipRadius,
    required this.chipText,
    required this.chipPadding,
    required this.cell,
    required this.cellRadius,
    required this.cellText,
    required this.cellGap,
    this.columns = 0,
    this.cellWidth = 0,
  });
  final Size cover;
  final double coverRadius;
  final double title;
  final double meta;
  final double tag;
  final double note;
  final double body;
  final double bodyHeight;
  final double button;
  final double buttonText;
  final double buttonIcon;
  final double section;
  final double summary;
  final double chip;
  final double chipRadius;
  final double chipText;
  final double chipPadding;
  final double cell;
  final double cellRadius;
  final double cellText;
  final double cellGap;
  final int columns;
  final double cellWidth;

  int columnsFor(double width) => columns > 0
      ? columns
      : math.max(4, ((width + cellGap) / (cellWidth + cellGap)).floor());
}

const _phone = _Metrics(
  cover: Size(120, 180),
  coverRadius: 12,
  title: 22,
  meta: 13,
  tag: 12,
  note: 12,
  body: 14,
  bodyHeight: 1.6,
  button: 52,
  buttonText: 16,
  buttonIcon: 24,
  section: 17,
  summary: 13,
  chip: 32,
  chipRadius: 8,
  chipText: 13,
  chipPadding: 14,
  cell: 54,
  cellRadius: 12,
  cellText: 16,
  cellGap: 10,
  columns: 5,
);

const _desktop = _Metrics(
  cover: Size(160, 240),
  coverRadius: 14,
  title: 28,
  meta: 14,
  tag: 12,
  note: 13,
  body: 14,
  bodyHeight: 1.7,
  button: 48,
  buttonText: 15,
  buttonIcon: 22,
  section: 18,
  summary: 13,
  chip: 32,
  chipRadius: 8,
  chipText: 13,
  chipPadding: 14,
  cell: 52,
  cellRadius: 12,
  cellText: 16,
  cellGap: 10,
  cellWidth: 72,
);

const _pad = _Metrics(
  cover: Size(150, 225),
  coverRadius: 14,
  title: 24,
  meta: 14,
  tag: 13,
  note: 13,
  body: 15,
  bodyHeight: 1.6,
  button: 56,
  buttonText: 16,
  buttonIcon: 24,
  section: 18,
  summary: 13,
  chip: 40,
  chipRadius: 10,
  chipText: 14,
  chipPadding: 16,
  cell: 56,
  cellRadius: 12,
  cellText: 17,
  cellGap: 12,
  cellWidth: 76,
);

class DetailPage extends StatefulWidget {
  const DetailPage({super.key, required this.store, required this.drama});
  final LocalStore store;
  final Drama drama;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  DramaDetails? _details;
  final _currentEpisode = GlobalKey();
  bool _expanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _details ??= DramaDetails(
      AppScope.of(context).repository,
      widget.store,
      widget.drama,
    );
  }

  @override
  void dispose() {
    _details?.dispose();
    super.dispose();
  }

  bool get _canDownload =>
      AppScope.of(context).repository.supportsDownloads &&
      widget.store.canDownload;

  bool get _ready => !_details!.loading && _details!.episodes.isNotEmpty;

  Future<void> _refresh() async {
    final details = _details!;
    await details.load();
    if (!mounted || details.error == null || details.episodes.isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(details.error!)));
  }

  void _play(int index) => openPage<void>(
    context,
    (_) => const PendingPage(title: '播放', icon: Icons.play_circle_outline),
  );

  void _download() => openPage<void>(
    context,
    (_) => const PendingPage(title: '下载选集', icon: Icons.download_rounded),
  );

  void _locate(int index) {
    _details!.selectGroup(index ~/ episodeGroupSize);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _currentEpisode.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.3,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _details!,
    builder: (context, _) {
      final details = _details!;
      if (!details.allowed) {
        return Scaffold(
          appBar: AppBar(),
          body: const StatusView(
            title: '当前用户无权访问',
            message: '请返回剧库后重新选择。',
            icon: Icons.lock_outline_rounded,
          ),
        );
      }
      final scope = AppScope.of(context);
      if (scope.television || MediaQuery.sizeOf(context).width < 840) {
        return _phonePage(details);
      }
      return _widePage(details, desktop: scope.desktop);
    },
  );

  PreferredSizeWidget _appBar(DramaDetails details, double height) {
    final colors = Theme.of(context).colorScheme;
    return AppBar(
      toolbarHeight: height,
      backgroundColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.scrolledUnder)
            ? colors.surfaceContainer
            : Colors.transparent,
      ),
      actions: [
        IconButton(
          tooltip: '更新剧集信息',
          onPressed: details.loading ? null : _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _withBackdrop(Drama drama, double height, Widget child) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: height,
          child: CoverBackdrop(
            drama: drama,
            sigma: 36,
            opacity: theme.brightness == Brightness.dark ? 0.55 : 0.45,
            overlay: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.92],
              colors: [surface.withValues(alpha: 0), surface],
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _phonePage(DramaDetails details) {
    const m = _phone;
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final drama = details.drama;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _appBar(details, kToolbarHeight),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _withBackdrop(
              drama,
              top + 250,
              Padding(
                padding: EdgeInsets.fromLTRB(20, top + 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 16,
                      children: [
                        _cover(drama, m),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _headline(details, m),
                          ),
                        ),
                      ],
                    ),
                    if (_stats(drama, m) case final stats?)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: stats,
                      ),
                    if (_tags(drama, m) case final tags?)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: tags,
                      ),
                    if (drama.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _description(drama, m),
                      ),
                    if (details.warning.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _warning(details.warning, m),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (details.episodes.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _episodeStatus(details),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: _episodeHeader(details, m),
              ),
            ),
            if (details.groupCount > 1)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: m.chip + 2,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                    itemCount: details.groupCount,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, group) =>
                        _groupChip(details, m, group),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              sliver: SliverToBoxAdapter(child: _grid(details, m)),
            ),
          ],
        ],
      ),
      bottomNavigationBar: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Row(
              spacing: 12,
              children: [
                if (_canDownload)
                  FocusRing(
                    radius: m.button / 2,
                    child: IconButton.filledTonal(
                      tooltip: '下载选集',
                      onPressed: _ready ? _download : null,
                      style: IconButton.styleFrom(
                        minimumSize: Size.square(m.button),
                      ),
                      icon: const Icon(Icons.download_rounded),
                    ),
                  ),
                Expanded(child: _playButton(details, m)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _widePage(DramaDetails details, {required bool desktop}) {
    final m = desktop ? _desktop : _pad;
    final top = MediaQuery.paddingOf(context).top + 64;
    final inset = desktop ? 32.0 : 24.0;
    final gap = desktop ? 40.0 : 32.0;
    final side = desktop ? 420.0 : 380.0;
    final drama = details.drama;
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: desktop ? 20 : 18,
          children: [
            _cover(drama, m),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _headline(details, m),
              ),
            ),
          ],
        ),
        if (_stats(drama, m) case final stats?)
          Padding(
            padding: EdgeInsets.only(top: desktop ? 18 : 16),
            child: stats,
          ),
        if (_tags(drama, m) case final tags?)
          Padding(padding: const EdgeInsets.only(top: 10), child: tags),
        Padding(
          padding: EdgeInsets.only(top: desktop ? 22 : 20),
          child: Row(
            spacing: 12,
            children: [
              Expanded(child: _playButton(details, m)),
              if (_canDownload) _downloadButton(m),
            ],
          ),
        ),
        if (drama.description.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: desktop ? 22 : 20),
            child: _description(drama, m),
          ),
        if (details.warning.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _warning(details.warning, m),
          ),
      ],
    );
    final episodes = details.episodes.isEmpty
        ? SizedBox(height: 320, child: _episodeStatus(details))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: desktop ? 44 : 48,
                child: _episodeHeader(details, m),
              ),
              if (details.groupCount > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var group = 0; group < details.groupCount; group++)
                        _groupChip(details, m, group),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _grid(details, m),
              ),
            ],
          );
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _appBar(details, 64),
      body: SingleChildScrollView(
        child: _withBackdrop(
          drama,
          top + 336,
          Padding(
            padding: EdgeInsets.fromLTRB(inset, top + 4, inset, 40),
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >= side + gap + 480
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: gap,
                      children: [
                        SizedBox(width: side, child: info),
                        Expanded(child: episodes),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: gap,
                      children: [info, episodes],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cover(Drama drama, _Metrics m) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(m.coverRadius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x4D000000),
          blurRadius: 26,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: SizedBox.fromSize(
      size: m.cover,
      child: DramaCover(drama: drama, radius: m.coverRadius),
    ),
  );

  Widget _headline(
    DramaDetails details,
    _Metrics m, {
    double spacing = 8,
    List<Widget> trailing = const [],
  }) {
    final drama = details.drama;
    TextStyle sub(double size) => TextStyle(
      fontSize: size,
      height: 1.5,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final meta = [
      SourceSite.byId(drama.source).name,
      if (drama.episodes > 0) '共 ${drama.episodes} 集',
      if (drama.releaseStatus.isNotEmpty && drama.releaseStatus != 'unknown')
        drama.releaseLabel,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing,
      children: [
        Text(
          drama.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: m.title,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        ),
        Text(meta.join(' · '), style: sub(m.meta)),
        if (drama.category.isNotEmpty) Text(drama.category, style: sub(m.meta)),
        if (drama.source == 'huangdou')
          Text(
            drama.vipStatus == null
                ? 'VIP 状态待补齐'
                : drama.vip
                ? 'VIP 内容'
                : '免费内容',
            style: sub(m.tag),
          ),
        ...trailing,
      ],
    );
  }

  Widget? _stats(Drama drama, _Metrics m) {
    final stats = [
      if (drama.onlineDate.isNotEmpty) '${drama.onlineDate} 上线',
      if (drama.views.isNotEmpty) '播放 ${drama.views}',
    ];
    if (stats.isEmpty) return null;
    return Text(
      stats.join(' · '),
      style: TextStyle(
        fontSize: m.note,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget? _tags(Drama drama, _Metrics m) {
    if (drama.tags.isEmpty) return null;
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in drama.tags.take(12))
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              child: Text(tag, style: TextStyle(fontSize: m.tag)),
            ),
          ),
      ],
    );
  }

  Widget _description(Drama drama, _Metrics m) {
    final colors = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: m.body,
      height: m.bodyHeight,
      color: colors.onSurfaceVariant,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: drama.description, style: style),
          maxLines: 3,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        final label = Text(_expanded ? '收起简介' : '展开简介');
        void toggle() => setState(() => _expanded = !_expanded);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              drama.description,
              maxLines: _expanded ? null : 3,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: style,
            ),
            if (overflows)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: toggle, child: label),
              ),
          ],
        );
      },
    );
  }

  Widget _warning(String text, _Metrics m) {
    final color = Theme.of(context).colorScheme.error;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.error_outline_rounded,
            size: m.note + 3,
            color: color,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: m.note, height: 1.5, color: color),
          ),
        ),
      ],
    );
  }

  Widget _playButton(DramaDetails details, _Metrics m) {
    final label = details.watch != null && details.episodes.isNotEmpty
        ? '继续播放 · 第 ${details.episodes[details.resumeIndex].number} 集'
        : '立即播放';
    return FocusRing(
      radius: m.button / 2,
      child: FilledButton.icon(
        key: const ValueKey('detail-play'),
        onPressed: _ready ? () => _play(details.resumeIndex) : null,
        style: FilledButton.styleFrom(
          minimumSize: Size(0, m.button),
          iconSize: m.buttonIcon,
          textStyle: TextStyle(
            fontSize: m.buttonText,
            fontWeight: FontWeight.w700,
          ),
        ),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _downloadButton(_Metrics m) => FocusRing(
    radius: m.button / 2,
    child: FilledButton.tonalIcon(
      onPressed: _ready ? _download : null,
      style: FilledButton.styleFrom(
        minimumSize: Size(0, m.button),
        iconSize: m.buttonIcon - 2,
        textStyle: TextStyle(
          fontSize: m.buttonText - 1,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: const Icon(Icons.download_rounded),
      label: const Text('下载选集'),
    ),
  );

  Widget _episodeStatus(DramaDetails details) {
    if (details.loading) return const StatusView.loading();
    return StatusView(
      title: details.error != null ? '剧集信息暂时不可用' : '暂时没有可播放的集数',
      message: details.error ?? '可以更新剧集信息后重试。',
      icon: Icons.error_outline_rounded,
      action: '重试',
      onAction: details.load,
    );
  }

  Widget _episodeTitle(DramaDetails details, _Metrics m) {
    final current = details.currentIndex;
    final summary = [
      '${details.episodes.length} 集',
      if (current != null) '当前第 ${details.episodes[current].number} 集',
    ].join(' · ');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '选集',
          style: TextStyle(fontSize: m.section, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Text(
          summary,
          style: TextStyle(
            fontSize: m.summary,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _episodeHeader(DramaDetails details, _Metrics m) => Row(
    children: [
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: _episodeTitle(details, m),
        ),
      ),
      if (details.currentIndex case final current?)
        TextButton(
          onPressed: () => _locate(current),
          child: const Text('定位当前'),
        ),
    ],
  );

  Widget _groupChip(DramaDetails details, _Metrics m, int group) => _GroupChip(
    label: details.groupLabel(group),
    selected: group == details.group,
    metrics: m,
    onPressed: () => details.selectGroup(group),
  );

  Widget _grid(DramaDetails details, _Metrics m) {
    final extent = math.max(
      m.cell,
      MediaQuery.textScalerOf(context).scale(m.cellText) + 28,
    );
    final current = details.currentIndex;
    final start = details.group * episodeGroupSize;
    final episodes = details.groupEpisodes;
    Widget cell(int offset) {
      final index = start + offset;
      final episode = episodes[offset];
      return _EpisodeCell(
        key: index == current
            ? _currentEpisode
            : ValueKey('episode-${episode.number}'),
        episode: episode,
        metrics: m,
        current: index == current,
        watched: current != null && index < current,
        onPressed: () => _play(index),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = m.columnsFor(constraints.maxWidth);
        return Column(
          spacing: m.cellGap,
          children: [
            for (var row = 0; row < episodes.length; row += columns)
              SizedBox(
                height: extent,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: m.cellGap,
                  children: [
                    for (var offset = row; offset < row + columns; offset++)
                      Expanded(
                        child: offset < episodes.length
                            ? cell(offset)
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.selected,
    required this.metrics,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final _Metrics metrics;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final m = metrics;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(m.chipRadius),
    );
    final padding = EdgeInsets.symmetric(horizontal: m.chipPadding);
    final size = Size(0, m.chip);
    return FocusRing(
      radius: m.chipRadius,
      child: selected
          ? FilledButton.tonal(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                shape: shape,
                padding: padding,
                minimumSize: size,
                textStyle: TextStyle(
                  fontSize: m.chipText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                shape: shape,
                padding: padding,
                minimumSize: size,
                foregroundColor: colors.onSurfaceVariant,
                side: BorderSide(color: colors.outlineVariant),
                textStyle: TextStyle(fontSize: m.chipText),
              ),
              child: Text(label),
            ),
    );
  }
}

class _EpisodeCell extends StatelessWidget {
  const _EpisodeCell({
    super.key,
    required this.episode,
    required this.metrics,
    required this.current,
    required this.watched,
    required this.onPressed,
  });
  final Episode episode;
  final _Metrics metrics;
  final bool current;
  final bool watched;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(metrics.cellRadius);
    return FocusRing(
      radius: metrics.cellRadius,
      child: Semantics(
        button: true,
        label: '第 ${episode.number} 集${episode.vip ? '，VIP' : ''}',
        excludeSemantics: true,
        child: Material(
          color: current ? colors.primaryContainer : colors.surfaceContainer,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Text(
                    '${episode.number}',
                    style: TextStyle(
                      fontSize: metrics.cellText,
                      fontWeight: current
                          ? FontWeight.w800
                          : watched
                          ? FontWeight.w400
                          : FontWeight.w600,
                      color: current
                          ? colors.onPrimaryContainer
                          : watched
                          ? colors.onSurfaceVariant
                          : colors.onSurface,
                    ),
                  ),
                ),
                if (episode.vip)
                  Positioned(
                    right: 5,
                    top: 4,
                    child: Text(
                      'VIP',
                      style: TextStyle(
                        fontSize: metrics.cellText - 7,
                        fontWeight: FontWeight.w800,
                        color: dark ? vipGold : const Color(0xFFB08200),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
