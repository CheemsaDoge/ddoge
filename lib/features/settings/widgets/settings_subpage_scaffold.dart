import 'package:flutter/material.dart';

import 'package:ddoge/core/router/app_router.dart';
import 'package:ddoge/shared/widgets/glass_container.dart';

/// 设置二级页统一壳层。
class SettingsSubpageScaffold extends StatelessWidget {
  const SettingsSubpageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.leading,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(title),
        actions: actions,
        leading: leading,
      ),
      body: Column(
        children: [
          SizedBox(height: topInset),
          Expanded(child: child),
        ],
      ),
    );
  }
}

double settingsSubpageBottomPadding(BuildContext context, {double extra = 16}) {
  return MediaQuery.of(context).padding.bottom + kCustomNavBarHeight + extra;
}
