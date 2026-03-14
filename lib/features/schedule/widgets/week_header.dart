import 'package:flutter/material.dart';

import 'package:ddoge/core/constants/time_slots.dart';

/// 顶部星期+日期头组件
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

    return Row(
      children: [
        // 左侧时间列占位
        const SizedBox(width: 40),
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
