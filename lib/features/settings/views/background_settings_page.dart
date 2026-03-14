import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:ddoge/core/constants/wallpapers.dart';
import 'package:ddoge/core/storage/settings_storage.dart';
import 'package:ddoge/features/schedule/providers/schedule_providers.dart';

/// 课表背景设置页面
class BackgroundSettingsPage extends ConsumerWidget {
  const BackgroundSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bgType = ref.watch(backgroundTypeProvider);
    final builtinIndex = ref.watch(builtinWallpaperProvider);
    final customPath = ref.watch(customBackgroundPathProvider);
    final opacity = ref.watch(backgroundOpacityProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('课表背景')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 预览区域
          _buildPreview(context, bgType, builtinIndex, customPath, opacity),
          const SizedBox(height: 24),

          // 透明度调节
          Text('背景透明度', style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          )),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('淡'),
              Expanded(
                child: Slider(
                  value: opacity,
                  min: 0.05,
                  max: 0.8,
                  divisions: 15,
                  label: '${(opacity * 100).round()}%',
                  onChanged: (v) {
                    ref.read(backgroundOpacityProvider.notifier).state = v;
                    _saveOpacity(ref, v);
                  },
                ),
              ),
              const Text('浓'),
            ],
          ),
          const SizedBox(height: 24),

          // 无背景选项
          Text('背景选择', style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          )),
          const SizedBox(height: 8),
          _buildOptionTile(
            context,
            icon: Icons.block,
            label: '无背景',
            selected: bgType == BackgroundType.none,
            onTap: () => _selectNone(ref),
          ),
          const SizedBox(height: 8),

          // 本地图片选项
          _buildOptionTile(
            context,
            icon: Icons.photo_library_outlined,
            label: '选择本地图片',
            subtitle: bgType == BackgroundType.custom && customPath != null
                ? p.basename(customPath)
                : null,
            selected: bgType == BackgroundType.custom,
            onTap: () => _pickLocalImage(context, ref),
          ),
          const SizedBox(height: 16),

          // 内置渐变壁纸网格
          Text('内置壁纸', style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          )),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: BuiltinWallpapers.all.length,
            itemBuilder: (context, index) {
              final wallpaper = BuiltinWallpapers.all[index];
              final isSelected = bgType == BackgroundType.builtin &&
                  builtinIndex == index;

              return GestureDetector(
                onTap: () => _selectBuiltin(ref, index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    gradient: wallpaper.toGradient(),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(
                            color: theme.colorScheme.primary,
                            width: 3,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          wallpaper.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 预览区域
  Widget _buildPreview(
    BuildContext context,
    BackgroundType bgType,
    int builtinIndex,
    String? customPath,
    double opacity,
  ) {
    final theme = Theme.of(context);

    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 模拟网格
          CustomPaint(painter: _PreviewGridPainter(theme)),
          // 背景层
          if (bgType == BackgroundType.builtin &&
              builtinIndex < BuiltinWallpapers.all.length)
            Opacity(
              opacity: opacity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: BuiltinWallpapers.all[builtinIndex].toGradient(),
                ),
              ),
            ),
          if (bgType == BackgroundType.custom && customPath != null)
            Opacity(
              opacity: opacity,
              child: Image.file(
                File(customPath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ),
          // 标签
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '预览效果',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.bodyMedium),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle,
                    color: theme.colorScheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _selectNone(WidgetRef ref) {
    ref.read(backgroundTypeProvider.notifier).state = BackgroundType.none;
    final storage = ref.read(settingsStorageProvider);
    storage.setBackgroundType(BackgroundType.none);
  }

  void _selectBuiltin(WidgetRef ref, int index) {
    ref.read(backgroundTypeProvider.notifier).state = BackgroundType.builtin;
    ref.read(builtinWallpaperProvider.notifier).state = index;
    final storage = ref.read(settingsStorageProvider);
    storage.setBackgroundType(BackgroundType.builtin);
    storage.setBuiltinWallpaper(index);
  }

  Future<void> _pickLocalImage(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final sourcePath = result.files.single.path;
    if (sourcePath == null) return;

    // 复制图片到应用目录，确保持久化
    final appDir = await getApplicationDocumentsDirectory();
    final bgDir = Directory(p.join(appDir.path, 'ddoge_backgrounds'));
    if (!await bgDir.exists()) {
      await bgDir.create(recursive: true);
    }
    final ext = p.extension(sourcePath);
    final destPath = p.join(bgDir.path, 'custom_bg$ext');
    await File(sourcePath).copy(destPath);

    ref.read(backgroundTypeProvider.notifier).state = BackgroundType.custom;
    ref.read(customBackgroundPathProvider.notifier).state = destPath;
    final storage = ref.read(settingsStorageProvider);
    storage.setBackgroundType(BackgroundType.custom);
    storage.setCustomBackgroundPath(destPath);
  }

  void _saveOpacity(WidgetRef ref, double opacity) {
    final storage = ref.read(settingsStorageProvider);
    storage.setBackgroundOpacity(opacity);
  }
}

/// 预览网格线绘制器
class _PreviewGridPainter extends CustomPainter {
  _PreviewGridPainter(this.theme);

  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = theme.colorScheme.outlineVariant.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;

    const cols = 7;
    const rows = 6;
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    for (int i = 0; i <= cols; i++) {
      canvas.drawLine(Offset(i * cellW, 0), Offset(i * cellW, size.height), paint);
    }
    for (int i = 0; i <= rows; i++) {
      canvas.drawLine(Offset(0, i * cellH), Offset(size.width, i * cellH), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
