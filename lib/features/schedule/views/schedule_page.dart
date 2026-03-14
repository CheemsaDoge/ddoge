import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ddoge/core/constants/time_slots.dart';
import 'package:ddoge/core/constants/wallpapers.dart';
import 'package:ddoge/core/router/app_router.dart';
import 'package:ddoge/core/storage/settings_storage.dart';
import 'package:ddoge/core/utils/date_utils.dart' as app_date;
import 'package:ddoge/data/database/app_database.dart';
import '../providers/schedule_providers.dart';
import '../widgets/course_card.dart';
import '../widgets/time_column.dart';
import '../widgets/week_header.dart';
import '../widgets/week_selector.dart';
import '../widgets/current_time_line.dart';

/// 课程表周视图主页面
class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  /// 格子选中状态：{dayOfWeek, startSlot, endSlot}
  int? _selectedDay;
  int? _selectedStartSlot;
  int? _selectedEndSlot;

  /// 周切换 PageView 控制器
  PageController? _pageController;
  /// 标记是否正在由 PageView 滑动触发周数变化（避免循环更新）
  bool _isPageAnimating = false;

  /// 网格区域的 Key，用于拖拽手柄的坐标转换
  final GlobalKey _gridKey = GlobalKey();

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  /// 确保 PageController 已初始化，并与当前 selectedWeek 同步
  void _ensurePageController(int totalWeeks, int selectedWeek) {
    if (_pageController == null) {
      _pageController = PageController(initialPage: selectedWeek - 1);
    } else if (!_isPageAnimating &&
        _pageController!.hasClients &&
        _pageController!.page?.round() != selectedWeek - 1) {
      // 外部（WeekSelector/本周按钮）触发的周数变化 → 带动画跳转
      _pageController!.animateToPage(
        selectedWeek - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final semesterAsync = ref.watch(currentSemesterProvider);
    final timeSlotsAsync = ref.watch(timeSlotsProvider);
    final selectedWeek = ref.watch(selectedWeekProvider);
    final allCourses = ref.watch(coursesForCurrentSemesterProvider);
    final autoFit = ref.watch(autoFitHeightProvider);
    final fixedSlotHeight = ref.watch(fixedSlotHeightProvider);
    final cardRadius = ref.watch(cardBorderRadiusProvider);
    final cardOpacity = ref.watch(cardOpacityProvider);
    final cardFontScale = ref.watch(cardFontScaleProvider);
    final showGrid = ref.watch(showGridLinesProvider);
    final showTimeLine = ref.watch(showTimeLineProvider);
    final bgType = ref.watch(backgroundTypeProvider);
    final builtinIndex = ref.watch(builtinWallpaperProvider);
    final customBgPath = ref.watch(customBackgroundPathProvider);
    final bgOpacity = ref.watch(backgroundOpacityProvider);

    return Scaffold(
      appBar: AppBar(
        title: semesterAsync.when(
          data: (semester) => Text(
            semester?.name ?? 'DDoge 课程表',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          loading: () => const Text('DDoge 课程表'),
          error: (_, _) => const Text('DDoge 课程表'),
        ),
        actions: [
          if (selectedWeek != _currentWeekNumber(semesterAsync))
            TextButton(
              onPressed: () {
                final week = _currentWeekNumber(semesterAsync);
                if (week > 0) {
                  ref.read(selectedWeekProvider.notifier).state = week;
                }
              },
              child: const Text('本周'),
            ),
        ],
      ),
      body: semesterAsync.when(
        data: (semester) {
          if (semester == null) {
            return _buildEmptyState(context);
          }

          final totalWeeks = semester.totalWeeks;
          final currentWeek =
              app_date.DateUtils.currentWeekNumber(semester.startDate);
          final timeSlots = timeSlotsAsync.valueOrNull ?? [];
          final coursesList = allCourses.valueOrNull ?? [];

          _ensurePageController(totalWeeks, selectedWeek);

          return Column(
            children: [
              // 周数选择器
              WeekSelector(
                totalWeeks: totalWeeks,
                selectedWeek: selectedWeek,
                currentWeek: currentWeek,
                onWeekSelected: (week) {
                  ref.read(selectedWeekProvider.notifier).state = week;
                },
              ),
              const Divider(height: 1),
              // 课程表网格（PageView 实现平滑滑动过渡）+ 背景独立于课表
              Expanded(
                child: Stack(
                  children: [
                    // 背景图层（固定，不随 PageView 滑动）
                    if (bgType != BackgroundType.none)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: bgOpacity,
                            child: _buildStaticBackground(bgType, builtinIndex, customBgPath),
                          ),
                        ),
                      ),
                    // PageView 层
                    PageView.builder(
                      controller: _pageController,
                      // 有格子选中时禁止 PageView 滑动，防止误触翻页导致变白
                      physics: _selectedDay != null
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      itemCount: totalWeeks,
                      onPageChanged: (index) {
                        _isPageAnimating = true;
                        ref.read(selectedWeekProvider.notifier).state = index + 1;
                        // 切换页面时清除选中状态
                        setState(() {
                          _selectedDay = null;
                          _selectedStartSlot = null;
                          _selectedEndSlot = null;
                        });
                        Future.microtask(() => _isPageAnimating = false);
                      },
                      itemBuilder: (context, index) {
                        final pageWeek = index + 1;
                        // 按周过滤课程
                        final weekCourses = coursesList.where((course) {
                          return app_date.DateUtils.isCourseActiveInWeek(
                            course.startWeek,
                            course.endWeek,
                            course.weekType,
                            pageWeek,
                          );
                        }).toList();

                        return _ScheduleGrid(
                          courses: weekCourses,
                          timeSlots: timeSlots,
                          weekDates: app_date.DateUtils.datesForWeek(
                            semester.startDate,
                            pageWeek,
                          ),
                          selectedWeek: pageWeek,
                          currentWeek: currentWeek,
                          autoFitHeight: autoFit,
                          fixedSlotHeight: fixedSlotHeight,
                          cardBorderRadius: cardRadius,
                          cardOpacity: cardOpacity,
                          cardFontScale: cardFontScale,
                          showGridLines: showGrid,
                          showTimeLine: showTimeLine,
                          selectedDay: pageWeek == selectedWeek ? _selectedDay : null,
                          selectedStartSlot: pageWeek == selectedWeek ? _selectedStartSlot : null,
                          selectedEndSlot: pageWeek == selectedWeek ? _selectedEndSlot : null,
                          onSlotTap: _onSlotTap,
                          gridKey: pageWeek == selectedWeek ? _gridKey : null,
                          onHandleDragUpdate: _onHandleDragUpdate,
                          onHandleDragEnd: _onHandleDragEnd,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败: $error')),
      ),
      floatingActionButton: _selectedDay != null
          ? FloatingActionButton.extended(
              onPressed: _addCourseFromSelection,
              icon: const Icon(Icons.add),
              label: const Text('添加课程'),
            )
          : FloatingActionButton(
              onPressed: () => context.push(AppRoutes.courseAdd),
              child: const Icon(Icons.add),
            ),
    );
  }

  int _currentWeekNumber(AsyncValue<Semester?> semesterAsync) {
    final semester = semesterAsync.valueOrNull;
    if (semester == null) return 0;
    final week = app_date.DateUtils.currentWeekNumber(semester.startDate);
    if (week < 1) return 1;
    if (week > semester.totalWeeks) return semester.totalWeeks;
    return week;
  }

  /// 点击空白格子
  void _onSlotTap(int day, int slot) {
    setState(() {
      if (_selectedDay == day &&
          _selectedStartSlot == slot &&
          _selectedEndSlot == slot) {
        // 再次点击同一个选中格子 → 跳转添加课程
        _addCourseFromSelection();
        return;
      }
      // 选中格子
      _selectedDay = day;
      _selectedStartSlot = slot;
      _selectedEndSlot = slot;
    });
  }

  /// 拖拽手柄更新：扩展选区到目标节次
  void _onHandleDragUpdate(int endSlot) {
    if (_selectedDay == null || _selectedStartSlot == null) return;
    setState(() {
      if (endSlot >= _selectedStartSlot!) {
        _selectedEndSlot = endSlot;
      }
    });
  }

  /// 拖拽手柄松开：跳转添加课程
  void _onHandleDragEnd() {
    _addCourseFromSelection();
  }

  /// 从选中区域跳转到添加课程页面
  void _addCourseFromSelection() {
    if (_selectedDay == null || _selectedStartSlot == null) return;
    final day = _selectedDay!;
    final startSlot = _selectedStartSlot!;
    final endSlot = _selectedEndSlot ?? startSlot;

    // 清除选中
    setState(() {
      _selectedDay = null;
      _selectedStartSlot = null;
      _selectedEndSlot = null;
    });

    context.push(AppRoutes.courseAdd, extra: {
      'dayOfWeek': day,
      'slot': startSlot,
      'endSlot': endSlot,
    });
  }

  /// 构建固定背景层（独立于 PageView，不随滑动移动）
  Widget _buildStaticBackground(
    BackgroundType type,
    int builtinIndex,
    String? customPath,
  ) {
    if (type == BackgroundType.builtin &&
        builtinIndex < BuiltinWallpapers.all.length) {
      return Container(
        decoration: BoxDecoration(
          gradient: BuiltinWallpapers.all[builtinIndex].toGradient(),
        ),
      );
    } else if (type == BackgroundType.custom && customPath != null) {
      return Image.file(
        File(customPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    return const SizedBox.shrink();
  }

  /// 空状态引导页
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 80,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              '欢迎使用 DDoge 课程表',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              '请先设置学期信息，包括开学日期和总周数',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.push('/settings/semester'),
              icon: const Icon(Icons.calendar_today),
              label: const Text('设置学期'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 课程表网格组件
class _ScheduleGrid extends StatelessWidget {
  const _ScheduleGrid({
    required this.courses,
    required this.timeSlots,
    required this.weekDates,
    required this.selectedWeek,
    required this.currentWeek,
    required this.autoFitHeight,
    required this.fixedSlotHeight,
    this.cardBorderRadius = 8.0,
    this.cardOpacity = 0.85,
    this.cardFontScale = 1.0,
    this.showGridLines = true,
    this.showTimeLine = true,
    this.selectedDay,
    this.selectedStartSlot,
    this.selectedEndSlot,
    this.onSlotTap,
    this.gridKey,
    this.onHandleDragUpdate,
    this.onHandleDragEnd,
  });

  final List<Course> courses;
  final List<TimeSlot> timeSlots;
  final List<DateTime> weekDates;
  final int selectedWeek;
  final int currentWeek;
  final bool autoFitHeight;
  final double fixedSlotHeight;
  final double cardBorderRadius;
  final double cardOpacity;
  final double cardFontScale;
  final bool showGridLines;
  final bool showTimeLine;

  // 格子选中回调
  final int? selectedDay;
  final int? selectedStartSlot;
  final int? selectedEndSlot;
  final void Function(int day, int slot)? onSlotTap;

  // 拖拽手柄
  final GlobalKey? gridKey;
  final void Function(int endSlot)? onHandleDragUpdate;
  final VoidCallback? onHandleDragEnd;

  @override
  Widget build(BuildContext context) {
    final slotCount =
        timeSlots.isEmpty ? TimeSlotConstants.maxSlotsPerDay : timeSlots.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final timeColumnWidth = 40.0;
        final dayWidth = (constraints.maxWidth - timeColumnWidth) / 7;

        // 自适应高度：网格填满可用空间；固定高度：使用设置值
        final headerHeight = 36.0; // WeekHeader 高度
        final dividerHeight = 1.0;
        final availableHeight =
            constraints.maxHeight - headerHeight - dividerHeight;
        final slotHeight = autoFitHeight
            ? (availableHeight / slotCount).clamp(30.0, 100.0)
            : fixedSlotHeight;

        // 计算今天在本周的索引
        final today = DateTime.now();
        int todayIndex = -1;
        if (selectedWeek == currentWeek) {
          todayIndex = today.weekday - 1;
        }

        final gridHeight = slotHeight * slotCount;

        return Column(
          children: [
            // 星期头
            WeekHeader(dates: weekDates, dayWidth: dayWidth),
            const Divider(height: 1),
            // 网格
            Expanded(
              child: autoFitHeight
                  ? _buildGrid(context, slotCount, slotHeight, dayWidth,
                      timeColumnWidth, todayIndex, gridHeight)
                  : SingleChildScrollView(
                      child: _buildGrid(context, slotCount, slotHeight,
                          dayWidth, timeColumnWidth, todayIndex, gridHeight),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGrid(
    BuildContext context,
    int slotCount,
    double slotHeight,
    double dayWidth,
    double timeColumnWidth,
    int todayIndex,
    double gridHeight,
  ) {
    return SizedBox(
      key: gridKey,
      height: gridHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 背景网格线
          if (showGridLines)
            _buildGridLines(
                context, slotCount, slotHeight, dayWidth, timeColumnWidth),
          // 空白格子的点击区域
          ..._buildSlotHitAreas(
              context, slotCount, slotHeight, dayWidth, timeColumnWidth),
          // 选中高亮 + 拖拽手柄
          if (selectedDay != null && selectedStartSlot != null)
            ..._buildSelectionOverlay(
                context, slotCount, slotHeight, dayWidth, timeColumnWidth),
          // 左侧时间列
          Positioned(
            left: 0,
            top: 0,
            child: TimeColumn(
              slotHeight: slotHeight,
              timeSlots: timeSlots,
            ),
          ),
          // 课程卡片
          ..._buildCourseCards(context, dayWidth, slotHeight, timeColumnWidth),
          // 当前时间线
          if (showTimeLine)
            CurrentTimeLine(
              timeSlots: timeSlots,
              slotHeight: slotHeight,
              dayWidth: dayWidth,
              todayIndex: todayIndex,
            ),
        ],
      ),
    );
  }

  /// 空白格子的触摸区域
  List<Widget> _buildSlotHitAreas(
    BuildContext context,
    int slotCount,
    double slotHeight,
    double dayWidth,
    double timeColumnWidth,
  ) {
    final areas = <Widget>[];
    for (int day = 1; day <= 7; day++) {
      for (int slot = 1; slot <= slotCount; slot++) {
        // 跳过已有课程的格子
        final hasCourse = courses.any((c) =>
            c.dayOfWeek == day && slot >= c.startSlot && slot <= c.endSlot);
        if (hasCourse) continue;

        final left = timeColumnWidth + (day - 1) * dayWidth;
        final top = (slot - 1) * slotHeight;

        areas.add(Positioned(
          left: left,
          top: top,
          width: dayWidth,
          height: slotHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSlotTap?.call(day, slot),
            child: const SizedBox.expand(),
          ),
        ));
      }
    }
    return areas;
  }

  /// 选中区域的高亮层 + 右侧拖拽手柄
  List<Widget> _buildSelectionOverlay(
    BuildContext context,
    int slotCount,
    double slotHeight,
    double dayWidth,
    double timeColumnWidth,
  ) {
    final theme = Theme.of(context);
    final startSlot = selectedStartSlot!;
    final endSlot = selectedEndSlot ?? startSlot;
    final left = timeColumnWidth + (selectedDay! - 1) * dayWidth;
    final top = (startSlot - 1) * slotHeight;
    final height = (endSlot - startSlot + 1) * slotHeight;

    final widgets = <Widget>[];

    // 主体高亮区域（不可交互，避免拦截点击事件）
    widgets.add(Positioned(
      left: left,
      top: top,
      width: dayWidth,
      height: height,
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline,
                  size: 18,
                  color: theme.colorScheme.primary.withValues(alpha: 0.7)),
              if (height > slotHeight * 1.5)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '第$startSlot${endSlot > startSlot ? '-$endSlot' : ''}节',
                    style: TextStyle(
                      fontSize: 9,
                      color:
                          theme.colorScheme.primary.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ));

    // 右侧拖拽手柄（可交互，放在格子外的右方）
    final handleWidth = 22.0;
    final handleTop = endSlot * slotHeight - slotHeight; // 手柄放在选区最后一格
    widgets.add(Positioned(
      left: left + dayWidth,
      top: handleTop,
      width: handleWidth,
      height: slotHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) {
          // 通过 gridKey 将全局坐标转换为网格内局部坐标
          final RenderBox? gridBox =
              gridKey?.currentContext?.findRenderObject() as RenderBox?;
          if (gridBox == null) return;
          final localPos = gridBox.globalToLocal(details.globalPosition);
          final targetSlot = (localPos.dy / slotHeight).floor() + 1;
          final clamped = targetSlot.clamp(startSlot, slotCount);
          onHandleDragUpdate?.call(clamped);
        },
        onVerticalDragEnd: (_) => onHandleDragEnd?.call(),
        child: Center(
          child: Container(
            width: 18,
            height: slotHeight - 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.drag_indicator,
              size: 14,
              color: theme.colorScheme.primary.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    ));

    return widgets;
  }

  /// 绘制背景网格线
  Widget _buildGridLines(
    BuildContext context,
    int slotCount,
    double slotHeight,
    double dayWidth,
    double timeColumnWidth,
  ) {
    final color =
        Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3);

    return CustomPaint(
      size: Size(
        timeColumnWidth + dayWidth * 7,
        slotHeight * slotCount,
      ),
      painter: _GridPainter(
        slotCount: slotCount,
        slotHeight: slotHeight,
        dayWidth: dayWidth,
        timeColumnWidth: timeColumnWidth,
        lineColor: color,
      ),
    );
  }

  /// 构建课程卡片
  List<Widget> _buildCourseCards(
    BuildContext context,
    double dayWidth,
    double slotHeight,
    double timeColumnWidth,
  ) {
    return courses.map((course) {
      final left = timeColumnWidth + (course.dayOfWeek - 1) * dayWidth;
      final top = (course.startSlot - 1) * slotHeight;
      final height = (course.endSlot - course.startSlot + 1) * slotHeight;

      return Positioned(
        left: left,
        top: top,
        width: dayWidth,
        height: height,
        child: CourseCard(
          course: course,
          slotCount: course.endSlot - course.startSlot + 1,
          borderRadius: cardBorderRadius,
          opacity: cardOpacity,
          fontScale: cardFontScale,
          onTap: () {
            _showCourseDetail(context, course);
          },
          onLongPress: () {
            GoRouter.of(context).push('/course/edit/${course.id}');
          },
        ),
      );
    }).toList();
  }

  /// 显示课程详情弹窗
  void _showCourseDetail(BuildContext context, Course course) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              course.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (course.teacher.isNotEmpty)
              _detailRow(
                  Icons.person_outline, '教师', course.teacher, theme),
            if (course.classroom.isNotEmpty)
              _detailRow(Icons.location_on_outlined, '教室',
                  course.classroom, theme),
            _detailRow(
              Icons.calendar_today_outlined,
              '周次',
              '第${course.startWeek}-${course.endWeek}周'
                  '${course.weekType == 1 ? '(单周)' : course.weekType == 2 ? '(双周)' : ''}',
              theme,
            ),
            _detailRow(
              Icons.access_time,
              '节次',
              '周${TimeSlotConstants.weekdayShortNames[course.dayOfWeek - 1]} 第${course.startSlot}-${course.endSlot}节',
              theme,
            ),
            if (course.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              _detailRow(Icons.note_outlined, '备注', course.note, theme),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.pop(context);
                    GoRouter.of(context)
                        .push('/course/edit/${course.id}');
                  },
                  child: const Text('编辑'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
      IconData icon, String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$label：',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// 网格线绘制器
class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.slotCount,
    required this.slotHeight,
    required this.dayWidth,
    required this.timeColumnWidth,
    required this.lineColor,
  });

  final int slotCount;
  final double slotHeight;
  final double dayWidth;
  final double timeColumnWidth;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.5;

    // 横线
    for (int i = 0; i <= slotCount; i++) {
      final y = i * slotHeight;
      canvas.drawLine(
        Offset(timeColumnWidth, y),
        Offset(size.width, y),
        paint,
      );
    }

    // 竖线
    for (int i = 0; i <= 7; i++) {
      final x = timeColumnWidth + i * dayWidth;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}
