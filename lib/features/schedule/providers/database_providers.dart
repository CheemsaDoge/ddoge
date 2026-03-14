import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ddoge/data/database/app_database.dart';
import 'package:ddoge/data/database/daos/course_dao.dart';
import 'package:ddoge/data/database/daos/semester_dao.dart';
import 'package:ddoge/data/database/daos/time_slot_dao.dart';

/// 数据库单例
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// 课程 DAO
final courseDaoProvider = Provider<CourseDao>((ref) {
  return CourseDao(ref.watch(databaseProvider));
});

/// 学期 DAO
final semesterDaoProvider = Provider<SemesterDao>((ref) {
  return SemesterDao(ref.watch(databaseProvider));
});

/// 节次时间 DAO
final timeSlotDaoProvider = Provider<TimeSlotDao>((ref) {
  return TimeSlotDao(ref.watch(databaseProvider));
});
