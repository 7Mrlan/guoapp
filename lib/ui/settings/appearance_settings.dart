import 'package:flutter/material.dart';

import '../../local_store.dart';
import '../../theme_color.dart';
import '../app_scope.dart';
import '../widgets/focus_ring.dart';
import '../widgets/group_card.dart';
import 'settings_rows.dart';

const displayModes = {
  'auto': '自动识别设备',
  'television': '电视 / 遥控器',
  'standard': '手机 / 电脑',
  'pad': '平板',
};

class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({super.key, required this.store});
  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final systemColorAvailable = AppScope.of(context).systemColorAvailable;
    final following = systemColorAvailable && store.followSystemColor;
    return Column(
      spacing: 12,
      children: [
        GroupCard(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Text('主题模式', style: text.titleMedium),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'light', label: Text('浅色')),
                      ButtonSegment(value: 'dark', label: Text('深色')),
                      ButtonSegment(value: 'system', label: Text('跟随系统')),
                    ],
                    selected: {store.themeMode},
                    onSelectionChanged: (value) => saveSetting(
                      context,
                      () => store.setThemeMode(value.first),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(indent: 16, endIndent: 16),
            TileFocus(
              builder: (focusNode) => SwitchListTile(
                focusNode: focusNode,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: const Text('跟随系统取色'),
                subtitle: Text(
                  systemColorAvailable
                      ? 'Android 12 及以上跟随壁纸，Windows 跟随系统强调色'
                      : '本机不支持系统取色，使用预设色板',
                ),
                value: following,
                onChanged: systemColorAvailable
                    ? (value) => saveSetting(
                        context,
                        () => store.setFollowSystemColor(value),
                      )
                    : null,
              ),
            ),
            const Divider(indent: 16, endIndent: 16),
            Opacity(
              opacity: following ? 0.45 : 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text('预设色板', style: text.titleMedium),
                        Text(
                          following ? '关闭「跟随系统取色」后可选' : '选一个种子色生成整套配色',
                          style: text.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        for (final color in ThemeColor.values)
                          Expanded(
                            child: _Swatch(
                              color: color,
                              selected: !following && store.themeColor == color,
                              onPressed: following
                                  ? null
                                  : () => saveSetting(
                                      context,
                                      () => store.setThemeColor(color),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        GroupCard(
          children: [
            SettingsTile(
              title: '界面模式',
              subtitle: displayModes[store.displayMode]!,
              onTap: () async {
                final selection = await showOptionDialog(
                  context,
                  title: '界面模式',
                  options: displayModes,
                  selected: store.displayMode,
                );
                if (selection != null && context.mounted) {
                  await saveSetting(
                    context,
                    () => store.setDisplayMode(selection),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onPressed,
  });
  final ThemeColor color;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = ColorScheme.fromSeed(
      seedColor: Color(color.seed),
      brightness: theme.brightness,
    );
    return Column(
      spacing: 6,
      children: [
        Semantics(
          button: true,
          selected: selected,
          label: color.label,
          excludeSemantics: true,
          child: Container(
            width: 50,
            height: 50,
            padding: const EdgeInsets.all(3),
            decoration: ShapeDecoration(
              shape: CircleBorder(
                side: BorderSide(
                  color: selected ? scheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Material(
              color: scheme.primary,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: selected
                    ? Icon(Icons.check_rounded, color: scheme.onPrimary)
                    : null,
              ),
            ),
          ),
        ),
        Text(
          color.label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
