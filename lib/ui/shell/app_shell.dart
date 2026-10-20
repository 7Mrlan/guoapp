import 'package:flutter/material.dart';

import '../../local_store.dart';
import '../app_scope.dart';
import '../widgets/bar_button.dart';
import '../widgets/focus_ring.dart';
import 'pending_pages.dart';

enum AppTab {
  explore('发现', Icons.explore_outlined, Icons.explore),
  rank('榜单', Icons.leaderboard_outlined, Icons.leaderboard),
  follow('追剧', Icons.bookmark_border_rounded, Icons.bookmark_rounded),
  mine('我的', Icons.person_outline_rounded, Icons.person_rounded);

  const AppTab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

Future<T?> openPage<T>(BuildContext context, WidgetBuilder builder) =>
    Navigator.of(
      context,
      rootNavigator: AppScope.formFactorOf(context) != FormFactor.wide,
    ).push(MaterialPageRoute<T>(builder: builder));

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});
  final LocalStore store;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _navigators = [
    for (final _ in AppTab.values) GlobalKey<NavigatorState>(),
  ];
  final _tabFocus = [for (final _ in AppTab.values) FocusNode()];
  var _tab = AppTab.explore;

  NavigatorState? get _navigator => _navigators[_tab.index].currentState;

  @override
  void dispose() {
    for (final node in _tabFocus) {
      node.dispose();
    }
    super.dispose();
  }

  void _select(AppTab tab) => setState(() => _tab = tab);

  void _back() {
    final navigator = _navigator;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return;
    }
    _select(AppTab.explore);
    if (AppScope.of(context).television) _tabFocus.first.requestFocus();
  }

  Widget _root(AppTab tab) => switch (tab) {
    AppTab.mine => PendingMinePage(store: widget.store),
    _ => PendingTabPage(label: tab.label, icon: tab.icon),
  };

  @override
  Widget build(BuildContext context) {
    final pages = NotificationListener<NavigationNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
        return false;
      },
      child: IndexedStack(
        index: _tab.index,
        children: [
          for (final tab in AppTab.values)
            Navigator(
              key: _navigators[tab.index],
              routeTraversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
              routeDirectionalTraversalEdgeBehavior:
                  TraversalEdgeBehavior.parentScope,
              onGenerateInitialRoutes: (_, _) => [
                MaterialPageRoute<void>(builder: (_) => _root(tab)),
              ],
            ),
        ],
      ),
    );
    return PopScope(
      canPop: _tab == AppTab.explore && !(_navigator?.canPop() ?? false),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: switch (AppScope.formFactorOf(context)) {
        FormFactor.phone => Scaffold(
          body: pages,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab.index,
            onDestinationSelected: (index) => _select(AppTab.values[index]),
            destinations: [
              for (final tab in AppTab.values)
                NavigationDestination(
                  key: ValueKey('nav-${tab.name}'),
                  icon: Icon(tab.icon),
                  selectedIcon: Icon(tab.selectedIcon),
                  label: tab.label,
                ),
            ],
          ),
        ),
        FormFactor.wide => _wide(pages),
        FormFactor.television => Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    televisionInset,
                    24,
                    televisionInset,
                    8,
                  ),
                  child: Row(
                    spacing: 6,
                    children: [
                      for (final tab in AppTab.values)
                        _TelevisionTab(
                          tab: tab,
                          selected: tab == _tab,
                          focusNode: _tabFocus[tab.index],
                          onTap: () => _select(tab),
                        ),
                    ],
                  ),
                ),
                Expanded(child: pages),
              ],
            ),
          ),
        ),
      },
    );
  }

  Widget _wide(Widget pages) {
    final roomy = MediaQuery.sizeOf(context).width >= 840;
    final expanded = roomy && widget.store.sideBarExpanded;
    return Scaffold(
      body: Row(
        children: [
          _SideBar(
            selected: _tab,
            expanded: expanded,
            onSelect: _select,
            onToggle: roomy
                ? () => widget.store.setSideBarExpanded(!expanded)
                : null,
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: true,
              child: pages,
            ),
          ),
        ],
      ),
    );
  }
}

typedef _SideMetrics = ({
  double width,
  double inset,
  double top,
  double menuGap,
  double spacing,
  double itemHeight,
  double iconSize,
  double labelSize,
  EdgeInsets labelPadding,
});

_SideMetrics _sideMetrics({required bool desktop, required bool expanded}) =>
    desktop
    ? (
        width: expanded ? 240 : 80,
        inset: 12,
        top: 12,
        menuGap: 8,
        spacing: 4,
        itemHeight: 48,
        iconSize: 22,
        labelSize: 14,
        labelPadding: const EdgeInsets.fromLTRB(17, 0, 16, 0),
      )
    : (
        width: expanded ? 232 : 88,
        inset: 16,
        top: 8,
        menuGap: 12,
        spacing: 4,
        itemHeight: 56,
        iconSize: 24,
        labelSize: 15,
        labelPadding: const EdgeInsets.fromLTRB(16, 0, 20, 0),
      );

class _SideBar extends StatelessWidget {
  const _SideBar({
    required this.selected,
    required this.expanded,
    required this.onSelect,
    this.onToggle,
  });
  final AppTab selected;
  final bool expanded;
  final ValueChanged<AppTab> onSelect;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final metrics = _sideMetrics(
      desktop: AppScope.of(context).desktop,
      expanded: expanded,
    );
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        right: false,
        child: SizedBox(
          key: const ValueKey('side-bar'),
          width: metrics.width,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.inset,
              metrics.top,
              metrics.inset,
              12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: metrics.spacing,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: metrics.menuGap),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 56,
                      height: 48,
                      child: onToggle == null
                          ? null
                          : Center(
                              child: BarButton(
                                icon: Icons.menu_rounded,
                                tooltip: expanded ? '收起侧栏' : '展开侧栏',
                                onPressed: onToggle,
                              ),
                            ),
                    ),
                  ),
                ),
                for (final tab in AppTab.values)
                  _SideItem(
                    tab: tab,
                    selected: tab == selected,
                    expanded: expanded,
                    metrics: metrics,
                    onTap: () => onSelect(tab),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.tab,
    required this.selected,
    required this.expanded,
    required this.metrics,
    required this.onTap,
  });
  final AppTab tab;
  final bool selected;
  final bool expanded;
  final _SideMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = selected
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;
    final icon = Icon(
      selected ? tab.selectedIcon : tab.icon,
      color: color,
      size: metrics.iconSize,
    );
    final item = Material(
      color: selected ? colors.secondaryContainer : Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('nav-${tab.name}'),
        onTap: onTap,
        child: SizedBox(
          height: metrics.itemHeight,
          child: expanded
              ? Padding(
                  padding: metrics.labelPadding,
                  child: Row(
                    spacing: 12,
                    children: [
                      icon,
                      Expanded(
                        child: Text(
                          tab.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: metrics.labelSize,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Center(child: icon),
        ),
      ),
    );
    return Semantics(
      selected: selected,
      child: FocusRing(
        radius: metrics.itemHeight / 2,
        child: expanded ? item : Tooltip(message: tab.label, child: item),
      ),
    );
  }
}

class _TelevisionTab extends StatelessWidget {
  const _TelevisionTab({
    required this.tab,
    required this.selected,
    required this.focusNode,
    required this.onTap,
  });
  final AppTab tab;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      selected: selected,
      child: FocusRing(
        radius: 20,
        child: Material(
          color: selected ? colors.secondaryContainer : Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('nav-${tab.name}'),
            focusNode: focusNode,
            autofocus: tab == AppTab.explore,
            onTap: onTap,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              child: Text(
                tab.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? colors.onSecondaryContainer
                      : colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
