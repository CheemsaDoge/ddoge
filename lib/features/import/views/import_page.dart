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
  String? _pendingUrl;

  // 地址栏
  final _urlBarController = TextEditingController();
  String _currentUrl = '';
  bool _canGoBack = false;
  bool _canGoForward = false;

  // UESTC 专用状态
  _UestcState _uestcState = _UestcState.loading;
  String _uestcStatusText = '';
  String? _uestcJsonResult;

  @override
  void dispose() {
    _urlBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUestc = widget.system == SchoolSystem.uestc;
    final showWebView = widget.system.url.isNotEmpty || _urlSubmitted;

    return Scaffold(
      appBar: AppBar(title: Text('导入 ${widget.system.name}')),
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
                      _uestcState != _UestcState.casLogin &&
                      _uestcState != _UestcState.eamsHome &&
                      _uestcState != _UestcState.courseTablePage)
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
                      child: Icon(
                        Icons.check_circle,
                        size: 18,
                        color: Colors.green,
                      ),
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
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '请登录后导航到课表查询页面，然后点击下方「导入当前页面」按钮',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // 地址栏 + 导航按钮
          if (showWebView)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // 后退
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                    onPressed: _canGoBack ? () => _controller?.goBack() : null,
                    visualDensity: VisualDensity.compact,
                    tooltip: '后退',
                  ),
                  // 前进
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 18),
                    onPressed: _canGoForward
                        ? () => _controller?.goForward()
                        : null,
                    visualDensity: VisualDensity.compact,
                    tooltip: '前进',
                  ),
                  // URL 输入框
                  Expanded(
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: TextField(
                        controller: _urlBarController,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: InputBorder.none,
                          hintText: 'https://',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          prefixIcon: _isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.lock_outline,
                                  size: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                          prefixIconConstraints: const BoxConstraints(
                            maxWidth: 30,
                            maxHeight: 30,
                          ),
                        ),
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (url) {
                          final trimmed = url.trim();
                          if (trimmed.isNotEmpty) {
                            var navigateUrl = trimmed;
                            if (!navigateUrl.startsWith('http://') &&
                                !navigateUrl.startsWith('https://')) {
                              navigateUrl = 'https://$navigateUrl';
                            }
                            _controller?.loadUrl(
                              urlRequest: URLRequest(url: WebUri(navigateUrl)),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  // 刷新
                  IconButton(
                    icon: Icon(
                      _isLoading ? Icons.close : Icons.refresh,
                      size: 18,
                    ),
                    onPressed: () {
                      if (_isLoading) {
                        _controller?.stopLoading();
                      } else {
                        _controller?.reload();
                      }
                    },
                    visualDensity: VisualDensity.compact,
                    tooltip: _isLoading ? '停止' : '刷新',
                  ),
                ],
              ),
            ),
          // WebView
          Expanded(
            child: !showWebView
                ? _UrlInputView(
                    onUrlSubmitted: (url) {
                      setState(() => _urlSubmitted = true);
                      _pendingUrl = url;
                    },
                  )
                : InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri(_pendingUrl ?? widget.system.url),
                    ),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      cacheMode: CacheMode.LOAD_DEFAULT,
                      domStorageEnabled: true,
                      databaseEnabled: true,
                      useOnLoadResource: false,
                      mixedContentMode:
                          MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                      allowContentAccess: true,
                      allowFileAccess: true,
                      userAgent:
                          'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                    ),
                    onWebViewCreated: (controller) {
                      _controller = controller;
                    },
                    onLoadStart: (controller, url) {
                      setState(() {
                        _isLoading = true;
                        if (url != null) {
                          _currentUrl = url.toString();
                          _urlBarController.text = _currentUrl;
                        }
                      });
                    },
                    onLoadStop: (controller, url) async {
                      final back = await controller.canGoBack();
                      final forward = await controller.canGoForward();
                      setState(() {
                        _isLoading = false;
                        _canGoBack = back;
                        _canGoForward = forward;
                        if (url != null) {
                          _currentUrl = url.toString();
                          _urlBarController.text = _currentUrl;
                        }
                      });
                      if (url != null) {
                        final urlStr = url.toString();
                        if (widget.system == SchoolSystem.uestc) {
                          _handleUestcNavigation(urlStr);
                        }
                      }
                    },
                    onUpdateVisitedHistory:
                        (controller, url, androidIsReload) async {
                          final back = await controller.canGoBack();
                          final forward = await controller.canGoForward();
                          setState(() {
                            _canGoBack = back;
                            _canGoForward = forward;
                            if (url != null) {
                              _currentUrl = url.toString();
                              _urlBarController.text = _currentUrl;
                            }
                          });
                        },
                    onReceivedError: (controller, request, error) {
                      setState(() => _isLoading = false);
                    },
                  ),
          ),
        ],
      ),
      // FAB 始终显示（UESTC 在自动提取完成后、其他系统始终可点击）
      floatingActionButton: showWebView && !_isImporting
          ? FloatingActionButton.extended(
              onPressed: _startImport,
              icon: const Icon(Icons.download),
              label: const Text('导入当前页面'),
            )
          : null,
    );
  }

  // ─── UESTC state machine ───

  void _handleUestcNavigation(String url) {
    final lowerUrl = url.toLowerCase();

    if (lowerUrl.contains('idas.uestc.edu.cn')) {
      setState(() {
        _uestcState = _UestcState.casLogin;
        _uestcStatusText = '请先登录统一身份认证，登录后自行进入课表查询页';
      });
      return;
    }

    if (lowerUrl.contains('/eams/home') ||
        RegExp(r'/eams/?$').hasMatch(lowerUrl) ||
        RegExp(r'/eams/\?ticket=').hasMatch(lowerUrl)) {
      setState(() {
        _uestcState = _UestcState.eamsHome;
        _uestcStatusText = '登录成功，请自行进入课表查询页';
      });
      return;
    }

    if (_isUestcCourseTablePage(lowerUrl)) {
      setState(() {
        _uestcState = _UestcState.courseTablePage;
        _uestcStatusText = '已进入课表查询页，点击下方按钮导入当前页面';
        _uestcJsonResult = null;
      });
      return;
    }
  }

  bool _isUestcCourseTablePage(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('coursetableforstd.action') &&
        !lowerUrl.contains('!coursetable');
  }

  Future<String?> _uestcExtractData({bool updateStatus = true}) async {
    if (updateStatus) {
      setState(() {
        _uestcState = _UestcState.extractingData;
        _uestcStatusText = '正在提取课表数据...';
      });
    }

    try {
      final result = await _controller?.evaluateJavascript(
        source: '''
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
''',
      );

      if (result == null) {
        if (updateStatus) {
          setState(() {
            _uestcStatusText = '提取失败: 页面未返回课表数据';
            _uestcState = _UestcState.courseTablePage;
          });
        }
        return null;
      }

      final jsonStr = result.toString();
      _uestcJsonResult = jsonStr;

      if (updateStatus) {
        setState(() {
          _uestcState = _UestcState.done;
          _uestcStatusText = '课表数据提取完成，正在导入';
        });
      }
      return jsonStr;
    } catch (e) {
      if (updateStatus) {
        setState(() {
          _uestcStatusText = '提取失败: $e';
          _uestcState = _UestcState.courseTablePage;
        });
      }
      return null;
    }
  }

  // ─── Import logic ───

  Future<void> _startImport() async {
    final semesterAsync = ref.read(currentSemesterProvider);
    final semester = semesterAsync.valueOrNull;

    if (semester == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先设置学期')));
      return;
    }

    setState(() => _isImporting = true);

    try {
      List<Course> parsedCourses = [];

      if (widget.system == SchoolSystem.uestc &&
          _isUestcCourseTablePage(_currentUrl)) {
        final extracted = await _uestcExtractData();
        if (extracted != null) {
          parsedCourses = UestcEamsParser().parseFromJson(
            extracted,
            semester.id,
          );
        }
      } else if (widget.system == SchoolSystem.uestc &&
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
        await courseDao.upsertCourse(
          CoursesCompanion(
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
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '导入成功：${names.length} 门课程，共 ${parsedCourses.length} 条记录',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败: $e')));
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
          const Text(
            '请输入您的教务系统网址',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '请确保输入的网址可以直接访问登录页面',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
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
