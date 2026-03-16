import 'package:flutter/material.dart';

import 'package:ddoge/core/router/app_router.dart';
import 'package:ddoge/shared/widgets/background_layer.dart';
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
    final theme = Theme.of(context);
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    final scrimTop = theme.colorScheme.surface.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.74 : 0.62,
    );
    final scrimBottom = theme.colorScheme.surfaceContainerLow.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.82 : 0.72,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(title),
        actions: actions,
        leading: leading,
      ),
      body: Stack(
        children: [
          const BackgroundLayer(),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [scrimTop, scrimBottom],
                ),
              ),
            ),
          ),
          Column(
            children: [
              SizedBox(height: topInset),
              Expanded(child: child),
            ],
          ),
        ],
      ),
    );
  }
}

double settingsSubpageBottomPadding(BuildContext context, {double extra = 16}) {
  return MediaQuery.of(context).padding.bottom + kCustomNavBarHeight + extra;
}
