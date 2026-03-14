import 'package:flutter/material.dart';

import 'package:ddoge/data/database/app_database.dart';

/// 当前时间指示线组件
///
/// 在课程表网格中显示一条红色横线，表示当前时间位置
class CurrentTimeLine extends StatelessWidget {
  const CurrentTimeLine({
    super.key,
    required this.timeSlots,
    required this.slotHeight,
    required this.dayWidth,
    required this.todayIndex,
  });

  /// 节次时间配置
  final List<TimeSlot> timeSlots;

  /// 每个节次的高度
  final double slotHeight;

  /// 每天的列宽
  final double dayWidth;

  /// 今天是周几（0=周一, -1 表示不在本周）
  final int todayIndex;

  @override
  Widget build(BuildContext context) {
    if (todayIndex < 0 || timeSlots.isEmpty) {
      return const SizedBox.shrink();
    }

    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;

    // 查找当前时间在哪个节次范围内
    double? topOffset;
    for (int i = 0; i < timeSlots.length; i++) {
      final slot = timeSlots[i];
      final slotStart = slot.startHour * 60 + slot.startMinute;
      final slotEnd = slot.endHour * 60 + slot.endMinute;

      if (nowMinutes >= slotStart && nowMinutes <= slotEnd) {
        // 在某节课内：按比例计算位置
        final progress = (nowMinutes - slotStart) / (slotEnd - slotStart);
        topOffset = i * slotHeight + progress * slotHeight;
        break;
      } else if (i < timeSlots.length - 1) {
        final nextSlotStart =
            timeSlots[i + 1].startHour * 60 + timeSlots[i + 1].startMinute;
        if (nowMinutes > slotEnd && nowMinutes < nextSlotStart) {
          // 在两节课之间
          topOffset = (i + 1) * slotHeight;
          break;
        }
      }
    }

    // 如果在第一节课之前或最后一节课之后，不显示
    if (topOffset == null) {
      final firstStart =
          timeSlots.first.startHour * 60 + timeSlots.first.startMinute;
      final lastEnd =
          timeSlots.last.endHour * 60 + timeSlots.last.endMinute;
      if (nowMinutes < firstStart || nowMinutes > lastEnd) {
        return const SizedBox.shrink();
      }
      topOffset = timeSlots.length * slotHeight;
    }

    return Positioned(
      top: topOffset,
      left: 40 + todayIndex * dayWidth,
      width: dayWidth,
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 1.5,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }
}
