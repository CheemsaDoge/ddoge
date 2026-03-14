import 'package:flutter/material.dart';

/// 周数选择器组件
///
/// 横向滚动的周数选择列表，选中周变化时自动平滑滚动到对应位置
class WeekSelector extends StatefulWidget {
  const WeekSelector({
    super.key,
    required this.totalWeeks,
    required this.selectedWeek,
    required this.currentWeek,
    required this.onWeekSelected,
  });

  /// 总周数
  final int totalWeeks;

  /// 当前选中的周
  final int selectedWeek;

  /// 实际当前周（用于高亮）
  final int currentWeek;

  /// 选择周的回调
  final ValueChanged<int> onWeekSelected;

  @override
  State<WeekSelector> createState() => _WeekSelectorState();
}

class _WeekSelectorState extends State<WeekSelector> {
  late ScrollController _scrollController;

  static const double _itemWidth = 64.0;
  static const double _horizontalPadding = 8.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: _scrollOffsetFor(widget.selectedWeek),
    );
  }

  @override
  void didUpdateWidget(WeekSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedWeek != widget.selectedWeek &&
        _scrollController.hasClients) {
      final targetOffset = _scrollOffsetFor(widget.selectedWeek);
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _scrollOffsetFor(int week) {
    // 将选中项滚动到视口左侧偏移一点的位置
    return ((week - 1) * _itemWidth).clamp(0.0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 44,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
        itemCount: widget.totalWeeks,
        itemBuilder: (context, index) {
          final week = index + 1;
          final isSelected = week == widget.selectedWeek;
          final isCurrent = week == widget.currentWeek;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            child: Material(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => widget.onWeekSelected(week),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: isCurrent && !isSelected
                      ? BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.5),
                          ),
                          borderRadius: BorderRadius.circular(16),
                        )
                      : null,
                  child: Text(
                    '第$week周',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : isCurrent
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                      fontWeight: isSelected || isCurrent
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
