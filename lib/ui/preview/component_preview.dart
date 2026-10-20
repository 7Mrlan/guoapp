import 'package:flutter/material.dart';

import '../../models.dart';
import '../app_scope.dart';
import '../widgets/bar_button.dart';
import '../widgets/category_tabs.dart';
import '../widgets/choice_panel.dart';
import '../widgets/cover_backdrop.dart';
import '../widgets/drama_tile.dart';
import '../widgets/focus_ring.dart';
import '../widgets/group_card.dart';
import '../widgets/page_header.dart';
import '../widgets/source_bar.dart';
import '../widgets/status_view.dart';

const _genres = [
  '都市',
  '古装',
  '甜宠',
  '逆袭',
  '悬疑',
  '家庭',
  '战神',
  '萌宝',
  '穿越',
  '重生',
  '虐恋',
  '豪门',
  '复仇',
  '神医',
  '年代',
  '民国',
  '玄幻',
  '仙侠',
  '校园',
  '职场',
  '喜剧',
  '乡村',
];

final _dramas = [
  for (var index = 0; index < 12; index++)
    Drama(
      id: '',
      source: 'preview',
      title: index == 1 ? '较长的剧名会在这里换到第二行，超出部分省略' : '示例短剧 ${index + 1}',
      episodes: 60 + index * 7 % 41,
      category: _genres[index % _genres.length],
      vip: index % 5 == 1,
    ),
];

class ComponentPreview extends StatefulWidget {
  const ComponentPreview({super.key});

  @override
  State<ComponentPreview> createState() => _ComponentPreviewState();
}

class _ComponentPreviewState extends State<ComponentPreview> {
  String _source = '站源 1';
  String _category = '推荐';
  bool _toggle = true;

  void _message(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _pickSource(BuildContext anchor) async {
    final value = await showChoicePanel<String>(
      context: anchor,
      title: '全部站源',
      options: [
        for (var index = 1; index <= 11; index++)
          ChoiceOption('站源 $index', '站源 $index'),
      ],
      selected: _source,
      grid: ChoiceGrid.sources,
      action: (
        label: '管理站源',
        icon: Icons.tune_rounded,
        onPressed: () => _message('管理站源'),
      ),
    );
    if (value != null) setState(() => _source = value);
  }

  Future<void> _pickCategory(BuildContext anchor) async {
    final value = await showChoicePanel<String>(
      context: anchor,
      title: '全部分类',
      options: [
        for (final label in ['推荐', '全部', ..._genres])
          ChoiceOption(label, label),
      ],
      selected: _category,
      grid: ChoiceGrid.categories,
    );
    if (value != null) setState(() => _category = value);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 32;
    final columns = width < 568 ? 3 : (width / 180).floor().clamp(4, 9);
    final spacing = width < 568 ? 10.0 : 18.0;
    final tileWidth = (width - (columns - 1) * spacing) / columns;
    final form = AppScope.formFactorOf(context);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('组件预览')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SourceBar(
              source: _source,
              onSwitchSource: _pickSource,
              onOpenSearch: () => _message('打开搜索'),
              onSearchSubmitted: (query) => _message('搜索：$query'),
              actions: [
                if (form == FormFactor.wide) ...[
                  BarButton(
                    icon: Icons.checklist_rounded,
                    tooltip: '多选下载',
                    onPressed: () => _message('多选下载'),
                  ),
                  BarButton(
                    icon: Icons.refresh_rounded,
                    tooltip: '更新剧库',
                    onPressed: () => _message('更新剧库'),
                  ),
                ],
              ],
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: form == FormFactor.wide ? 24 : 0,
            ),
            sliver: SliverToBoxAdapter(
              child: CategoryTabs<String>(
                options: [
                  for (final label in ['推荐', '全部', ..._genres])
                    ChoiceOption(label, label),
                ],
                selected: _category,
                onSelected: (value) => setState(() => _category = value),
                onShowAll: _pickCategory,
                onAnotherBatch: form == FormFactor.phone
                    ? null
                    : () => _message('换一批'),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SectionHeader(title: '页面标题')),
          const SliverToBoxAdapter(child: PageHeader(title: '我的')),
          const SliverToBoxAdapter(child: SectionHeader(title: '封面模糊背景')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: 358,
                      height: 196,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CoverBackdrop(
                            drama: _dramas.first,
                            overlay: const LinearGradient(
                              colors: [Color(0xE0161214), Color(0x8C161214)],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 6,
                              children: [
                                const Text(
                                  '继续观看',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _dramas.first.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                FocusRing(
                                  radius: 999,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colors.primaryFixedDim,
                                      foregroundColor: colors.onPrimaryFixed,
                                    ),
                                    onPressed: () => _message('继续播放'),
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: const Text('继续第 13 集'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 358,
                    height: 196,
                    child: CoverBackdrop(
                      drama: _dramas.first,
                      opacity: Theme.of(context).brightness == Brightness.dark
                          ? 0.55
                          : 0.45,
                      sigma: 36,
                      overlay: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.92],
                        colors: [
                          colors.surface.withValues(alpha: 0),
                          colors.surface,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: '横排海报',
              action: '全部',
              onAction: () => _message('全部观看记录'),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 214,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: 8,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) => ProgressPoster(
                  drama: _dramas[index],
                  progress: (index + 1) / 9,
                  caption: '看到第 ${index * 7 + 3} 集',
                  onTap: () => _message('继续 ${_dramas[index].title}'),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SectionHeader(title: '剧集卡片')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverGrid.builder(
              itemCount: _dramas.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: spacing,
                mainAxisSpacing: 22,
                mainAxisExtent: DramaTile.extentFor(context, tileWidth),
              ),
              itemBuilder: (context, index) => DramaTile(
                drama: _dramas[index],
                autofocus: index == 0,
                onTap: () => _message('打开 ${_dramas[index].title}'),
                onMore: () => _message('${_dramas[index].title} 的菜单'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: '选择面板',
              action: '全部',
              onAction: () => _message('区块标题按钮'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  Builder(
                    builder: (anchor) => FilledButton.tonalIcon(
                      onPressed: () => _pickSource(anchor),
                      icon: const Icon(Icons.public_rounded),
                      label: Text('全部站源 · $_source'),
                    ),
                  ),
                  Builder(
                    builder: (anchor) => FilledButton.tonalIcon(
                      onPressed: () => _pickCategory(anchor),
                      icon: const Icon(Icons.grid_view_rounded),
                      label: Text('全部分类 · $_category'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SectionHeader(title: '分组卡片')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: GroupCard(
                children: [
                  SettingsTile(
                    icon: Icons.contrast_rounded,
                    title: '外观',
                    subtitle: '跟随系统 · 系统取色 · 自动识别设备',
                    onTap: () => _message('外观'),
                  ),
                  SettingsTile(
                    icon: Icons.play_arrow_rounded,
                    title: '播放',
                    subtitle: '1.0x · 自动（优先高清） · 弹幕开',
                    onTap: () => _message('播放'),
                  ),
                  SettingsTile(
                    title: '行尾显示当前值',
                    value: '1.0x',
                    onTap: () => _message('倍速'),
                  ),
                  SettingsTile(
                    title: '没有图标和副标题的行',
                    onTap: () => _message('普通行'),
                  ),
                  SettingsTile(
                    title: '行尾放开关',
                    subtitle: '开关和当前值直接放在行尾',
                    trailing: Switch(
                      value: _toggle,
                      onChanged: (value) => setState(() => _toggle = value),
                    ),
                    onTap: () => setState(() => _toggle = !_toggle),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SectionHeader(title: '状态页')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final view in [
                    const StatusView.loading(),
                    const StatusView(
                      title: '这个分类还没有剧',
                      message: '换一个分类看看',
                      icon: Icons.inbox_outlined,
                    ),
                    StatusView(
                      title: '加载失败',
                      message: '网络连接超时',
                      icon: Icons.cloud_off_rounded,
                      action: '重试',
                      onAction: () => _message('重试'),
                    ),
                  ])
                    SizedBox(
                      width: 280,
                      height: 260,
                      child: GroupCard(children: [Expanded(child: view)]),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
