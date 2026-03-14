import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';
import 'package:ddoge/data/database/app_database.dart';

/// 电子科技大学 (UESTC) EAMS 教务系统解析器
class UestcEamsParser {
  static const String _uuidNamespace = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';

  /// 从 JS 注入返回的 JSON 解析课表
  /// JSON 格式: {"courses": [{ teacherName, courseFullName, roomName, weekBitmap, indices: [{day, slot}] }]}
  List<Course> parseFromJson(String jsonStr, String semesterId) {
    final uuid = const Uuid();
    final courses = <Course>[];

    final data = json.decode(jsonStr) as Map<String, dynamic>;
    if (data.containsKey('error')) return courses;

    final items = data['courses'] as List<dynamic>? ?? [];

    for (final item in items) {
      final teacher = (item['teacherName'] as String?) ?? '';
      final courseFullName = (item['courseFullName'] as String?) ?? '';
      final roomName = (item['roomName'] as String?) ?? '';
      final weekBitmap = (item['weekBitmap'] as String?) ?? '';
      final indices = (item['indices'] as List<dynamic>?) ?? [];

      if (indices.isEmpty || weekBitmap.isEmpty) continue;

      final weeks = _parseWeeks(weekBitmap);
      if (weeks == null) continue;

      // 课程名：去掉括号中的课程编号
      var name = courseFullName;
      final nameMatch = RegExp(r'^(.+?)\([A-Z]').firstMatch(courseFullName);
      if (nameMatch != null) {
        name = nameMatch.group(1)!;
      }

      // 按天分组
      final dayToSlots = <int, List<int>>{};
      for (final idx in indices) {
        final day = (idx['day'] as int) + 1; // 0-indexed → 1-indexed
        final slot = (idx['slot'] as int) + 1;
        dayToSlots.putIfAbsent(day, () => []);
        dayToSlots[day]!.add(slot);
      }

      dayToSlots.forEach((day, daySlots) {
        daySlots.sort();

        // 合并连续节次
        var start = daySlots[0];
        var end = daySlots[0];

        for (var j = 1; j < daySlots.length; j++) {
          if (daySlots[j] == end + 1) {
            end = daySlots[j];
          } else {
            courses.add(_createCourse(
              name, teacher, roomName, day, start, end, weeks, semesterId, uuid,
            ));
            start = daySlots[j];
            end = daySlots[j];
          }
        }
        courses.add(_createCourse(
          name, teacher, roomName, day, start, end, weeks, semesterId, uuid,
        ));
      });
    }

    return courses;
  }

  /// 解析课表 HTML（fallback）
  List<Course> parse(String html, String semesterId) {
    final document = html_parser.parse(html);
    final scripts = document.getElementsByTagName('script');

    final courses = <Course>[];
    final uuid = const Uuid();

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

    final activityRegExp = RegExp(
      r'new TaskActivity\("([^"]*)","([^"]*)","([^"]*)","([^"]*)","([^"]*)","([^"]*)","([^"]*)"\)',
    );
    final indexRegExp = RegExp(r'index\s*=\s*(\d+)\s*\*\s*unitCount\s*\+\s*(\d+)');

    final lines = content.split('\n');

    _RawActivity? currentActivity;
    final List<MapEntry<_RawActivity, _IndexPair>> activitySlots = [];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      final activityMatch = activityRegExp.firstMatch(line);
      if (activityMatch != null) {
        currentActivity = _RawActivity(
          teacher: activityMatch.group(2) ?? '',
          name: activityMatch.group(4) ?? '',
          classroom: (activityMatch.group(6) ?? '').trim(),
          weekBitmap: activityMatch.group(7) ?? '',
        );
        continue;
      }

      if (currentActivity != null) {
        final indexMatch = indexRegExp.firstMatch(line);
        if (indexMatch != null) {
          final dayIndex = int.parse(indexMatch.group(1)!);
          final slotIndex = int.parse(indexMatch.group(2)!);
          activitySlots.add(MapEntry(currentActivity, _IndexPair(dayIndex, slotIndex)));
        }
      }
    }

    // Group by activity
    final Map<_RawActivity, List<_IndexPair>> grouped = {};
    for (final entry in activitySlots) {
      grouped.putIfAbsent(entry.key, () => []);
      grouped[entry.key]!.add(entry.value);
    }

    grouped.forEach((raw, pairs) {
      if (pairs.isEmpty) return;

      final weeks = _parseWeeks(raw.weekBitmap);
      if (weeks == null) return;

      var name = raw.name;
      final nameMatch = RegExp(r'^(.+?)\([A-Z]').firstMatch(raw.name);
      if (nameMatch != null) {
        name = nameMatch.group(1)!;
      }

      // Group by day
      final dayToSlots = <int, List<int>>{};
      for (final p in pairs) {
        final day = p.day + 1; // 0-indexed → 1-indexed
        final slot = p.slot + 1;
        dayToSlots.putIfAbsent(day, () => []);
        dayToSlots[day]!.add(slot);
      }

      dayToSlots.forEach((day, daySlots) {
        daySlots.sort();
        var start = daySlots[0];
        var end = daySlots[0];

        for (var j = 1; j < daySlots.length; j++) {
          if (daySlots[j] == end + 1) {
            end = daySlots[j];
          } else {
            courses.add(_createCourse(
              name, raw.teacher, raw.classroom, day, start, end, weeks, semesterId, uuid,
            ));
            start = daySlots[j];
            end = daySlots[j];
          }
        }
        courses.add(_createCourse(
          name, raw.teacher, raw.classroom, day, start, end, weeks, semesterId, uuid,
        ));
      });
    });

    return courses;
  }

  /// 解析周次位图 (如 "01111100...")
  /// 位置 i 的 '1' 表示第 i+1 周有课（0-indexed bitmap → 1-indexed weeks）
  _WeekInfo? _parseWeeks(String bitmap) {
    if (bitmap.isEmpty) return null;

    final activeWeeks = <int>[];
    for (var i = 0; i < bitmap.length; i++) {
      if (bitmap[i] == '1') {
        activeWeeks.add(i + 1); // bitmap[0]='1' → week 1
      }
    }

    if (activeWeeks.isEmpty) return null;

    final firstWeek = activeWeeks.first;
    final lastWeek = activeWeeks.last;

    // 判断单双周：检查所有有课的周是否纯奇或纯偶
    int weekType = 0; // 0=每周
    if (activeWeeks.length > 1) {
      final allOdd = activeWeeks.every((w) => w % 2 == 1);
      final allEven = activeWeeks.every((w) => w % 2 == 0);
      if (allOdd) {
        weekType = 1; // 单周
      } else if (allEven) {
        weekType = 2; // 双周
      }
    }

    return _WeekInfo(
      startWeek: firstWeek,
      endWeek: lastWeek,
      weekType: weekType,
    );
  }

  Course _createCourse(
    String name,
    String teacher,
    String classroom,
    int day,
    int start,
    int end,
    _WeekInfo weeks,
    String semesterId,
    Uuid uuid,
  ) {
    return Course(
      id: uuid.v5(_uuidNamespace, '$name-$day-$start-${weeks.startWeek}-$semesterId'),
      name: name,
      teacher: teacher,
      classroom: classroom,
      dayOfWeek: day,
      startSlot: start,
      endSlot: end,
      startWeek: weeks.startWeek,
      endWeek: weeks.endWeek,
      weekType: weeks.weekType,
      colorIndex: 0,
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

class _IndexPair {
  final int day;
  final int slot;
  _IndexPair(this.day, this.slot);
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
