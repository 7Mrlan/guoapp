import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models.dart';
import '../app_scope.dart';
import 'cover_image.dart';
import 'focus_ring.dart';

const _coverRadius = 12.0;

class _PosterButton extends StatefulWidget {
  const _PosterButton({
    required this.cover,
    required this.caption,
    required this.label,
    required this.onTap,
    this.onMore,
    this.focusNode,
    this.autofocus = false,
  });
  final Widget cover;
  final List<Widget> caption;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<_PosterButton> createState() => _PosterButtonState();
}

class _PosterButtonState extends State<_PosterButton> {
  bool _focused = false;
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final visible = focusVisible(_focused);
    final layer = _pressed ? 0.12 : (_hovered ? 0.08 : 0.0);
    final button = InkWell(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onTap: widget.onTap,
      onLongPress: widget.onMore,
      onSecondaryTap: widget.onMore,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHover: (hovered) => setState(() => _hovered = hovered),
      onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: FocusOutline(
              visible: visible,
              radius: _coverRadius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.cover,
                  IgnorePointer(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_coverRadius),
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: layer),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...widget.caption,
        ],
      ),
    );
    return Semantics(
      label: widget.label,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.contextMenu): ?widget.onMore,
        },
        child: AnimatedScale(
          scale: visible && AppScope.of(context).television ? 1.06 : 1,
          duration: const Duration(milliseconds: 120),
          child: button,
        ),
      ),
    );
  }
}

Widget _line(BuildContext context, String text, TextStyle style, int lines) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        height:
            MediaQuery.textScalerOf(context).scale(style.fontSize!) *
            style.height! *
            lines,
        child: Text(
          text,
          maxLines: lines,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );

class DramaTile extends StatelessWidget {
  const DramaTile({
    super.key,
    required this.drama,
    required this.onTap,
    this.subtitle,
    this.rank,
    this.onMore,
    this.focusNode,
    this.autofocus = false,
  });
  final Drama drama;
  final VoidCallback onTap;
  final String? subtitle;
  final int? rank;
  final VoidCallback? onMore;
  final FocusNode? focusNode;
  final bool autofocus;

  static TextStyle titleStyle(BuildContext context) => TextStyle(
    fontSize: AppScope.of(context).television ? 15 : 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static TextStyle subtitleStyle(BuildContext context) => TextStyle(
    fontSize: AppScope.of(context).television ? 13 : 12,
    height: 1.3,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );

  static double extentFor(BuildContext context, double width) {
    final scaler = MediaQuery.textScalerOf(context);
    final title = scaler.scale(titleStyle(context).fontSize!) * 1.3 * 2;
    final subtitle = scaler.scale(subtitleStyle(context).fontSize!) * 1.3;
    return (width * 1.5 + 9 + title + 4 + subtitle).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) => _PosterButton(
    cover: DramaCover(drama: drama, radius: _coverRadius, rank: rank),
    label:
        '${rank == null ? '' : '第$rank名，'}'
        '${drama.title}，${drama.episodes}集${drama.vip ? '，VIP' : ''}',
    onTap: onTap,
    onMore: onMore,
    focusNode: focusNode,
    autofocus: autofocus,
    caption: [
      const SizedBox(height: 9),
      _line(context, drama.title, titleStyle(context), 2),
      const SizedBox(height: 4),
      _line(context, subtitle ?? drama.category, subtitleStyle(context), 1),
    ],
  );
}

class ProgressPoster extends StatelessWidget {
  const ProgressPoster({
    super.key,
    required this.drama,
    required this.progress,
    required this.caption,
    required this.onTap,
    this.onMore,
    this.width = 100,
  });
  final Drama drama;
  final double progress;
  final String caption;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final television = AppScope.of(context).television;
    return SizedBox(
      width: width,
      child: _PosterButton(
        cover: Stack(
          fit: StackFit.expand,
          children: [
            DramaCover(drama: drama, radius: _coverRadius, details: false),
            Positioned(
              left: _coverRadius,
              right: _coverRadius,
              bottom: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1.5),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 3,
                  color: colors.primaryFixedDim,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.zero,
                  stopIndicatorColor: Colors.transparent,
                ),
              ),
            ),
          ],
        ),
        label: '${drama.title}，$caption',
        onTap: onTap,
        onMore: onMore,
        caption: [
          const SizedBox(height: 8),
          _line(
            context,
            drama.title,
            TextStyle(
              fontSize: television ? 15 : 14,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            1,
          ),
          const SizedBox(height: 2),
          _line(
            context,
            caption,
            TextStyle(
              fontSize: television ? 13 : 12,
              height: 1.3,
              color: colors.onSurfaceVariant,
            ),
            1,
          ),
        ],
      ),
    );
  }
}
