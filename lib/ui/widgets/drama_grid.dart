import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../drama_feed.dart';
import '../app_scope.dart';
import 'drama_tile.dart';
import 'focus_ring.dart';

(int, double, double) _gridLayout(BuildContext context, double width) =>
    switch (AppScope.formFactorOf(context)) {
      FormFactor.phone => (3, 10.0, 22.0),
      FormFactor.television => (
        ((width + 20) / 120).floor().clamp(3, 8),
        20.0,
        24.0,
      ),
      FormFactor.wide when AppScope.of(context).desktop => (
        math.max(2, ((width + 18) / 178).floor()),
        18.0,
        24.0,
      ),
      FormFactor.wide => ((width / 180).floor().clamp(4, 9), 18.0, 22.0),
    };

double dramaTileWidth(BuildContext context, double width) {
  final (columns, spacing, _) = _gridLayout(context, width);
  return (width - (columns - 1) * spacing) / columns;
}

SliverGridDelegate dramaGridDelegate(BuildContext context, double width) {
  final (columns, spacing, runSpacing) = _gridLayout(context, width);
  final tile = dramaTileWidth(context, width);
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    crossAxisSpacing: spacing,
    mainAxisSpacing: runSpacing,
    mainAxisExtent: DramaTile.extentFor(context, tile),
  );
}

class AutoLoadMore extends StatelessWidget {
  const AutoLoadMore({super.key, required this.feed, required this.child});
  final DramaFeed feed;
  final Widget child;

  bool _check(ScrollMetrics metrics, int depth) {
    if (depth == 0 &&
        metrics.axis == Axis.vertical &&
        metrics.extentAfter < 600 &&
        feed.canLoadMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) => feed.loadMore());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) =>
            _check(notification.metrics, notification.depth),
        child: NotificationListener<ScrollUpdateNotification>(
          onNotification: (notification) =>
              _check(notification.metrics, notification.depth),
          child: child,
        ),
      );
}

class FeedFooter extends StatelessWidget {
  const FeedFooter({super.key, required this.feed});
  final DramaFeed feed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return SizedBox(
      height: 72,
      child: Center(
        child: feed.loadingMore
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : feed.error.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      feed.error,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: caption,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FocusRing(
                    radius: 999,
                    child: TextButton(
                      onPressed: feed.hasMore
                          ? feed.loadMore
                          : () => feed.reload(force: true),
                      child: const Text('重试'),
                    ),
                  ),
                ],
              )
            : feed.hasMore
            ? null
            : Text('已经到底了', style: caption),
      ),
    );
  }
}
