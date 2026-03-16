import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:ddoge/core/models/time_slot_template.dart';
import 'package:ddoge/data/database/app_database.dart';
import 'package:ddoge/features/schedule/providers/database_providers.dart';
import 'package:ddoge/features/schedule/providers/schedule_providers.dart';
import 'package:ddoge/features/settings/widgets/settings_subpage_scaffold.dart';

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
  List<TimeSlotTemplate> _templates = const [];
  String? _selectedTemplateId;
  bool _templateStateLoaded = false;
  String? _templateStateSemesterId;
  bool _hasChanges = false;

  // 批量生成参数
  int _slotDuration = 45; // 单节课时长（分钟）
  int _breakDuration = 10; // 课间休息（分钟）
  int _morningSlots = 4; // 上午节数
  int _afternoonSlots = 4; // 下午节数
  int _eveningSlots = 4; // 晚上节数
  TimeOfDay _morningFirstSlotStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _afternoonFirstSlotStart = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _eveningFirstSlotStart = const TimeOfDay(hour: 19, minute: 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeSlotsAsync = ref.watch(timeSlotsProvider);
    final semester = ref.watch(currentSemesterProvider).valueOrNull;

    if (semester == null) {
      return const SettingsSubpageScaffold(
        title: '节次时间设置',
        child: Center(child: Text('请先创建学期')),
      );
    }

    return SettingsSubpageScaffold(
      title: '节次时间设置',
      actions: [
        if (_hasChanges)
          TextButton(
            onPressed: () => _saveAll(semester.id),
            child: const Text('保存'),
          ),
      ],
      child: timeSlotsAsync.when(
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
          _ensureTemplateState(semester.id, slots);

          return ListView(
            padding: EdgeInsets.only(
              bottom: settingsSubpageBottomPadding(context, extra: 32),
            ),
            children: [
              _buildTemplateSection(theme),
              // 批量生成区域
              _buildBatchGenerator(theme),
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
  Widget _buildBatchGenerator(ThemeData theme) {
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
          Text(
            '各时段第一节开始时间',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          _buildSessionStartRow(
            theme,
            label: '上午第一节',
            time: _morningFirstSlotStart,
            onChanged: (time) => setState(() => _morningFirstSlotStart = time),
          ),
          const SizedBox(height: 8),
          _buildSessionStartRow(
            theme,
            label: '下午第一节',
            time: _afternoonFirstSlotStart,
            onChanged: (time) =>
                setState(() => _afternoonFirstSlotStart = time),
          ),
          const SizedBox(height: 8),
          _buildSessionStartRow(
            theme,
            label: '晚上第一节',
            time: _eveningFirstSlotStart,
            onChanged: (time) => setState(() => _eveningFirstSlotStart = time),
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

  Widget _buildTemplateSection(ThemeData theme) {
    final selectedTemplate = _selectedTemplate;
    final dropdownValue = _selectedTemplateValue;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '节次模板',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bookmarks_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: dropdownValue,
                      hint: const Text('从模板库中选择'),
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(12),
                      items: _templates
                          .map(
                            (template) => DropdownMenuItem<String>(
                              value: template.id,
                              child: Text(template.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedTemplateId = value;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: selectedTemplate == null
                      ? null
                      : () => _applySelectedTemplate(selectedTemplate),
                  icon: const Icon(Icons.file_download_done_outlined),
                  label: const Text('套用到本学期'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _editingSlots == null || _editingSlots!.isEmpty
                      ? null
                      : _saveCurrentAsTemplate,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('另存为模板'),
                ),
              ),
            ],
          ),
          if (selectedTemplate != null) ...[
            const SizedBox(height: 8),
            Text(
              selectedTemplate.isBuiltin
                  ? '当前模板：${selectedTemplate.name} · 内置'
                  : '当前模板：${selectedTemplate.name}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionStartRow(
    ThemeData theme, {
    required String label,
    required TimeOfDay time,
    required ValueChanged<TimeOfDay> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          _TimeButton(
            label: label,
            hour: time.hour,
            minute: time.minute,
            onChanged: (hour, minute) =>
                onChanged(TimeOfDay(hour: hour, minute: minute)),
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
    int slotIndex = 1;

    slotIndex = _appendSessionSlots(
      slots,
      slotIndex,
      _morningSlots,
      _morningFirstSlotStart,
    );
    slotIndex = _appendSessionSlots(
      slots,
      slotIndex,
      _afternoonSlots,
      _afternoonFirstSlotStart,
    );
    _appendSessionSlots(
      slots,
      slotIndex,
      _eveningSlots,
      _eveningFirstSlotStart,
    );

    _updateEditingState(() {
      _editingSlots = slots;
    });
  }

  int _appendSessionSlots(
    List<_EditableTimeSlot> slots,
    int startIndex,
    int slotCount,
    TimeOfDay firstSlotStart,
  ) {
    var currentMinutes = firstSlotStart.hour * 60 + firstSlotStart.minute;
    var slotIndex = startIndex;

    for (int i = 0; i < slotCount; i++) {
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
      if (i < slotCount - 1) {
        currentMinutes += _breakDuration;
      }
    }

    return slotIndex;
  }

  /// 一键统一时长：保持每节开始时间不变，只调整结束时间
  void _applyUniformDuration() {
    if (_editingSlots == null || _editingSlots!.isEmpty) return;

    _updateEditingState(() {
      for (final slot in _editingSlots!) {
        final startMinutes = slot.startHour * 60 + slot.startMinute;
        final endMinutes = startMinutes + _slotDuration;
        slot.endHour = endMinutes ~/ 60;
        slot.endMinute = endMinutes % 60;
      }
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
        _updateEditingState(() {
          _editingSlots!.removeAt(listIndex);
          _reindex();
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
              onChanged: (h, m) => _updateEditingState(() {
                slot.startHour = h;
                slot.startMinute = m;
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
              onChanged: (h, m) => _updateEditingState(() {
                slot.endHour = h;
                slot.endMinute = m;
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

    _updateEditingState(() {
      final startMinutes = slot.startHour * 60 + slot.startMinute;
      final endMinutes = startMinutes + minutes;
      slot.endHour = endMinutes ~/ 60;
      slot.endMinute = endMinutes % 60;
    });
  }

  void _reindex() {
    for (int i = 0; i < _editingSlots!.length; i++) {
      _editingSlots![i].index = i + 1;
    }
  }

  void _addSlot() {
    _updateEditingState(() {
      final last = _editingSlots?.lastOrNull;
      final newIndex = (_editingSlots?.length ?? 0) + 1;
      _editingSlots ??= [];
      final startMinutes = last == null
          ? (_morningFirstSlotStart.hour * 60 + _morningFirstSlotStart.minute)
          : (last.endHour * 60 + last.endMinute + _breakDuration);
      final endMinutes = startMinutes + _slotDuration;
      _editingSlots!.add(
        _EditableTimeSlot(
          index: newIndex,
          startHour: startMinutes ~/ 60,
          startMinute: startMinutes % 60,
          endHour: endMinutes ~/ 60,
          endMinute: endMinutes % 60,
        ),
      );
    });
  }

  Future<void> _saveAll(String semesterId) async {
    if (_editingSlots == null) return;
    final validationError = _validateEditingSlots();
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    final dao = ref.read(timeSlotDaoProvider);
    final settingsStorage = ref.read(settingsStorageProvider);
    final currentSlots = _currentEditableTemplateSlots();
    final matchedTemplateId =
        _selectedTemplateId ??
        findMatchingTimeSlotTemplateId(_templates, currentSlots);

    await dao.replaceTimeSlotsForSemester(semesterId, currentSlots);
    await settingsStorage.setSemesterTimeSlotTemplateId(
      semesterId,
      matchedTemplateId,
    );

    setState(() {
      _hasChanges = false;
      _editingSlots = null;
      _selectedTemplateId = matchedTemplateId;
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('节次时间已保存')));
    }
  }

  void _ensureTemplateState(String semesterId, List<TimeSlot> slots) {
    if (_templateStateLoaded && _templateStateSemesterId == semesterId) {
      return;
    }

    final settingsStorage = ref.read(settingsStorageProvider);
    final templates = settingsStorage.getTimeSlotTemplates();
    final currentSlots = timeSlotTemplateSlotsFromDatabase(slots);
    final boundTemplateId = settingsStorage.getSemesterTimeSlotTemplateId(
      semesterId,
    );

    _templates = templates;
    _selectedTemplateId =
        boundTemplateId ??
        findMatchingTimeSlotTemplateId(templates, currentSlots);
    _templateStateLoaded = true;
    _templateStateSemesterId = semesterId;
  }

  List<TimeSlotTemplateSlot> _currentEditableTemplateSlots() {
    final slots = _editingSlots ?? const <_EditableTimeSlot>[];
    return slots
        .map(
          (slot) => TimeSlotTemplateSlot(
            index: slot.index,
            startHour: slot.startHour,
            startMinute: slot.startMinute,
            endHour: slot.endHour,
            endMinute: slot.endMinute,
          ),
        )
        .toList()
      ..sort((left, right) => left.index.compareTo(right.index));
  }

  TimeSlotTemplate? get _selectedTemplate {
    if (_selectedTemplateId == null) {
      return null;
    }
    for (final template in _templates) {
      if (template.id == _selectedTemplateId) {
        return template;
      }
    }
    return null;
  }

  String? get _selectedTemplateValue {
    final selectedTemplateId = _selectedTemplateId;
    if (selectedTemplateId == null) {
      return null;
    }
    for (final template in _templates) {
      if (template.id == selectedTemplateId) {
        return selectedTemplateId;
      }
    }
    return null;
  }

  void _applySelectedTemplate(TimeSlotTemplate template) {
    _updateEditingState(() {
      _editingSlots = template.slots
          .map(
            (slot) => _EditableTimeSlot(
              index: slot.index,
              startHour: slot.startHour,
              startMinute: slot.startMinute,
              endHour: slot.endHour,
              endMinute: slot.endMinute,
            ),
          )
          .toList();
      _selectedTemplateId = template.id;
    }, keepSelectedTemplate: true);
  }

  Future<void> _saveCurrentAsTemplate() async {
    final currentSlots = _currentEditableTemplateSlots();
    if (currentSlots.isEmpty) {
      return;
    }

    final controller = TextEditingController(
      text: _selectedTemplate?.isBuiltin == true
          ? ''
          : _selectedTemplate?.name ?? '',
    );

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存为模板'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '模板名称',
            hintText: '如：电子科大 2026 春季',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isEmpty) {
                return;
              }
              Navigator.pop(context, trimmed);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (name == null || name.trim().isEmpty) {
      return;
    }

    final settingsStorage = ref.read(settingsStorageProvider);
    final templateId = _selectedTemplate?.isBuiltin == false
        ? _selectedTemplate!.id
        : const Uuid().v4();
    final template = TimeSlotTemplate(
      id: templateId,
      name: name.trim(),
      slots: currentSlots,
    );

    await settingsStorage.upsertTimeSlotTemplate(template);

    setState(() {
      _templates = settingsStorage.getTimeSlotTemplates();
      _selectedTemplateId = template.id;
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('模板“${template.name}”已保存')));
    }
  }

  void _updateEditingState(
    VoidCallback mutation, {
    bool keepSelectedTemplate = false,
  }) {
    setState(() {
      mutation();
      _hasChanges = true;
      if (!keepSelectedTemplate) {
        _selectedTemplateId = null;
      }
    });
  }

  String? _validateEditingSlots() {
    final slots = _editingSlots;
    if (slots == null || slots.isEmpty) {
      return '请先生成或添加至少一个节次';
    }

    for (final slot in slots) {
      final startMinutes = slot.startHour * 60 + slot.startMinute;
      final endMinutes = slot.endHour * 60 + slot.endMinute;
      if (endMinutes <= startMinutes) {
        return '第 ${slot.index} 节结束时间必须晚于开始时间';
      }
    }

    return null;
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
