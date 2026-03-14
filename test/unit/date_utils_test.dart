import 'package:flutter_test/flutter_test.dart';
import 'package:ddoge/core/utils/date_utils.dart';

void main() {
  group('DateUtils 周数计算', () {
    test('学期第一天应该是第1周', () {
      final start = DateTime(2025, 9, 1); // 周一
      final week = DateUtils.currentWeekNumber(start, DateTime(2025, 9, 1));
      expect(week, 1);
    });

    test('第一周周日仍是第1周', () {
      final start = DateTime(2025, 9, 1);
      final week = DateUtils.currentWeekNumber(start, DateTime(2025, 9, 7));
      expect(week, 1);
    });

    test('第二周周一应该是第2周', () {
      final start = DateTime(2025, 9, 1);
      final week = DateUtils.currentWeekNumber(start, DateTime(2025, 9, 8));
      expect(week, 2);
    });

    test('学期开始前应返回0', () {
      final start = DateTime(2025, 9, 1);
      final week = DateUtils.currentWeekNumber(start, DateTime(2025, 8, 30));
      expect(week, 0);
    });

    test('第10周计算正确', () {
      final start = DateTime(2025, 9, 1);
      final week = DateUtils.currentWeekNumber(start, DateTime(2025, 11, 3));
      expect(week, 10);
    });
  });

  group('DateUtils 课程激活判断', () {
    test('在范围内且每周上课', () {
      expect(DateUtils.isCourseActiveInWeek(1, 16, 0, 5), true);
    });

    test('超出范围', () {
      expect(DateUtils.isCourseActiveInWeek(1, 16, 0, 17), false);
    });

    test('单周课在双周不上', () {
      expect(DateUtils.isCourseActiveInWeek(1, 16, 1, 4), false); // 第4周是双周
    });

    test('单周课在单周上', () {
      expect(DateUtils.isCourseActiveInWeek(1, 16, 1, 3), true); // 第3周是单周
    });

    test('双周课在双周上', () {
      expect(DateUtils.isCourseActiveInWeek(1, 16, 2, 4), true);
    });

    test('双周课在单周不上', () {
      expect(DateUtils.isCourseActiveInWeek(1, 16, 2, 3), false);
    });
  });

  group('DateUtils 日期计算', () {
    test('获取某周某天的日期', () {
      final start = DateTime(2025, 9, 1); // 周一
      final date = DateUtils.dateForWeekAndDay(start, 1, 3); // 第1周周三
      expect(date, DateTime(2025, 9, 3));
    });

    test('获取第2周周五', () {
      final start = DateTime(2025, 9, 1);
      final date = DateUtils.dateForWeekAndDay(start, 2, 5);
      expect(date, DateTime(2025, 9, 12));
    });

    test('获取某周的全部日期', () {
      final start = DateTime(2025, 9, 1);
      final dates = DateUtils.datesForWeek(start, 1);
      expect(dates.length, 7);
      expect(dates[0], DateTime(2025, 9, 1)); // 周一
      expect(dates[6], DateTime(2025, 9, 7)); // 周日
    });
  });
}
