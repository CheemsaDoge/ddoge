import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ddoge/data/services/notification_service.dart';
import 'package:ddoge/data/services/reminder_scheduler.dart';
import 'package:ddoge/data/services/widget_service.dart';
import 'package:ddoge/features/schedule/providers/schedule_providers.dart';

/// 课前提醒分钟数：0=关闭, 5/10/15/30
final reminderMinutesProvider = StateProvider<int>((ref) {
  return ref.read(settingsStorageProvider).getReminderMinutes();
});

/// 通知服务实例
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

/// 提醒调度器
final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  return ReminderScheduler.instance;
});

/// 桌面小组件服务
final widgetServiceProvider = Provider<WidgetService>((ref) {
  return WidgetService.instance;
});

/// 监听课程/学期变化，自动重新调度提醒 & 刷新小组件
final reminderAutoScheduleProvider = Provider<void>((ref) {
  final semester = ref.watch(currentSemesterProvider).valueOrNull;
  final courses =
      ref.watch(coursesForCurrentSemesterProvider).valueOrNull ?? [];
  final timeSlots = ref.watch(timeSlotsProvider).valueOrNull ?? [];
  final minutes = ref.watch(reminderMinutesProvider);

  if (semester == null) return;

  // 调度课前提醒
  Future.microtask(() {
    ReminderScheduler.instance.rescheduleAll(
      semester: semester,
      courses: courses,
      timeSlots: timeSlots,
      minutesBefore: minutes,
    );
  });

  // 刷新桌面小组件
  Future.microtask(() {
    WidgetService.instance.updateWidget(
      semester: semester,
      courses: courses,
      timeSlots: timeSlots,
    );
  });
});
