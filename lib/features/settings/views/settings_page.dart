import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ddoge/features/schedule/providers/schedule_providers.dart';

/// 设置页面
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final autoFit = ref.watch(autoFitHeightProvider);
    final fixedSlotHeight = ref.watch(fixedSlotHeightProvider);
    final cardRadius = ref.watch(cardBorderRadiusProvider);
    final cardOpacity = ref.watch(cardOpacityProvider);
    final cardFontScale = ref.watch(cardFontScaleProvider);
    final showGrid = ref.watch(showGridLinesProvider);
    final showTimeLine = ref.watch(showTimeLineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // 学期管理
          _SettingsSection(
            title: '学期管理',
            children: [
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('学期设置'),
                subtitle: const Text('开学日期、总周数'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/semester'),
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('节次时间'),
                subtitle: const Text('自定义每节课的上课时间和时长'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/time-slots'),
              ),
            ],
          ),

          // 课表显示
          _SettingsSection(
            title: '课表显示',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.fit_screen_outlined),
                title: const Text('自适应一屏显示'),
                subtitle: const Text('课表自动缩放以适应屏幕，无需滚动'),
                value: autoFit,
                onChanged: (v) {
                  ref.read(autoFitHeightProvider.notifier).state = v;
                },
              ),
              if (!autoFit)
                ListTile(
                  leading: const Icon(Icons.height),
                  title: const Text('格子高度'),
                  subtitle: Slider(
                    value: fixedSlotHeight,
                    min: 40,
                    max: 100,
                    divisions: 12,
                    label: '${fixedSlotHeight.round()}',
                    onChanged: (v) {
                      ref.read(fixedSlotHeightProvider.notifier).state = v;
                    },
                  ),
                  trailing: Text('${fixedSlotHeight.round()}'),
                ),
            ],
          ),

          // 卡片样式
          _SettingsSection(
            title: '卡片样式',
            children: [
              ListTile(
                leading: const Icon(Icons.rounded_corner),
                title: const Text('圆角半径'),
                subtitle: Slider(
                  value: cardRadius,
                  min: 0,
                  max: 20,
                  divisions: 20,
                  label: '${cardRadius.round()}',
                  onChanged: (v) {
                    ref.read(cardBorderRadiusProvider.notifier).state = v;
                  },
                ),
                trailing: Text('${cardRadius.round()}'),
              ),
              ListTile(
                leading: const Icon(Icons.opacity),
                title: const Text('透明度'),
                subtitle: Slider(
                  value: cardOpacity,
                  min: 0.3,
                  max: 1.0,
                  divisions: 14,
                  label: '${(cardOpacity * 100).round()}%',
                  onChanged: (v) {
                    ref.read(cardOpacityProvider.notifier).state = v;
                  },
                ),
                trailing: Text('${(cardOpacity * 100).round()}%'),
              ),
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('字体缩放'),
                subtitle: Slider(
                  value: cardFontScale,
                  min: 0.8,
                  max: 1.4,
                  divisions: 12,
                  label: '${(cardFontScale * 100).round()}%',
                  onChanged: (v) {
                    ref.read(cardFontScaleProvider.notifier).state = v;
                  },
                ),
                trailing: Text('${(cardFontScale * 100).round()}%'),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.grid_on),
                title: const Text('显示网格线'),
                value: showGrid,
                onChanged: (v) {
                  ref.read(showGridLinesProvider.notifier).state = v;
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.timeline),
                title: const Text('显示当前时间线'),
                value: showTimeLine,
                onChanged: (v) {
                  ref.read(showTimeLineProvider.notifier).state = v;
                },
              ),
            ],
          ),

          // 外观
          _SettingsSection(
            title: '外观',
            children: [
              ListTile(
                leading: const Icon(Icons.wallpaper_outlined),
                title: const Text('课表背景'),
                subtitle: const Text('设置内置壁纸或自定义图片'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/background'),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('主题模式'),
                trailing: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('自动')),
                    ButtonSegment(value: 1, label: Text('浅色')),
                    ButtonSegment(value: 2, label: Text('深色')),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (v) {
                    ref.read(themeModeProvider.notifier).state = v.first;
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),

          // 数据管理
          _SettingsSection(
            title: '数据',
            children: [
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('导出课程数据'),
                subtitle: const Text('导出为 JSON 文件'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('导出功能将在后续版本实现')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('导入课程数据'),
                subtitle: const Text('从 JSON 文件导入'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('导入功能将在后续版本实现')),
                  );
                },
              ),
            ],
          ),

          // 关于
          _SettingsSection(
            title: '关于',
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('DDoge 课程表'),
                subtitle: const Text('版本 1.0.0'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 设置分区组件
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        ...children,
      ],
    );
  }
}
