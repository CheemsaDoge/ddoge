import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ddoge/core/router/app_router.dart';
import 'package:ddoge/data/database/app_database.dart';
import 'package:ddoge/features/schedule/providers/database_providers.dart';
import 'package:ddoge/features/schedule/providers/schedule_providers.dart';

/// 节次时间设置页面
///
/// 支持统一设置课程时长批量生成，也支持逐个调整
class TimeSlotSettingsPage extends ConsumerStatefulWidget {
  const TimeSlotSettingsPage({super.key});

  @override
  ConsumerState<TimeSlotSettingsPage> createState() =>
      _TimeSlotSettingsPageState();
}

class _TimeSlotSettingsPageState extends ConsumerState<TimeSlotSettingsPage> {
  List<_EditableTimeSlot>? _editingSlots;
  bool _hasChanges = false;

  // 批量生成参数
  int _slotDuration = 45; // 单节课时长（分钟）
  int _breakDuration = 10; // 课间休息（分钟）
  int _lunchBreak = 120; // 午休时长（分钟）
  int _dinnerBreak = 80; // 晚餐休息（分钟）
  int _morningSlots = 4; // 上午节数
  int _afternoonSlots = 4; // 下午节数
  int _eveningSlots = 4; // 晚上节数
  TimeOfDay _firstSlotStart = const TimeOfDay(hour: 8, minute: 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeSlotsAsync = ref.watch(timeSlotsProvider);
    final semester = ref.watch(currentSemesterProvider).valueOrNull;

    if (semester == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('节次时间设置')),
        body: const Center(child: Text('请先创建学期')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('节次时间设置'),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: () => _saveAll(semester.id),
              child: const Text('保存'),
            ),
        ],
      ),
      body: timeSlotsAsync.when(
        data: (slots) {
          _editingSlots ??= slots
              .map(
                (s) => _EditableTimeSlot(
                  index: s.index,
                  startHour: s.startHour,
                  startMinute: s.startMinute,
                  endHour: s.endHour,
                  endMinute: s.endMinute,
                ),
              )
              .toList();

          return ListView(
            padding: EdgeInsets.only(
              bottom:
                  MediaQuery.of(context).padding.bottom +
                  kCustomNavBarHeight +
                  32,
            ),
            children: [
              // 批量生成区域
              _buildBatchGenerator(theme, semester.id),
              const Divider(height: 1),
              // 节次列表标题
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(
                      '节次详情',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addSlot,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('添加'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
              // 节次列表
              if (_editingSlots!.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('暂无节次，请使用上方批量生成')),
                )
              else
                ..._editingSlots!.asMap().entries.map(
                  (e) => _buildSlotTile(theme, e.key, e.value),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  /// 批量生成区域
  Widget _buildBatchGenerator(ThemeData theme, String semesterId) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '批量生成',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          // 第一行：课时长 + 课间
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  label: '单节课时长',
                  suffix: '分钟',
                  value: _slotDuration,
                  min: 20,
                  max: 120,
                  onChanged: (v) => setState(() => _slotDuration = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNumberField(
                  label: '课间休息',
                  suffix: '分钟',
                  value: _breakDuration,
                  min: 0,
                  max: 60,
                  onChanged: (v) => setState(() => _breakDuration = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 第二行：上午节数 + 下午节数 + 晚上节数
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  label: '上午',
                  suffix: '节',
                  value: _morningSlots,
                  min: 0,
                  max: 8,
                  onChanged: (v) => setState(() => _morningSlots = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberField(
                  label: '下午',
                  suffix: '节',
                  value: _afternoonSlots,
                  min: 0,
                  max: 8,
                  onChanged: (v) => setState(() => _afternoonSlots = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberField(
                  label: '晚上',
                  suffix: '节',
                  value: _eveningSlots,
                  min: 0,
                  max: 8,
                  onChanged: (v) => setState(() => _eveningSlots = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 第三行：午休 + 晚餐休息
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  label: '午休',
                  suffix: '分钟',
                  value: _lunchBreak,
                  min: 0,
                  max: 240,
                  onChanged: (v) => setState(() => _lunchBreak = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNumberField(
                  label: '晚餐休息',
                  suffix: '分钟',
                  value: _dinnerBreak,
                  min: 0,
                  max: 240,
                  onChanged: (v) => setState(() => _dinnerBreak = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 第一节课开始时间
          Row(
            children: [
              Text('第一节课开始', style: theme.textTheme.bodyMedium),
              const Spacer(),
              _TimeButton(
                label: '开始',
                hour: _firstSlotStart.hour,
                minute: _firstSlotStart.minute,
                onChanged: (h, m) => setState(() {
                  _firstSlotStart = TimeOfDay(hour: h, minute: m);
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _generateSlots,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('生成节次时间'),
            ),
          ),
          const SizedBox(height: 8),
          // 一键统一时长
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _editingSlots != null && _editingSlots!.isNotEmpty
                  ? _applyUniformDuration
                  : null,
              icon: const Icon(Icons.timer_outlined),
              label: Text('统一每节 $_slotDuration 分钟'),
            ),
          ),
        ],
      ),
    );
  }

  /// 数字调节控件
  Widget _buildNumberField({
    required String label,
    required String suffix,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '$value$suffix',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: value < max ? () => onChanged(value + 1) : null,
                child: Icon(
                  Icons.arrow_drop_up,
                  size: 20,
                  color: value < max ? null : theme.disabledColor,
                ),
              ),
              InkWell(
                onTap: value > min ? () => onChanged(value - 1) : null,
                child: Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: value > min ? null : theme.disabledColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 批量生成节次
  void _generateSlots() {
    final totalSlots = _morningSlots + _afternoonSlots + _eveningSlots;
    if (totalSlots == 0) return;

    final slots = <_EditableTimeSlot>[];
    int currentMinutes = _firstSlotStart.hour * 60 + _firstSlotStart.minute;
    int slotIndex = 1;

    // 上午
    for (int i = 0; i < _morningSlots; i++) {
      final startH = currentMinutes ~/ 60;
      final startM = currentMinutes % 60;
      currentMinutes += _slotDuration;
      final endH = currentMinutes ~/ 60;
      final endM = currentMinutes % 60;
      slots.add(
        _EditableTimeSlot(
          index: slotIndex++,
          startHour: startH,
          startMinute: startM,
          endHour: endH,
          endMinute: endM,
        ),
      );
      if (i < _morningSlots - 1) currentMinutes += _breakDuration;
    }

    // 午休
    if (_afternoonSlots > 0) currentMinutes += _lunchBreak;

    // 下午
    for (int i = 0; i < _afternoonSlots; i++) {
      final startH = currentMinutes ~/ 60;
      final startM = currentMinutes % 60;
      currentMinutes += _slotDuration;
      final endH = currentMinutes ~/ 60;
      final endM = currentMinutes % 60;
      slots.add(
        _EditableTimeSlot(
          index: slotIndex++,
          startHour: startH,
          startMinute: startM,
          endHour: endH,
          endMinute: endM,
        ),
      );
      if (i < _afternoonSlots - 1) currentMinutes += _breakDuration;
    }

    // 晚餐休息
    if (_eveningSlots > 0) currentMinutes += _dinnerBreak;

    // 晚上
    for (int i = 0; i < _eveningSlots; i++) {
      final startH = currentMinutes ~/ 60;
      final startM = currentMinutes % 60;
      currentMinutes += _slotDuration;
      final endH = currentMinutes ~/ 60;
      final endM = currentMinutes % 60;
      slots.add(
        _EditableTimeSlot(
          index: slotIndex++,
          startHour: startH,
          startMinute: startM,
          endHour: endH,
          endMinute: endM,
        ),
      );
      if (i < _eveningSlots - 1) currentMinutes += _breakDuration;
    }

    setState(() {
      _editingSlots = slots;
      _hasChanges = true;
    });
  }

  /// 一键统一时长：保持每节开始时间不变，只调整结束时间
  void _applyUniformDuration() {
    if (_editingSlots == null || _editingSlots!.isEmpty) return;

    setState(() {
      for (final slot in _editingSlots!) {
        final startMinutes = slot.startHour * 60 + slot.startMinute;
        final endMinutes = startMinutes + _slotDuration;
        slot.endHour = endMinutes ~/ 60;
        slot.endMinute = endMinutes % 60;
      }
      _hasChanges = true;
    });
  }

  /// 单个节次条目
  Widget _buildSlotTile(
    ThemeData theme,
    int listIndex,
    _EditableTimeSlot slot,
  ) {
    final duration =
        (slot.endHour * 60 + slot.endMinute) -
        (slot.startHour * 60 + slot.startMinute);

    return Dismissible(
      key: ValueKey('slot_${slot.index}_$listIndex'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      onDismissed: (_) {
        setState(() {
          _editingSlots!.removeAt(listIndex);
          _reindex();
          _hasChanges = true;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                '${slot.index}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _TimeButton(
              label: '开始',
              hour: slot.startHour,
              minute: slot.startMinute,
              onChanged: (h, m) => setState(() {
                slot.startHour = h;
                slot.startMinute = m;
                _hasChanges = true;
              }),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.arrow_forward,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            _TimeButton(
              label: '结束',
              hour: slot.endHour,
              minute: slot.endMinute,
              onChanged: (h, m) => setState(() {
                slot.endHour = h;
                slot.endMinute = m;
                _hasChanges = true;
              }),
            ),
            const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _editSlotDuration(slot),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$duration分钟',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editSlotDuration(_EditableTimeSlot slot) async {
    final currentDuration =
        (slot.endHour * 60 + slot.endMinute) -
        (slot.startHour * 60 + slot.startMinute);
    final controller = TextEditingController(text: '$currentDuration');

    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑课程时长'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '时长', suffixText: '分钟'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value <= 0 || value > 300) return;
              Navigator.pop(context, value);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (minutes == null) return;

    setState(() {
      final startMinutes = slot.startHour * 60 + slot.startMinute;
      final endMinutes = startMinutes + minutes;
      slot.endHour = endMinutes ~/ 60;
      slot.endMinute = endMinutes % 60;
      _hasChanges = true;
    });
  }

  void _reindex() {
    for (int i = 0; i < _editingSlots!.length; i++) {
      _editingSlots![i].index = i + 1;
    }
  }

  void _addSlot() {
    setState(() {
      final last = _editingSlots?.lastOrNull;
      final newIndex = (_editingSlots?.length ?? 0) + 1;
      _editingSlots ??= [];
      _editingSlots!.add(
        _EditableTimeSlot(
          index: newIndex,
          startHour: last != null ? last.endHour : 8,
          startMinute: last != null ? last.endMinute + 10 : 0,
          endHour: last != null ? last.endHour + 1 : 8,
          endMinute: last != null ? last.endMinute : 45,
        ),
      );
      _hasChanges = true;
    });
  }

  Future<void> _saveAll(String semesterId) async {
    if (_editingSlots == null) return;

    final dao = ref.read(timeSlotDaoProvider);
    await dao.deleteTimeSlotsForSemester(semesterId);
    for (final slot in _editingSlots!) {
      await dao.updateTimeSlot(
        TimeSlotsCompanion(
          index: Value(slot.index),
          startHour: Value(slot.startHour),
          startMinute: Value(slot.startMinute),
          endHour: Value(slot.endHour),
          endMinute: Value(slot.endMinute),
          semesterId: Value(semesterId),
        ),
      );
    }

    setState(() {
      _hasChanges = false;
      _editingSlots = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('节次时间已保存')));
    }
  }
}

class _EditableTimeSlot {
  int index;
  int startHour;
  int startMinute;
  int endHour;
  int endMinute;

  _EditableTimeSlot({
    required this.index,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.hour,
    required this.minute,
    required this.onChanged,
  });

  final String label;
  final int hour;
  final int minute;
  final void Function(int hour, int minute) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: minute),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
        if (time != null) onChanged(time.hour, time.minute);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: [const FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
