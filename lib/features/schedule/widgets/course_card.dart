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
  void _handleTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final color = AppColors.courseColors[
        widget.course.colorIndex % AppColors.courseColors.length];
    final textColor = _contrastTextColor(color);
    final fs = widget.fontScale;
    final nameMaxLines = switch (widget.slotCount) {
      <= 1 => 2,
      2 => 3,
      _ => 4,
    };
    final detailMaxLines = switch (widget.slotCount) {
      <= 1 => 1,
      2 => 2,
      _ => 3,
    };
    final showTeacher = widget.course.teacher.isNotEmpty && widget.slotCount >= 3;

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
          border: Border.all(
            color: textColor.withValues(alpha: 0.12),
            width: 0.8,
          ),
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
              padding: const EdgeInsets.fromLTRB(6, 6, 5, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    widget.course.name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11 * fs,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    maxLines: nameMaxLines,
                    overflow: TextOverflow.clip,
                    softWrap: true,
                    textAlign: TextAlign.left,
                  ),
                  if (widget.course.classroom.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      '@${widget.course.classroom}',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.85),
                        fontSize: 9 * fs,
                        height: 1.2,
                      ),
                      maxLines: detailMaxLines,
                      overflow: TextOverflow.clip,
                      softWrap: true,
                      textAlign: TextAlign.left,
                    ),
                  ],
                  if (showTeacher) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.course.teacher,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.74),
                        fontSize: 8.5 * fs,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      textAlign: TextAlign.left,
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
