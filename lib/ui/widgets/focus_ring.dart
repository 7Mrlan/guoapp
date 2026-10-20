import 'package:flutter/material.dart';

import '../app_scope.dart';

bool focusVisible(bool focused) =>
    focused &&
    FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

class FocusOutline extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spread = offset + 3;
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        child,
        if (visible)
          Positioned(
            left: -spread,
            top: -spread,
            right: -spread,
            bottom: -spread,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius + spread),
                  border: Border.all(
                    color: AppScope.of(context).television
                        ? colors.onSurface
                        : colors.primary,
                    width: 3,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
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
