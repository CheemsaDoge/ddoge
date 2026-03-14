import 'package:flutter/material.dart';

import 'package:ddoge/core/constants/app_colors.dart';
import 'package:ddoge/data/database/app_database.dart';

/// 课程卡片组件
///
/// 显示课程名称、教室、教师，使用彩色圆角卡片样式
/// 点击时带有缩放动画反馈，支持自定义圆角、透明度、字号
class CourseCard extends StatefulWidget {
  const CourseCard({
    super.key,
    required this.course,
    required this.slotCount,
    this.onTap,
    this.onLongPress,
    this.borderRadius = 8.0,
    this.opacity = 0.85,
    this.fontScale = 1.0,
  });

  final Course course;
  final int slotCount;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final double opacity;
  final double fontScale;

  @override
  State<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) => _controller.forward();
  void _handleTapUp(TapUpDetails _) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final color = AppColors.courseColors[
        widget.course.colorIndex % AppColors.courseColors.length];
    final textColor = _contrastTextColor(color);
    final fs = widget.fontScale;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: widget.opacity),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTapDown: _handleTapDown,
            onTap: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onLongPress: widget.onLongPress,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            splashColor: textColor.withValues(alpha: 0.2),
            highlightColor: textColor.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.course.name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11 * fs,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: widget.slotCount > 1 ? 4 : 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  if (widget.course.classroom.isNotEmpty &&
                      widget.slotCount > 1) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.course.classroom,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.85),
                        fontSize: 9 * fs,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTapUp() {
    _controller.reverse();
    widget.onTap?.call();
  }

  Color _contrastTextColor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}
