import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ddoge/app.dart';
import 'package:ddoge/features/schedule/providers/schedule_providers.dart';

void main() {
  testWidgets('应用启动冒烟测试', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const DDogeApp(),
      ),
    );
    // 只 pump 一帧验证不崩溃，不用 pumpAndSettle（有持续异步流）
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
