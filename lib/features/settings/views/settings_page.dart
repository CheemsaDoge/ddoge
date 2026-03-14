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
                subtitle: Text(reminderMinutes == 0
                    ? '已关闭'
                    : '课前 $reminderMinutes 分钟提醒'),
                trailing: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('关')),
                    ButtonSegment(value: 5, label: Text('5m')),
                    ButtonSegment(value: 15, label: Text('15m')),
                    ButtonSegment(value: 30, label: Text('30m')),
                  ],
                  selected: {reminderMinutes},
                  onSelectionChanged: (v) async {
                    final minutes = v.first;
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
                    ref.read(settingsStorageProvider).setReminderMinutes(minutes);
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
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
                trailing: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('自动')),
                    ButtonSegment(value: 1, label: Text('浅色')),
                    ButtonSegment(value: 2, label: Text('深色')),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (v) {
                    ref.read(themeModeProvider.notifier).state = v.first;
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
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
                subtitle: const Text('支持 UESTC、正方、强智、URP 系统'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ImportOption(
                            icon: Icons.account_balance_outlined,
                            title: 'UESTC (EAMS)',
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/import/uestc');
                            },
                          ),
                          _ImportOption(
                            icon: Icons.grid_view,
                            title: '正方教务系统',
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/import/zhengfang');
                            },
                          ),
                          _ImportOption(
                            icon: Icons.bolt,
                            title: '强智教务系统',
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/import/qiangzhi');
                            },
                          ),
                          _ImportOption(
                            icon: Icons.table_chart_outlined,
                            title: 'URP 教务系统',
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/import/urp');
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('导出课程数据'),
                subtitle: const Text('导出为 JSON 文件并分享'),
                onTap: () => _exportData(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('导入课程数据'),
                subtitle: const Text('从 JSON 文件导入'),
                onTap: () => _importData(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.widgets_outlined),
                title: const Text('刷新桌面小组件'),
                subtitle: const Text('手动更新桌面课表小组件'),
                onTap: () {
                  ref.invalidate(reminderAutoScheduleProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('桌面小组件已刷新')),
                  );
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
                subtitle: const Text('版本 1.1.0'),
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
      final semesterDao = ref.read(semesterDaoProvider);
      final courseDao = ref.read(courseDaoProvider);
      final timeSlotDao = ref.read(timeSlotDaoProvider);

      final semesters = await semesterDao.getAllSemesters();

      if (semesters.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有数据可导出')),
          );
        }
        return;
      }

      // Collect all courses and time slots
      final List<Map<String, dynamic>> semesterList = [];
      final List<Map<String, dynamic>> courseList = [];
      final List<Map<String, dynamic>> timeSlotList = [];

      for (final sem in semesters) {
        semesterList.add({
          'id': sem.id,
          'name': sem.name,
          'startDate': sem.startDate.toIso8601String(),
          'totalWeeks': sem.totalWeeks,
          'isCurrent': sem.isCurrent,
        });

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

      final exportData = {
        'version': 1,
        'exportDate': DateTime.now().toIso8601String(),
        'semesters': semesterList,
        'courses': courseList,
        'timeSlots': timeSlotList,
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);

      // Write to temp file and share
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(p.join(tempDir.path, 'ddoge_export_$timestamp.json'));
      await file.writeAsString(jsonStr);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'DDoge 课程表数据导出',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
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

      // Show confirmation dialog
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认导入'),
          content: Text(
            '即将导入 ${semesterList.length} 个学期、'
            '${courseList.length} 条课程记录、'
            '${timeSlotList.length} 个节次时间配置。\n\n'
            '已有数据将被覆盖（相同 ID 的记录），是否继续？',
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
        await semesterDao.upsertSemester(SemestersCompanion(
          id: drift.Value(map['id'] as String),
          name: drift.Value(map['name'] as String),
          startDate: drift.Value(DateTime.parse(map['startDate'] as String)),
          totalWeeks: drift.Value(map['totalWeeks'] as int),
          isCurrent: drift.Value(map['isCurrent'] as bool? ?? false),
        ));
      }

      // Import courses
      for (final c in courseList) {
        final map = c as Map<String, dynamic>;
        await courseDao.upsertCourse(CoursesCompanion(
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
        ));
      }

      // Import time slots
      for (final t in timeSlotList) {
        final map = t as Map<String, dynamic>;
        await timeSlotDao.updateTimeSlot(TimeSlotsCompanion(
          index: drift.Value(map['index'] as int),
          startHour: drift.Value(map['startHour'] as int),
          startMinute: drift.Value(map['startMinute'] as int),
          endHour: drift.Value(map['endHour'] as int),
          endMinute: drift.Value(map['endMinute'] as int),
          semesterId: drift.Value(map['semesterId'] as String),
        ));
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '导入成功：${semesterList.length} 个学期、'
              '${courseList.length} 条课程记录',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }
}

/// 导入选项组件
class _ImportOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ImportOption({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }
}

/// 设置分区组件
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

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
