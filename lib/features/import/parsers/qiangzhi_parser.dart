import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';
import 'package:ddoge/data/database/app_database.dart';

/// 强智教务系统解析器 (Qiangzhi)
class QiangzhiParser {
  static const String _uuidNamespace = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';

  /// 解析强智课表 HTML
  List<Course> parse(String html, String semesterId) {
    final document = html_parser.parse(html);
    final uuid = const Uuid();
    
    // 强智通常使用 id="kbtable" 的表格
    final table = document.getElementById('kbtable') ?? 
                  document.querySelector('table.kbtable');
    
    if (table == null) return [];

    final courses = <Course>[];
    final rows = table.getElementsByTagName('tr');

    // 强智 7x12 宫格结构：
    // 行 1+: 节次行
    // 每行有 7 列（或更多，取决于是否有早晚课）
    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final cells = rows[rowIndex].getElementsByTagName('td');
      if (cells.isEmpty) continue;

      // 跳过第一列（节次序号）
      for (var colIndex = 1; colIndex < cells.length; colIndex++) {
        final cell = cells[colIndex];
        final content = cell.innerHtml.trim();
        if (content.isEmpty || content.length < 5) continue;

        // 强智格子内通常用分界线或 div 分隔多门课
        final courseDivs = cell.getElementsByTagName('div');
        final blocks = courseDivs.isNotEmpty 
            ? courseDivs.map((e) => e.innerHtml).toList()
            : [content];

        for (var block in blocks) {
          final parts = block.split(RegExp(r'<br\s*/?>'));
          if (parts.length < 2) continue;

          final name = parts[0].replaceAll(RegExp(r'<[^>]*>'), '').trim();
          // 强智格式通常：[教师] / [周次] / [教室]
          String teacher = '';
          String classroom = '';
          String weekStr = '';

          for (var part in parts.skip(1)) {
            final text = part.replaceAll(RegExp(r'<[^>]*>'), '').trim();
            if (text.contains('周')) weekStr = text;
            else if (text.length > 2 && teacher.isEmpty) teacher = text;
            else if (text.length > 2) classroom = text;
          }

          final weekInfo = _parseWeekInfo(weekStr);
          if (weekInfo == null) continue;

          courses.add(Course(
            id: uuid.v5(_uuidNamespace, '$name-$colIndex-$rowIndex-$semesterId'),
            name: name,
            teacher: teacher,
            classroom: classroom,
            dayOfWeek: colIndex, // 1-7
            startSlot: rowIndex, // 粗略，实际应根据行号判断
            endSlot: rowIndex,
            startWeek: weekInfo.startWeek,
            endWeek: weekInfo.endWeek,
            weekType: weekInfo.weekType,
            colorIndex: 0,
            semesterId: semesterId,
            note: '',
          ));
        }
      }
    }
    
    // 合并同一天、同一门课的连续节次
    return _mergeContinuousSlots(courses);
  }

  _QzWeekInfo? _parseWeekInfo(String info) {
    // 格式如: "1-16周" 或 "1,3,5,7-15周(单)"
    final match = RegExp(r'(\d+)-(\d+)').firstMatch(info);
    if (match == null) return null;

    final start = int.parse(match.group(1)!);
    final end = int.parse(match.group(2)!);
    
    int type = 0;
    if (info.contains('单')) type = 1;
    if (info.contains('双')) type = 2;

    return _QzWeekInfo(startWeek: start, endWeek: end, weekType: type);
  }

  List<Course> _mergeContinuousSlots(List<Course> courses) {
    // 逻辑：如果课程名、教室、星期、周次都相同，且节次连续，则合并
    // 这是一个简化处理
    return courses; 
  }
}

class _QzWeekInfo {
  final int startWeek;
  final int endWeek;
  final int weekType;
  _QzWeekInfo({required this.startWeek, required this.endWeek, required this.weekType});
}
