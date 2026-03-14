// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CourseImpl _$$CourseImplFromJson(Map<String, dynamic> json) => _$CourseImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  teacher: json['teacher'] as String? ?? '',
  classroom: json['classroom'] as String? ?? '',
  dayOfWeek: (json['dayOfWeek'] as num).toInt(),
  startSlot: (json['startSlot'] as num).toInt(),
  endSlot: (json['endSlot'] as num).toInt(),
  startWeek: (json['startWeek'] as num).toInt(),
  endWeek: (json['endWeek'] as num).toInt(),
  weekType:
      $enumDecodeNullable(_$WeekTypeEnumMap, json['weekType']) ?? WeekType.all,
  colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
  note: json['note'] as String? ?? '',
  semesterId: json['semesterId'] as String,
);

Map<String, dynamic> _$$CourseImplToJson(_$CourseImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'teacher': instance.teacher,
      'classroom': instance.classroom,
      'dayOfWeek': instance.dayOfWeek,
      'startSlot': instance.startSlot,
      'endSlot': instance.endSlot,
      'startWeek': instance.startWeek,
      'endWeek': instance.endWeek,
      'weekType': _$WeekTypeEnumMap[instance.weekType]!,
      'colorIndex': instance.colorIndex,
      'note': instance.note,
      'semesterId': instance.semesterId,
    };

const _$WeekTypeEnumMap = {
  WeekType.all: 'all',
  WeekType.odd: 'odd',
  WeekType.even: 'even',
};
