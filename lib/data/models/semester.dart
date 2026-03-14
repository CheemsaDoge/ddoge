import 'package:freezed_annotation/freezed_annotation.dart';

part 'semester.freezed.dart';
part 'semester.g.dart';

/// 学期数据模型
@freezed
class Semester with _$Semester {
  const factory Semester({
    /// 唯一标识
    required String id,

    /// 学期名称（如"2025-2026 第一学期"）
    required String name,

    /// 开学日期（学期第一周的周一）
    required DateTime startDate,

    /// 总周数
    @Default(20) int totalWeeks,

    /// 是否为当前学期
    @Default(false) bool isCurrent,
  }) = _Semester;

  factory Semester.fromJson(Map<String, dynamic> json) =>
      _$SemesterFromJson(json);
}
