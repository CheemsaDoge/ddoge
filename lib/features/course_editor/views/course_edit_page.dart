import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ddoge/core/constants/app_colors.dart';
import 'package:ddoge/core/constants/time_slots.dart';
import 'package:ddoge/data/database/app_database.dart';
import 'package:ddoge/features/schedule/providers/database_providers.dart';
import 'package:ddoge/features/schedule/providers/schedule_providers.dart';

/// 编辑课程页面
class CourseEditPage extends ConsumerStatefulWidget {
  const CourseEditPage({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<CourseEditPage> createState() => _CourseEditPageState();
}

class _CourseEditPageState extends ConsumerState<CourseEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _teacherController = TextEditingController();
  final _classroomController = TextEditingController();
  final _noteController = TextEditingController();

  int _dayOfWeek = 1;
  int _startSlot = 1;
  int _endSlot = 2;
  int _startWeek = 1;
  int _endWeek = 20;
  int _weekType = 0;
  int _colorIndex = 0;
  bool _loaded = false;

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    _classroomController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _loadCourse() {
    if (_loaded) return;
    final courses =
        ref.read(coursesForCurrentSemesterProvider).valueOrNull ?? [];
    final course = courses.where((c) => c.id == widget.courseId).firstOrNull;
    if (course == null) return;

    _nameController.text = course.name;
    _teacherController.text = course.teacher;
    _classroomController.text = course.classroom;
    _noteController.text = course.note;
    _dayOfWeek = course.dayOfWeek;
    _startSlot = course.startSlot;
    _endSlot = course.endSlot;
    _startWeek = course.startWeek;
    _endWeek = course.endWeek;
    _weekType = course.weekType;
    _colorIndex = course.colorIndex;
    _loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semester = ref.watch(currentSemesterProvider).valueOrNull;

    // 等课程数据加载后填充表单
    ref.listen(coursesForCurrentSemesterProvider, (_, next) {
      if (!_loaded && next.hasValue) {
        setState(() => _loadCourse());
      }
    });
    _loadCourse();

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑课程'),
        actions: [
          // 删除按钮
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteCourse,
          ),
          TextButton(onPressed: _saveCourse, child: const Text('保存')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '课程名称',
                prefixIcon: Icon(Icons.book_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '请输入课程名称' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _teacherController,
              decoration: const InputDecoration(
                labelText: '教师',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _classroomController,
              decoration: const InputDecoration(
                labelText: '教室',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 20),

            Text('上课时间', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
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
            _buildDropdownRow(
              icon: Icons.arrow_downward,
              label: '开始节次',
              value: _startSlot,
              items: List.generate(
                TimeSlotConstants.maxSlotsPerDay,
                (i) =>
                    DropdownMenuItem(value: i + 1, child: Text('第${i + 1}节')),
              ),
              onChanged: (v) {
                setState(() {
                  _startSlot = v!;
                  if (_endSlot < _startSlot) _endSlot = _startSlot;
                });
              },
            ),
            const SizedBox(height: 8),
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

            Text('周次范围', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDropdownRow(
                    icon: Icons.first_page,
                    label: '开始',
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
                    label: '结束',
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

            Text('卡片颜色', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _buildColorSelector(),
            const SizedBox(height: 12),

            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注',
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
    if (semester == null) return;

    final courseDao = ref.read(courseDaoProvider);
    await courseDao.upsertCourse(
      CoursesCompanion(
        id: Value(widget.courseId),
        name: Value(_nameController.text.trim()),
        teacher: Value(_teacherController.text.trim()),
        classroom: Value(_classroomController.text.trim()),
        dayOfWeek: Value(_dayOfWeek),
        startSlot: Value(_startSlot),
        endSlot: Value(_endSlot),
        startWeek: Value(_startWeek),
        endWeek: Value(_endWeek),
        weekType: Value(_weekType),
        colorIndex: Value(_colorIndex),
        note: Value(_noteController.text.trim()),
        semesterId: Value(semester.id),
      ),
    );

    if (mounted) context.pop();
  }

  Future<void> _deleteCourse() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除课程'),
        content: const Text('确定要删除这门课程吗？此操作不可撤销。'),
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
      await ref.read(courseDaoProvider).deleteCourse(widget.courseId);
      if (mounted) context.pop();
    }
  }
}
