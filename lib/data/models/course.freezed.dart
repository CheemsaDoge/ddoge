// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'course.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Course _$CourseFromJson(Map<String, dynamic> json) {
  return _Course.fromJson(json);
}

/// @nodoc
mixin _$Course {
  /// 唯一标识
  String get id => throw _privateConstructorUsedError;

  /// 课程名称
  String get name => throw _privateConstructorUsedError;

  /// 授课教师
  String get teacher => throw _privateConstructorUsedError;

  /// 上课教室
  String get classroom => throw _privateConstructorUsedError;

  /// 星期几（1=周一, 7=周日）
  int get dayOfWeek => throw _privateConstructorUsedError;

  /// 开始节次（从1开始）
  int get startSlot => throw _privateConstructorUsedError;

  /// 结束节次（包含）
  int get endSlot => throw _privateConstructorUsedError;

  /// 起始周
  int get startWeek => throw _privateConstructorUsedError;

  /// 结束周（包含）
  int get endWeek => throw _privateConstructorUsedError;

  /// 单双周类型
  WeekType get weekType => throw _privateConstructorUsedError;

  /// 课程卡片颜色索引
  int get colorIndex => throw _privateConstructorUsedError;

  /// 备注
  String get note => throw _privateConstructorUsedError;

  /// 所属学期 ID
  String get semesterId => throw _privateConstructorUsedError;

  /// Serializes this Course to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Course
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CourseCopyWith<Course> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CourseCopyWith<$Res> {
  factory $CourseCopyWith(Course value, $Res Function(Course) then) =
      _$CourseCopyWithImpl<$Res, Course>;
  @useResult
  $Res call({
    String id,
    String name,
    String teacher,
    String classroom,
    int dayOfWeek,
    int startSlot,
    int endSlot,
    int startWeek,
    int endWeek,
    WeekType weekType,
    int colorIndex,
    String note,
    String semesterId,
  });
}

/// @nodoc
class _$CourseCopyWithImpl<$Res, $Val extends Course>
    implements $CourseCopyWith<$Res> {
  _$CourseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Course
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? teacher = null,
    Object? classroom = null,
    Object? dayOfWeek = null,
    Object? startSlot = null,
    Object? endSlot = null,
    Object? startWeek = null,
    Object? endWeek = null,
    Object? weekType = null,
    Object? colorIndex = null,
    Object? note = null,
    Object? semesterId = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            teacher: null == teacher
                ? _value.teacher
                : teacher // ignore: cast_nullable_to_non_nullable
                      as String,
            classroom: null == classroom
                ? _value.classroom
                : classroom // ignore: cast_nullable_to_non_nullable
                      as String,
            dayOfWeek: null == dayOfWeek
                ? _value.dayOfWeek
                : dayOfWeek // ignore: cast_nullable_to_non_nullable
                      as int,
            startSlot: null == startSlot
                ? _value.startSlot
                : startSlot // ignore: cast_nullable_to_non_nullable
                      as int,
            endSlot: null == endSlot
                ? _value.endSlot
                : endSlot // ignore: cast_nullable_to_non_nullable
                      as int,
            startWeek: null == startWeek
                ? _value.startWeek
                : startWeek // ignore: cast_nullable_to_non_nullable
                      as int,
            endWeek: null == endWeek
                ? _value.endWeek
                : endWeek // ignore: cast_nullable_to_non_nullable
                      as int,
            weekType: null == weekType
                ? _value.weekType
                : weekType // ignore: cast_nullable_to_non_nullable
                      as WeekType,
            colorIndex: null == colorIndex
                ? _value.colorIndex
                : colorIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            note: null == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String,
            semesterId: null == semesterId
                ? _value.semesterId
                : semesterId // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CourseImplCopyWith<$Res> implements $CourseCopyWith<$Res> {
  factory _$$CourseImplCopyWith(
    _$CourseImpl value,
    $Res Function(_$CourseImpl) then,
  ) = __$$CourseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String teacher,
    String classroom,
    int dayOfWeek,
    int startSlot,
    int endSlot,
    int startWeek,
    int endWeek,
    WeekType weekType,
    int colorIndex,
    String note,
    String semesterId,
  });
}

/// @nodoc
class __$$CourseImplCopyWithImpl<$Res>
    extends _$CourseCopyWithImpl<$Res, _$CourseImpl>
    implements _$$CourseImplCopyWith<$Res> {
  __$$CourseImplCopyWithImpl(
    _$CourseImpl _value,
    $Res Function(_$CourseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Course
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? teacher = null,
    Object? classroom = null,
    Object? dayOfWeek = null,
    Object? startSlot = null,
    Object? endSlot = null,
    Object? startWeek = null,
    Object? endWeek = null,
    Object? weekType = null,
    Object? colorIndex = null,
    Object? note = null,
    Object? semesterId = null,
  }) {
    return _then(
      _$CourseImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        teacher: null == teacher
            ? _value.teacher
            : teacher // ignore: cast_nullable_to_non_nullable
                  as String,
        classroom: null == classroom
            ? _value.classroom
            : classroom // ignore: cast_nullable_to_non_nullable
                  as String,
        dayOfWeek: null == dayOfWeek
            ? _value.dayOfWeek
            : dayOfWeek // ignore: cast_nullable_to_non_nullable
                  as int,
        startSlot: null == startSlot
            ? _value.startSlot
            : startSlot // ignore: cast_nullable_to_non_nullable
                  as int,
        endSlot: null == endSlot
            ? _value.endSlot
            : endSlot // ignore: cast_nullable_to_non_nullable
                  as int,
        startWeek: null == startWeek
            ? _value.startWeek
            : startWeek // ignore: cast_nullable_to_non_nullable
                  as int,
        endWeek: null == endWeek
            ? _value.endWeek
            : endWeek // ignore: cast_nullable_to_non_nullable
                  as int,
        weekType: null == weekType
            ? _value.weekType
            : weekType // ignore: cast_nullable_to_non_nullable
                  as WeekType,
        colorIndex: null == colorIndex
            ? _value.colorIndex
            : colorIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        note: null == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String,
        semesterId: null == semesterId
            ? _value.semesterId
            : semesterId // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CourseImpl implements _Course {
  const _$CourseImpl({
    required this.id,
    required this.name,
    this.teacher = '',
    this.classroom = '',
    required this.dayOfWeek,
    required this.startSlot,
    required this.endSlot,
    required this.startWeek,
    required this.endWeek,
    this.weekType = WeekType.all,
    this.colorIndex = 0,
    this.note = '',
    required this.semesterId,
  });

  factory _$CourseImpl.fromJson(Map<String, dynamic> json) =>
      _$$CourseImplFromJson(json);

  /// 唯一标识
  @override
  final String id;

  /// 课程名称
  @override
  final String name;

  /// 授课教师
  @override
  @JsonKey()
  final String teacher;

  /// 上课教室
  @override
  @JsonKey()
  final String classroom;

  /// 星期几（1=周一, 7=周日）
  @override
  final int dayOfWeek;

  /// 开始节次（从1开始）
  @override
  final int startSlot;

  /// 结束节次（包含）
  @override
  final int endSlot;

  /// 起始周
  @override
  final int startWeek;

  /// 结束周（包含）
  @override
  final int endWeek;

  /// 单双周类型
  @override
  @JsonKey()
  final WeekType weekType;

  /// 课程卡片颜色索引
  @override
  @JsonKey()
  final int colorIndex;

  /// 备注
  @override
  @JsonKey()
  final String note;

  /// 所属学期 ID
  @override
  final String semesterId;

  @override
  String toString() {
    return 'Course(id: $id, name: $name, teacher: $teacher, classroom: $classroom, dayOfWeek: $dayOfWeek, startSlot: $startSlot, endSlot: $endSlot, startWeek: $startWeek, endWeek: $endWeek, weekType: $weekType, colorIndex: $colorIndex, note: $note, semesterId: $semesterId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CourseImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.teacher, teacher) || other.teacher == teacher) &&
            (identical(other.classroom, classroom) ||
                other.classroom == classroom) &&
            (identical(other.dayOfWeek, dayOfWeek) ||
                other.dayOfWeek == dayOfWeek) &&
            (identical(other.startSlot, startSlot) ||
                other.startSlot == startSlot) &&
            (identical(other.endSlot, endSlot) || other.endSlot == endSlot) &&
            (identical(other.startWeek, startWeek) ||
                other.startWeek == startWeek) &&
            (identical(other.endWeek, endWeek) || other.endWeek == endWeek) &&
            (identical(other.weekType, weekType) ||
                other.weekType == weekType) &&
            (identical(other.colorIndex, colorIndex) ||
                other.colorIndex == colorIndex) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.semesterId, semesterId) ||
                other.semesterId == semesterId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    teacher,
    classroom,
    dayOfWeek,
    startSlot,
    endSlot,
    startWeek,
    endWeek,
    weekType,
    colorIndex,
    note,
    semesterId,
  );

  /// Create a copy of Course
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CourseImplCopyWith<_$CourseImpl> get copyWith =>
      __$$CourseImplCopyWithImpl<_$CourseImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CourseImplToJson(this);
  }
}

abstract class _Course implements Course {
  const factory _Course({
    required final String id,
    required final String name,
    final String teacher,
    final String classroom,
    required final int dayOfWeek,
    required final int startSlot,
    required final int endSlot,
    required final int startWeek,
    required final int endWeek,
    final WeekType weekType,
    final int colorIndex,
    final String note,
    required final String semesterId,
  }) = _$CourseImpl;

  factory _Course.fromJson(Map<String, dynamic> json) = _$CourseImpl.fromJson;

  /// 唯一标识
  @override
  String get id;

  /// 课程名称
  @override
  String get name;

  /// 授课教师
  @override
  String get teacher;

  /// 上课教室
  @override
  String get classroom;

  /// 星期几（1=周一, 7=周日）
  @override
  int get dayOfWeek;

  /// 开始节次（从1开始）
  @override
  int get startSlot;

  /// 结束节次（包含）
  @override
  int get endSlot;

  /// 起始周
  @override
  int get startWeek;

  /// 结束周（包含）
  @override
  int get endWeek;

  /// 单双周类型
  @override
  WeekType get weekType;

  /// 课程卡片颜色索引
  @override
  int get colorIndex;

  /// 备注
  @override
  String get note;

  /// 所属学期 ID
  @override
  String get semesterId;

  /// Create a copy of Course
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CourseImplCopyWith<_$CourseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
