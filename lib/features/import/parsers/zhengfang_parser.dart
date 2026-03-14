import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';
import 'package:ddoge/data/database/app_database.dart';

/// 正方教务系统解析器 (Zhengfang)
class ZhengfangParser {
  static const String _uuidNamespace = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';

  /// 解析正方课表 HTML
  List<Course> parse(String html, String semesterId) {
    final document = html_parser.parse(html);
    final uuid = const Uuid();

    // 优先尝试解析 7x12 宫格型课表 (Table1)
    if (document.getElementById('Table1') != null) {
      return _parseGridTable(document, semesterId, uuid);
    }

    // 备选方案：尝试解析列表型数据 (datagrid)
    final gridTable = document.getElementById('kcmcGrid') ?? 
                      document.getElementById('datagrid1');
    if (gridTable != null) {
      return _parseListTable(gridTable, semesterId, uuid);
    }

    return [];
  }

  /// 解析 7x12 宫格型课表 (Table1)
  List<Course> _parseGridTable(dynamic document, String semesterId, Uuid uuid) {
    final table = document.getElementById('Table1');
    if (table == null) return [];

    final courses = <Course>[];
    final rows = table.getElementsByTagName('tr');

    // 正方 Table1 结构：
    // 行 0-1: 表头
    // 行 2, 4, 6, 8, 10, 12: 对应 1, 3, 5, 7, 9, 11 节（单数行通常带 rowspan=2）
    for (var rowIndex = 2; rowIndex < rows.length; rowIndex++) {
      final cells = rows[rowIndex].getElementsByTagName('td');
      
      for (var colIndex = 0; colIndex < cells.length; colIndex++) {
        final cell = cells[colIndex];
        final content = cell.innerHtml.trim();
        if (content.isEmpty || content.length < 5) continue;

        // 处理单元格内的多门课程（正方会在同一个格子放多门课，用 <br> 分隔）
        final courseBlocks = content.split(RegExp(r'<br\s*/?>\s*<br\s*/?>'));
        
        for (var block in courseBlocks) {
          final parts = block.split(RegExp(r'<br\s*/?>'));
          if (parts.length < 3) continue;

          final name = parts[0].trim();
          final info = parts[1].trim(); // 通常是 "周一第1,2节{第1-16周}" 或类似
          final teacher = parts.length > 2 ? parts[2].trim() : '';
          final classroom = parts.length > 3 ? parts[3].trim() : '';

          // 解析周次、节次、星期
          final weekInfo = _parseTimeInfo(info);
          if (weekInfo == null) continue;

          courses.add(Course(
            id: uuid.v5(_uuidNamespace, '$name-${weekInfo.day}-$semesterId'),
            name: name,
            teacher: teacher,
            classroom: classroom,
            dayOfWeek: weekInfo.day,
            startSlot: weekInfo.startSlot,
            endSlot: weekInfo.endSlot,
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
    return courses;
  }

  /// 解析列表型数据 (例如有些版本的正方直接输出 Table 列表)
  List<Course> _parseListTable(dynamic table, String semesterId, Uuid uuid) {
    final courses = <Course>[];
    final rows = table.getElementsByTagName('tr');
    if (rows.length < 2) return [];

    for (var i = 1; i < rows.length; i++) {
      final cells = rows[i].getElementsByTagName('td');
      if (cells.length < 5) continue;

      final name = cells[1].text.trim();
      final timeStr = cells[ cells.length > 8 ? 8 : 4].text.trim();
      final teacher = cells[3].text.trim();
      final classroom = cells[ cells.length > 9 ? 9 : 5].text.trim();

      final weekInfo = _parseTimeInfo(timeStr);
      if (weekInfo == null) continue;

      courses.add(Course(
        id: uuid.v5(_uuidNamespace, '$name-${weekInfo.day}-$semesterId'),
        name: name,
        teacher: teacher,
        classroom: classroom,
        dayOfWeek: weekInfo.day,
        startSlot: weekInfo.startSlot,
        endSlot: weekInfo.endSlot,
        startWeek: weekInfo.startWeek,
        endWeek: weekInfo.endWeek,
        weekType: weekInfo.weekType,
        colorIndex: 0,
        semesterId: semesterId,
        note: '',
      ));
    }
    return courses;
  }

  /// 解析正方的时间字符串，例如 "周一第1,2节{第1-16周}" 或 "1-16周(双)"
  _ZfTimeInfo? _parseTimeInfo(String info) {
    try {
      // 提取周次: "1-16周"
      final weekMatch = RegExp(r'(\d+)-(\d+)周').firstMatch(info);
      if (weekMatch == null) return null;
      
      final startWeek = int.parse(weekMatch.group(1)!);
      final endWeek = int.parse(weekMatch.group(2)!);
      
      int weekType = 0;
      if (info.contains('单')) weekType = 1;
      if (info.contains('双')) weekType = 2;

      // 提取星期
      int day = 1;
      final dayMap = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7, '天': 7};
      for (var entry in dayMap.entries) {
        if (info.contains('周${entry.key}')) {
          day = entry.value;
          break;
        }
      }

      // 提取节次: "第1,2节"
      final slotMatch = RegExp(r'第(\d+),(\d+)节').firstMatch(info);
      int startSlot = 1;
      int endSlot = 2;
      if (slotMatch != null) {
        startSlot = int.parse(slotMatch.group(1)!);
        endSlot = int.parse(slotMatch.group(2)!);
      }

      return _ZfTimeInfo(
        day: day,
        startSlot: startSlot,
        endSlot: endSlot,
        startWeek: startWeek,
        endWeek: endWeek,
        weekType: weekType,
      );
    } catch (e) {
      return null;
    }
  }
}

class _ZfTimeInfo {
  final int day;
  final int startSlot;
  final int endSlot;
  final int startWeek;
  final int endWeek;
  final int weekType;

  _ZfTimeInfo({
    required this.day,
    required this.startSlot,
    required this.endSlot,
    required this.startWeek,
    required this.endWeek,
    required this.weekType,
  });
}
