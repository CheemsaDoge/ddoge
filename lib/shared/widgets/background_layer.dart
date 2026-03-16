import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ddoge/core/constants/wallpapers.dart';
import 'package:ddoge/core/storage/settings_storage.dart';
import 'package:ddoge/features/schedule/providers/schedule_providers.dart';

/// 背景层组件
class BackgroundLayer extends ConsumerWidget {
  const BackgroundLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bgType = ref.watch(backgroundTypeProvider);
    final builtinIndex = ref.watch(builtinWallpaperProvider);
    final customBgPath = ref.watch(customBackgroundPathProvider);
    final bgOpacity = ref.watch(backgroundOpacityProvider);

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: bgOpacity,
          child: _buildBackground(
            theme,
            bgType,
            builtinIndex,
            customBgPath,
          ),
        ),
      ),
    );
  }

  Widget _buildBackground(
    ThemeData theme,
    BackgroundType type,
    int builtinIndex,
    String? customPath,
  ) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
            theme.colorScheme.surface.withValues(alpha: 0.96),
          ],
        ),
      ),
    );

    if (type == BackgroundType.builtin &&
        builtinIndex < BuiltinWallpapers.all.length) {
      return Container(
        decoration: BoxDecoration(
          gradient: BuiltinWallpapers.all[builtinIndex].toGradient(),
        ),
      );
    } else if (type == BackgroundType.custom && customPath != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          fallback,
          Image.file(
            File(customPath),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ],
      );
    }
    return fallback;
  }
}
