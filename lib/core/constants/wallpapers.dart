import 'package:flutter/material.dart';

/// 内置渐变壁纸定义
class BuiltinWallpaper {
  const BuiltinWallpaper({
    required this.name,
    required this.colors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });

  final String name;
  final List<Color> colors;
  final Alignment begin;
  final Alignment end;

  /// 生成渐变装饰
  LinearGradient toGradient() {
    return LinearGradient(
      colors: colors,
      begin: begin,
      end: end,
    );
  }
}

/// 内置壁纸集合
class BuiltinWallpapers {
  BuiltinWallpapers._();

  static const List<BuiltinWallpaper> all = [
    // 晨曦蓝紫
    BuiltinWallpaper(
      name: '晨曦',
      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
    ),
    // 暖阳橘粉
    BuiltinWallpaper(
      name: '暖阳',
      colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ),
    // 薄荷清新
    BuiltinWallpaper(
      name: '薄荷',
      colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    // 森林绿意
    BuiltinWallpaper(
      name: '森林',
      colors: [Color(0xFF38ef7d), Color(0xFF11998e)],
    ),
    // 星空紫蓝
    BuiltinWallpaper(
      name: '星空',
      colors: [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    // 日落金橙
    BuiltinWallpaper(
      name: '日落',
      colors: [Color(0xFFf12711), Color(0xFFf5af19)],
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
    ),
    // 樱花粉白
    BuiltinWallpaper(
      name: '樱花',
      colors: [Color(0xFFffecd2), Color(0xFFfcb69f)],
    ),
    // 海洋深蓝
    BuiltinWallpaper(
      name: '海洋',
      colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    ),
  ];
}
