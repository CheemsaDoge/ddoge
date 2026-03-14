import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:ddoge/features/import/parsers/uestc_eams_parser.dart';
import 'package:ddoge/features/import/parsers/zhengfang_parser.dart';
import 'package:ddoge/features/import/parsers/qiangzhi_parser.dart';
import 'package:ddoge/features/import/parsers/urp_parser.dart';
import 'package:ddoge/features/schedule/providers/schedule_providers.dart';
import 'package:ddoge/features/schedule/providers/database_providers.dart';
import 'package:ddoge/data/database/app_database.dart';
import 'package:drift/drift.dart' as drift;

/// 教务系统类型
enum SchoolSystem {
  uestc(name: 'UESTC (EAMS)', url: 'https://eams.uestc.edu.cn/eams/courseTableForStd.action'),
  zhengfang(name: '正方教务系统', url: ''),
  qiangzhi(name: '强智教务系统', url: ''),
  urp(name: 'URP 教务系统', url: '');

  final String name;
  final String url;
  const SchoolSystem({required this.name, required this.url});
}

/// 通用教务系统导入页面
class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key, required this.system});

  final SchoolSystem system;

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
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
              // 自动检测是否在课表页面
              _checkCanImport(url);
            });
          },
        ),
      );
    
    if (widget.system.url.isNotEmpty) {
      _controller.loadRequest(Uri.parse(widget.system.url));
    }
  }

  void _checkCanImport(String url) {
    bool can = false;
    switch (widget.system) {
      case SchoolSystem.uestc:
        can = url.contains('courseTableForStd!courseTable.action');
        break;
      case SchoolSystem.zhengfang:
        can = url.contains('xskbcx') || url.contains('xsgrkbcx'); // 正方课表页面关键词
        break;
      case SchoolSystem.qiangzhi:
        can = url.contains('kbcx') || url.contains('KbSearch'); 
        break;
      case SchoolSystem.urp:
        can = url.contains('kb') || url.contains('courseTable');
        break;
    }
    setState(() => _canImport = can);
  }

  Future<void> _startImport() async {
    final semesterAsync = ref.read(currentSemesterProvider);
    final semester = semesterAsync.valueOrNull;
    
    if (semester == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先设置学期')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final html = await _controller.runJavaScriptReturningResult(
        "document.documentElement.outerHTML"
      ) as String;
      
      String decodedHtml = html;
      if (html.startsWith('"') && html.endsWith('"')) {
        decodedHtml = html.substring(1, html.length - 1)
            .replaceAll(r'\"', '"')
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\r', '\r')
            .replaceAll(r'\t', '\t');
      }

      List<Course> parsedCourses = [];
      switch (widget.system) {
        case SchoolSystem.uestc:
          parsedCourses = UestcEamsParser().parse(decodedHtml, semester.id);
          break;
        case SchoolSystem.zhengfang:
          parsedCourses = ZhengfangParser().parse(decodedHtml, semester.id);
          break;
        case SchoolSystem.qiangzhi:
          parsedCourses = QiangzhiParser().parse(decodedHtml, semester.id);
          break;
        case SchoolSystem.urp:
          parsedCourses = UrpParser().parse(decodedHtml, semester.id);
          break;
      }

      if (parsedCourses.isEmpty) {
        throw Exception('未找到课表数据，请确保已进入查询结果页面');
      }

      final courseDao = ref.read(courseDaoProvider);
      final Set<String> names = {};
      for (final c in parsedCourses) {
        if (!names.contains(c.name)) names.add(c.name);
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
          colorIndex: drift.Value(names.length % 10),
          semesterId: drift.Value(semester.id),
        ));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入成功：${names.length} 门课程')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
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
        title: Text('导入 ${widget.system.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (widget.system.url.isEmpty)
             _UrlInputView(onUrlSubmitted: (url) {
               _controller.loadRequest(Uri.parse(url));
             })
          else
            WebViewWidget(controller: _controller),
            
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
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

class _UrlInputView extends StatefulWidget {
  final Function(String) onUrlSubmitted;
  const _UrlInputView({required this.onUrlSubmitted});
  @override
  State<_UrlInputView> createState() => _UrlInputViewState();
}

class _UrlInputViewState extends State<_UrlInputView> {
  final _urlController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.link, size: 64, color: Colors.grey),
          const SizedBox(height: 24),
          const Text('请输入您的教务系统网址', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('请确保输入的网址可以直接访问登录页面', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 32),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              hintText: 'https://...',
              border: OutlineInputBorder(),
              labelText: '教务系统 URL',
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () => widget.onUrlSubmitted(_urlController.text),
              child: const Text('进入系统'),
            ),
          ),
        ],
      ),
    );
  }
}
