/// 日期与周数计算工具
class DateUtils {
  DateUtils._();

  /// 计算当前是第几周
  ///
  /// [semesterStart] 学期开始日期（第一周周一）
  /// [current] 当前日期
  /// 返回周数（从1开始），如果在学期开始之前返回0
  static int currentWeekNumber(DateTime semesterStart, [DateTime? current]) {
    final now = current ?? DateTime.now();
    // 标准化到午夜
    final start = DateTime(semesterStart.year, semesterStart.month, semesterStart.day);
    final today = DateTime(now.year, now.month, now.day);

    final diff = today.difference(start).inDays;
    if (diff < 0) return 0;
    return (diff ~/ 7) + 1;
  }

  /// 获取某一周某天的日期
  ///
  /// [semesterStart] 学期开始日期
  /// [week] 第几周（从1开始）
  /// [dayOfWeek] 星期几（1=周一, 7=周日）
  static DateTime dateForWeekAndDay(
    DateTime semesterStart,
    int week,
    int dayOfWeek,
  ) {
    final start = DateTime(
      semesterStart.year,
      semesterStart.month,
      semesterStart.day,
    );
    return start.add(Duration(days: (week - 1) * 7 + (dayOfWeek - 1)));
  }

  /// 获取某周所有天的日期列表
  static List<DateTime> datesForWeek(DateTime semesterStart, int week) {
    return List.generate(
      7,
      (i) => dateForWeekAndDay(semesterStart, week, i + 1),
    );
  }

  /// 判断课程在指定周是否上课
  ///
  /// [startWeek] 课程起始周
  /// [endWeek] 课程结束周
  /// [weekType] 0=每周, 1=单周, 2=双周
  /// [currentWeek] 当前周数
  static bool isCourseActiveInWeek(
    int startWeek,
    int endWeek,
    int weekType,
    int currentWeek,
  ) {
    if (currentWeek < startWeek || currentWeek > endWeek) return false;
    if (weekType == 1 && currentWeek.isEven) return false; // 单周，但当前是双周
    if (weekType == 2 && currentWeek.isOdd) return false;  // 双周，但当前是单周
    return true;
  }
}
