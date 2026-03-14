import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:ddoge/app.dart';

void main() {
  testWidgets('应用启动冒烟测试', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: DDogeApp()),
    );
    // 只 pump 一帧验证不崩溃，不用 pumpAndSettle（有持续异步流）
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
