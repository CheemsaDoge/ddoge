import 'dart:ui';
import 'package:flutter/material.dart';

/// 毛玻璃容器
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    this.child,
    this.blur = 10.0,
    this.opacity = 0.5,
    this.borderRadius,
    this.border,
    this.color,
  });

  final Widget? child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = color ?? (theme.brightness == Brightness.light
        ? Colors.white.withValues(alpha: opacity)
        : Colors.black.withValues(alpha: opacity));

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: borderRadius,
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 毛玻璃 AppBar
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.bottom,
    this.blur = 15.0,
    this.opacity = 0.5,
    this.toolbarHeight = kToolbarHeight,
  });

  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final double blur;
  final double opacity;
  final double toolbarHeight;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: blur,
      opacity: opacity,
      child: AppBar(
        title: title,
        actions: actions,
        leading: leading,
        bottom: bottom,
        toolbarHeight: toolbarHeight,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
      toolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}
