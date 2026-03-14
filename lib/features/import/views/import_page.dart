import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:ddoge/features/import/parsers/uestc_eams_parser.dart';
import 'package:ddoge/features/schedule/providers/schedule_providers.dart';
import 'package:ddoge/features/schedule/providers/database_providers.dart';
import 'package:ddoge/data/database/app_database.dart';
import 'package:drift/drift.dart' as drift;

/// UESTC 教务系统导入页面
class UestcEamsImportPage extends ConsumerStatefulWidget {
  const UestcEamsImportPage({super.key});

  @override
  ConsumerState<UestcEamsImportPage> createState() => _UestcEamsImportPageState();
}

class _UestcEamsImportPageState extends ConsumerState<UestcEamsImportPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _canImport = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _canImport = false;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
              // 检查是否在课表页面
              if (url.contains('courseTableForStd!courseTable.action')) {
                _canImport = true;
              }
            });
          },
        ),
      )
      ..loadRequest(Uri.parse('https://eams.uestc.edu.cn/eams/courseTableForStd.action'));
  }

  Future<void> _startImport() async {
    final semesterAsync = ref.read(currentSemesterProvider);
    final semester = semesterAsync.valueOrNull;
    
    if (semester == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在设置中创建并选择一个学期')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 抓取页面 HTML
      final html = await _controller.runJavaScriptReturningResult(
        "document.documentElement.outerHTML"
      ) as String;
      
      // 注意：runJavaScriptReturningResult 返回的是 JSON 字符串，包含引号
      // 简单处理：如果是字符串类型，去掉首尾引号并处理转义
      String decodedHtml = html;
      if (html.startsWith('"') && html.endsWith('"')) {
        decodedHtml = html.substring(1, html.length - 1)
            .replaceAll(r'\"', '"')
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\r', '\r')
            .replaceAll(r'\t', '\t');
      }

      final parser = UestcEamsParser();
      final parsedCourses = parser.parse(decodedHtml, semester.id);

      if (parsedCourses.isEmpty) {
        throw Exception('未在页面中找到课程数据，请确保已点击“查询”并显示了课表');
      }

      // 保存到数据库
      final courseDao = ref.read(courseDaoProvider);
      
      // 为新导入的课程分配颜色索引
      int colorIdx = 0;
      final Set<String> courseNames = {};
      
      for (final c in parsedCourses) {
        if (!courseNames.contains(c.name)) {
          courseNames.add(c.name);
          colorIdx++;
        }
        
        await courseDao.upsertCourse(CoursesCompanion(
          id: drift.Value(c.id),
          name: drift.Value(c.name),
          teacher: drift.Value(c.teacher),
          classroom: drift.Value(c.classroom),
          dayOfWeek: drift.Value(c.dayOfWeek),
          startSlot: drift.Value(c.startSlot),
          endSlot: drift.Value(c.endSlot),
          startWeek: drift.Value(c.startWeek),
          endWeek: drift.Value(c.endWeek),
          weekType: drift.Value(c.weekType),
          colorIndex: drift.Value(courseNames.length % 10), // 简单轮询颜色
          semesterId: drift.Value(semester.id),
        ));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入 ${courseNames.length} 门课程')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入 UESTC 课表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          if (!_isLoading && !_canImport)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    '提示：请登录并进入“我的课表”页面，点击查询显示完整课表后，点击下方的“立即导入”按钮。',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _canImport
          ? FloatingActionButton.extended(
              onPressed: _startImport,
              icon: const Icon(Icons.download),
              label: const Text('立即导入'),
            )
          : null,
    );
  }
}
