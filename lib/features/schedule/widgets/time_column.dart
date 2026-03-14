import 'package:flutter/material.dart';

import 'package:ddoge/core/constants/time_slots.dart';
import 'package:ddoge/data/database/app_database.dart';

/// 左侧时间列组件
///
/// 显示每节课的序号、上课时间和下课时间
class TimeColumn extends StatelessWidget {
  const TimeColumn({
    super.key,
    required this.slotHeight,
    required this.timeSlots,
  });

  /// 每个节次的高度
  final double slotHeight;

  /// 节次时间配置
  final List<TimeSlot> timeSlots;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slotCount = timeSlots.isEmpty
        ? TimeSlotConstants.maxSlotsPerDay
        : timeSlots.length;

    return SizedBox(
      width: 40,
      child: Column(
        children: List.generate(slotCount, (index) {
          final slot = index < timeSlots.length ? timeSlots[index] : null;
          final startTime = slot != null
              ? '${slot.startHour.toString().padLeft(2, '0')}:${slot.startMinute.toString().padLeft(2, '0')}'
              : '';
          final endTime = slot != null
              ? '${slot.endHour.toString().padLeft(2, '0')}:${slot.endMinute.toString().padLeft(2, '0')}'
              : '';

          final timeStyle = theme.textTheme.labelSmall?.copyWith(
            fontSize: 8,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          );

          return SizedBox(
            height: slotHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (startTime.isNotEmpty)
                  Text(startTime, style: timeStyle),
                Text(
                  '${index + 1}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (endTime.isNotEmpty)
                  Text(endTime, style: timeStyle),
              ],
            ),
          );
        }),
      ),
    );
  }
}
