import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/schedule/providers/schedule_providers.dart';

/// 应用根组件
class DDogeApp extends ConsumerWidget {
  const DDogeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp.router(
          title: 'DDoge 课程表',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(dynamicColorScheme: lightDynamic),
          darkTheme: AppTheme.dark(dynamicColorScheme: darkDynamic),
          themeMode: switch (themeMode) {
            1 => ThemeMode.light,
            2 => ThemeMode.dark,
            _ => ThemeMode.system,
          },
          routerConfig: appRouter,
        );
      },
    );
  }
}
