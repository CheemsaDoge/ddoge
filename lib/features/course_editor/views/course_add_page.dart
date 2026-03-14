import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:ddoge/core/constants/app_colors.dart';
import 'package:ddoge/core/constants/time_slots.dart';
import 'package:ddoge/data/database/app_database.dart';
import 'package:ddoge/features/schedule/providers/database_providers.dart';
import 'package:ddoge/features/schedule/providers/schedule_providers.dart';

/// 添加课程页面
class CourseAddPage extends ConsumerStatefulWidget {
  const CourseAddPage({
    super.key,
    this.initialDayOfWeek,
    this.initialSlot,
    this.initialEndSlot,
  });

  /// 初始星期几
  final int? initialDayOfWeek;

  /// 初始开始节次
  final int? initialSlot;

  /// 初始结束节次（拖选时使用）
  final int? initialEndSlot;

  @override
  ConsumerState<CourseAddPage> createState() => _CourseAddPageState();
}

class _CourseAddPageState extends ConsumerState<CourseAddPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _teacherController = TextEditingController();
  final _classroomController = TextEditingController();
  final _noteController = TextEditingController();

  late int _dayOfWeek;
  late int _startSlot;
  int _endSlot = 2;
  int _startWeek = 1;
  int _endWeek = 20;
  int _weekType = 0; // 0=每周, 1=单周, 2=双周
  int _colorIndex = 0;

  @override
  void initState() {
    super.initState();
    _dayOfWeek = widget.initialDayOfWeek ?? 1;
    _startSlot = widget.initialSlot ?? 1;
    _endSlot = widget.initialEndSlot ?? _startSlot + 1;
    _colorIndex = DateTime.now().millisecond % AppColors.courseColors.length;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    _classroomController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semester = ref.watch(currentSemesterProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加课程'),
        actions: [
          TextButton(
            onPressed: _saveCourse,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 课程名称
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '课程名称',
                hintText: '如：高等数学',
                prefixIcon: Icon(Icons.book_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '请输入课程名称' : null,
            ),
            const SizedBox(height: 12),

            // 教师
            TextFormField(
              controller: _teacherController,
              decoration: const InputDecoration(
                labelText: '教师',
                hintText: '选填',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),

            // 教室
            TextFormField(
              controller: _classroomController,
              decoration: const InputDecoration(
                labelText: '教室',
                hintText: '如：A101',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 20),

            // 时间设置标题
            Text('上课时间', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),

            // 星期选择
            _buildDropdownRow(
              icon: Icons.calendar_view_week,
              label: '星期',
              value: _dayOfWeek,
              items: List.generate(
                7,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(TimeSlotConstants.weekdayNames[i]),
                ),
              ),
              onChanged: (v) => setState(() => _dayOfWeek = v!),
            ),
            const SizedBox(height: 8),

            // 开始节次
            _buildDropdownRow(
              icon: Icons.arrow_downward,
              label: '开始节次',
              value: _startSlot,
              items: List.generate(
                TimeSlotConstants.maxSlotsPerDay,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text('第${i + 1}节'),
                ),
              ),
              onChanged: (v) {
                setState(() {
                  _startSlot = v!;
                  if (_endSlot < _startSlot) _endSlot = _startSlot;
                });
              },
            ),
            const SizedBox(height: 8),

            // 结束节次
            _buildDropdownRow(
              icon: Icons.arrow_upward,
              label: '结束节次',
              value: _endSlot,
              items: List.generate(
                TimeSlotConstants.maxSlotsPerDay - _startSlot + 1,
                (i) => DropdownMenuItem(
                  value: _startSlot + i,
                  child: Text('第${_startSlot + i}节'),
                ),
              ),
              onChanged: (v) => setState(() => _endSlot = v!),
            ),
            const SizedBox(height: 20),

            // 周次设置标题
            Text('周次范围', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),

            // 开始周和结束周
            Row(
              children: [
                Expanded(
                  child: _buildDropdownRow(
                    icon: Icons.first_page,
                    label: '开始周',
                    value: _startWeek,
                    items: List.generate(
                      semester?.totalWeeks ?? 20,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('第${i + 1}周'),
                      ),
                    ),
                    onChanged: (v) {
                      setState(() {
                        _startWeek = v!;
                        if (_endWeek < _startWeek) _endWeek = _startWeek;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownRow(
                    icon: Icons.last_page,
                    label: '结束周',
                    value: _endWeek,
                    items: List.generate(
                      (semester?.totalWeeks ?? 20) - _startWeek + 1,
                      (i) => DropdownMenuItem(
                        value: _startWeek + i,
                        child: Text('第${_startWeek + i}周'),
                      ),
                    ),
                    onChanged: (v) => setState(() => _endWeek = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 单双周
            _buildDropdownRow(
              icon: Icons.repeat,
              label: '频率',
              value: _weekType,
              items: const [
                DropdownMenuItem(value: 0, child: Text('每周')),
                DropdownMenuItem(value: 1, child: Text('仅单周')),
                DropdownMenuItem(value: 2, child: Text('仅双周')),
              ],
              onChanged: (v) => setState(() => _weekType = v!),
            ),
            const SizedBox(height: 20),

            // 颜色选择
            Text('卡片颜色', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _buildColorSelector(),
            const SizedBox(height: 12),

            // 备注
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注',
                hintText: '选填',
                prefixIcon: Icon(Icons.note_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownRow<T>({
    required IconData icon,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          underline: const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildColorSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(AppColors.courseColors.length, (index) {
        final color = AppColors.courseColors[index];
        final isSelected = index == _colorIndex;
        return GestureDetector(
          onTap: () => setState(() => _colorIndex = index),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    )
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 8,
                      )
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : null,
          ),
        );
      }),
    );
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    final semester = ref.read(currentSemesterProvider).valueOrNull;
    if (semester == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先设置学期信息')),
      );
      return;
    }

    // 冲突检测
    final existingCourses =
        ref.read(coursesForCurrentSemesterProvider).valueOrNull ?? [];
    final conflicts = existingCourses.where((c) {
      if (c.dayOfWeek != _dayOfWeek) return false;
      // 节次重叠检测
      if (c.startSlot > _endSlot || c.endSlot < _startSlot) return false;
      // 周次重叠检测
      if (c.startWeek > _endWeek || c.endWeek < _startWeek) return false;
      // 单双周检测
      if (_weekType != 0 && c.weekType != 0 && _weekType != c.weekType) {
        return false;
      }
      return true;
    }).toList();

    if (conflicts.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('课程冲突'),
          content: Text(
            '与以下课程时间冲突：\n${conflicts.map((c) => '  - ${c.name}').join('\n')}\n\n是否仍要添加？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('仍然添加'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final courseDao = ref.read(courseDaoProvider);
    await courseDao.upsertCourse(CoursesCompanion.insert(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      teacher: Value(_teacherController.text.trim()),
      classroom: Value(_classroomController.text.trim()),
      dayOfWeek: _dayOfWeek,
      startSlot: _startSlot,
      endSlot: _endSlot,
      startWeek: _startWeek,
      endWeek: _endWeek,
      weekType: Value(_weekType),
      colorIndex: Value(_colorIndex),
      note: Value(_noteController.text.trim()),
      semesterId: semester.id,
    ));

    if (mounted) {
      context.pop();
    }
  }
}
