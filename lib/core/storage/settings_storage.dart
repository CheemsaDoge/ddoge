import 'dart:convert';

import 'package:ddoge/core/models/time_slot_template.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 背景类型枚举
enum BackgroundType {
  /// 无背景
  none,

  /// 内置渐变壁纸
  builtin,

  /// 本地自定义图片
  custom,
}

/// 应用设置持久化存储
///
/// 封装 SharedPreferences，提供类型安全的读写接口
class SettingsStorage {
  SettingsStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _keyBackgroundType = 'background_type';
  static const _keyBuiltinWallpaper = 'builtin_wallpaper';
  static const _keyCustomBackgroundPath = 'custom_background_path';
  static const _keyBackgroundOpacity = 'background_opacity';
  static const _keyReminderMinutes = 'reminder_minutes';
  static const _keyThemeMode = 'theme_mode';
  static const _keyAutoFitHeight = 'auto_fit_height';
  static const _keyFixedSlotHeight = 'fixed_slot_height';
  static const _keyCardBorderRadius = 'card_border_radius';
  static const _keyCardOpacity = 'card_opacity';
  static const _keyCardFontScale = 'card_font_scale';
  static const _keyShowGridLines = 'show_grid_lines';
  static const _keyShowTimeLine = 'show_time_line';
  static const _keyGridLineColorIndex = 'grid_line_color_index';
  static const _keyGridLineWidth = 'grid_line_width';
  static const _keyGridLineOpacity = 'grid_line_opacity';
  static const _keyGridLineDashed = 'grid_line_dashed';
  static const _keyTimeSlotTemplates = 'time_slot_templates';
  static const _keySemesterTimeSlotTemplateBindings =
      'semester_time_slot_template_bindings';

  // 背景类型
  BackgroundType getBackgroundType() {
    final index = _prefs.getInt(_keyBackgroundType) ?? 0;
    return BackgroundType.values[index.clamp(
      0,
      BackgroundType.values.length - 1,
    )];
  }

  Future<void> setBackgroundType(BackgroundType type) async {
    await _prefs.setInt(_keyBackgroundType, type.index);
  }

  // 内置壁纸索引
  int getBuiltinWallpaper() {
    return _prefs.getInt(_keyBuiltinWallpaper) ?? 0;
  }

  Future<void> setBuiltinWallpaper(int index) async {
    await _prefs.setInt(_keyBuiltinWallpaper, index);
  }

  // 自定义背景图片路径
  String? getCustomBackgroundPath() {
    return _prefs.getString(_keyCustomBackgroundPath);
  }

  Future<void> setCustomBackgroundPath(String? path) async {
    if (path == null) {
      await _prefs.remove(_keyCustomBackgroundPath);
    } else {
      await _prefs.setString(_keyCustomBackgroundPath, path);
    }
  }

  // 背景透明度（0.0~1.0）
  double getBackgroundOpacity() {
    return _prefs.getDouble(_keyBackgroundOpacity) ?? 0.3;
  }

  Future<void> setBackgroundOpacity(double opacity) async {
    await _prefs.setDouble(_keyBackgroundOpacity, opacity);
  }

  // 课前提醒分钟数（0=关闭）
  int getReminderMinutes() {
    return _prefs.getInt(_keyReminderMinutes) ?? 0;
  }

  Future<void> setReminderMinutes(int minutes) async {
    await _prefs.setInt(_keyReminderMinutes, minutes);
  }

  // 主题模式
  int getThemeMode() {
    return _prefs.getInt(_keyThemeMode) ?? 0;
  }

  Future<void> setThemeMode(int mode) async {
    await _prefs.setInt(_keyThemeMode, mode);
  }

  // 是否自适应一屏
  bool getAutoFitHeight() {
    return _prefs.getBool(_keyAutoFitHeight) ?? true;
  }

  Future<void> setAutoFitHeight(bool value) async {
    await _prefs.setBool(_keyAutoFitHeight, value);
  }

  // 固定模式格子高度
  double getFixedSlotHeight() {
    return _prefs.getDouble(_keyFixedSlotHeight) ?? 58.0;
  }

  Future<void> setFixedSlotHeight(double value) async {
    await _prefs.setDouble(_keyFixedSlotHeight, value);
  }

  // 卡片圆角
  double getCardBorderRadius() {
    return _prefs.getDouble(_keyCardBorderRadius) ?? 8.0;
  }

  Future<void> setCardBorderRadius(double value) async {
    await _prefs.setDouble(_keyCardBorderRadius, value);
  }

  // 卡片透明度
  double getCardOpacity() {
    return _prefs.getDouble(_keyCardOpacity) ?? 0.85;
  }

  Future<void> setCardOpacity(double value) async {
    await _prefs.setDouble(_keyCardOpacity, value);
  }

  // 卡片字体缩放
  double getCardFontScale() {
    return _prefs.getDouble(_keyCardFontScale) ?? 1.0;
  }

  Future<void> setCardFontScale(double value) async {
    await _prefs.setDouble(_keyCardFontScale, value);
  }

  // 显示网格线
  bool getShowGridLines() {
    return _prefs.getBool(_keyShowGridLines) ?? true;
  }

  Future<void> setShowGridLines(bool value) async {
    await _prefs.setBool(_keyShowGridLines, value);
  }

  // 显示当前时间线
  bool getShowTimeLine() {
    return _prefs.getBool(_keyShowTimeLine) ?? true;
  }

  Future<void> setShowTimeLine(bool value) async {
    await _prefs.setBool(_keyShowTimeLine, value);
  }

  // 网格线颜色
  int getGridLineColorIndex() {
    return _prefs.getInt(_keyGridLineColorIndex) ?? 0;
  }

  Future<void> setGridLineColorIndex(int index) async {
    await _prefs.setInt(_keyGridLineColorIndex, index);
  }

  // 网格线粗细
  double getGridLineWidth() {
    return _prefs.getDouble(_keyGridLineWidth) ?? 0.5;
  }

  Future<void> setGridLineWidth(double width) async {
    await _prefs.setDouble(_keyGridLineWidth, width);
  }

  // 网格线透明度
  double getGridLineOpacity() {
    return _prefs.getDouble(_keyGridLineOpacity) ?? 0.3;
  }

  Future<void> setGridLineOpacity(double opacity) async {
    await _prefs.setDouble(_keyGridLineOpacity, opacity);
  }

  // 网格线样式
  bool getGridLineDashed() {
    return _prefs.getBool(_keyGridLineDashed) ?? false;
  }

  Future<void> setGridLineDashed(bool dashed) async {
    await _prefs.setBool(_keyGridLineDashed, dashed);
  }

  List<TimeSlotTemplate> getTimeSlotTemplates() {
    final templates = <String, TimeSlotTemplate>{
      for (final template in TimeSlotTemplate.builtInTemplates)
        template.id: template,
    };
    for (final template in getCustomTimeSlotTemplates()) {
      templates[template.id] = template.copyWith(isBuiltin: false);
    }
    return templates.values.toList();
  }

  List<TimeSlotTemplate> getCustomTimeSlotTemplates() {
    final rawJson = _prefs.getString(_keyTimeSlotTemplates);
    if (rawJson == null || rawJson.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawJson) as List<dynamic>;
      return decoded.map((item) {
        final template = TimeSlotTemplate.fromJson(
          item as Map<String, dynamic>,
        );
        return template.copyWith(isBuiltin: false);
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  TimeSlotTemplate? getTimeSlotTemplateById(String templateId) {
    for (final template in getTimeSlotTemplates()) {
      if (template.id == templateId) {
        return template;
      }
    }
    return null;
  }

  Future<void> upsertTimeSlotTemplate(TimeSlotTemplate template) async {
    if (template.isBuiltin) {
      return;
    }

    final templates = getCustomTimeSlotTemplates();
    final normalizedTemplate = template.copyWith(isBuiltin: false);
    final existingIndex = templates.indexWhere(
      (current) => current.id == normalizedTemplate.id,
    );
    if (existingIndex >= 0) {
      templates[existingIndex] = normalizedTemplate;
    } else {
      templates.add(normalizedTemplate);
    }

    await _prefs.setString(
      _keyTimeSlotTemplates,
      jsonEncode(templates.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> deleteTimeSlotTemplate(String templateId) async {
    if (templateId.startsWith('builtin.')) {
      return;
    }

    final templates = getCustomTimeSlotTemplates()
      ..removeWhere((template) => template.id == templateId);
    await _prefs.setString(
      _keyTimeSlotTemplates,
      jsonEncode(templates.map((item) => item.toJson()).toList()),
    );

    final bindings = getSemesterTimeSlotTemplateBindings();
    bindings.removeWhere((_, value) => value == templateId);
    await _prefs.setString(
      _keySemesterTimeSlotTemplateBindings,
      jsonEncode(bindings),
    );
  }

  Map<String, String> getSemesterTimeSlotTemplateBindings() {
    final rawJson = _prefs.getString(_keySemesterTimeSlotTemplateBindings);
    if (rawJson == null || rawJson.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return {};
    }
  }

  String? getSemesterTimeSlotTemplateId(String semesterId) {
    final bindings = getSemesterTimeSlotTemplateBindings();
    final templateId = bindings[semesterId];
    if (templateId == null) {
      return null;
    }
    return getTimeSlotTemplateById(templateId) == null ? null : templateId;
  }

  Future<void> setSemesterTimeSlotTemplateId(
    String semesterId,
    String? templateId,
  ) async {
    final bindings = getSemesterTimeSlotTemplateBindings();
    if (templateId == null || templateId.isEmpty) {
      bindings.remove(semesterId);
    } else {
      bindings[semesterId] = templateId;
    }
    await _prefs.setString(
      _keySemesterTimeSlotTemplateBindings,
      jsonEncode(bindings),
    );
  }
}
