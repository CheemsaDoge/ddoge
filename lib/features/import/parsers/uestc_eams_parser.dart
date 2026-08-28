import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';

import 'package:ddoge/core/constants/time_slots.dart';
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

    // A browser-saved MHT can contain only the rendered EAMS table rather
    // than the original TaskActivity script. Parse that safe static markup as
    // a fallback so the same timetable remains importable offline.
    if (activities.isEmpty) {
      activities.addAll(_parseRenderedTable(document));
    }

    return _buildImportResult(activities, semesterId);
  }

  List<_ParsedActivity> _parseRenderedTable(Document document) {
    const slotsPerDay = 12;
    final activities = <_ParsedActivity>[];

    for (final cell in document.querySelectorAll('td.infoTitle')) {
      final idMatch = RegExp(r'^TD(\d+)(?:_|$)').firstMatch(cell.id);
      final title = cell.attributes['title']?.trim() ?? '';
      if (idMatch == null || title.isEmpty) continue;

      final lesson = _parseRenderedLesson(title);
      if (lesson == null) continue;

      final tableIndex = int.parse(idMatch.group(1)!);
      final day = tableIndex ~/ slotsPerDay + 1;
      final startSlot = tableIndex % slotsPerDay + 1;
      final rowspan = int.tryParse(cell.attributes['rowspan'] ?? '') ?? 1;
      final slots = List<int>.generate(rowspan, (index) => startSlot + index);

      for (final period in lesson.periods) {
        final activeWeeks = <int>[];
        for (var week = period.startWeek; week <= period.endWeek; week++) {
          if (period.weekType == 1 && week.isEven) continue;
          if (period.weekType == 2 && week.isOdd) continue;
          activeWeeks.add(week);
        }
        if (activeWeeks.isEmpty) continue;

        activities.add(
          _ParsedActivity(
            teacher: lesson.teacher,
            courseFullName: lesson.courseFullName,
            classroom: lesson.classroom,
            weekBitmap: _weekBitmap(activeWeeks),
            activeWeeks: activeWeeks,
            dayToSlots: <int, List<int>>{day: slots},
          ),
        );
      }
    }

    return activities;
  }

  _RenderedLesson? _parseRenderedLesson(String title) {
    final separator = title.indexOf(';');
    if (separator < 1) return null;
    final header = title.substring(0, separator).trim();
    final headerMatch = RegExp(r'^(\S+)\s+(.+)$').firstMatch(header);
    if (headerMatch == null) return null;

    final details = title
        .substring(separator + 1)
        .trim()
        .replaceFirst(RegExp(r'^\('), '')
        .replaceFirst(RegExp(r'\)$'), '');
    final detailSeparator = details.indexOf(RegExp(r'[,，]'));
    final weekText = detailSeparator < 0
        ? details
        : details.substring(0, detailSeparator);
    final classroom = detailSeparator < 0
        ? ''
        : details.substring(detailSeparator + 1).trim();
    final periods = <_RenderedWeekPeriod>[];
    final periodPattern = RegExp(
      r'([连单双])\s*(?:第)?\s*(\d+)\s*(?:周)?\s*[-~至]\s*'
      r'(?:第)?\s*(\d+)\s*(?:周)?',
    );
    for (final match in periodPattern.allMatches(weekText)) {
      final startWeek = int.parse(match.group(2)!);
      final endWeek = int.parse(match.group(3)!);
      if (startWeek < 1 || endWeek < startWeek) continue;
      periods.add(
        _RenderedWeekPeriod(
          startWeek: startWeek,
          endWeek: endWeek,
          weekType: switch (match.group(1)) {
            '单' => 1,
            '双' => 2,
            _ => 0,
          },
        ),
      );
    }
    if (periods.isEmpty) return null;

    return _RenderedLesson(
      teacher: headerMatch.group(1)!,
      courseFullName: headerMatch.group(2)!,
      classroom: classroom,
      periods: periods,
    );
  }

  String _weekBitmap(List<int> activeWeeks) {
    final bitmap = List<String>.filled(53, '0');
    for (final week in activeWeeks) {
      if (week >= 1 && week <= bitmap.length) bitmap[week - 1] = '1';
    }
    return bitmap.join();
  }

  ImportParseResult _buildImportResult(
    List<_ParsedActivity> activities,
    String semesterId,
  ) {
    if (activities.isEmpty) {
      return const ImportParseResult(
        courses: <Course>[],
        warnings: <String>['未识别到 EAMS TaskActivity 课表数据。'],
      );
    }

    final uuid = const Uuid();
    final courses = <Course>[];
    final warnings = <String>[];
    final unsupportedActivities = <String>{};
    final invalidActivities = <String>{};
    final invalidDays = <String>{};
    final normalizedWeekOffset = _detectWeekShift(activities);

    for (final activity in activities) {
      if (activity.displayName.trim().isEmpty) {
        invalidActivities.add('缺少课程名称');
        continue;
      }
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
        if (day < 1 || day > TimeSlotConstants.daysPerWeek) {
          invalidDays.add(activity.displayName);
          return;
        }
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

          _addCourseIfSupported(
            courses: courses,
            unsupportedActivities: unsupportedActivities,
            activity: activity,
            day: day,
            start: start,
            end: end,
            weeks: weeks,
            semesterId: semesterId,
            uuid: uuid,
          );
          start = sortedSlots[index];
          end = sortedSlots[index];
        }

        _addCourseIfSupported(
          courses: courses,
          unsupportedActivities: unsupportedActivities,
          activity: activity,
          day: day,
          start: start,
          end: end,
          weeks: weeks,
          semesterId: semesterId,
          uuid: uuid,
        );
      });
    }

    if (unsupportedActivities.isNotEmpty) {
      warnings.add(
        '已跳过 ${unsupportedActivities.length} 门包含第${TimeSlotConstants.maxSlotsPerDay + 1}节'
        '及以后节次的课程：${unsupportedActivities.join('、')}。',
      );
    }
    if (invalidActivities.isNotEmpty) {
      warnings.add('已跳过 ${invalidActivities.length} 条缺少课程名称的记录。');
    }
    if (invalidDays.isNotEmpty) {
      warnings.add('已跳过 ${invalidDays.length} 门星期信息无效的课程。');
    }

    return ImportParseResult(
      courses: courses,
      normalizedWeekOffset: normalizedWeekOffset,
      warnings: warnings,
    );
  }

  void _addCourseIfSupported({
    required List<Course> courses,
    required Set<String> unsupportedActivities,
    required _ParsedActivity activity,
    required int day,
    required int start,
    required int end,
    required _WeekInfo weeks,
    required String semesterId,
    required Uuid uuid,
  }) {
    if (end > TimeSlotConstants.maxSlotsPerDay) {
      unsupportedActivities.add(activity.displayName);
      return;
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

class _RenderedLesson {
  const _RenderedLesson({
    required this.teacher,
    required this.courseFullName,
    required this.classroom,
    required this.periods,
  });

  final String teacher;
  final String courseFullName;
  final String classroom;
  final List<_RenderedWeekPeriod> periods;
}

class _RenderedWeekPeriod {
  const _RenderedWeekPeriod({
    required this.startWeek,
    required this.endWeek,
    required this.weekType,
  });

  final int startWeek;
  final int endWeek;
  final int weekType;
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
