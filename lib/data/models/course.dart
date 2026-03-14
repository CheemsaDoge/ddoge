import 'package:freezed_annotation/freezed_annotation.dart';

part 'course.freezed.dart';
part 'course.g.dart';

/// 单双周类型
enum WeekType {
  /// 每周都有
  all,
  /// 仅单周
  odd,
  /// 仅双周
  even,
}

/// 课程数据模型
@freezed
class Course with _$Course {
  const factory Course({
    /// 唯一标识
    required String id,

    /// 课程名称
    required String name,

    /// 授课教师
    @Default('') String teacher,

    /// 上课教室
    @Default('') String classroom,

    /// 星期几（1=周一, 7=周日）
    required int dayOfWeek,

    /// 开始节次（从1开始）
    required int startSlot,

    /// 结束节次（包含）
    required int endSlot,

    /// 起始周
    required int startWeek,

    /// 结束周（包含）
    required int endWeek,

    /// 单双周类型
    @Default(WeekType.all) WeekType weekType,

    /// 课程卡片颜色索引
    @Default(0) int colorIndex,

    /// 备注
    @Default('') String note,

    /// 所属学期 ID
    required String semesterId,
  }) = _Course;

  factory Course.fromJson(Map<String, dynamic> json) =>
      _$CourseFromJson(json);
}
