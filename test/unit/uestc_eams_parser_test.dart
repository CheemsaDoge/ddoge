import 'package:flutter_test/flutter_test.dart';
import 'package:ddoge/features/import/parsers/uestc_eams_parser.dart';

void main() {
  group('UestcEamsParser Tests', () {
    final parser = UestcEamsParser();
    const semesterId = 'test-semester-id';

    test('should parse TaskActivity correctly from HTML script', () {
      const html = '''
        <script>
          var table0 = new CourseTable(2026,84);
          var unitCount = 12;
          var index=0;
          var activity=null;
          activity = new TaskActivity("10118","叶茂","58493","专业写作基础(A6200810.62)","343","品学楼C111","01111101110000000000000000000000000000000000000000000");
          index =0*unitCount+6;
          table0.activities[index][table0.activities[index].length]=activity;
          index =0*unitCount+7;
          table0.activities[index][table0.activities[index].length]=activity;
          
          activity = new TaskActivity("10004","傅彦","50198","离散数学(P0824135.07)","408","品学楼A110","01111111101000000000000000000000000000000000000000000");
          index =4*unitCount+8;
          table0.activities[index][table0.activities[index].length]=activity;
          index =4*unitCount+9;
          table0.activities[index][table0.activities[index].length]=activity;
          index =4*unitCount+10;
          table0.activities[index][table0.activities[index].length]=activity;
        </script>
      ''';

      final courses = parser.parse(html, semesterId);

      expect(courses.length, 2);
      
      // 检查第一个课程：专业写作基础
      final writing = courses.firstWhere((c) => c.name == '专业写作基础');
      expect(writing.teacher, '叶茂');
      expect(writing.classroom, '品学楼C111');
      expect(writing.dayOfWeek, 1); // index = 0*unitCount
      expect(writing.startSlot, 7); // index + 1 = 6+1
      expect(writing.endSlot, 8); // index + 1 = 7+1
      expect(writing.startWeek, 1);
      expect(writing.endWeek, 9);
      expect(writing.weekType, 0);

      // 检查第二个课程：离散数学
      final discrete = courses.firstWhere((c) => c.name == '离散数学');
      expect(discrete.teacher, '傅彦');
      expect(discrete.classroom, '品学楼A110');
      expect(discrete.dayOfWeek, 5); // index = 4*unitCount
      expect(discrete.startSlot, 9); 
      expect(discrete.endSlot, 11);
    });

    test('should detect single/even week types', () {
      const html = '''
        <script>
          var unitCount = 12;
          // 单周: 第1, 3, 5周有课
          activity = new TaskActivity("1","T1","101","单周课(1)","1","R1","01010100000000000000000000000000000000000000000000000");
          index = 0*unitCount+0;
          table0.activities[index][0]=activity;
          
          // 双周: 第2, 4, 6周有课
          activity = new TaskActivity("2","T2","102","双周课(2)","2","R2","00101010000000000000000000000000000000000000000000000");
          index = 1*unitCount+0;
          table0.activities[index][0]=activity;
        </script>
      ''';

      final courses = parser.parse(html, semesterId);
      
      final oddCourse = courses.firstWhere((c) => c.name == '单周课');
      expect(oddCourse.weekType, 1);
      expect(oddCourse.startWeek, 1);
      expect(oddCourse.endWeek, 5);

      final evenCourse = courses.firstWhere((c) => c.name == '双周课');
      expect(evenCourse.weekType, 2);
      expect(evenCourse.startWeek, 2);
      expect(evenCourse.endWeek, 6);
    });
  });
}
