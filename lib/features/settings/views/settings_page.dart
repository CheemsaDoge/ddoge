import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart' as drift;

import 'package:ddoge/features/schedule/providers/schedule_providers.dart';
import 'package:ddoge/features/schedule/providers/database_providers.dart';
import 'package:ddoge/features/notification/providers/notification_providers.dart';
import 'package:ddoge/core/router/app_router.dart';
import 'package:ddoge/core/storage/settings_storage.dart';
import 'package:ddoge/data/services/notification_service.dart';
import 'package:ddoge/data/database/app_database.dart';

import 'package:ddoge/shared/widgets/glass_container.dart';

/// 设置页面
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final reminderMinutes = ref.watch(reminderMinutesProvider);
    final settingsStorage = ref.read(settingsStorageProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('设置')),
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + kToolbarHeight,
          bottom: MediaQuery.of(context).padding.bottom + kCustomNavBarHeight,
        ),
        children: [
          // 学期管理
          _SettingsSection(
            title: '学期管理',
            children: [
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('学期设置'),
                subtitle: const Text('开学日期、总周数'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/semester'),
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('节次时间'),
                subtitle: const Text('自定义每节课的上课时间和时长'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/time-slots'),
              ),
            ],
          ),

          // 课前提醒
          _SettingsSection(
            title: '课前提醒',
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('提醒时间'),
                subtitle: Text(
                  reminderMinutes == 0 ? '已关闭' : '课前 $reminderMinutes 分钟提醒',
                ),
                trailing: _CompactSelect<int>(
                  value: reminderMinutes,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('关闭')),
                    DropdownMenuItem(value: 5, child: Text('5分钟')),
                    DropdownMenuItem(value: 15, child: Text('15分钟')),
                    DropdownMenuItem(value: 30, child: Text('30分钟')),
                  ],
                  onChanged: (minutes) async {
                    if (minutes == null) return;
                    if (minutes > 0) {
                      final granted = await NotificationService.instance
                          .requestPermission();
                      if (!granted) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请授予通知权限以启用课前提醒')),
                          );
                        }
                        return;
                      }
                    }
                    ref.read(reminderMinutesProvider.notifier).state = minutes;
                    ref
                        .read(settingsStorageProvider)
                        .setReminderMinutes(minutes);
                  },
                ),
              ),
            ],
          ),

          // 个性化（跳转子页面）
          _SettingsSection(
            title: '个性化',
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('课表显示与卡片样式'),
                subtitle: const Text('网格线、时间线、圆角、透明度等'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/personalization'),
              ),
            ],
          ),

          // 外观
          _SettingsSection(
            title: '外观',
            children: [
              ListTile(
                leading: const Icon(Icons.wallpaper_outlined),
                title: const Text('课表背景'),
                subtitle: const Text('设置内置壁纸或自定义图片'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/background'),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('主题模式'),
                trailing: _CompactSelect<int>(
                  value: themeMode,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('自动')),
                    DropdownMenuItem(value: 1, child: Text('浅色')),
                    DropdownMenuItem(value: 2, child: Text('深色')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    ref.read(themeModeProvider.notifier).state = value;
                    settingsStorage.setThemeMode(value);
                  },
                ),
              ),
            ],
          ),

          // 数据管理
          _SettingsSection(
            title: '数据与导入',
            children: [
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('从教务系统导入'),
                subtitle: const Text('打开内置浏览器后自行进入课表页面'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/import/generic'),
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('导出课程与样式数据'),
                subtitle: const Text('导出为 JSON 文件并分享'),
                onTap: () => _exportData(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('导入课程与样式数据'),
                subtitle: const Text('从 JSON 文件导入'),
                onTap: () => _importData(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.widgets_outlined),
                title: const Text('刷新桌面小组件'),
                subtitle: const Text('手动更新桌面课表小组件'),
                onTap: () {
                  ref.invalidate(reminderAutoScheduleProvider);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('桌面小组件已刷新')));
                },
              ),
            ],
          ),

          // 关于
          _SettingsSection(
            title: '关于',
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('DDoge 课程表'),
                subtitle: const Text('版本 1.1.4'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 导出课程数据为 JSON
  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    try {
      final exportOptions = await _showExportOptionsDialog(context);
      if (exportOptions == null) return;

      final semesterDao = ref.read(semesterDaoProvider);
      final courseDao = ref.read(courseDaoProvider);
      final timeSlotDao = ref.read(timeSlotDaoProvider);

      final semesters =
          exportOptions.includeSemesters ||
              exportOptions.includeTimeSlots ||
              exportOptions.includeCourses
          ? await semesterDao.getAllSemesters()
          : const <Semester>[];

      // Collect all courses and time slots
      final List<Map<String, dynamic>> semesterList = [];
      final List<Map<String, dynamic>> courseList = [];
      final List<Map<String, dynamic>> timeSlotList = [];
      final settingsStorage = ref.read(settingsStorageProvider);

      for (final sem in semesters) {
        if (exportOptions.includeSemesters) {
          semesterList.add({
            'id': sem.id,
            'name': sem.name,
            'startDate': sem.startDate.toIso8601String(),
            'totalWeeks': sem.totalWeeks,
            'isCurrent': sem.isCurrent,
          });
        }

        if (exportOptions.includeCourses) {
          final courses = await courseDao.getCoursesForSemester(sem.id);
          for (final c in courses) {
            courseList.add({
              'id': c.id,
              'name': c.name,
              'teacher': c.teacher,
              'classroom': c.classroom,
              'dayOfWeek': c.dayOfWeek,
              'startSlot': c.startSlot,
              'endSlot': c.endSlot,
              'startWeek': c.startWeek,
              'endWeek': c.endWeek,
              'weekType': c.weekType,
              'colorIndex': c.colorIndex,
              'note': c.note,
              'semesterId': c.semesterId,
            });
          }
        }

        if (exportOptions.includeTimeSlots) {
          final slots = await timeSlotDao.getTimeSlotsForSemester(sem.id);
          for (final s in slots) {
            timeSlotList.add({
              'index': s.index,
              'startHour': s.startHour,
              'startMinute': s.startMinute,
              'endHour': s.endHour,
              'endMinute': s.endMinute,
              'semesterId': s.semesterId,
            });
          }
        }
      }

      final settingsData = _buildSettingsSubsetExportData(
        settingsStorage,
        includeReminderSettings: exportOptions.includeReminderSettings,
        includeDisplaySettings: exportOptions.includeDisplaySettings,
      );

      if (semesterList.isEmpty &&
          courseList.isEmpty &&
          timeSlotList.isEmpty &&
          settingsData.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('请至少选择一项导出内容')));
        }
        return;
      }

      final exportData = {
        'version': 2,
        'exportDate': DateTime.now().toIso8601String(),
        'semesters': semesterList,
        'courses': courseList,
        'timeSlots': timeSlotList,
        'settings': settingsData,
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);

      // Write to temp file and share
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(p.join(tempDir.path, 'ddoge_export_$timestamp.json'));
      await file.writeAsString(jsonStr);

      await Share.shareXFiles([XFile(file.path)], subject: 'DDoge 课程表与样式数据导出');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }

  /// 从 JSON 文件导入课程数据
  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.single.path;
      if (filePath == null) return;

      final jsonStr = await File(filePath).readAsString();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Validate version
      final version = data['version'];
      if (version == null || version is! int) {
        throw Exception('无效的导出文件：缺少 version 字段');
      }

      final semesterList = data['semesters'] as List<dynamic>? ?? [];
      final courseList = data['courses'] as List<dynamic>? ?? [];
      final timeSlotList = data['timeSlots'] as List<dynamic>? ?? [];
      final settingsMap = data['settings'] as Map<String, dynamic>?;

      // Show confirmation dialog
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认导入'),
          content: Text(
            '即将导入 ${semesterList.length} 个学期、'
            '${courseList.length} 条课程记录、'
            '${timeSlotList.length} 个节次时间配置'
            '${settingsMap == null ? '' : '，以及样式设置'}。\n\n'
            '已有数据将被覆盖（相同 ID 的记录/设置项），是否继续？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('导入'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final semesterDao = ref.read(semesterDaoProvider);
      final courseDao = ref.read(courseDaoProvider);
      final timeSlotDao = ref.read(timeSlotDaoProvider);

      // Import semesters
      for (final s in semesterList) {
        final map = s as Map<String, dynamic>;
        await semesterDao.upsertSemester(
          SemestersCompanion(
            id: drift.Value(map['id'] as String),
            name: drift.Value(map['name'] as String),
            startDate: drift.Value(DateTime.parse(map['startDate'] as String)),
            totalWeeks: drift.Value(map['totalWeeks'] as int),
            isCurrent: drift.Value(map['isCurrent'] as bool? ?? false),
          ),
        );
      }

      // Import courses
      for (final c in courseList) {
        final map = c as Map<String, dynamic>;
        await courseDao.upsertCourse(
          CoursesCompanion(
            id: drift.Value(map['id'] as String),
            name: drift.Value(map['name'] as String),
            teacher: drift.Value(map['teacher'] as String? ?? ''),
            classroom: drift.Value(map['classroom'] as String? ?? ''),
            dayOfWeek: drift.Value(map['dayOfWeek'] as int),
            startSlot: drift.Value(map['startSlot'] as int),
            endSlot: drift.Value(map['endSlot'] as int),
            startWeek: drift.Value(map['startWeek'] as int),
            endWeek: drift.Value(map['endWeek'] as int),
            weekType: drift.Value(map['weekType'] as int? ?? 0),
            colorIndex: drift.Value(map['colorIndex'] as int? ?? 0),
            note: drift.Value(map['note'] as String? ?? ''),
            semesterId: drift.Value(map['semesterId'] as String),
          ),
        );
      }

      // Import time slots
      for (final t in timeSlotList) {
        final map = t as Map<String, dynamic>;
        await timeSlotDao.updateTimeSlot(
          TimeSlotsCompanion(
            index: drift.Value(map['index'] as int),
            startHour: drift.Value(map['startHour'] as int),
            startMinute: drift.Value(map['startMinute'] as int),
            endHour: drift.Value(map['endHour'] as int),
            endMinute: drift.Value(map['endMinute'] as int),
            semesterId: drift.Value(map['semesterId'] as String),
          ),
        );
      }

      if (settingsMap != null) {
        await _importSettings(ref, settingsMap);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '导入成功：${semesterList.length} 个学期、'
              '${courseList.length} 条课程记录'
              '${settingsMap == null ? '' : '，样式设置已恢复'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }

  Map<String, dynamic> _buildSettingsSubsetExportData(
    SettingsStorage storage, {
    required bool includeReminderSettings,
    required bool includeDisplaySettings,
  }) {
    final data = <String, dynamic>{};

    if (includeReminderSettings) {
      data['reminderMinutes'] = storage.getReminderMinutes();
    }

    if (includeDisplaySettings) {
      data.addAll({
        'themeMode': storage.getThemeMode(),
        'autoFitHeight': storage.getAutoFitHeight(),
        'fixedSlotHeight': storage.getFixedSlotHeight(),
        'cardBorderRadius': storage.getCardBorderRadius(),
        'cardOpacity': storage.getCardOpacity(),
        'cardFontScale': storage.getCardFontScale(),
        'showGridLines': storage.getShowGridLines(),
        'showTimeLine': storage.getShowTimeLine(),
        'gridLineColorIndex': storage.getGridLineColorIndex(),
        'gridLineWidth': storage.getGridLineWidth(),
        'gridLineOpacity': storage.getGridLineOpacity(),
        'gridLineDashed': storage.getGridLineDashed(),
        'backgroundType': storage.getBackgroundType().index,
        'builtinWallpaper': storage.getBuiltinWallpaper(),
        'customBackgroundPath': storage.getCustomBackgroundPath(),
        'backgroundOpacity': storage.getBackgroundOpacity(),
      });
    }

    return data;
  }

  Future<void> _importSettings(
    WidgetRef ref,
    Map<String, dynamic> settingsMap,
  ) async {
    final storage = ref.read(settingsStorageProvider);

    final themeMode = (settingsMap['themeMode'] as num?)?.toInt();
    if (themeMode != null) {
      ref.read(themeModeProvider.notifier).state = themeMode;
      await storage.setThemeMode(themeMode);
    }

    final reminderMinutes = (settingsMap['reminderMinutes'] as num?)?.toInt();
    if (reminderMinutes != null) {
      ref.read(reminderMinutesProvider.notifier).state = reminderMinutes;
      await storage.setReminderMinutes(reminderMinutes);
    }

    final autoFitHeight = settingsMap['autoFitHeight'] as bool?;
    if (autoFitHeight != null) {
      ref.read(autoFitHeightProvider.notifier).state = autoFitHeight;
      await storage.setAutoFitHeight(autoFitHeight);
    }

    final fixedSlotHeight = (settingsMap['fixedSlotHeight'] as num?)
        ?.toDouble();
    if (fixedSlotHeight != null) {
      ref.read(fixedSlotHeightProvider.notifier).state = fixedSlotHeight;
      await storage.setFixedSlotHeight(fixedSlotHeight);
    }

    final cardBorderRadius = (settingsMap['cardBorderRadius'] as num?)
        ?.toDouble();
    if (cardBorderRadius != null) {
      ref.read(cardBorderRadiusProvider.notifier).state = cardBorderRadius;
      await storage.setCardBorderRadius(cardBorderRadius);
    }

    final cardOpacity = (settingsMap['cardOpacity'] as num?)?.toDouble();
    if (cardOpacity != null) {
      ref.read(cardOpacityProvider.notifier).state = cardOpacity;
      await storage.setCardOpacity(cardOpacity);
    }

    final cardFontScale = (settingsMap['cardFontScale'] as num?)?.toDouble();
    if (cardFontScale != null) {
      ref.read(cardFontScaleProvider.notifier).state = cardFontScale;
      await storage.setCardFontScale(cardFontScale);
    }

    final showGridLines = settingsMap['showGridLines'] as bool?;
    if (showGridLines != null) {
      ref.read(showGridLinesProvider.notifier).state = showGridLines;
      await storage.setShowGridLines(showGridLines);
    }

    final showTimeLine = settingsMap['showTimeLine'] as bool?;
    if (showTimeLine != null) {
      ref.read(showTimeLineProvider.notifier).state = showTimeLine;
      await storage.setShowTimeLine(showTimeLine);
    }

    final gridLineColorIndex = (settingsMap['gridLineColorIndex'] as num?)
        ?.toInt();
    if (gridLineColorIndex != null) {
      ref.read(gridLineColorIndexProvider.notifier).state = gridLineColorIndex;
      await storage.setGridLineColorIndex(gridLineColorIndex);
    }

    final gridLineWidth = (settingsMap['gridLineWidth'] as num?)?.toDouble();
    if (gridLineWidth != null) {
      ref.read(gridLineWidthProvider.notifier).state = gridLineWidth;
      await storage.setGridLineWidth(gridLineWidth);
    }

    final gridLineOpacity = (settingsMap['gridLineOpacity'] as num?)
        ?.toDouble();
    if (gridLineOpacity != null) {
      ref.read(gridLineOpacityProvider.notifier).state = gridLineOpacity;
      await storage.setGridLineOpacity(gridLineOpacity);
    }

    final gridLineDashed = settingsMap['gridLineDashed'] as bool?;
    if (gridLineDashed != null) {
      ref.read(gridLineDashedProvider.notifier).state = gridLineDashed;
      await storage.setGridLineDashed(gridLineDashed);
    }

    final backgroundTypeIndex = (settingsMap['backgroundType'] as num?)
        ?.toInt();
    if (backgroundTypeIndex != null &&
        backgroundTypeIndex >= 0 &&
        backgroundTypeIndex < BackgroundType.values.length) {
      final backgroundType = BackgroundType.values[backgroundTypeIndex];
      ref.read(backgroundTypeProvider.notifier).state = backgroundType;
      await storage.setBackgroundType(backgroundType);
    }

    final builtinWallpaper = (settingsMap['builtinWallpaper'] as num?)?.toInt();
    if (builtinWallpaper != null) {
      ref.read(builtinWallpaperProvider.notifier).state = builtinWallpaper;
      await storage.setBuiltinWallpaper(builtinWallpaper);
    }

    final customBackgroundPath = settingsMap['customBackgroundPath'] as String?;
    if (customBackgroundPath != null) {
      ref.read(customBackgroundPathProvider.notifier).state =
          customBackgroundPath;
      await storage.setCustomBackgroundPath(customBackgroundPath);
    }

    final backgroundOpacity = (settingsMap['backgroundOpacity'] as num?)
        ?.toDouble();
    if (backgroundOpacity != null) {
      ref.read(backgroundOpacityProvider.notifier).state = backgroundOpacity;
      await storage.setBackgroundOpacity(backgroundOpacity);
    }
  }

  Future<_ExportOptions?> _showExportOptionsDialog(BuildContext context) {
    return showDialog<_ExportOptions>(
      context: context,
      builder: (context) => const _ExportOptionsDialog(),
    );
  }
}

/// 设置分区组件
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _CompactSelect<T> extends StatelessWidget {
  const _CompactSelect({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropdownButtonHideUnderline(
      child: Container(
        constraints: const BoxConstraints(minWidth: 92, maxWidth: 112),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          style: theme.textTheme.bodyMedium,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        ),
      ),
    );
  }
}

class _ExportOptions {
  const _ExportOptions({
    required this.includeSemesters,
    required this.includeTimeSlots,
    required this.includeReminderSettings,
    required this.includeDisplaySettings,
    required this.includeCourses,
  });

  final bool includeSemesters;
  final bool includeTimeSlots;
  final bool includeReminderSettings;
  final bool includeDisplaySettings;
  final bool includeCourses;
}

class _ExportOptionsDialog extends StatefulWidget {
  const _ExportOptionsDialog();

  @override
  State<_ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<_ExportOptionsDialog> {
  bool includeSemesters = true;
  bool includeTimeSlots = true;
  bool includeReminderSettings = true;
  bool includeDisplaySettings = true;
  bool includeCourses = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择导出内容'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              value: includeSemesters,
              onChanged: (value) {
                setState(() => includeSemesters = value ?? false);
              },
              title: const Text('学期'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              value: includeTimeSlots,
              onChanged: (value) {
                setState(() => includeTimeSlots = value ?? false);
              },
              title: const Text('节次'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              value: includeReminderSettings,
              onChanged: (value) {
                setState(() => includeReminderSettings = value ?? false);
              },
              title: const Text('提醒'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              value: includeDisplaySettings,
              onChanged: (value) {
                setState(() => includeDisplaySettings = value ?? false);
              },
              title: const Text('课表显示样式'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              value: includeCourses,
              onChanged: (value) {
                setState(() => includeCourses = value ?? false);
              },
              title: const Text('课程信息'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              _ExportOptions(
                includeSemesters: includeSemesters,
                includeTimeSlots: includeTimeSlots,
                includeReminderSettings: includeReminderSettings,
                includeDisplaySettings: includeDisplaySettings,
                includeCourses: includeCourses,
              ),
            );
          },
          child: const Text('导出'),
        ),
      ],
    );
  }
}
