import 'package:ddoge/core/constants/time_slots.dart';
import 'package:ddoge/data/database/app_database.dart';

class TimeSlotTemplateSlot {
  const TimeSlotTemplateSlot({
    required this.index,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  final int index;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  factory TimeSlotTemplateSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlotTemplateSlot(
      index: (json['index'] as num).toInt(),
      startHour: (json['startHour'] as num).toInt(),
      startMinute: (json['startMinute'] as num).toInt(),
      endHour: (json['endHour'] as num).toInt(),
      endMinute: (json['endMinute'] as num).toInt(),
    );
  }

  factory TimeSlotTemplateSlot.fromDatabase(TimeSlot slot) {
    return TimeSlotTemplateSlot(
      index: slot.index,
      startHour: slot.startHour,
      startMinute: slot.startMinute,
      endHour: slot.endHour,
      endMinute: slot.endMinute,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
    };
  }
}

class TimeSlotTemplate {
  const TimeSlotTemplate({
    required this.id,
    required this.name,
    required this.slots,
    this.isBuiltin = false,
    this.source,
  });

  static const defaultTemplateId = 'builtin.default_12_slots';
  static const uestcTemplateId = 'builtin.uestc_12_slots';

  final String id;
  final String name;
  final List<TimeSlotTemplateSlot> slots;
  final bool isBuiltin;
  final String? source;

  static final List<TimeSlotTemplate> builtInTemplates = [
    TimeSlotTemplate(
      id: defaultTemplateId,
      name: '标准 12 节',
      slots: _slotsFromDefaults(),
      isBuiltin: true,
    ),
    TimeSlotTemplate(
      id: uestcTemplateId,
      name: '电子科大 12 节',
      slots: _slotsFromDefaults(),
      isBuiltin: true,
      source: 'UESTC',
    ),
  ];

  factory TimeSlotTemplate.fromJson(Map<String, dynamic> json) {
    final slotsJson = json['slots'] as List<dynamic>? ?? const [];
    return TimeSlotTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      slots: slotsJson
          .map(
            (slot) =>
                TimeSlotTemplateSlot.fromJson(slot as Map<String, dynamic>),
          )
          .toList(),
      isBuiltin: json['isBuiltin'] as bool? ?? false,
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slots': slots.map((slot) => slot.toJson()).toList(),
      'isBuiltin': isBuiltin,
      'source': source,
    };
  }

  TimeSlotTemplate copyWith({
    String? id,
    String? name,
    List<TimeSlotTemplateSlot>? slots,
    bool? isBuiltin,
    String? source,
  }) {
    return TimeSlotTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      slots: slots ?? this.slots,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      source: source ?? this.source,
    );
  }

  static List<TimeSlotTemplateSlot> _slotsFromDefaults() {
    final defaults = TimeSlotConstants.defaultTimeSlots;
    return List.generate(
      defaults.length,
      (index) => TimeSlotTemplateSlot(
        index: index + 1,
        startHour: defaults[index].startHour,
        startMinute: defaults[index].startMinute,
        endHour: defaults[index].endHour,
        endMinute: defaults[index].endMinute,
      ),
    );
  }
}

List<TimeSlotTemplateSlot> timeSlotTemplateSlotsFromDatabase(
  Iterable<TimeSlot> slots,
) {
  final normalized = slots.map(TimeSlotTemplateSlot.fromDatabase).toList()
    ..sort((left, right) => left.index.compareTo(right.index));
  return normalized;
}

String? findMatchingTimeSlotTemplateId(
  Iterable<TimeSlotTemplate> templates,
  Iterable<TimeSlotTemplateSlot> slots,
) {
  final normalizedSlots = slots.toList()
    ..sort((left, right) => left.index.compareTo(right.index));

  for (final template in templates) {
    if (_slotsEqual(template.slots, normalizedSlots)) {
      return template.id;
    }
  }
  return null;
}

bool timeSlotTemplateSlotsEqual(
  Iterable<TimeSlotTemplateSlot> left,
  Iterable<TimeSlotTemplateSlot> right,
) {
  return _slotsEqual(left.toList(), right.toList());
}

bool _slotsEqual(
  List<TimeSlotTemplateSlot> left,
  List<TimeSlotTemplateSlot> right,
) {
  if (left.length != right.length) {
    return false;
  }

  final normalizedLeft = [...left]
    ..sort((first, second) => first.index.compareTo(second.index));
  final normalizedRight = [...right]
    ..sort((first, second) => first.index.compareTo(second.index));

  for (var index = 0; index < normalizedLeft.length; index++) {
    final leftSlot = normalizedLeft[index];
    final rightSlot = normalizedRight[index];
    if (leftSlot.index != rightSlot.index ||
        leftSlot.startHour != rightSlot.startHour ||
        leftSlot.startMinute != rightSlot.startMinute ||
        leftSlot.endHour != rightSlot.endHour ||
        leftSlot.endMinute != rightSlot.endMinute) {
      return false;
    }
  }

  return true;
}
