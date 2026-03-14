import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ddoge/features/schedule/providers/schedule_providers.dart';

/// 个性化设置页面
///
/// 包含卡片样式、网格线、时间线等视觉相关设置
class PersonalizationSettingsPage extends ConsumerWidget {
  const PersonalizationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsStorage = ref.read(settingsStorageProvider);
    final autoFit = ref.watch(autoFitHeightProvider);
    final fixedSlotHeight = ref.watch(fixedSlotHeightProvider);
    final cardRadius = ref.watch(cardBorderRadiusProvider);
    final cardOpacity = ref.watch(cardOpacityProvider);
    final cardFontScale = ref.watch(cardFontScaleProvider);
    final showGrid = ref.watch(showGridLinesProvider);
    final showTimeLine = ref.watch(showTimeLineProvider);
    final gridLineColorIndex = ref.watch(gridLineColorIndexProvider);
    final gridLineWidth = ref.watch(gridLineWidthProvider);
    final gridLineOpacity = ref.watch(gridLineOpacityProvider);
    final gridLineDashed = ref.watch(gridLineDashedProvider);
    final theme = Theme.of(context);
    final gridColors = <Color>[
      theme.colorScheme.outlineVariant,
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.onSurfaceVariant,
      const Color(0xFF00ACC1),
    ];
    const gridColorLabels = ['默认', '主色', '辅色', '强调', '灰色', '青色'];

    return Scaffold(
      appBar: AppBar(title: const Text('个性化')),
      body: ListView(
        children: [
          // 课表显示
          _Section(
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
              SwitchListTile(
                secondary: const Icon(Icons.grid_on),
                title: const Text('显示网格线'),
                value: showGrid,
                onChanged: (v) {
                  ref.read(showGridLinesProvider.notifier).state = v;
                },
              ),
              if (showGrid) ...[
                ListTile(
                  leading: const Icon(Icons.color_lens_outlined),
                  title: const Text('网格线颜色'),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(gridColors.length, (index) {
                        return ChoiceChip(
                          label: Text(gridColorLabels[index]),
                          selected: gridLineColorIndex == index,
                          avatar: CircleAvatar(
                            radius: 8,
                            backgroundColor: gridColors[index],
                          ),
                          onSelected: (_) {
                            ref
                                    .read(gridLineColorIndexProvider.notifier)
                                    .state =
                                index;
                            settingsStorage.setGridLineColorIndex(index);
                          },
                        );
                      }),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.line_weight),
                  title: const Text('网格线粗细'),
                  subtitle: Slider(
                    value: gridLineWidth,
                    min: 0.5,
                    max: 2.0,
                    divisions: 6,
                    label: gridLineWidth.toStringAsFixed(1),
                    onChanged: (v) {
                      ref.read(gridLineWidthProvider.notifier).state = v;
                      settingsStorage.setGridLineWidth(v);
                    },
                  ),
                  trailing: Text(gridLineWidth.toStringAsFixed(1)),
                ),
                ListTile(
                  leading: const Icon(Icons.opacity),
                  title: const Text('网格线透明度'),
                  subtitle: Slider(
                    value: gridLineOpacity,
                    min: 0.1,
                    max: 0.9,
                    divisions: 8,
                    label: '${(gridLineOpacity * 100).round()}%',
                    onChanged: (v) {
                      ref.read(gridLineOpacityProvider.notifier).state = v;
                      settingsStorage.setGridLineOpacity(v);
                    },
                  ),
                  trailing: Text('${(gridLineOpacity * 100).round()}%'),
                ),
                ListTile(
                  leading: const Icon(Icons.border_style),
                  title: const Text('网格线样式'),
                  subtitle: const Text('在实线和虚线之间切换'),
                  trailing: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(value: false, label: Text('实线')),
                      ButtonSegment<bool>(value: true, label: Text('虚线')),
                    ],
                    selected: {gridLineDashed},
                    onSelectionChanged: (selection) {
                      final dashed = selection.first;
                      ref.read(gridLineDashedProvider.notifier).state = dashed;
                      settingsStorage.setGridLineDashed(dashed);
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
              SwitchListTile(
                secondary: const Icon(Icons.timeline),
                title: const Text('显示当前时间线'),
                subtitle: const Text('在课表中以红线标示当前时间'),
                value: showTimeLine,
                onChanged: (v) {
                  ref.read(showTimeLineProvider.notifier).state = v;
                },
              ),
            ],
          ),

          // 卡片样式
          _Section(
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
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

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
