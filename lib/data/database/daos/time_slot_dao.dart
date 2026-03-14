import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/tables.dart';
import '../../../core/constants/time_slots.dart' as constants;

part 'time_slot_dao.g.dart';

/// 节次时间数据访问对象
@DriftAccessor(tables: [TimeSlots])
class TimeSlotDao extends DatabaseAccessor<AppDatabase>
    with _$TimeSlotDaoMixin {
  TimeSlotDao(super.db);

  /// 获取指定学期的节次时间配置
  Future<List<TimeSlot>> getTimeSlotsForSemester(String semesterId) {
    return (select(timeSlots)
          ..where((t) => t.semesterId.equals(semesterId))
          ..orderBy([(t) => OrderingTerm.asc(t.index)]))
        .get();
  }

  /// 监听指定学期的节次时间
  Stream<List<TimeSlot>> watchTimeSlotsForSemester(String semesterId) {
    return (select(timeSlots)
          ..where((t) => t.semesterId.equals(semesterId))
          ..orderBy([(t) => OrderingTerm.asc(t.index)]))
        .watch();
  }

  /// 为学期初始化默认节次时间
  Future<void> initDefaultTimeSlots(String semesterId) async {
    await batch((b) {
      final slots = constants.TimeSlotConstants.defaultTimeSlots;
      b.insertAll(
        timeSlots,
        List.generate(
          slots.length,
          (i) => TimeSlotsCompanion.insert(
            index: i + 1,
            startHour: slots[i].startHour,
            startMinute: slots[i].startMinute,
            endHour: slots[i].endHour,
            endMinute: slots[i].endMinute,
            semesterId: semesterId,
          ),
        ),
      );
    });
  }

  /// 更新节次时间
  Future<void> updateTimeSlot(TimeSlotsCompanion slot) {
    return into(timeSlots).insertOnConflictUpdate(slot);
  }

  /// 删除指定学期的所有节次时间
  Future<int> deleteTimeSlotsForSemester(String semesterId) {
    return (delete(timeSlots)
          ..where((t) => t.semesterId.equals(semesterId)))
        .go();
  }
}
