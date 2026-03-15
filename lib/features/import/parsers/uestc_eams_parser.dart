import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';

import 'package:ddoge/data/database/app_database.dart';
import 'package:ddoge/features/import/models/import_parse_result.dart';

/// 电子科技大学 (UESTC) EAMS 教务系统解析器
class UestcEamsParser {
  static const String _uuidNamespace = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';

  /// 从 JS 注入返回的 JSON 解析课表
  /// JSON 格式: {"courses": [{ teacherName, courseFullName, roomName, weekBitmap, indices: [{day, slot}] }]}
  List<Course> parseFromJson(String jsonStr, String semesterId) {
    return parseImportResultFromJson(jsonStr, semesterId).courses;
  }

  ImportParseResult parseImportResultFromJson(
    String jsonStr,
    String semesterId,
  ) {
    final activities = <_ParsedActivity>[];
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    if (data.containsKey('error')) {
      return const ImportParseResult(courses: <Course>[]);
    }

    final items = data['courses'] as List<dynamic>? ?? [];
    for (final item in items) {
      final teacher = (item['teacherName'] as String?) ?? '';
      final courseFullName = (item['courseFullName'] as String?) ?? '';
      final roomName = (item['roomName'] as String?) ?? '';
      final weekBitmap = (item['weekBitmap'] as String?) ?? '';
      final indices = (item['indices'] as List<dynamic>?) ?? [];
      if (indices.isEmpty || weekBitmap.isEmpty) {
        continue;
      }

      final activeWeeks = _parseActiveWeeks(weekBitmap);
      if (activeWeeks.isEmpty) {
        continue;
      }

      final dayToSlots = <int, List<int>>{};
      for (final idx in indices) {
        final day = ((idx['day'] as int?) ?? 0) + 1;
        final slot = ((idx['slot'] as int?) ?? 0) + 1;
        dayToSlots.putIfAbsent(day, () => []);
        dayToSlots[day]!.add(slot);
      }

      if (dayToSlots.isEmpty) {
        continue;
      }

      activities.add(
        _ParsedActivity(
          teacher: teacher,
          courseFullName: courseFullName,
          classroom: roomName,
          weekBitmap: weekBitmap,
          activeWeeks: activeWeeks,
          dayToSlots: dayToSlots,
        ),
      );
    }

    return _buildImportResult(activities, semesterId);
  }

  /// 解析课表 HTML（fallback）
  List<Course> parse(String html, String semesterId) {
    return parseImportResult(html, semesterId).courses;
  }

  ImportParseResult parseImportResult(String html, String semesterId) {
    final document = html_parser.parse(html);
    final scripts = document.getElementsByTagName('script');
    final activities = <_ParsedActivity>[];

    for (final script in scripts) {
      final content = script.text;
      if (!content.contains('new TaskActivity')) {
        continue;
      }
      activities.addAll(_parseScriptContent(content));
    }

    return _buildImportResult(activities, semesterId);
  }

  ImportParseResult _buildImportResult(
    List<_ParsedActivity> activities,
    String semesterId,
  ) {
    if (activities.isEmpty) {
      return const ImportParseResult(courses: <Course>[]);
    }

    final uuid = const Uuid();
    final courses = <Course>[];
    final normalizedWeekOffset = _detectWeekShift(activities);

    for (final activity in activities) {
      final normalizedWeeks = normalizedWeekOffset == 0
          ? activity.activeWeeks
          : activity.activeWeeks
                .map((week) => week - normalizedWeekOffset)
                .where((week) => week > 0)
                .toList();
      final weeks = _buildWeekInfo(normalizedWeeks);
      if (weeks == null) {
        continue;
      }

      activity.dayToSlots.forEach((day, daySlots) {
        final sortedSlots = [...daySlots]..sort();
        if (sortedSlots.isEmpty) {
          return;
        }

        var start = sortedSlots.first;
        var end = sortedSlots.first;

        for (var index = 1; index < sortedSlots.length; index++) {
          if (sortedSlots[index] == end + 1) {
            end = sortedSlots[index];
            continue;
          }

          courses.add(
            _createCourse(
              activity: activity,
              day: day,
              start: start,
              end: end,
              weeks: weeks,
              semesterId: semesterId,
              uuid: uuid,
            ),
          );
          start = sortedSlots[index];
          end = sortedSlots[index];
        }

        courses.add(
          _createCourse(
            activity: activity,
            day: day,
            start: start,
            end: end,
            weeks: weeks,
            semesterId: semesterId,
            uuid: uuid,
          ),
        );
      });
    }

    return ImportParseResult(
      courses: courses,
      normalizedWeekOffset: normalizedWeekOffset,
    );
  }

  List<_ParsedActivity> _parseScriptContent(String content) {
    final activityRegExp = RegExp(
      r'new TaskActivity\("([^"]*)","([^"]*)","([^"]*)","([^"]*)","([^"]*)","([^"]*)","([^"]*)"\)',
    );
    final indexRegExp = RegExp(
      r'index\s*=\s*(\d+)\s*\*\s*unitCount\s*\+\s*(\d+)',
    );

    final lines = content.split('\n');
    _RawActivity? currentActivity;
    final activitySlots = <MapEntry<_RawActivity, _IndexPair>>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();

      final activityMatch = activityRegExp.firstMatch(line);
      if (activityMatch != null) {
        currentActivity = _RawActivity(
          teacher: activityMatch.group(2) ?? '',
          courseFullName: activityMatch.group(4) ?? '',
          classroom: (activityMatch.group(6) ?? '').trim(),
          weekBitmap: activityMatch.group(7) ?? '',
        );
        continue;
      }

      if (currentActivity == null) {
        continue;
      }

      final indexMatch = indexRegExp.firstMatch(line);
      if (indexMatch == null) {
        continue;
      }

      final dayIndex = int.parse(indexMatch.group(1)!);
      final slotIndex = int.parse(indexMatch.group(2)!);
      activitySlots.add(
        MapEntry(currentActivity, _IndexPair(dayIndex, slotIndex)),
      );
    }

    final groupedActivities = <_RawActivity, List<_IndexPair>>{};
    for (final entry in activitySlots) {
      groupedActivities.putIfAbsent(entry.key, () => []);
      groupedActivities[entry.key]!.add(entry.value);
    }

    final parsedActivities = <_ParsedActivity>[];
    groupedActivities.forEach((raw, pairs) {
      final activeWeeks = _parseActiveWeeks(raw.weekBitmap);
      if (pairs.isEmpty || activeWeeks.isEmpty) {
        return;
      }

      final dayToSlots = <int, List<int>>{};
      for (final pair in pairs) {
        final day = pair.day + 1;
        final slot = pair.slot + 1;
        dayToSlots.putIfAbsent(day, () => []);
        dayToSlots[day]!.add(slot);
      }

      if (dayToSlots.isEmpty) {
        return;
      }

      parsedActivities.add(
        _ParsedActivity(
          teacher: raw.teacher,
          courseFullName: raw.courseFullName,
          classroom: raw.classroom,
          weekBitmap: raw.weekBitmap,
          activeWeeks: activeWeeks,
          dayToSlots: dayToSlots,
        ),
      );
    });

    return parsedActivities;
  }

  List<int> _parseActiveWeeks(String bitmap) {
    if (bitmap.isEmpty) {
      return const [];
    }

    final activeWeeks = <int>[];
    for (var index = 0; index < bitmap.length; index++) {
      if (bitmap[index] == '1') {
        activeWeeks.add(index + 1);
      }
    }
    return activeWeeks;
  }

  int _detectWeekShift(List<_ParsedActivity> activities) {
    final allWeeks = activities
        .expand((activity) => activity.activeWeeks)
        .toList();
    if (allWeeks.isEmpty || allWeeks.contains(1)) {
      return 0;
    }

    final minWeek = allWeeks.reduce(
      (left, right) => left < right ? left : right,
    );
    if (minWeek != 2) {
      return 0;
    }

    final weekTwoHitCount = activities
        .where((activity) => activity.activeWeeks.contains(2))
        .length;

    // UESTC 常见情况是所有课程整体从第 2 周起，此时前移 1 周对齐本地学期周。
    return weekTwoHitCount * 2 >= activities.length ? 1 : 0;
  }

  _WeekInfo? _buildWeekInfo(List<int> activeWeeks) {
    if (activeWeeks.isEmpty) {
      return null;
    }

    final sortedWeeks = [...activeWeeks]..sort();
    final firstWeek = sortedWeeks.first;
    final lastWeek = sortedWeeks.last;

    var weekType = 0;
    if (sortedWeeks.length > 1) {
      final allOdd = sortedWeeks.every((week) => week.isOdd);
      final allEven = sortedWeeks.every((week) => week.isEven);
      if (allOdd) {
        weekType = 1;
      } else if (allEven) {
        weekType = 2;
      }
    }

    return _WeekInfo(
      startWeek: firstWeek,
      endWeek: lastWeek,
      weekType: weekType,
    );
  }

  Course _createCourse({
    required _ParsedActivity activity,
    required int day,
    required int start,
    required int end,
    required _WeekInfo weeks,
    required String semesterId,
    required Uuid uuid,
  }) {
    return Course(
      id: uuid.v5(
        _uuidNamespace,
        '${activity.courseFullName}|${activity.teacher}|${activity.classroom}|'
        '$day|$start|$end|${activity.weekBitmap}|$semesterId',
      ),
      name: activity.displayName,
      teacher: activity.teacher,
      classroom: activity.classroom,
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

class _ParsedActivity {
  const _ParsedActivity({
    required this.teacher,
    required this.courseFullName,
    required this.classroom,
    required this.weekBitmap,
    required this.activeWeeks,
    required this.dayToSlots,
  });

  final String teacher;
  final String courseFullName;
  final String classroom;
  final String weekBitmap;
  final List<int> activeWeeks;
  final Map<int, List<int>> dayToSlots;

  String get displayName {
    final match = RegExp(r'^(.+?)\([A-Z]').firstMatch(courseFullName);
    return match?.group(1) ?? courseFullName;
  }
}

class _RawActivity {
  const _RawActivity({
    required this.teacher,
    required this.courseFullName,
    required this.classroom,
    required this.weekBitmap,
  });

  final String teacher;
  final String courseFullName;
  final String classroom;
  final String weekBitmap;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _RawActivity &&
            teacher == other.teacher &&
            courseFullName == other.courseFullName &&
            classroom == other.classroom &&
            weekBitmap == other.weekBitmap;
  }

  @override
  int get hashCode {
    return teacher.hashCode ^
        courseFullName.hashCode ^
        classroom.hashCode ^
        weekBitmap.hashCode;
  }
}

class _IndexPair {
  const _IndexPair(this.day, this.slot);

  final int day;
  final int slot;
}

class _WeekInfo {
  const _WeekInfo({
    required this.startWeek,
    required this.endWeek,
    required this.weekType,
  });

  final int startWeek;
  final int endWeek;
  final int weekType;
}
