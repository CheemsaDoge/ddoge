// 课程卡片预设颜色
//
// 用于课程卡片的柔和色彩，每种颜色对应一个索引
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// 课程卡片预设颜色列表
  static const List<Color> courseColors = [
    Color(0xFF5C6BC0), // 靛蓝
    Color(0xFF26A69A), // 青绿
    Color(0xFFEF5350), // 珊瑚红
    Color(0xFFAB47BC), // 紫罗兰
    Color(0xFF42A5F5), // 天蓝
    Color(0xFFFFA726), // 橙黄
    Color(0xFF66BB6A), // 翠绿
    Color(0xFFEC407A), // 玫红
    Color(0xFF78909C), // 蓝灰
    Color(0xFF8D6E63), // 棕褐
    Color(0xFFD4E157), // 柠檬黄
    Color(0xFF29B6F6), // 浅蓝
    Color(0xFFFF7043), // 深橙
    Color(0xFF9CCC65), // 浅绿
    Color(0xFF7E57C2), // 深紫
    Color(0xFF26C6DA), // 青色
  ];

  /// 根据课程名称哈希值自动分配颜色
  static Color colorForCourse(String courseName) {
    final index = courseName.hashCode.abs() % courseColors.length;
    return courseColors[index];
  }
}
