import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/tables.dart';

part 'course_dao.g.dart';

/// 课程数据访问对象
@DriftAccessor(tables: [Courses])
class CourseDao extends DatabaseAccessor<AppDatabase> with _$CourseDaoMixin {
  CourseDao(super.db);

  /// 获取指定学期的所有课程
  Future<List<Course>> getCoursesForSemester(String semesterId) {
    return (select(courses)..where((c) => c.semesterId.equals(semesterId)))
        .get();
  }

  /// 监听指定学期的课程变化
  Stream<List<Course>> watchCoursesForSemester(String semesterId) {
    return (select(courses)..where((c) => c.semesterId.equals(semesterId)))
        .watch();
  }

  /// 获取指定周指定星期的课程
  Stream<List<Course>> watchCoursesForDayAndWeek(
    String semesterId,
    int dayOfWeek,
    int weekNumber,
  ) {
    return (select(courses)
          ..where((c) =>
              c.semesterId.equals(semesterId) &
              c.dayOfWeek.equals(dayOfWeek) &
              c.startWeek.isSmallerOrEqualValue(weekNumber) &
              c.endWeek.isBiggerOrEqualValue(weekNumber)))
        .watch();
  }

  /// 插入或更新课程
  Future<void> upsertCourse(CoursesCompanion course) {
    return into(courses).insertOnConflictUpdate(course);
  }

  /// 删除课程
  Future<int> deleteCourse(String id) {
    return (delete(courses)..where((c) => c.id.equals(id))).go();
  }

  /// 删除指定学期的所有课程
  Future<int> deleteCoursesForSemester(String semesterId) {
    return (delete(courses)..where((c) => c.semesterId.equals(semesterId)))
        .go();
  }
}
