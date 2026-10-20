import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../app_scope.dart';

bool focusVisible(bool focused) =>
    focused &&
    FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

typedef _Outline = ({
  LayerLink link,
  double radius,
  double spread,
  Color color,
});

final _outlineLayout = ValueNotifier<Size>(Size.zero);

void revealFocus(
  FocusNode node, {
  ScrollPositionAlignmentPolicy? alignmentPolicy,
  double? alignment,
  Duration? duration,
  Curve? curve,
}) {
  node.requestFocus();
  final box = node.context?.findRenderObject();
  if (box is RenderBox && box.hasSize) {
    box.showOnScreen(rect: (Offset.zero & box.size).inflate(16));
  }
}

class FocusOutlineScrollBehavior extends MaterialScrollBehavior {
  const FocusOutlineScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final indicator = super.buildOverscrollIndicator(context, child, details);
    return axisDirectionToAxis(details.direction) == Axis.vertical
        ? FocusOutlineLayer(child: indicator)
        : indicator;
  }
}

class _OutlineScope extends InheritedWidget {
  const _OutlineScope({required this.shown, required super.child});
  final ValueNotifier<_Outline?> shown;

  @override
  bool updateShouldNotify(_OutlineScope oldWidget) => shown != oldWidget.shown;
}

class FocusOutlineLayer extends StatefulWidget {
  const FocusOutlineLayer({super.key, required this.child});
  final Widget child;

  @override
  State<FocusOutlineLayer> createState() => _FocusOutlineLayerState();
}

class _FocusOutlineLayerState extends State<FocusOutlineLayer> {
  final _shown = ValueNotifier<_Outline?>(null);

  @override
  Widget build(BuildContext context) => _OutlineScope(
    shown: _shown,
    child: ClipRect(
      child: Stack(
        alignment: Alignment.topLeft,
        fit: StackFit.passthrough,
        children: [
          widget.child,
          ValueListenableBuilder(
            valueListenable: _shown,
            builder: (context, outline, _) => switch (outline) {
              final outline? => Positioned(
                left: 0,
                top: 0,
                child: IgnorePointer(
                  child: CompositedTransformFollower(
                    link: outline.link,
                    showWhenUnlinked: false,
                    child: CustomPaint(painter: _OutlinePainter(outline)),
                  ),
                ),
              ),
              null => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    ),
  );
}

class _OutlinePainter extends CustomPainter {
  _OutlinePainter(this.outline) : super(repaint: _outlineLayout);
  final _Outline outline;

  @override
  void paint(Canvas canvas, Size size) {
    final leader = outline.link.leaderSize;
    if (leader == null) return;
    final inset = outline.spread - 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & leader).inflate(inset),
        Radius.circular(outline.radius + inset),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = outline.color,
    );
  }

  @override
  bool shouldRepaint(_OutlinePainter oldDelegate) =>
      oldDelegate.outline != outline;
}

class _LayoutProbe extends SingleChildRenderObjectWidget {
  const _LayoutProbe({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLayoutProbe();
}

class _RenderLayoutProbe extends RenderProxyBox {
  @override
  void performLayout() {
    super.performLayout();
    _outlineLayout.value = size;
  }
}

class FocusOutline extends StatefulWidget {
  const FocusOutline({
    super.key,
    required this.visible,
    required this.radius,
    required this.child,
    this.offset = 3,
  });
  final bool visible;
  final double radius;
  final Widget child;
  final double offset;

  @override
  State<FocusOutline> createState() => _FocusOutlineState();
}

class _FocusOutlineState extends State<FocusOutline> {
  final _link = LayerLink();
  final _child = GlobalKey();
  _Outline? _outline;
  ValueNotifier<_Outline?>? _shown;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shown = context.dependOnInheritedWidgetOfExactType<_OutlineScope>()?.shown;
  }

  @override
  void dispose() {
    _outline = null;
    _publish();
    super.dispose();
  }

  void _publish() {
    final shown = _shown;
    if (shown == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_outline case final outline? when mounted) {
        shown.value = outline;
      } else if (shown.value?.link == _link) {
        shown.value = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final _Outline? outline = widget.visible
        ? (
            link: _link,
            radius: widget.radius,
            spread: widget.offset + 3,
            color: AppScope.of(context).television
                ? colors.onSurface
                : colors.primary,
          )
        : null;
    if (outline != _outline) {
      _outline = outline;
      _publish();
    }
    final child = KeyedSubtree(key: _child, child: widget.child);
    return widget.visible
        ? CompositedTransformTarget(
            link: _link,
            child: _LayoutProbe(child: child),
          )
        : child;
  }
}

class FocusRing extends StatefulWidget {
  const FocusRing({
    super.key,
    required this.radius,
    required this.child,
    this.offset = 3,
  });
  final double radius;
  final Widget child;
  final double offset;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final visible = focusVisible(_focused);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: AnimatedScale(
        scale: visible && AppScope.of(context).television ? 1.06 : 1,
        duration: const Duration(milliseconds: 120),
        child: FocusOutline(
          visible: visible,
          radius: widget.radius,
          offset: widget.offset,
          child: widget.child,
        ),
      ),
    );
  }
}
