import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:ddoge/core/models/time_slot_template.dart';
import 'package:ddoge/data/database/app_database.dart';
import 'package:ddoge/features/schedule/providers/database_providers.dart';
import 'package:ddoge/features/schedule/providers/schedule_providers.dart';
import 'package:ddoge/features/settings/widgets/settings_subpage_scaffold.dart';

/// 学期设置页面
class SemesterSettingsPage extends ConsumerStatefulWidget {
  const SemesterSettingsPage({super.key});

  @override
  ConsumerState<SemesterSettingsPage> createState() =>
      _SemesterSettingsPageState();
}

class _SemesterSettingsPageState extends ConsumerState<SemesterSettingsPage> {
  final _nameController = TextEditingController();
  DateTime _startDate = DateTime.now();
  int _totalWeeks = 20;
  bool _isEditing = false;
  String? _editingSemesterId;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semestersAsync = ref.watch(allSemestersProvider);
    // 监听当前学期以确保状态同步
    ref.watch(currentSemesterProvider);

    return SettingsSubpageScaffold(
      title: '学期管理',
      child: semestersAsync.when(
        data: (semesters) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            settingsSubpageBottomPadding(context),
          ),
          children: [
            // 已有学期列表
            if (semesters.isNotEmpty) ...[
              Text('已有学期', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...semesters.map(
                (s) => Card(
                  color: s.isCurrent
                      ? theme.colorScheme.primaryContainer
                      : null,
                  child: ListTile(
                    title: Text(s.name),
                    subtitle: Text(
                      '开学日期：${s.startDate.year}-${s.startDate.month.toString().padLeft(2, '0')}-${s.startDate.day.toString().padLeft(2, '0')}  共${s.totalWeeks}周',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!s.isCurrent)
                          TextButton(
                            onPressed: () => _setCurrentSemester(s.id),
                            child: const Text('设为当前'),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _startEdit(s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _deleteSemester(s.id, s.name),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 添加/编辑表单
            Text(
              _isEditing ? '编辑学期' : '添加新学期',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '学期名称',
                hintText: '如：2025-2026 第一学期',
                prefixIcon: Icon(Icons.school_outlined),
              ),
            ),
            const SizedBox(height: 12),

            // 开学日期选择
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('开学日期（第一周周一）'),
              subtitle: Text(
                '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickStartDate,
            ),
            const SizedBox(height: 8),

            // 总周数
            Row(
              children: [
                const Icon(Icons.date_range),
                const SizedBox(width: 16),
                const Text('总周数'),
                const Spacer(),
                IconButton(
                  onPressed: _totalWeeks > 1
                      ? () => setState(() => _totalWeeks--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_totalWeeks', style: theme.textTheme.titleMedium),
                IconButton(
                  onPressed: _totalWeeks < 30
                      ? () => setState(() => _totalWeeks++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 保存按钮
            Row(
              children: [
                if (_isEditing)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelEdit,
                      child: const Text('取消'),
                    ),
                  ),
                if (_isEditing) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saveSemester,
                    child: Text(_isEditing ? '保存修改' : '创建学期'),
                  ),
                ),
              ],
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  void _startEdit(dynamic semester) {
    setState(() {
      _isEditing = true;
      _editingSemesterId = semester.id;
      _nameController.text = semester.name;
      _startDate = semester.startDate;
      _totalWeeks = semester.totalWeeks;
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _editingSemesterId = null;
      _nameController.clear();
      _startDate = DateTime.now();
      _totalWeeks = 20;
    });
  }

  Future<void> _pickStartDate() async {
    // 找到最近的周一
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      // 调整到周一
      final weekday = picked.weekday;
      final monday = picked.subtract(Duration(days: weekday - 1));
      setState(() => _startDate = monday);
    }
  }

  Future<void> _saveSemester() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入学期名称')));
      return;
    }

    final semesterDao = ref.read(semesterDaoProvider);
    final timeSlotDao = ref.read(timeSlotDaoProvider);
    final settingsStorage = ref.read(settingsStorageProvider);
    final id = _editingSemesterId ?? const Uuid().v4();
    final isFirst = (ref.read(allSemestersProvider).valueOrNull ?? []).isEmpty;

    await semesterDao.upsertSemester(
      SemestersCompanion(
        id: Value(id),
        name: Value(name),
        startDate: Value(_startDate),
        totalWeeks: Value(_totalWeeks),
        isCurrent: Value(isFirst || _isEditing ? true : false),
      ),
    );

    // 如果是新学期，初始化默认节次时间
    if (!_isEditing) {
      await timeSlotDao.initDefaultTimeSlots(id);
      await settingsStorage.setSemesterTimeSlotTemplateId(
        id,
        TimeSlotTemplate.defaultTemplateId,
      );
      // 如果是第一个学期，设置为当前
      if (isFirst) {
        await semesterDao.setCurrentSemester(id);
      }
    }

    _cancelEdit();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_isEditing ? '学期已更新' : '学期已创建')));
      // 保存后自动回退到课表主页
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _setCurrentSemester(String id) async {
    await ref.read(semesterDaoProvider).setCurrentSemester(id);
  }

  Future<void> _deleteSemester(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除学期'),
        content: Text('确定要删除学期"$name"及其所有课程数据吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(courseDaoProvider).deleteCoursesForSemester(id);
      await ref.read(timeSlotDaoProvider).deleteTimeSlotsForSemester(id);
      await ref
          .read(settingsStorageProvider)
          .setSemesterTimeSlotTemplateId(id, null);
      await ref.read(semesterDaoProvider).deleteSemester(id);
    }
  }
}
