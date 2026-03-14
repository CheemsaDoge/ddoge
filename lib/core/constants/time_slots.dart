/// 节次时间常量
///
/// 定义每节课的默认开始和结束时间
class TimeSlotConstants {
  TimeSlotConstants._();

  /// 默认每天最大节次数
  static const int maxSlotsPerDay = 12;

  /// 每周天数（周一到周日）
  static const int daysPerWeek = 7;

  /// 默认学期总周数
  static const int defaultTotalWeeks = 20;

  /// 默认节次时间配置（小时, 分钟）
  static const List<({int startHour, int startMinute, int endHour, int endMinute})> defaultTimeSlots = [
    (startHour: 8, startMinute: 0, endHour: 8, endMinute: 45),     // 第1节
    (startHour: 8, startMinute: 55, endHour: 9, endMinute: 40),    // 第2节
    (startHour: 10, startMinute: 0, endHour: 10, endMinute: 45),   // 第3节
    (startHour: 10, startMinute: 55, endHour: 11, endMinute: 40),  // 第4节
    (startHour: 14, startMinute: 0, endHour: 14, endMinute: 45),   // 第5节
    (startHour: 14, startMinute: 55, endHour: 15, endMinute: 40),  // 第6节
    (startHour: 16, startMinute: 0, endHour: 16, endMinute: 45),   // 第7节
    (startHour: 16, startMinute: 55, endHour: 17, endMinute: 40),  // 第8节
    (startHour: 19, startMinute: 0, endHour: 19, endMinute: 45),   // 第9节
    (startHour: 19, startMinute: 55, endHour: 20, endMinute: 40),  // 第10节
    (startHour: 20, startMinute: 50, endHour: 21, endMinute: 35),  // 第11节
    (startHour: 21, startMinute: 45, endHour: 22, endMinute: 30),  // 第12节
  ];

  /// 星期名称
  static const List<String> weekdayNames = [
    '周一', '周二', '周三', '周四', '周五', '周六', '周日',
  ];

  /// 星期简称
  static const List<String> weekdayShortNames = [
    '一', '二', '三', '四', '五', '六', '日',
  ];
}
