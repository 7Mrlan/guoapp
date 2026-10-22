import 'dart:io';

import 'package:flutter/material.dart';

import '../../app_build.dart';
import '../../download_preferences.dart';
import '../../local_store.dart';
import '../../resource_settings.dart';
import '../../resource_settings_editor.dart';
import '../app_scope.dart';
import '../widgets/focus_ring.dart';
import '../widgets/group_card.dart';
import '../widgets/status_view.dart';
import 'appearance_settings.dart';
import 'diary_view.dart';
import 'settings_rows.dart';
import 'storage_view.dart';

enum SettingsGroup {
  appearance('外观', Icons.palette_outlined),
  playback('播放', Icons.play_arrow_rounded, placeholder: '播放'),
  download('下载', Icons.download_rounded),
  sources('站源', Icons.dns_outlined),
  proxy('代理', Icons.language_rounded),
  users('用户', Icons.manage_accounts_outlined, placeholder: '用户管理'),
  about('关于', Icons.info_outline_rounded),
  diagnostics('诊断', Icons.receipt_long_outlined);

  const SettingsGroup(this.label, this.icon, {this.placeholder});
  final String label;
  final IconData icon;
  final String? placeholder;
}

typedef OpenSubpage = void Function(String title, WidgetBuilder body);

const adminOnly = '需要管理员';
const _noDownload = '当前用户没有下载权限';
const _proxyModes = {'auto': '自动', 'direct': '直连', 'manual': '手动代理'};
const _counts = {1: '1', 2: '2', 3: '3', 4: '4', 5: '5', 6: '6'};
const _intervals = [0, 100, 250, 500, 1000, 2000, 3000, 5000];

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.group,
    required this.store,
    required this.editor,
    required this.open,
  });
  final SettingsGroup group;
  final LocalStore store;
  final ResourceSettingsEditor editor;
  final OpenSubpage open;

  Future<void> _saveResource(BuildContext context, ResourceSettings settings) =>
      saveSetting(context, () => editor.save(settings));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([store, editor]),
    builder: (context, _) => group == SettingsGroup.appearance
        ? AppearanceSettings(store: store)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: switch (group) {
              SettingsGroup.download => _download(context),
              SettingsGroup.sources => _sources(context),
              SettingsGroup.proxy => _proxy(context),
              SettingsGroup.about => _about(context),
              SettingsGroup.diagnostics => _diagnostics(),
              _ => const [],
            },
          ),
  );

  Widget? _editorError() => switch (editor.error) {
    final error? => SettingsTile(
      title: '无法读取网络与下载设置',
      subtitle: error,
      trailing: const Icon(Icons.refresh_rounded),
      onTap: editor.load,
    ),
    null => null,
  };

  List<Widget> _download(BuildContext context) {
    final canDownload = store.canDownload;
    final admin = store.profile.admin;
    final preferences = store.downloadPreferences;
    final settings = editor.settings;
    final editable = settings != null && !editor.saving;
    void savePreferences(DownloadPreferences next) =>
        saveSetting(context, () => store.setDownloadPreferences(next));
    return [
      SettingsCard(
        children: [
          ValueTile<int>(
            title: '默认画质',
            subtitle: canDownload ? '指定画质不可用时，使用源站可用画质' : _noDownload,
            options: {
              for (final quality in DownloadPreferences.qualities)
                quality: quality == 0 ? '自动（优先高清）' : '${quality}P',
            },
            value: preferences.quality,
            onChanged: canDownload
                ? (quality) =>
                      savePreferences(preferences.copyWith(quality: quality))
                : null,
          ),
          SwitchTile(
            title: '默认包含 VIP 集',
            subtitle: canDownload ? 'VIP 集可能仅提供试看内容，下载前仍可调整选择' : _noDownload,
            value: preferences.includeVip,
            onChanged: canDownload
                ? (value) =>
                      savePreferences(preferences.copyWith(includeVip: value))
                : null,
          ),
          SettingsTile(
            title: '目录与空间',
            subtitle: canDownload ? '查看存储用量、迁移已下载文件' : _noDownload,
            enabled: canDownload,
            onTap: () => open('目录与空间', (_) => StorageView(store: store)),
          ),
        ],
      ),
      SettingsCard(
        children: [
          ?_editorError(),
          ValueTile<int>(
            title: '同时下载数量',
            subtitle: admin ? null : adminOnly,
            options: _counts,
            value: settings?.downloadConcurrency,
            onChanged: editable
                ? (value) => _saveResource(
                    context,
                    settings.copyWith(downloadConcurrency: value),
                  )
                : null,
          ),
          SwitchTile(
            title: '按站源分类保存',
            subtitle: admin ? '新任务放入各站源的子目录，已有下载继续使用原位置' : adminOnly,
            value: settings?.downloadBySource ?? false,
            onChanged: editable
                ? (value) => _saveResource(
                    context,
                    settings.copyWith(downloadBySource: value),
                  )
                : null,
          ),
        ],
      ),
      if (Platform.isIOS) const _Note('iOS 下载和媒体处理需要保持应用在前台；切到后台会暂停，回到前台后可继续。'),
    ];
  }

  List<Widget> _sources(BuildContext context) {
    final settings = editor.settings;
    final editable = settings != null && !editor.saving;
    return [
      SettingsCard(
        children: [
          SettingsTile(
            title: '站源管理',
            subtitle: '独立更新、连接与播放检测',
            onTap: () => open(
              '站源管理',
              (_) => const StatusView(
                title: '「站源管理」正在重建',
                icon: Icons.tune_rounded,
              ),
            ),
          ),
        ],
      ),
      SettingsCard(
        children: [
          ?_editorError(),
          ValueTile<int>(
            title: '目录请求间隔',
            subtitle: store.profile.admin ? '同一站源两次请求之间的最短间隔' : adminOnly,
            options: {
              for (final interval in {
                ..._intervals,
                ?settings?.catalogIntervalMs,
              }.toList()..sort())
                interval: '$interval 毫秒',
            },
            value: settings?.catalogIntervalMs,
            onChanged: editable
                ? (value) => _saveResource(
                    context,
                    settings.copyWith(catalogIntervalMs: value),
                  )
                : null,
          ),
        ],
      ),
    ];
  }

  List<Widget> _proxy(BuildContext context) {
    final admin = store.profile.admin;
    final settings = editor.settings;
    final editable = settings != null && !editor.saving;
    final mode = settings?.proxyMode;
    return [
      if (settings != null && settings.warning.isNotEmpty)
        _Note(settings.warning),
      SettingsCard(
        children: [
          ?_editorError(),
          ValueTile<String>(
            title: '连接方式',
            subtitle: !admin
                ? adminOnly
                : switch (mode) {
                    'auto' when settings!.systemProxyStatus.isNotEmpty =>
                      settings.systemProxyStatus,
                    'auto' => '使用系统静态代理；未配置时使用环境变量或直连',
                    _ => null,
                  },
            options: _proxyModes,
            value: mode,
            onChanged: editable
                ? (value) => value == 'manual'
                      ? _editProxy(context, settings)
                      : _saveResource(
                          context,
                          settings.copyWith(proxyMode: value),
                        )
                : null,
          ),
          if (mode == 'manual')
            SettingsTile(
              title: '代理地址',
              subtitle: '支持 HTTP、HTTPS、SOCKS5；仅保存在本机，不进入配置备份',
              value: settings!.proxyUrl.isEmpty ? '未设置' : '已设置',
              enabled: editable,
              onTap: () => _editProxy(context, settings),
            ),
        ],
      ),
    ];
  }

  Future<void> _editProxy(
    BuildContext context,
    ResourceSettings settings,
  ) async {
    final address = await showDialog<String>(
      context: context,
      builder: (_) => _ProxyDialog(initial: settings.proxyUrl),
    );
    if (address == null || !context.mounted) return;
    await _saveResource(
      context,
      settings.copyWith(proxyMode: 'manual', proxyUrl: address),
    );
  }

  List<Widget> _about(BuildContext context) {
    final version = AppScope.of(context).version;
    return [
      SettingsCard(
        children: [
          SettingsTile(
            title: appName,
            value: version.isEmpty ? '版本未知' : '版本 $version',
          ),
        ],
      ),
    ];
  }

  List<Widget> _diagnostics() => [
    SettingsCard(
      children: [
        SettingsTile(
          title: '播放调试日记',
          subtitle: '查看并复制应用运行与播放器的详细事件日志',
          onTap: () => open('播放调试日记', (_) => const DiaryView()),
        ),
      ],
    ),
  ];
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
      ),
    ),
  );
}

class _ProxyDialog extends StatefulWidget {
  const _ProxyDialog({required this.initial});
  final String initial;

  @override
  State<_ProxyDialog> createState() => _ProxyDialogState();
}

class _ProxyDialogState extends State<_ProxyDialog> {
  late final _address = TextEditingController(text: widget.initial);
  var _visible = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  void _submit() {
    final address = _address.text.trim();
    if (address.isNotEmpty) Navigator.pop(context, address);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('代理地址'),
    content: SizedBox(
      width: 420,
      child: TextField(
        controller: _address,
        autofocus: true,
        obscureText: !_visible,
        enableSuggestions: false,
        autocorrect: false,
        keyboardType: TextInputType.url,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'http://127.0.0.1:7890',
          helperText: '支持 HTTP、HTTPS、SOCKS5',
          suffixIcon: IconButton(
            tooltip: _visible ? '隐藏代理地址' : '显示代理地址',
            onPressed: () => setState(() => _visible = !_visible),
            icon: Icon(
              _visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
        ),
      ),
    ),
    actions: [
      FocusRing(
        radius: 20,
        child: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
      FocusRing(
        radius: 20,
        child: FilledButton(onPressed: _submit, child: const Text('保存')),
      ),
    ],
  );
}
