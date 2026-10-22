import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../local_store.dart';
import '../../resource_settings_editor.dart';
import '../app_scope.dart';
import '../shell/app_shell.dart';
import '../shell/pending_pages.dart';
import '../widgets/bar_button.dart';
import '../widgets/focus_ring.dart';
import '../widgets/group_card.dart';
import '../widgets/status_view.dart';
import 'appearance_settings.dart';
import 'backup_actions.dart';
import 'settings_rows.dart';
import 'settings_sections.dart';

const _themeModes = {'light': '浅色', 'dark': '深色', 'system': '跟随系统'};

typedef _Subpage = ({String title, WidgetBuilder body});

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.store});
  final LocalStore store;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ResourceSettingsEditor? _editor;
  final _groupsScope = FocusScopeNode(
    debugLabel: 'settings-groups',
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );
  final _detailScope = FocusScopeNode(
    debugLabel: 'settings-detail',
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );
  final _groupFocus = [for (final _ in SettingsGroup.values) FocusNode()];
  var _group = SettingsGroup.appearance;
  _Subpage? _subpage;
  FocusNode? _opener;
  var _detailFocused = false;
  var _backupBusy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _editor ??= ResourceSettingsEditor(
      AppScope.of(context).repository,
      widget.store,
    )..load();
  }

  @override
  void dispose() {
    _editor?.dispose();
    _groupsScope.dispose();
    _detailScope.dispose();
    for (final node in _groupFocus) {
      node.dispose();
    }
    super.dispose();
  }

  String _summary(SettingsGroup group) {
    final store = widget.store;
    final scope = AppScope.of(context);
    return switch (group) {
      SettingsGroup.appearance => [
        _themeModes[store.themeMode],
        scope.systemColorAvailable && store.followSystemColor
            ? '系统取色'
            : store.themeColor.label,
        displayModes[store.displayMode],
      ].join(' · '),
      SettingsGroup.playback => '倍速、清晰度、连播与弹幕',
      SettingsGroup.download => '默认画质、目录与空间、同时下载数量',
      SettingsGroup.sources => '站源管理、目录请求间隔',
      SettingsGroup.proxy => '连接方式、代理地址',
      SettingsGroup.users => '当前：${store.profile.name}',
      SettingsGroup.about =>
        scope.version.isEmpty ? '版本未知' : '版本 ${scope.version}',
      SettingsGroup.diagnostics => '播放调试日记',
    };
  }

  Future<void> _backup(Future<String?> Function() task) async {
    setState(() => _backupBusy = true);
    String? message;
    try {
      message = await task();
    } catch (failure) {
      message = '$failure';
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
    if (message != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _exportBackup() => _backup(() => exportBackupFile(widget.store));

  void _restoreBackup() =>
      _backup(() => restoreBackupFile(context, widget.store));

  bool get _backupEnabled => widget.store.profile.admin && !_backupBusy;

  Widget _section(SettingsGroup group) => SettingsSection(
    group: group,
    store: widget.store,
    editor: _editor!,
    open: _open,
  );

  void _open(String title, WidgetBuilder body) {
    if (!settingsSplit(context)) {
      openPage<void>(
        context,
        (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: body(context),
        ),
      );
      return;
    }
    _opener = FocusManager.instance.primaryFocus;
    setState(() => _subpage = (title: title, body: body));
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusDetail());
  }

  void _closeSubpage() {
    final opener = _opener;
    _opener = null;
    setState(() => _subpage = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (opener != null && opener.context != null) revealFocus(opener);
    });
  }

  void _select(SettingsGroup group) {
    if (group == _group) return;
    setState(() {
      _group = group;
      _subpage = null;
      _opener = null;
    });
  }

  FocusNode? _detailTarget({required bool resume}) {
    final last = _detailScope.focusedChild;
    if (resume && last != null && last.canRequestFocus) return last;
    final first = FocusTraversalGroup.of(
      context,
    ).findFirstFocus(_detailScope, ignoreCurrentFocus: true);
    return first == _detailScope ? null : first;
  }

  void _focusDetail() {
    if (!mounted || !AppScope.of(context).television) return;
    if (_detailTarget(resume: false) case final target?) revealFocus(target);
  }

  KeyEventResult _onGroupsKey(KeyEvent event) {
    if (event is KeyUpEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }
    final target = _detailTarget(resume: true);
    if (target == null) return KeyEventResult.ignored;
    revealFocus(target);
    return KeyEventResult.handled;
  }

  KeyEventResult _onDetailKey(KeyEvent event) {
    if (event is KeyUpEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    final focus = FocusManager.instance.primaryFocus;
    if (focus != null && focus.focusInDirection(TraversalDirection.left)) {
      return KeyEventResult.handled;
    }
    revealFocus(_groupFocus[_group.index]);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) =>
      settingsSplit(context) ? _split(context) : _phone(context);

  Widget _phone(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('设置')),
    body: ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          GroupCard(
            children: [
              for (final group in SettingsGroup.values)
                SettingsTile(
                  icon: group.icon,
                  title: group.label,
                  subtitle: _summary(group),
                  onTap: () => _openGroup(group),
                ),
            ],
          ),
          const SizedBox(height: 12),
          GroupCard(
            children: [
              SettingsTile(
                icon: Icons.upload_file_outlined,
                title: '导出备份',
                subtitle: widget.store.profile.admin
                    ? '包含本地用户、追剧、历史和设置，不含视频文件'
                    : adminOnly,
                enabled: _backupEnabled,
                onTap: _exportBackup,
              ),
              SettingsTile(
                icon: Icons.restore_rounded,
                title: '恢复备份',
                subtitle: widget.store.profile.admin
                    ? '替换本机的用户、追剧、观看记录和偏好设置，已下载视频保留'
                    : adminOnly,
                enabled: _backupEnabled,
                onTap: _restoreBackup,
              ),
            ],
          ),
        ],
      ),
    ),
  );

  void _openGroup(SettingsGroup group) => openPage<void>(
    context,
    (_) => group.placeholder != null
        ? PendingPage(title: group.placeholder!, icon: group.icon)
        : Scaffold(
            appBar: AppBar(title: Text(group.label)),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [_section(group)],
            ),
          ),
  );

  Widget _split(BuildContext context) {
    final television = AppScope.of(context).television;
    return PopScope(
      canPop: _subpage == null && !(television && _detailFocused),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_subpage != null) {
          _closeSubpage();
        } else {
          revealFocus(_groupFocus[_group.index]);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 280,
                child: Focus(
                  canRequestFocus: false,
                  skipTraversal: true,
                  onKeyEvent: (_, event) => _onGroupsKey(event),
                  child: FocusScope(
                    node: _groupsScope,
                    child: _groupList(television),
                  ),
                ),
              ),
              Expanded(
                child: Focus(
                  canRequestFocus: false,
                  skipTraversal: true,
                  onFocusChange: (focused) =>
                      setState(() => _detailFocused = focused),
                  onKeyEvent: (_, event) => _onDetailKey(event),
                  child: FocusScope(
                    node: _detailScope,
                    child: _detail(television),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupList(bool television) => ListView(
    padding: EdgeInsets.fromLTRB(16, television ? 24 : 20, 12, 24),
    children: [
      SizedBox(
        height: 48,
        child: Row(
          spacing: 4,
          children: [
            if (!television)
              BarButton(
                icon: Icons.arrow_back_rounded,
                tooltip: '返回',
                onPressed: () => Navigator.pop(context),
              ),
            Padding(
              padding: EdgeInsets.only(left: television ? 8 : 0),
              child: Text(
                '设置',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      for (final group in SettingsGroup.values)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _GroupItem(
            key: ValueKey('settings-${group.name}'),
            label: group.label,
            selected: group == _group,
            focusNode: _groupFocus[group.index],
            autofocus: television && group == _group,
            onTap: () => _select(group),
            onFocus: television ? () => _select(group) : null,
          ),
        ),
      const SizedBox(height: 12),
      const Divider(indent: 8, endIndent: 8),
      const SizedBox(height: 8),
      _GroupItem(
        key: const ValueKey('settings-export'),
        label: '导出备份',
        onTap: _backupEnabled ? _exportBackup : null,
      ),
      const SizedBox(height: 4),
      _GroupItem(
        key: const ValueKey('settings-restore'),
        label: '恢复备份',
        onTap: _backupEnabled ? _restoreBackup : null,
      ),
    ],
  );

  Widget _detail(bool television) {
    final subpage = _subpage;
    final top = television ? 24.0 : 20.0;
    final placeholder = _group.placeholder;
    final content = placeholder != null
        ? StatusView(title: '「$placeholder」正在重建', icon: _group.icon)
        : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _section(_group),
              ),
            ),
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: subpage != null,
          child: ExcludeFocus(
            excluding: subpage != null,
            child: Column(
              key: ValueKey(_group),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DetailHeader(title: _group.label, top: top),
                Expanded(child: content),
              ],
            ),
          ),
        ),
        if (subpage != null)
          Column(
            key: ValueKey(subpage.title),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailHeader(
                title: subpage.title,
                top: top,
                onBack: _closeSubpage,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 776),
                      child: subpage.body(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.title, required this.top, this.onBack});
  final String title;
  final double top;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(onBack == null ? 24 : 16, top, 24, 0),
    child: SizedBox(
      height: 48,
      child: Row(
        spacing: 4,
        children: [
          if (onBack != null)
            BarButton(
              icon: Icons.arrow_back_rounded,
              tooltip: '返回',
              onPressed: onBack,
            ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _GroupItem extends StatelessWidget {
  const _GroupItem({
    super.key,
    required this.label,
    this.selected = false,
    this.focusNode,
    this.autofocus = false,
    required this.onTap,
    this.onFocus,
  });
  final String label;
  final bool selected;
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onTap;
  final VoidCallback? onFocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      selected: selected,
      child: FocusRing(
        radius: 24,
        child: Material(
          color: selected ? colors.secondaryContainer : Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            focusNode: focusNode,
            autofocus: autofocus,
            onTap: onTap,
            onFocusChange: (focused) {
              if (focused) onFocus?.call();
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? colors.onSecondaryContainer
                      : onTap == null
                      ? colors.onSurface.withValues(alpha: 0.38)
                      : colors.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
