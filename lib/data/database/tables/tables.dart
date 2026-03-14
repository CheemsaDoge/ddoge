import 'package:drift/drift.dart';

/// 课程数据表
class Courses extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get teacher => text().withDefault(const Constant(''))();
  TextColumn get classroom => text().withDefault(const Constant(''))();
  IntColumn get dayOfWeek => integer()();
  IntColumn get startSlot => integer()();
  IntColumn get endSlot => integer()();
  IntColumn get startWeek => integer()();
  IntColumn get endWeek => integer()();
  IntColumn get weekType => integer().withDefault(const Constant(0))();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get semesterId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 学期数据表
class Semesters extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  DateTimeColumn get startDate => dateTime()();
  IntColumn get totalWeeks => integer().withDefault(const Constant(20))();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 节次时间配置表
class TimeSlots extends Table {
  IntColumn get index => integer()();
  IntColumn get startHour => integer()();
  IntColumn get startMinute => integer()();
  IntColumn get endHour => integer()();
  IntColumn get endMinute => integer()();
  TextColumn get semesterId => text()();

  @override
  Set<Column> get primaryKey => {index, semesterId};
}
