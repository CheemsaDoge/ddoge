import 'package:freezed_annotation/freezed_annotation.dart';

part 'time_slot.freezed.dart';
part 'time_slot.g.dart';

/// 节次时间数据模型
@freezed
class TimeSlot with _$TimeSlot {
  const factory TimeSlot({
    /// 节次序号（从1开始）
    required int index,

    /// 开始时间 - 小时
    required int startHour,

    /// 开始时间 - 分钟
    required int startMinute,

    /// 结束时间 - 小时
    required int endHour,

    /// 结束时间 - 分钟
    required int endMinute,
  }) = _TimeSlot;

  factory TimeSlot.fromJson(Map<String, dynamic> json) =>
      _$TimeSlotFromJson(json);
}
