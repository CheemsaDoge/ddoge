import 'package:home_widget/home_widget.dart';

import 'package:ddoge/core/constants/time_slots.dart';
import 'package:ddoge/core/utils/date_utils.dart' as app_date;
import 'package:ddoge/data/database/app_database.dart';

/// 桌面小组件服务 — 更新 Android/iOS 桌面课表组件
class WidgetService {
  WidgetService._();
  static final instance = WidgetService._();

  static const _appGroupId = 'group.com.ddoge.ddoge';
  static const _androidWidgetName = 'HomeWidgetProvider';

  /// 初始化
  Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// 更新桌面小组件内容
  ///
  /// [semester] 当前学期
  /// [courses] 当前学期的所有课程
  /// [timeSlots] 节次时间配置
  Future<void> updateWidget({
    required Semester? semester,
    required List<Course> courses,
    required List<TimeSlot> timeSlots,
  }) async {
    final title = _buildTitle();
    final content = _buildContent(semester, courses, timeSlots);

    await HomeWidget.saveWidgetData<String>('widget_title', title);
    await HomeWidget.saveWidgetData<String>('widget_content', content);
    await HomeWidget.updateWidget(androidName: _androidWidgetName);
  }

  /// 标题：今日日期
  String _buildTitle() {
    final now = DateTime.now();
    final weekdays = TimeSlotConstants.weekdayNames;
    final weekday = weekdays[now.weekday - 1];
    return '${now.month}月${now.day}日 $weekday';
  }

  /// 内容：今日课程列表
  String _buildContent(
    Semester? semester,
    List<Course> courses,
    List<TimeSlot> timeSlots,
  ) {
    if (semester == null) return '请先设置学期';

    final currentWeek =
        app_date.DateUtils.currentWeekNumber(semester.startDate);
    if (currentWeek < 1 || currentWeek > semester.totalWeeks) {
      return '当前不在学期范围内';
    }

    final todayWeekday = DateTime.now().weekday;

    // 过滤今天且本周有课的课程
    final todayCourses = courses.where((c) {
      if (c.dayOfWeek != todayWeekday) return false;
      return app_date.DateUtils.isCourseActiveInWeek(
        c.startWeek,
        c.endWeek,
        c.weekType,
        currentWeek,
      );
    }).toList()
      ..sort((a, b) => a.startSlot.compareTo(b.startSlot));

    if (todayCourses.isEmpty) return '今天没有课程，享受自由时光!';

    final buffer = StringBuffer();
    buffer.writeln('第$currentWeek周 共${todayCourses.length}节课');
    buffer.writeln();

    for (final course in todayCourses) {
      final slot = _findTimeSlot(timeSlots, course.startSlot);
      final timeStr = slot != null
          ? '${slot.startHour.toString().padLeft(2, '0')}:${slot.startMinute.toString().padLeft(2, '0')}'
          : '第${course.startSlot}节';

      buffer.write('$timeStr ${course.name}');
      if (course.classroom.isNotEmpty) buffer.write(' @${course.classroom}');
      buffer.writeln();
    }

    return buffer.toString().trimRight();
  }

  TimeSlot? _findTimeSlot(List<TimeSlot> slots, int slotIndex) {
    for (final s in slots) {
      if (s.index == slotIndex) return s;
    }
    return null;
  }
}
