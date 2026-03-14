import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ddoge/data/database/app_database.dart';
import 'package:ddoge/features/schedule/providers/schedule_providers.dart';

/// 今日课程页面
///
/// 纵向时间轴展示当天课程，高亮当前/下一节课
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semesterAsync = ref.watch(currentSemesterProvider);
    final timeSlotsAsync = ref.watch(timeSlotsProvider);
    final coursesAsync = ref.watch(coursesForSelectedWeekProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _todayTitle(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: semesterAsync.when(
        data: (semester) {
          if (semester == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_busy, size: 64,
                      color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('请先设置学期', style: theme.textTheme.bodyLarge),
                ],
              ),
            );
          }

          final todayWeekday = DateTime.now().weekday; // 1=周一
          final timeSlots = timeSlotsAsync.valueOrNull ?? [];

          // 过滤出今天的课程
          final todayCourses = coursesAsync
              .where((c) => c.dayOfWeek == todayWeekday)
              .toList()
            ..sort((a, b) => a.startSlot.compareTo(b.startSlot));

          if (todayCourses.isEmpty) {
            return _buildFreeDayView(theme);
          }

          return _buildCourseTimeline(theme, todayCourses, timeSlots);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  String _todayTitle() {
    final now = DateTime.now();
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${now.month}月${now.day}日 ${weekdays[now.weekday - 1]}';
  }

  /// 无课提示
  Widget _buildFreeDayView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wb_sunny_outlined, size: 80,
              color: theme.colorScheme.tertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 20),
          Text('今天没有课程', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('享受自由时光吧！',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
        ],
      ),
    );
  }

  /// 课程时间轴列表
  Widget _buildCourseTimeline(
    ThemeData theme,
    List<Course> courses,
    List<TimeSlot> timeSlots,
  ) {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final course = courses[index];
        final slot = _findTimeSlot(timeSlots, course.startSlot);
        final endSlot = _findTimeSlot(timeSlots, course.endSlot);

        // 判断课程状态
        final startMinutes = slot != null
            ? slot.startHour * 60 + slot.startMinute
            : 0;
        final endMinutes = endSlot != null
            ? endSlot.endHour * 60 + endSlot.endMinute
            : 0;

        final _CourseStatus status;
        if (nowMinutes < startMinutes) {
          status = _CourseStatus.upcoming;
        } else if (nowMinutes <= endMinutes) {
          status = _CourseStatus.ongoing;
        } else {
          status = _CourseStatus.finished;
        }

        // 距离上课的倒计时
        String? countdown;
        if (status == _CourseStatus.upcoming) {
          final diff = startMinutes - nowMinutes;
          if (diff <= 60) {
            countdown = '${diff}分钟后上课';
          }
        } else if (status == _CourseStatus.ongoing) {
          final remaining = endMinutes - nowMinutes;
          countdown = '还剩${remaining}分钟';
        }

        final isLast = index == courses.length - 1;

        return _TodayCourseCard(
          course: course,
          timeSlot: slot,
          endTimeSlot: endSlot,
          status: status,
          countdown: countdown,
          isLast: isLast,
        );
      },
    );
  }

  TimeSlot? _findTimeSlot(List<TimeSlot> slots, int slotIndex) {
    for (final s in slots) {
      if (s.index == slotIndex) return s;
    }
    return null;
  }
}

enum _CourseStatus { upcoming, ongoing, finished }

/// 今日课程卡片（时间轴样式）
class _TodayCourseCard extends StatelessWidget {
  const _TodayCourseCard({
    required this.course,
    required this.timeSlot,
    required this.endTimeSlot,
    required this.status,
    this.countdown,
    this.isLast = false,
  });

  final Course course;
  final TimeSlot? timeSlot;
  final TimeSlot? endTimeSlot;
  final _CourseStatus status;
  final String? countdown;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOngoing = status == _CourseStatus.ongoing;
    final isFinished = status == _CourseStatus.finished;

    final startTime = timeSlot != null
        ? '${timeSlot!.startHour.toString().padLeft(2, '0')}:${timeSlot!.startMinute.toString().padLeft(2, '0')}'
        : '--:--';
    final endTime = endTimeSlot != null
        ? '${endTimeSlot!.endHour.toString().padLeft(2, '0')}:${endTimeSlot!.endMinute.toString().padLeft(2, '0')}'
        : '--:--';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧时间轴
          SizedBox(
            width: 56,
            child: Column(
              children: [
                // 时间轴圆点
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOngoing
                        ? theme.colorScheme.primary
                        : isFinished
                            ? theme.colorScheme.outlineVariant
                            : theme.colorScheme.primaryContainer,
                    border: isOngoing
                        ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3), width: 3)
                        : null,
                  ),
                ),
                // 连线
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
          // 右侧课程信息
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isOngoing
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.6)
                      : isFinished
                          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
                          : theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: isOngoing
                      ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4), width: 1.5)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 时间 + 节次
                    Row(
                      children: [
                        Text(
                          '$startTime - $endTime',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: isFinished
                                ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                                : theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '第${course.startSlot}-${course.endSlot}节',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (countdown != null) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isOngoing
                                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                  : theme.colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              countdown!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isOngoing
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 课程名
                    Text(
                      course.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isFinished
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                            : null,
                        decoration: isFinished ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 教室 + 教师
                    Row(
                      children: [
                        if (course.classroom.isNotEmpty) ...[
                          Icon(Icons.location_on_outlined, size: 14,
                              color: theme.colorScheme.onSurfaceVariant.withValues(
                                  alpha: isFinished ? 0.3 : 0.7)),
                          const SizedBox(width: 4),
                          Text(
                            course.classroom,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(
                                  alpha: isFinished ? 0.4 : 0.8),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (course.teacher.isNotEmpty) ...[
                          Icon(Icons.person_outline, size: 14,
                              color: theme.colorScheme.onSurfaceVariant.withValues(
                                  alpha: isFinished ? 0.3 : 0.7)),
                          const SizedBox(width: 4),
                          Text(
                            course.teacher,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(
                                  alpha: isFinished ? 0.4 : 0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
