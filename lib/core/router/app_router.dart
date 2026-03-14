import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ddoge/features/schedule/views/schedule_page.dart';
import 'package:ddoge/features/schedule/providers/schedule_providers.dart';
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
                  builder: (context, state) =>
                      const PersonalizationSettingsPage(),
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
      path: '/course/edit/:id',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) {
        final courseId = state.pathParameters['id']!;
        return CustomTransitionPage(
          child: CourseEditPage(courseId: courseId),
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
          (e) => e.name.toLowerCase() == systemName.toLowerCase(),
          orElse: () => SchoolSystem.generic,
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
  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

  final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.6)),
  );

  return FadeTransition(
    opacity: fadeAnimation,
    child: SlideTransition(position: offsetAnimation, child: child),
  );
}

/// 自定义导航栏高度（Material 3 默认 80 偏高）
const kCustomNavBarHeight = 64.0;

/// 底部导航壳组件
class _MainShellScreen extends ConsumerStatefulWidget {
  const _MainShellScreen({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<_MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<_MainShellScreen> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // 非课表 Tab → 切回课表
        if (widget.navigationShell.currentIndex != 0) {
          widget.navigationShell.goBranch(0, initialLocation: true);
          return;
        }
        // 课表 Tab 有选中格子 → 优先取消选中
        if (ref.read(scheduleSelectionActiveProvider)) {
          ref.read(scheduleSelectionClearTriggerProvider.notifier).state++;
          return;
        }
        // 课表 Tab → 双击退出
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          Navigator.of(context).pop();
          return;
        }
        _lastBackPress = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('再按一次返回键退出'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
        extendBody: true, // 使 body 延伸到 NavigationBar 下方
        body: Stack(
          children: [const BackgroundLayer(), widget.navigationShell],
        ),
        bottomNavigationBar: GlassContainer(
          blur: 15.0,
          opacity: 0.5,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom,
            ),
            child: NavigationBar(
              height: kCustomNavBarHeight,
              elevation: 0,
              backgroundColor: Colors.transparent,
              selectedIndex: widget.navigationShell.currentIndex,
              onDestinationSelected: (index) {
                widget.navigationShell.goBranch(
                  index,
                  initialLocation: index == widget.navigationShell.currentIndex,
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
      ), // Scaffold
    ); // PopScope
  }
}
