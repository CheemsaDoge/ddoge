import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';
import 'package:ddoge/data/database/app_database.dart';

/// URP 教务系统解析器 (URP)
class UrpParser {
  static const String _uuidNamespace = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';

  /// 解析 URP 课表 HTML
  List<Course> parse(String html, String semesterId) {
    final document = html_parser.parse(html);
    final uuid = const Uuid();
    
    // URP 课表表格通常在 iframe 内或特定的 class 
    final table = document.querySelector('table.gridtable') ?? 
                  document.querySelector('table#kbTable');
    
    if (table == null) return [];

    final courses = <Course>[];
    final rows = table.getElementsByTagName('tr');

    // URP 结构通常：第一列是节次，之后 7 列是周一到周日
    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final cells = rows[rowIndex].getElementsByTagName('td');
      if (cells.length < 8) continue;

      for (var colIndex = 1; colIndex < 8; colIndex++) {
        final cell = cells[colIndex];
        final text = cell.text.trim();
        if (text.isEmpty || text.length < 5) continue;

        // URP 单元格内可能有多门课
        final parts = text.split('\n');
        if (parts.length < 3) continue;

        final name = parts[0].trim();
        final teacher = parts[1].trim();
        final timeAndPlace = parts.length > 2 ? parts[2].trim() : '';

        // URP 的时间通常格式: "1-16周(单) [1-2节] 教室A"
        final weekInfo = _parseUrpInfo(timeAndPlace);
        if (weekInfo == null) continue;

        courses.add(Course(
          id: uuid.v5(_uuidNamespace, '$name-$colIndex-$rowIndex-$semesterId'),
          name: name,
          teacher: teacher,
          classroom: weekInfo.classroom,
          dayOfWeek: colIndex,
          startWeek: weekInfo.startWeek,
          endWeek: weekInfo.endWeek,
          weekType: weekInfo.weekType,
          startSlot: weekInfo.startSlot,
          endSlot: weekInfo.endSlot,
          colorIndex: 0,
          semesterId: semesterId,
          note: '',
        ));
      }
    }
    return courses;
  }

  _UrpTimeInfo? _parseUrpInfo(String info) {
    // 简单正则提取
    final weekMatch = RegExp(r'(\d+)-(\d+)周').firstMatch(info);
    final slotMatch = RegExp(r'\[(\d+)-(\d+)节\]').firstMatch(info);
    
    if (weekMatch == null) return null;

    final startW = int.parse(weekMatch.group(1)!);
    final endW = int.parse(weekMatch.group(2)!);
    
    int startS = 1;
    int endS = 2;
    if (slotMatch != null) {
      startS = int.parse(slotMatch.group(1)!);
      endS = int.parse(slotMatch.group(2)!);
    }

    String classroom = info.split(']').last.trim();
    int type = 0;
    if (info.contains('单')) type = 1;
    if (info.contains('双')) type = 2;

    return _UrpTimeInfo(
      startWeek: startW,
      endWeek: endW,
      startSlot: startS,
      endSlot: endS,
      weekType: type,
      classroom: classroom,
    );
  }
}

class _UrpTimeInfo {
  final int startWeek;
  final int endWeek;
  final int startSlot;
  final int endSlot;
  final int weekType;
  final String classroom;
  _UrpTimeInfo({required this.startWeek, required this.endWeek, required this.startSlot, required this.endSlot, required this.weekType, required this.classroom});
}
