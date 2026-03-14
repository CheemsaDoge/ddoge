import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';
import 'package:ddoge/data/database/app_database.dart';

/// 电子科技大学 (UESTC) EAMS 教务系统解析器
class UestcEamsParser {
  static const String _uuidNamespace = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';

  /// 解析课表 HTML
  /// [html] 是 courseTable.action 的响应内容
  /// [semesterId] 当前要导入到的学期 ID
  List<Course> parse(String html, String semesterId) {
    final document = html_parser.parse(html);
    final scripts = document.getElementsByTagName('script');
    
    final courses = <Course>[];
    final uuid = const Uuid();

    // 查找包含 TaskActivity 的脚本块
    for (final script in scripts) {
      final content = script.text;
      if (content.contains('new TaskActivity')) {
        courses.addAll(_parseScriptContent(content, semesterId, uuid));
      }
    }

    return courses;
  }

  List<Course> _parseScriptContent(String content, String semesterId, Uuid uuid) {
    final courses = <Course>[];
    
    // 正则提取：activity = new TaskActivity("ID", "教师", "课程ID", "课程名(编号)", "代码", "教室", "周次位图");
    final activityRegExp = RegExp(
      r'new TaskActivity\("([^"]*)","([^"]*)","([^"]*)","([^"]*)","([^"]*)","([^"]*)","([^"]*)"\)',
    );

    // 正则提取：index = (dayOfWeek-1)*unitCount + (startSlot-1);
    // 注意：EAMS 的 index = dayIndex * unitCount + slotIndex
    // dayIndex 0-6 (周一-周日), slotIndex 0-11
    final indexRegExp = RegExp(r'index\s*=\s*(\d+)\*unitCount\+(\d+);');

    final lines = content.split('\n');
    
    _RawActivity? currentActivity;
    final Map<_RawActivity, List<int>> activityIndices = {};

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      final activityMatch = activityRegExp.firstMatch(line);
      if (activityMatch != null) {
        currentActivity = _RawActivity(
          teacher: activityMatch.group(2) ?? '',
          name: activityMatch.group(4) ?? '',
          classroom: activityMatch.group(6)?.trim() ?? '',
          weekBitmap: activityMatch.group(7) ?? '',
        );
        continue;
      }

      if (currentActivity != null) {
        final indexMatch = indexRegExp.firstMatch(line);
        if (indexMatch != null) {
          final dayIndex = int.parse(indexMatch.group(1)!);
          final slotIndex = int.parse(indexMatch.group(2)!);
          // 这里的 slotIndex 是从 0 开始的第几节课
          // 实际存储我们用 1-indexed
          final absoluteSlot = dayIndex * 100 + slotIndex; // 临时记录
          
          activityIndices.putIfAbsent(currentActivity, () => []);
          activityIndices[currentActivity]!.add(absoluteSlot);
        }
      }
    }

    // 将 RawActivity 转换为 Course 对象
    activityIndices.forEach((raw, slots) {
      if (slots.isEmpty) return;

      // 按天分组处理连续节次
      final dayToSlots = <int, List<int>>{};
      for (final s in slots) {
        final day = (s / 100).floor() + 1; // 1-7
        final slot = (s % 100) + 1; // 1-12
        dayToSlots.putIfAbsent(day, () => []);
        dayToSlots[day]!.add(slot);
      }

      final weeks = _parseWeeks(raw.weekBitmap);
      if (weeks == null) return;

      dayToSlots.forEach((day, daySlots) {
        daySlots.sort();
        
        // 合并连续节次（例如 1,2 -> 1-2）
        var start = daySlots[0];
        var end = daySlots[0];
        
        for (var j = 1; j < daySlots.length; j++) {
          if (daySlots[j] == end + 1) {
            end = daySlots[j];
          } else {
            // 断开了，先保存之前的
            courses.add(_createCourse(raw, day, start, end, weeks, semesterId, uuid));
            start = daySlots[j];
            end = daySlots[j];
          }
        }
        // 保存最后一组
        courses.add(_createCourse(raw, day, start, end, weeks, semesterId, uuid));
      });
    });

    return courses;
  }

  /// 解析周次位图 (如 "01111100...")
  /// 返回 [startWeek, endWeek, weekType]
  /// weekType: 0=每周, 1=单周, 2=双周
  _WeekInfo? _parseWeeks(String bitmap) {
    if (bitmap.isEmpty) return null;
    
    int firstWeek = -1;
    int lastWeek = -1;
    
    for (var i = 0; i < bitmap.length; i++) {
      if (bitmap[i] == '1') {
        if (firstWeek == -1) firstWeek = i;
        lastWeek = i;
      }
    }

    if (firstWeek == -1) return null;

    // 判断单双周
    bool onlyOdd = true;
    bool onlyEven = true;
    bool all = true;

    for (var i = firstWeek; i <= lastWeek; i++) {
      if (bitmap[i] == '1') {
        if (i % 2 == 0) onlyEven = false; // 位图索引 1 是第 1 周 (奇数)
        if (i % 2 != 0) onlyOdd = false;
      } else {
        // 如果中间有 0，判断是否是单/双周模式
        if (i % 2 != 0 && i <= lastWeek) { // 奇数周没课
          // 可能双周
        }
      }
    }
    
    // 简化处理：目前只支持提取范围，具体的单双周逻辑可以根据 bitmap 更精确计算
    // EAMS 的位图通常很准，我们取 [firstWeek, lastWeek]
    // 并检查步长
    int weekType = 0;
    List<int> activeWeeks = [];
    for(var i=0; i<bitmap.length; i++) {
      if(bitmap[i] == '1') activeWeeks.add(i);
    }
    
    if (activeWeeks.length > 1) {
      bool isStep2 = true;
      for (var i = 1; i < activeWeeks.length; i++) {
        if (activeWeeks[i] - activeWeeks[i-1] != 2) {
          isStep2 = false;
          break;
        }
      }
      if (isStep2) {
        weekType = (activeWeeks[0] % 2 != 0) ? 1 : 2;
      }
    }

    return _WeekInfo(
      startWeek: firstWeek,
      endWeek: lastWeek,
      weekType: weekType,
    );
  }

  Course _createCourse(
    _RawActivity raw,
    int day,
    int start,
    int end,
    _WeekInfo weeks,
    String semesterId,
    Uuid uuid,
  ) {
    // 移除课程名中的编号，如 "微积分(1234)" -> "微积分"
    var name = raw.name;
    if (name.contains('(')) {
      name = name.substring(0, name.lastIndexOf('('));
    }

    return Course(
      id: uuid.v5(_uuidNamespace, '${raw.name}-$day-$start-$semesterId'),
      name: name,
      teacher: raw.teacher,
      classroom: raw.classroom,
      dayOfWeek: day,
      startSlot: start,
      endSlot: end,
      startWeek: weeks.startWeek,
      endWeek: weeks.endWeek,
      weekType: weeks.weekType,
      colorIndex: 0, // 导入后由应用逻辑分配颜色
      semesterId: semesterId,
      note: '',
    );
  }
}

class _RawActivity {
  final String teacher;
  final String name;
  final String classroom;
  final String weekBitmap;

  _RawActivity({
    required this.teacher,
    required this.name,
    required this.classroom,
    required this.weekBitmap,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _RawActivity &&
          runtimeType == other.runtimeType &&
          teacher == other.teacher &&
          name == other.name &&
          classroom == other.classroom &&
          weekBitmap == other.weekBitmap;

  @override
  int get hashCode =>
      teacher.hashCode ^ name.hashCode ^ classroom.hashCode ^ weekBitmap.hashCode;
}

class _WeekInfo {
  final int startWeek;
  final int endWeek;
  final int weekType;

  _WeekInfo({
    required this.startWeek,
    required this.endWeek,
    required this.weekType,
  });
}
