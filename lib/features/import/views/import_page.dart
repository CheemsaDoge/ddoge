import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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
  uestc(name: 'UESTC (EAMS)', url: 'https://eams.uestc.edu.cn/eams/'),
  zhengfang(name: '正方教务系统', url: ''),
  qiangzhi(name: '强智教务系统', url: ''),
  urp(name: 'URP 教务系统', url: '');

  final String name;
  final String url;
  const SchoolSystem({required this.name, required this.url});
}

/// UESTC WebView 导航状态机
enum _UestcState {
  loading,
  casLogin,
  eamsHome,
  courseTablePage,
  extractingData,
  done,
}

/// 通用教务系统导入页面
class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key, required this.system});

  final SchoolSystem system;

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  bool _isImporting = false;

  // URL 已提交（用于非 UESTC 系统）
  bool _urlSubmitted = false;

  // UESTC 专用状态
  _UestcState _uestcState = _UestcState.loading;
  String _uestcStatusText = '';
  String? _uestcJsonResult;

  @override
  Widget build(BuildContext context) {
    final isUestc = widget.system == SchoolSystem.uestc;
    final showWebView = widget.system.url.isNotEmpty || _urlSubmitted;

    return Scaffold(
      appBar: AppBar(
        title: Text('导入 ${widget.system.name}'),
        actions: [
          if (showWebView)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller?.reload(),
            ),
        ],
      ),
      body: Column(
        children: [
          // UESTC 进度状态条
          if (isUestc && _uestcStatusText.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: _uestcState == _UestcState.done
                  ? Colors.green.shade50
                  : Colors.blue.shade50,
              child: Row(
                children: [
                  if (_uestcState != _UestcState.done &&
                      _uestcState != _UestcState.casLogin)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  if (_uestcState == _UestcState.done)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child:
                          Icon(Icons.check_circle, size: 18, color: Colors.green),
                    ),
                  Expanded(
                    child: Text(
                      _uestcStatusText,
                      style: TextStyle(
                        fontSize: 13,
                        color: _uestcState == _UestcState.done
                            ? Colors.green.shade800
                            : Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // 提示条（非 UESTC 系统）
          if (!isUestc && showWebView)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '请登录后导航到课表查询页面，然后点击下方「导入当前页面」按钮',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
          // WebView
          Expanded(
            child: !showWebView
                ? _UrlInputView(onUrlSubmitted: (url) {
                    setState(() => _urlSubmitted = true);
                    // WebView will be created with this URL
                    _pendingUrl = url;
                  })
                : Stack(
                    children: [
                      InAppWebView(
                        initialUrlRequest: URLRequest(
                          url: WebUri(
                            _pendingUrl ?? widget.system.url,
                          ),
                        ),
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          cacheMode: CacheMode.LOAD_DEFAULT,
                          domStorageEnabled: true,
                          databaseEnabled: true,
                          useOnLoadResource: false,
                          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                          allowContentAccess: true,
                          allowFileAccess: true,
                          userAgent:
                              'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                        ),
                        onWebViewCreated: (controller) {
                          _controller = controller;
                        },
                        onLoadStart: (controller, url) {
                          setState(() => _isLoading = true);
                        },
                        onLoadStop: (controller, url) {
                          setState(() => _isLoading = false);
                          if (url != null) {
                            final urlStr = url.toString();
                            if (widget.system == SchoolSystem.uestc) {
                              _handleUestcNavigation(urlStr);
                            }
                          }
                        },
                        onReceivedError: (controller, request, error) {
                          setState(() => _isLoading = false);
                        },
                      ),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
          ),
        ],
      ),
      // FAB 始终显示（UESTC 在自动提取完成后、其他系统始终可点击）
      floatingActionButton: showWebView && !_isImporting
          ? FloatingActionButton.extended(
              onPressed: _startImport,
              icon: const Icon(Icons.download),
              label: Text(
                isUestc && _uestcState == _UestcState.done
                    ? '导入已提取数据'
                    : '导入当前页面',
              ),
            )
          : null,
    );
  }

  String? _pendingUrl;

  // ─── UESTC state machine ───

  void _handleUestcNavigation(String url) {
    final lowerUrl = url.toLowerCase();

    if (lowerUrl.contains('idas.uestc.edu.cn')) {
      setState(() {
        _uestcState = _UestcState.casLogin;
        _uestcStatusText = '请在页面中登录统一身份认证';
      });
      return;
    }

    if (lowerUrl.contains('/eams/home') ||
        RegExp(r'/eams/?$').hasMatch(lowerUrl) ||
        RegExp(r'/eams/\?ticket=').hasMatch(lowerUrl)) {
      setState(() {
        _uestcState = _UestcState.eamsHome;
        _uestcStatusText = '登录成功，正在跳转课表页...';
      });
      _uestcInjectNavigation();
      return;
    }

    if (lowerUrl.contains('coursetableforstd.action') &&
        !lowerUrl.contains('!coursetable')) {
      setState(() {
        _uestcState = _UestcState.courseTablePage;
        _uestcStatusText = '正在提取课表数据...';
      });
      _uestcExtractData();
      return;
    }
  }

  Future<void> _uestcInjectNavigation() async {
    await _controller?.evaluateJavascript(
      source: "document.location = '/eams/courseTableForStd.action';",
    );
  }

  Future<void> _uestcExtractData() async {
    setState(() {
      _uestcState = _UestcState.extractingData;
      _uestcStatusText = '正在查询课表...';
    });

    try {
      final result = await _controller?.evaluateJavascript(source: '''
(function() {
  var idsMatch = document.body.innerHTML.match(/bg\\.form\\.addInput\\(form,"ids","(\\d+)"/);
  if (!idsMatch) return JSON.stringify({error: 'ids not found'});
  var ids = idsMatch[1];

  var semMatch = document.cookie.match(/semester\\.id=(\\d+)/);
  var semId = semMatch ? semMatch[1] : '';

  var xhr = new XMLHttpRequest();
  xhr.open('POST', '/eams/courseTableForStd!courseTable.action', false);
  xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
  xhr.send('ignoreHead=1&setting.kind=std&startWeek=&project.id=1&semester.id=' + semId + '&ids=' + ids);

  if (xhr.status !== 200) return JSON.stringify({error: 'HTTP ' + xhr.status});

  var html = xhr.responseText;
  var results = [];
  var currentActivity = null;
  var lines = html.split('\\n');

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    var actMatch = /new TaskActivity\\("([^"]*)","([^"]*)","([^"]*)","([^"]*)","([^"]*)","([^"]*)","([^"]*)"\\)/.exec(line);
    if (actMatch) {
      currentActivity = {
        teacherName: actMatch[2],
        courseFullName: actMatch[4],
        roomName: actMatch[6],
        weekBitmap: actMatch[7],
        indices: []
      };
      results.push(currentActivity);
    }
    var idxMatch = /index\\s*=\\s*(\\d+)\\s*\\*\\s*unitCount\\s*\\+\\s*(\\d+)/.exec(line);
    if (idxMatch && currentActivity) {
      currentActivity.indices.push({day: parseInt(idxMatch[1]), slot: parseInt(idxMatch[2])});
    }
  }
  return JSON.stringify({courses: results, semesterId: semId});
})()
''');

      if (result == null) {
        setState(() {
          _uestcStatusText = '提取失败: JavaScript 返回 null';
          _uestcState = _UestcState.courseTablePage;
        });
        return;
      }

      String jsonStr = result.toString();

      setState(() {
        _uestcState = _UestcState.done;
        _uestcStatusText = '数据提取完成，请点击导入';
      });

      _uestcJsonResult = jsonStr;
    } catch (e) {
      setState(() {
        _uestcStatusText = '提取失败: $e';
        _uestcState = _UestcState.courseTablePage;
      });
    }
  }

  // ─── Import logic ───

  Future<void> _startImport() async {
    final semesterAsync = ref.read(currentSemesterProvider);
    final semester = semesterAsync.valueOrNull;

    if (semester == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先设置学期')),
      );
      return;
    }

    setState(() => _isImporting = true);

    try {
      List<Course> parsedCourses = [];

      if (widget.system == SchoolSystem.uestc &&
          _uestcJsonResult != null &&
          _uestcState == _UestcState.done) {
        // UESTC: parse from extracted JSON
        parsedCourses = UestcEamsParser().parseFromJson(
          _uestcJsonResult!,
          semester.id,
        );
      } else {
        // All systems (including UESTC fallback): parse from page HTML
        final html = await _controller?.evaluateJavascript(
          source: "document.documentElement.outerHTML",
        );

        if (html == null || html.toString().isEmpty) {
          throw Exception('无法获取页面内容');
        }

        String decodedHtml = html.toString();

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
          SnackBar(
              content: Text(
                  '导入成功：${names.length} 门课程，共 ${parsedCourses.length} 条记录')),
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
      if (mounted) setState(() => _isImporting = false);
    }
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
          const Text('请输入您的教务系统网址',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('请确保输入的网址可以直接访问登录页面',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
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
              onPressed: () {
                final url = _urlController.text.trim();
                if (url.isNotEmpty) {
                  widget.onUrlSubmitted(url);
                }
              },
              child: const Text('进入系统'),
            ),
          ),
        ],
      ),
    );
  }
}
