import 'package:flutter/material.dart';

import '../../local_store.dart';
import '../../models.dart';
import 'settings_rows.dart';

class SourcesView extends StatelessWidget {
  const SourcesView({super.key, required this.store});
  final LocalStore store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final admin = store.profile.admin;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (!admin) ...[
            const _Note('需要管理员才能开启或关闭站源'),
            const SizedBox(height: 12),
          ],
          SettingsCard(
            children: [
              for (final site in SourceSite.values)
                _SourceTile(
                  site: site,
                  enabled: store.sourceEnabled(site.id),
                  onChanged: admin
                      ? (value) => saveSetting(
                          context,
                          () => store.setSourceEnabled(site.id, value),
                        )
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 12),
          const _Note('关闭的站源不在发现、搜索、追剧和观看记录中显示，记录保留，重新开启后恢复。'),
        ],
      );
    },
  );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.site,
    required this.enabled,
    required this.onChanged,
  });
  final SourceSite site;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: ListTile(
      minTileHeight: 68,
      contentPadding: const EdgeInsets.fromLTRB(20, 4, 16, 4),
      title: Text(site.name),
      subtitle: Text(site.description),
      onTap: onChanged == null ? null : () => onChanged!(!enabled),
      trailing: ExcludeFocus(
        child: Switch(value: enabled, onChanged: onChanged),
      ),
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.6,
      ),
    ),
  );
}
