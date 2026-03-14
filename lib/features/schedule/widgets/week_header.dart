import 'package:flutter/material.dart';

import 'package:ddoge/core/constants/time_slots.dart';

/// 顶部星期+日期头组件
///
/// 最左侧显示月份，右侧显示 7 天的星期和日期
class WeekHeader extends StatelessWidget {
  const WeekHeader({
    super.key,
    required this.dates,
    required this.dayWidth,
  });

  /// 本周每天的日期
  final List<DateTime> dates;

  /// 每天的列宽
  final double dayWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();

    // 取本周中间日期的月份作为显示月份
    final midDate = dates.isNotEmpty && dates.length > 3 ? dates[3] : today;

    return Row(
      children: [
        // 左侧月份指示器
        SizedBox(
          width: 40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${midDate.month}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                '月',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        // 7天的头部
        ...List.generate(7, (index) {
          final date = index < dates.length ? dates[index] : null;
          final isToday = date != null &&
              date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;

          return SizedBox(
            width: dayWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  TimeSlotConstants.weekdayShortNames[index],
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isToday
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                if (date != null)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: isToday
                        ? BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          )
                        : null,
                    alignment: Alignment.center,
                    child: Text(
                      '${date.day}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isToday
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight:
                            isToday ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
