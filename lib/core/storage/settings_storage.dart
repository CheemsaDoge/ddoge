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
  static const _keyGridLineColorIndex = 'grid_line_color_index';
  static const _keyGridLineWidth = 'grid_line_width';
  static const _keyGridLineOpacity = 'grid_line_opacity';
  static const _keyGridLineDashed = 'grid_line_dashed';

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
}
