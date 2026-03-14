import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ddoge/features/schedule/views/schedule_page.dart';
import 'package:ddoge/features/today/views/today_page.dart';
import 'package:ddoge/features/course_editor/views/course_add_page.dart';
import 'package:ddoge/features/course_editor/views/course_edit_page.dart';
import 'package:ddoge/features/settings/views/settings_page.dart';
import 'package:ddoge/features/settings/views/time_slot_settings_page.dart';
import 'package:ddoge/features/settings/views/semester_settings_page.dart';
import 'package:ddoge/features/settings/views/background_settings_page.dart';
import 'package:ddoge/features/settings/views/personalization_settings_page.dart';
import 'package:ddoge/features/import/views/import_page.dart';
import 'package:ddoge/shared/widgets/glass_container.dart';
import 'package:ddoge/shared/widgets/background_layer.dart';

/// 路由路径常量
class AppRoutes {
  AppRoutes._();

  static const String schedule = '/';
  static const String today = '/today';
  static const String settings = '/settings';
  static const String courseAdd = '/course/add';
  static const String courseEdit = '/course/edit/:id';
  static const String timeSlotSettings = '/settings/time-slots';
  static const String semesterSettings = '/settings/semester';
  static const String backgroundSettings = '/settings/background';
  static const String uestcImport = '/import/uestc';
}

/// 底部导航壳页面的 Key，用于从外部控制导航切换
final shellNavigatorKey = GlobalKey<NavigatorState>();
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter 路由配置
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.schedule,
  routes: [
    // 底部导航栏的 Shell
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return _MainShellScreen(navigationShell: navigationShell);
      },
      branches: [
        // 课表 Tab
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.schedule,
              builder: (context, state) => const SchedulePage(),
            ),
          ],
        ),
        // 今日 Tab
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.today,
              builder: (context, state) => const TodayPage(),
            ),
          ],
        ),
        // 设置 Tab
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.settings,
              builder: (context, state) => const SettingsPage(),
              routes: [
                GoRoute(
                  path: 'time-slots',
                  builder: (context, state) => const TimeSlotSettingsPage(),
                ),
                GoRoute(
                  path: 'semester',
                  builder: (context, state) => const SemesterSettingsPage(),
                ),
                GoRoute(
                  path: 'background',
                  builder: (context, state) => const BackgroundSettingsPage(),
                ),
                GoRoute(
                  path: 'personalization',
                  builder: (context, state) => const PersonalizationSettingsPage(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    // 全屏页面（不显示底部导航，从底部滑入）
    GoRoute(
      path: AppRoutes.courseAdd,
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return CustomTransitionPage(
          child: CourseAddPage(
            initialDayOfWeek: extra?['dayOfWeek'] as int?,
            initialSlot: extra?['slot'] as int?,
            initialEndSlot: extra?['endSlot'] as int?,
          ),
          transitionsBuilder: _slideUpTransition,
        );
      },
    ),
    GoRoute(
      path: '/import/:system',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final systemName = state.pathParameters['system']!;
        final system = SchoolSystem.values.firstWhere(
          (e) => e.name.toLowerCase().contains(systemName.toLowerCase()),
          orElse: () => SchoolSystem.uestc,
        );
        return ImportPage(system: system);
      },
    ),
  ],
);

/// 从底部滑入的页面过渡动画
Widget _slideUpTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final offsetAnimation = Tween<Offset>(
    begin: const Offset(0, 0.15),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
  ));

  final fadeAnimation = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(CurvedAnimation(
    parent: animation,
    curve: const Interval(0.0, 0.6),
  ));

  return FadeTransition(
    opacity: fadeAnimation,
    child: SlideTransition(
      position: offsetAnimation,
      child: child,
    ),
  );
}

/// 自定义导航栏高度（Material 3 默认 80 偏高）
const kCustomNavBarHeight = 64.0;

/// 底部导航壳组件
class _MainShellScreen extends StatelessWidget {
  const _MainShellScreen({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // 使 body 延伸到 NavigationBar 下方
      body: Stack(
        children: [
          const BackgroundLayer(),
          navigationShell,
        ],
      ),
      bottomNavigationBar: GlassContainer(
        blur: 15.0,
        opacity: 0.5,
        child: SizedBox(
          height: kCustomNavBarHeight + MediaQuery.of(context).padding.bottom,
          child: NavigationBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.calendar_view_week_outlined),
                selectedIcon: Icon(Icons.calendar_view_week),
                label: '课表',
              ),
              NavigationDestination(
                icon: Icon(Icons.today_outlined),
                selectedIcon: Icon(Icons.today),
                label: '今日',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: '设置',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
