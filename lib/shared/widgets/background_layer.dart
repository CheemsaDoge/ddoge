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
    final bgType = ref.watch(backgroundTypeProvider);
    final builtinIndex = ref.watch(builtinWallpaperProvider);
    final customBgPath = ref.watch(customBackgroundPathProvider);
    final bgOpacity = ref.watch(backgroundOpacityProvider);

    if (bgType == BackgroundType.none) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: bgOpacity,
          child: _buildBackground(bgType, builtinIndex, customBgPath),
        ),
      ),
    );
  }

  Widget _buildBackground(
    BackgroundType type,
    int builtinIndex,
    String? customPath,
  ) {
    if (type == BackgroundType.builtin &&
        builtinIndex < BuiltinWallpapers.all.length) {
      return Container(
        decoration: BoxDecoration(
          gradient: BuiltinWallpapers.all[builtinIndex].toGradient(),
        ),
      );
    } else if (type == BackgroundType.custom && customPath != null) {
      return Image.file(
        File(customPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    return const SizedBox.shrink();
  }
}
