import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ddoge/core/storage/settings_storage.dart';
import 'package:ddoge/core/utils/date_utils.dart' as app_date;
import 'package:ddoge/data/database/app_database.dart';
import 'database_providers.dart';

/// 当前学期
final currentSemesterProvider = StreamProvider<Semester?>((ref) {
  return ref.watch(semesterDaoProvider).watchCurrentSemester();
});

/// 所有学期列表
final allSemestersProvider = StreamProvider<List<Semester>>((ref) {
  return ref.watch(semesterDaoProvider).watchAllSemesters();
});

/// 当前选择的周数
final selectedWeekProvider = StateProvider<int>((ref) {
  final semesterAsync = ref.watch(currentSemesterProvider);
  return semesterAsync.whenOrNull(
        data: (semester) {
          if (semester == null) return 1;
          final week = app_date.DateUtils.currentWeekNumber(semester.startDate);
          if (week < 1) return 1;
          if (week > semester.totalWeeks) return semester.totalWeeks;
          return week;
        },
      ) ??
      1;
});

/// 当前学期的课程列表（响应式）
final coursesForCurrentSemesterProvider =
    StreamProvider<List<Course>>((ref) {
  final semesterAsync = ref.watch(currentSemesterProvider);
  final semester = semesterAsync.valueOrNull;
  if (semester == null) return Stream.value([]);
  return ref.watch(courseDaoProvider).watchCoursesForSemester(semester.id);
});

/// 当前周的课程（按星期和节次过滤）
final coursesForSelectedWeekProvider = Provider<List<Course>>((ref) {
  final coursesAsync = ref.watch(coursesForCurrentSemesterProvider);
  final selectedWeek = ref.watch(selectedWeekProvider);
  final courses = coursesAsync.valueOrNull ?? [];

  return courses.where((course) {
    return app_date.DateUtils.isCourseActiveInWeek(
      course.startWeek,
      course.endWeek,
      course.weekType,
      selectedWeek,
    );
  }).toList();
});

/// 当前学期的节次时间配置
final timeSlotsProvider = StreamProvider<List<TimeSlot>>((ref) {
  final semesterAsync = ref.watch(currentSemesterProvider);
  final semester = semesterAsync.valueOrNull;
  if (semester == null) return Stream.value([]);
  return ref.watch(timeSlotDaoProvider).watchTimeSlotsForSemester(semester.id);
});

/// 主题模式：0=跟随系统, 1=亮色, 2=暗色
final themeModeProvider = StateProvider<int>((ref) => 0);

/// 课表自适应高度开关（true=自适应一屏显示，false=固定高度可滚动）
final autoFitHeightProvider = StateProvider<bool>((ref) => true);

/// 固定模式下每格高度
final fixedSlotHeightProvider = StateProvider<double>((ref) => 58.0);

/// 课程卡片圆角半径
final cardBorderRadiusProvider = StateProvider<double>((ref) => 8.0);

/// 课程卡片透明度（0.0~1.0）
final cardOpacityProvider = StateProvider<double>((ref) => 0.85);

/// 课程卡片字体大小缩放（0.8~1.4）
final cardFontScaleProvider = StateProvider<double>((ref) => 1.0);

/// 是否显示网格线
final showGridLinesProvider = StateProvider<bool>((ref) => true);

/// 是否显示当前时间线
final showTimeLineProvider = StateProvider<bool>((ref) => true);

// ==================== SharedPreferences 与背景设置 ====================

/// SharedPreferences 实例（在 main.dart 中通过 override 注入）
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('必须在 ProviderScope 中 override sharedPreferencesProvider');
});

/// 设置存储服务
final settingsStorageProvider = Provider<SettingsStorage>((ref) {
  return SettingsStorage(ref.watch(sharedPreferencesProvider));
});

/// 课表背景类型
final backgroundTypeProvider = StateProvider<BackgroundType>((ref) {
  return ref.read(settingsStorageProvider).getBackgroundType();
});

/// 内置壁纸索引
final builtinWallpaperProvider = StateProvider<int>((ref) {
  return ref.read(settingsStorageProvider).getBuiltinWallpaper();
});

/// 自定义背景图片路径
final customBackgroundPathProvider = StateProvider<String?>((ref) {
  return ref.read(settingsStorageProvider).getCustomBackgroundPath();
});

/// 背景透明度
final backgroundOpacityProvider = StateProvider<double>((ref) {
  return ref.read(settingsStorageProvider).getBackgroundOpacity();
});
