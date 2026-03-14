import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/services/notification_service.dart';
import 'data/services/widget_service.dart';
import 'features/schedule/providers/schedule_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // 初始化通知服务和桌面小组件
  await NotificationService.instance.init();
  await WidgetService.instance.init();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const DDogeApp(),
    ),
  );
}
