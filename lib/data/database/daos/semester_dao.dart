import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/tables.dart';

part 'semester_dao.g.dart';

/// 学期数据访问对象
@DriftAccessor(tables: [Semesters])
class SemesterDao extends DatabaseAccessor<AppDatabase>
    with _$SemesterDaoMixin {
  SemesterDao(super.db);

  /// 获取所有学期
  Future<List<Semester>> getAllSemesters() => select(semesters).get();

  /// 监听所有学期
  Stream<List<Semester>> watchAllSemesters() => select(semesters).watch();

  /// 获取当前学期
  Future<Semester?> getCurrentSemester() {
    return (select(semesters)..where((s) => s.isCurrent.equals(true)))
        .getSingleOrNull();
  }

  /// 监听当前学期
  Stream<Semester?> watchCurrentSemester() {
    return (select(semesters)..where((s) => s.isCurrent.equals(true)))
        .watchSingleOrNull();
  }

  /// 设置当前学期（先取消其他学期的 isCurrent）
  Future<void> setCurrentSemester(String semesterId) async {
    await transaction(() async {
      // 取消所有学期的当前标记
      await (update(semesters)
            ..where((s) => s.isCurrent.equals(true)))
          .write(const SemestersCompanion(isCurrent: Value(false)));
      // 设置目标学期为当前
      await (update(semesters)
            ..where((s) => s.id.equals(semesterId)))
          .write(const SemestersCompanion(isCurrent: Value(true)));
    });
  }

  /// 插入或更新学期
  Future<void> upsertSemester(SemestersCompanion semester) {
    return into(semesters).insertOnConflictUpdate(semester);
  }

  /// 删除学期
  Future<int> deleteSemester(String id) {
    return (delete(semesters)..where((s) => s.id.equals(id))).go();
  }
}
