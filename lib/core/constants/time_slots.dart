/// 节次时间常量
///
/// 定义每节课的默认开始和结束时间
class TimeSlotConstants {
  TimeSlotConstants._();

  /// 默认每天最大节次数
  static const int maxSlotsPerDay = 11;

  /// 每周天数（周一到周日）
  static const int daysPerWeek = 7;

  /// 默认学期总周数
  static const int defaultTotalWeeks = 20;

  /// 默认节次时间配置（小时, 分钟）
  static const List<
    ({int startHour, int startMinute, int endHour, int endMinute})
  >
  defaultTimeSlots = [
    (startHour: 8, startMinute: 30, endHour: 9, endMinute: 15), // 第1节
    (startHour: 9, startMinute: 20, endHour: 10, endMinute: 5), // 第2节
    (startHour: 10, startMinute: 20, endHour: 11, endMinute: 5), // 第3节
    (startHour: 11, startMinute: 10, endHour: 11, endMinute: 55), // 第4节
    (startHour: 14, startMinute: 30, endHour: 15, endMinute: 15), // 第5节
    (startHour: 15, startMinute: 20, endHour: 16, endMinute: 5), // 第6节
    (startHour: 16, startMinute: 20, endHour: 17, endMinute: 5), // 第7节
    (startHour: 17, startMinute: 10, endHour: 17, endMinute: 55), // 第8节
    (startHour: 19, startMinute: 30, endHour: 20, endMinute: 15), // 第9节
    (startHour: 20, startMinute: 20, endHour: 21, endMinute: 5), // 第10节
    (startHour: 21, startMinute: 10, endHour: 21, endMinute: 55), // 第11节
  ];

  /// 星期名称
  static const List<String> weekdayNames = [
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ];

  /// 星期简称
  static const List<String> weekdayShortNames = [
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];
}
