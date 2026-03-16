import 'package:ddoge/core/utils/date_utils.dart' as app_date;
import 'package:ddoge/data/database/app_database.dart';
import 'package:ddoge/data/services/notification_service.dart';

/// 课前提醒调度器
///
/// 根据当前学期、课程、节次时间，计算提醒时刻并调度通知
class ReminderScheduler {
  ReminderScheduler._();
  static final instance = ReminderScheduler._();

  final _notification = NotificationService.instance;

  /// 重新调度所有课前提醒
  ///
  /// [semester] 当前学期
  /// [courses] 当前学期的课程列表
  /// [timeSlots] 节次时间配置
  /// [minutesBefore] 提前提醒的分钟数
  Future<void> rescheduleAll({
    required Semester semester,
    required List<Course> courses,
    required List<TimeSlot> timeSlots,
    required int minutesBefore,
  }) async {
    // 先清空旧通知
    await _notification.cancelAll();

    if (minutesBefore <= 0) return; // 提醒关闭

    final now = DateTime.now();
    final currentWeek = app_date.DateUtils.currentWeekNumber(semester.startDate);

    // 调度接下来 2 周内的课程提醒（避免一次调度太多）
    for (var weekOffset = 0; weekOffset <= 1; weekOffset++) {
      final week = currentWeek + weekOffset;
      if (week < 1 || week > semester.totalWeeks) continue;

      for (final course in courses) {
        if (!app_date.DateUtils.isCourseActiveInWeek(
          course.startWeek,
          course.endWeek,
          course.weekType,
          week,
        )) {
          continue;
        }

        // 找到课程开始时间对应的 TimeSlot
        final slot = _findTimeSlot(timeSlots, course.startSlot);
        if (slot == null) continue;

        // 计算课程所在日期
        final courseDate = app_date.DateUtils.dateForWeekAndDay(
          semester.startDate,
          week,
          course.dayOfWeek,
        );

        // 构建精确课程开始时间
        final courseStart = DateTime(
          courseDate.year,
          courseDate.month,
          courseDate.day,
          slot.startHour,
          slot.startMinute,
        );

        // 提醒时间
        final reminderTime =
            courseStart.subtract(Duration(minutes: minutesBefore));

        // 跳过已过去的提醒
        if (reminderTime.isBefore(now)) continue;

        // 用 course+week+day 生成唯一 ID
        final notifId = _generateId(course.id, week, course.dayOfWeek);

        await _notification.scheduleReminder(
          id: notifId,
          title: '${course.name} 即将开始',
          body: _buildBody(course, slot, minutesBefore),
          scheduledTime: reminderTime,
        );
      }
    }
  }

  /// 生成通知 ID（需要在 int 范围内且尽量唯一）
  int _generateId(String courseId, int week, int day) {
    return (courseId.hashCode + week * 100 + day) & 0x7FFFFFFF;
  }

  /// 构建通知正文
  String _buildBody(Course course, TimeSlot slot, int minutesBefore) {
    final parts = <String>[];
    parts.add('$minutesBefore分钟后上课');
    final timeStr =
        '${slot.startHour.toString().padLeft(2, '0')}:${slot.startMinute.toString().padLeft(2, '0')}';
    parts.add('时间: $timeStr');
    if (course.classroom.isNotEmpty) parts.add('教室: $course.classroom');
    if (course.teacher.isNotEmpty) parts.add('教师: $course.teacher');
    return parts.join('\n');
  }

  TimeSlot? _findTimeSlot(List<TimeSlot> slots, int slotIndex) {
    for (final s in slots) {
      if (s.index == slotIndex) return s;
    }
    return null;
  }
}
