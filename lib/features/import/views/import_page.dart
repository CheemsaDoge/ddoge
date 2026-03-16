import 'dart:convert';

import 'package:ddoge/core/models/time_slot_template.dart';
import 'package:ddoge/core/storage/settings_storage.dart';
import 'package:ddoge/data/database/daos/time_slot_dao.dart';
import 'package:ddoge/features/import/models/import_parse_result.dart';
import 'package:ddoge/features/import/parsers/qiangzhi_parser.dart';
import 'package:ddoge/features/import/parsers/uestc_eams_parser.dart';
import 'package:ddoge/features/import/parsers/urp_parser.dart';
import 'package:ddoge/features/import/parsers/zhengfang_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ddoge/features/schedule/providers/schedule_providers.dart';
import 'package:ddoge/features/schedule/providers/database_providers.dart';
import 'package:ddoge/data/database/app_database.dart';
import 'package:drift/drift.dart' as drift;

/// 教务系统类型
enum SchoolSystem {
  generic(name: 'generic', url: 'about:blank'),
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
  static const _uestcRootUrl = 'https://eams.uestc.edu.cn/eams/';
  static const _uestcCourseTableUrl =
      'https://eams.uestc.edu.cn/eams/courseTableForStd.action';
  static const _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36';
  static const _mobileChromeUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/133.0.0.0 Mobile Safari/537.36';
  static const _uestcDebugEventLimit = 30;

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
  bool _didLoadInitialPage = false;

  // UESTC 专用状态
  _UestcState _uestcState = _UestcState.loading;
  String _uestcStatusText = '';
  String? _uestcJsonResult;
  bool _pendingUestcFormSubmit = false;
  Map<String, dynamic>? _lastUestcProbePayload;
  final List<Map<String, dynamic>> _uestcConsoleMessages = [];
  final List<Map<String, dynamic>> _uestcLoadedResources = [];
  final List<Map<String, dynamic>> _uestcHttpErrors = [];
  final List<Map<String, dynamic>> _uestcLoadErrors = [];
  final List<Map<String, dynamic>> _uestcRuntimeSnapshots = [];

  @override
  void initState() {
    super.initState();
    assert(() {
      InAppWebViewController.setWebContentsDebuggingEnabled(true);
      return true;
    }());
  }

  @override
  void dispose() {
    _urlBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUestc = _usesUestcFlow;
    final showWebView = widget.system.url.isNotEmpty || _urlSubmitted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('从教务系统导入'),
        actions: [
          if (showWebView)
            IconButton(
              onPressed: _clearBrowserDataAndReload,
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '清除缓存',
            ),
          if (isUestc)
            IconButton(
              onPressed: _showUestcDebugPanel,
              icon: const Icon(Icons.bug_report_outlined),
              tooltip: '调试信息',
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
                  if (_uestcState == _UestcState.eamsHome)
                    TextButton(
                      onPressed: _openUestcCourseTablePage,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('打开课表页'),
                    ),
                ],
              ),
            ),
          // 提示条（非 UESTC 系统）
          if (showWebView)
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
                      isUestc
                          ? '已切换为移动端模式，请先登录并进入课表查询页，再点击下方按钮导入'
                          : '已启用桌面模式和缩放，请登录后导航到课表查询页面，再点击下方按钮导入',
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
                    onPressed: () async {
                      if (_isLoading) {
                        await _controller?.stopLoading();
                      } else {
                        await _refreshCurrentPage();
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
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      javaScriptCanOpenWindowsAutomatically: true,
                      cacheMode: CacheMode.LOAD_DEFAULT,
                      cacheEnabled: true,
                      domStorageEnabled: true,
                      databaseEnabled: true,
                      useOnLoadResource: isUestc,
                      useShouldOverrideUrlLoading: true,
                      mixedContentMode:
                          MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                      allowContentAccess: true,
                      allowFileAccess: true,
                      loadsImagesAutomatically: true,
                      thirdPartyCookiesEnabled: true,
                      supportMultipleWindows: true,
                      useHybridComposition: true,
                      sharedCookiesEnabled: true,
                      mediaPlaybackRequiresUserGesture: false,
                      textZoom: 100,
                      supportZoom: true,
                      builtInZoomControls: true,
                      displayZoomControls: false,
                      useWideViewPort: !isUestc,
                      loadWithOverviewMode: !isUestc,
                      preferredContentMode: isUestc
                          ? UserPreferredContentMode.MOBILE
                          : UserPreferredContentMode.DESKTOP,
                      userAgent: isUestc
                          ? _mobileChromeUserAgent
                          : _desktopUserAgent,
                    ),
                    onWebViewCreated: (controller) async {
                      _controller = controller;
                      if (_didLoadInitialPage) return;
                      _didLoadInitialPage = true;
                      await _syncWebViewMode(
                        controller,
                        _pendingUrl ?? widget.system.url,
                      );
                      await _loadInitialUrl(controller);
                    },
                    shouldOverrideUrlLoading:
                        (controller, navigationAction) async {
                          final uri = navigationAction.request.url;
                          if (uri == null) {
                            return NavigationActionPolicy.ALLOW;
                          }

                          if (_isSupportedNavigationUri(uri)) {
                            return NavigationActionPolicy.ALLOW;
                          }

                          return NavigationActionPolicy.CANCEL;
                        },
                    onCreateWindow: (controller, createWindowAction) async {
                      final popupUrl = createWindowAction.request.url;
                      if (_usesUestcFlow) {
                        if (popupUrl != null) {
                          _appendUestcDebugEvent(_uestcRuntimeSnapshots, {
                            'reason': 'createWindowIgnored',
                            'popupUrl': popupUrl.toString(),
                          });
                        }
                        return false;
                      }
                      if (popupUrl != null) {
                        await controller.loadUrl(
                          urlRequest: URLRequest(url: popupUrl),
                        );
                      }
                      return false;
                    },
                    onLoadStart: (controller, url) {
                      _syncWebViewMode(controller, url?.toString());
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
                      await _patchNavigationTargets(controller);
                      if (url != null) {
                        final urlStr = url.toString();
                        if (_usesUestcFlow) {
                          final isCourseTableQueryPage =
                              _isUestcCourseTablePage(urlStr);
                          final isCourseTableResultPage =
                              _isUestcCourseTableResultPage(urlStr);
                          _handleUestcNavigation(urlStr);
                          await _captureUestcRuntimeSnapshot(
                            _pendingUestcFormSubmit
                                ? (isCourseTableResultPage
                                      ? 'pendingFormSubmitResultLoadStop'
                                      : isCourseTableQueryPage
                                      ? 'pendingFormSubmitLoadStop'
                                      : 'loadStop')
                                : 'loadStop',
                          );
                          if (_pendingUestcFormSubmit &&
                              isCourseTableResultPage) {
                            setState(() {
                              _pendingUestcFormSubmit = false;
                              _uestcStatusText = '已加载课表查询结果，正在继续导入...';
                              _uestcState = _UestcState.courseTablePage;
                            });
                            Future<void>.delayed(Duration.zero, () async {
                              if (!mounted || _isImporting) return;
                              await _startImport();
                            });
                          } else if (_pendingUestcFormSubmit &&
                              isCourseTableQueryPage) {
                            setState(() {
                              _pendingUestcFormSubmit = false;
                              _uestcStatusText =
                                  '已提交课表查询；若页面仍无结果或学期控件仍不可见，请点右上角调试信息';
                              _uestcState = _UestcState.courseTablePage;
                            });
                          }
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
                    onConsoleMessage: (controller, consoleMessage) {
                      if (!_usesUestcFlow) return;
                      _appendUestcDebugEvent(_uestcConsoleMessages, {
                        'level': consoleMessage.messageLevel.toString(),
                        'message': consoleMessage.message,
                      });
                    },
                    onLoadResource: (controller, resource) {
                      if (!_usesUestcFlow) return;
                      final url = resource.url?.toString() ?? '';
                      final lowerUrl = url.toLowerCase();
                      final initiator = (resource.initiatorType ?? '')
                          .toLowerCase();
                      final looksRelevant =
                          lowerUrl.contains('uestc.edu.cn') ||
                          lowerUrl.endsWith('.js') ||
                          lowerUrl.endsWith('.css') ||
                          initiator.contains('script') ||
                          initiator.contains('css') ||
                          initiator.contains('xmlhttprequest') ||
                          initiator.contains('fetch') ||
                          initiator.contains('link');
                      if (!looksRelevant) return;
                      _appendUestcDebugEvent(_uestcLoadedResources, {
                        'url': url,
                        'initiatorType': resource.initiatorType,
                        'duration': resource.duration,
                      });
                    },
                    onReceivedError: (controller, request, error) {
                      if (_usesUestcFlow) {
                        _appendUestcDebugEvent(_uestcLoadErrors, {
                          'url': request.url.toString(),
                          'isForMainFrame': request.isForMainFrame,
                          'method': request.method,
                          'description': error.description,
                          'type': error.type.toString(),
                        });
                      }
                      setState(() => _isLoading = false);
                    },
                    onReceivedHttpError: (controller, request, response) {
                      if (_usesUestcFlow) {
                        _appendUestcDebugEvent(_uestcHttpErrors, {
                          'url': request.url.toString(),
                          'isForMainFrame': request.isForMainFrame,
                          'method': request.method,
                          'statusCode': response.statusCode,
                          'reasonPhrase': response.reasonPhrase,
                        });
                      }
                      setState(() => _isLoading = false);
                    },
                  ),
          ),
        ],
      ),
      // FAB 始终显示（UESTC 在自动提取完成后、其他系统始终可点击）
      floatingActionButton: showWebView && !_isImporting
          ? FloatingActionButton.extended(
              onPressed: _handlePrimaryAction,
              icon: Icon(
                _usesUestcFlow && _uestcState == _UestcState.eamsHome
                    ? Icons.open_in_new
                    : Icons.download,
              ),
              label: Text(_primaryActionLabel),
            )
          : null,
    );
  }

  bool get _usesUestcFlow {
    if (widget.system == SchoolSystem.uestc) return true;

    final candidates = <String>[
      widget.system.url,
      _pendingUrl ?? '',
      _currentUrl,
      _urlBarController.text,
    ];

    for (final candidate in candidates) {
      final lower = candidate.toLowerCase();
      if (lower.contains('eams.uestc.edu.cn') ||
          lower.contains('idas.uestc.edu.cn')) {
        return true;
      }
    }

    return false;
  }

  bool _looksLikeUestcUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('eams.uestc.edu.cn') ||
        lower.contains('idas.uestc.edu.cn');
  }

  String _normalizeUestcEntryUrl(String? url) {
    if (_looksLikeUestcUrl(url)) {
      return _uestcRootUrl;
    }
    return url ?? '';
  }

  Future<void> _syncWebViewMode(
    InAppWebViewController controller,
    String? url,
  ) async {
    final isUestc = _looksLikeUestcUrl(url) || _usesUestcFlow;
    try {
      await controller.setSettings(
        settings: InAppWebViewSettings(
          useOnLoadResource: isUestc,
          useWideViewPort: !isUestc,
          loadWithOverviewMode: !isUestc,
          preferredContentMode: isUestc
              ? UserPreferredContentMode.MOBILE
              : UserPreferredContentMode.DESKTOP,
          userAgent: isUestc ? _mobileChromeUserAgent : _desktopUserAgent,
        ),
      );
    } catch (_) {
      // Ignore dynamic settings failures and continue with existing settings.
    }
  }

  void _appendUestcDebugEvent(
    List<Map<String, dynamic>> target,
    Map<String, dynamic> event,
  ) {
    target.add({
      'at': DateTime.now().toIso8601String(),
      'pageUrl': _currentUrl,
      ...event,
    });
    if (target.length > _uestcDebugEventLimit) {
      target.removeRange(0, target.length - _uestcDebugEventLimit);
    }
  }

  List<Map<String, dynamic>> _takeRecentUestcEvents(
    List<Map<String, dynamic>> source, {
    int max = 10,
  }) {
    if (source.isEmpty) return const [];
    final start = source.length > max ? source.length - max : 0;
    return source
        .sublist(start)
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  Map<String, dynamic> _buildUestcClientDiagnostics() {
    return {
      'state': _uestcState.name,
      'statusText': _uestcStatusText,
      'currentUrl': _currentUrl,
      'pendingFormSubmit': _pendingUestcFormSubmit,
      'consoleMessages': _takeRecentUestcEvents(_uestcConsoleMessages, max: 12),
      'loadedResources': _takeRecentUestcEvents(_uestcLoadedResources, max: 12),
      'httpErrors': _takeRecentUestcEvents(_uestcHttpErrors, max: 12),
      'loadErrors': _takeRecentUestcEvents(_uestcLoadErrors, max: 12),
      'runtimeSnapshots': _takeRecentUestcEvents(
        _uestcRuntimeSnapshots,
        max: 6,
      ),
    };
  }

  Map<String, dynamic> _mergeUestcClientDiagnostics(
    Map<String, dynamic> payload,
  ) {
    final merged = Map<String, dynamic>.from(payload);
    final debug = merged['debug'];
    final debugMap = debug is Map
        ? Map<String, dynamic>.from(debug)
        : <String, dynamic>{};
    debugMap['clientDiagnostics'] = _buildUestcClientDiagnostics();
    merged['debug'] = debugMap;
    return merged;
  }

  void _resetUestcDebugHistory() {
    _lastUestcProbePayload = null;
    _uestcConsoleMessages.clear();
    _uestcLoadedResources.clear();
    _uestcHttpErrors.clear();
    _uestcLoadErrors.clear();
    _uestcRuntimeSnapshots.clear();
  }

  Future<void> _captureUestcRuntimeSnapshot(String reason) async {
    final controller = _controller;
    if (controller == null || !_usesUestcFlow) return;

    try {
      final raw = await controller.evaluateJavascript(
        source:
            '''
(function() {
  function truncate(value, limit) {
    value = value || '';
    return value.length > limit ? value.slice(0, limit) : value;
  }

  function isVisible(node) {
    if (!node) return false;
    var style = window.getComputedStyle ? window.getComputedStyle(node) : null;
    if (!style) return true;
    return style.display !== 'none' &&
        style.visibility !== 'hidden' &&
        style.opacity !== '0';
  }

  function collectAttribute(selector, attribute, limit) {
    var nodes = document.querySelectorAll(selector);
    var values = [];
    for (var i = 0; i < nodes.length && values.length < limit; i++) {
      var value = nodes[i].getAttribute(attribute) || '';
      if (value) values.push(value);
    }
    return values;
  }

  var selectNodes = document.querySelectorAll('select');
  var semesterNodes = document.querySelectorAll(
    '[name="semester.id"], [id*="semester"], [name*="semester"]'
  );
  var visibleSelectCount = 0;
  for (var i = 0; i < selectNodes.length; i++) {
    if (isVisible(selectNodes[i])) visibleSelectCount++;
  }

  var semesterValues = [];
  for (var j = 0; j < semesterNodes.length && semesterValues.length < 8; j++) {
    var value = semesterNodes[j].value ||
        semesterNodes[j].getAttribute('value') ||
        '';
    if (value) semesterValues.push(value);
  }

  return JSON.stringify({
    reason: ${json.encode(reason)},
    location: window.location.href || '',
    title: document.title || '',
    readyState: document.readyState || '',
    userAgent: navigator.userAgent || '',
    bgType: typeof window.bg,
    toolbarType: window.bg && window.bg.ui && window.bg.ui.toolbar
        ? typeof window.bg.ui.toolbar
        : 'missing',
    searchTableType: typeof window.searchTable,
    formCount: document.forms ? document.forms.length : 0,
    selectCount: selectNodes.length,
    visibleSelectCount: visibleSelectCount,
    semesterFieldCount: semesterNodes.length,
    semesterValues: semesterValues,
    scriptSources: collectAttribute('script[src]', 'src', 8),
    stylesheets: collectAttribute('link[rel="stylesheet"]', 'href', 8),
    bodyTextPreview: truncate(document.body ? document.body.innerText : '', 400)
  });
})()
''',
      );
      if (raw == null) return;
      final decoded = json.decode(raw.toString());
      if (decoded is Map) {
        _appendUestcDebugEvent(
          _uestcRuntimeSnapshots,
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (e) {
      _appendUestcDebugEvent(_uestcRuntimeSnapshots, {
        'reason': reason,
        'snapshotError': e.toString(),
      });
    }
  }

  // ─── UESTC state machine ───

  void _handleUestcNavigation(String url) {
    final lowerUrl = url.toLowerCase();

    if (lowerUrl.contains('idas.uestc.edu.cn')) {
      setState(() {
        _pendingUestcFormSubmit = false;
        _uestcState = _UestcState.casLogin;
        _uestcStatusText = '请先登录统一身份认证，登录后自行进入课表查询页';
      });
      return;
    }

    if (lowerUrl.contains('/eams/home') ||
        RegExp(r'/eams/?$').hasMatch(lowerUrl) ||
        RegExp(r'/eams/\?ticket=').hasMatch(lowerUrl)) {
      setState(() {
        _pendingUestcFormSubmit = false;
        _uestcState = _UestcState.eamsHome;
        _uestcStatusText = '登录成功，如首页显示不完整，可点“打开课表页”';
      });
      return;
    }

    if (_isUestcCourseTableResultPage(lowerUrl)) {
      setState(() {
        _uestcState = _UestcState.courseTablePage;
        _uestcStatusText = '课表查询结果已加载，可直接导入当前页面';
      });
      return;
    }

    if (_isUestcCourseTablePage(lowerUrl)) {
      setState(() {
        _uestcState = _UestcState.courseTablePage;
        _uestcStatusText = '已进入课表查询页，如页面控件不可用，可直接点下方按钮导入当前学期';
        _uestcJsonResult = null;
      });
      return;
    }
  }

  String get _primaryActionLabel {
    if (_usesUestcFlow) {
      if (_uestcState == _UestcState.eamsHome) {
        return '打开课表页';
      }
      if (_uestcState == _UestcState.courseTablePage ||
          _isUestcCourseTablePage(_currentUrl)) {
        return '直接导入当前学期';
      }
    }
    return '导入当前页面';
  }

  bool _isUestcCourseTablePage(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('coursetableforstd.action') &&
        !lowerUrl.contains('!coursetable');
  }

  bool _isUestcCourseTableResultPage(String url) {
    return url.toLowerCase().contains('coursetableforstd!coursetable.action');
  }

  Future<void> _handlePrimaryAction() async {
    if (_usesUestcFlow && _uestcState == _UestcState.eamsHome) {
      await _openUestcCourseTablePage();
      return;
    }

    await _startImport();
  }

  Future<void> _openUestcCourseTablePage() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      final raw = await controller.evaluateJavascript(
        source: '''
(function() {
  function findTarget() {
    var nodes = document.querySelectorAll('a, button, input[type="button"], input[type="submit"], li, span');
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i];
      var href = (node.getAttribute && (node.getAttribute('href') || node.getAttribute('data-href'))) || '';
      var text = (
        node.innerText ||
        node.textContent ||
        node.value ||
        node.getAttribute('title') ||
        ''
      ).replace(/\\s+/g, '');
      if (href.indexOf('courseTableForStd.action') !== -1 || text.indexOf('我的课表') !== -1) {
        return node;
      }
    }
    return null;
  }

  var target = findTarget();
  if (!target) return JSON.stringify({ok: false});
  try {
    if (typeof target.click === 'function') target.click();
    return JSON.stringify({
      ok: true,
      href: target.getAttribute ? (target.getAttribute('href') || '') : '',
      text: (target.innerText || target.textContent || target.value || '').trim()
    });
  } catch (error) {
    return JSON.stringify({ok: false, error: String(error)});
  }
})()
''',
      );
      if (raw != null) {
        final decoded = json.decode(raw.toString());
        if (decoded is Map && decoded['ok'] == true) {
          return;
        }
      }
    } catch (_) {
      // Fall through to root page reload.
    }

    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(_uestcCourseTableUrl)),
    );
  }

  Future<Map<String, dynamic>?> _submitUestcFormWithinPage(
    String? preferredSemesterId,
  ) async {
    final controller = _controller;
    if (controller == null) return null;

    try {
      final sourceScript =
          '''
(function() {
  function pickDynamicToken(html) {
    var patterns = [
      /[?&]4oY1vBSn=([^&#"'\\s]+)/i,
      /4oY1vBSn["']?\\s*[:=]\\s*["']?([^"'&\\s]+)/i
    ];

    var sources = [window.location.href || '', html || ''];
    var nodes = document.querySelectorAll('[href], [src], [action], [onclick], script');
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i];
      sources.push(node.getAttribute('href') || '');
      sources.push(node.getAttribute('src') || '');
      sources.push(node.getAttribute('action') || '');
      sources.push(node.getAttribute('onclick') || '');
      sources.push(node.textContent || '');
    }

    for (var sourceIndex = 0; sourceIndex < sources.length; sourceIndex++) {
      var source = sources[sourceIndex];
      if (!source) continue;
      for (var patternIndex = 0; patternIndex < patterns.length; patternIndex++) {
        var match = source.match(patterns[patternIndex]);
        if (match && match[1]) return match[1];
      }
    }

    return '';
  }

  function buildCourseTableAction(dynamicToken) {
    var action = '/eams/courseTableForStd!courseTable.action';
    if (dynamicToken) {
      action += '?4oY1vBSn=' + encodeURIComponent(dynamicToken);
    }
    return action;
  }

  function pickSemesterId(html) {
    var cookieMatch = document.cookie.match(/(?:^|;\\s*)semester\\.id=(\\d+)/);
    if (cookieMatch) return cookieMatch[1];

    var selectors = [
      'select[name="semester.id"]',
      'input[name="semester.id"]',
      'select[id*="semester"]',
      'input[id*="semester"]',
      'select[name*="semester"]',
      'input[name*="semester"]'
    ];

    for (var i = 0; i < selectors.length; i++) {
      var node = document.querySelector(selectors[i]);
      var value = node && typeof node.value === 'string' ? node.value.trim() : '';
      if (/^\\d+\$/.test(value)) return value;
    }

    var htmlPatterns = [
      /semesterId["']?\\s*[:=]\\s*["']?(\\d+)/i,
      /semester\\.id=(\\d+)/i,
      /name=["']semester\\.id["'][^>]*value=["']?(\\d+)/i,
      /semesterBar\\d+Semester[^]*?value["']?\\s*[:=]\\s*["']?(\\d+)/i
    ];

    for (var j = 0; j < htmlPatterns.length; j++) {
      var htmlMatch = html.match(htmlPatterns[j]);
      if (htmlMatch) return htmlMatch[1];
    }

    return '';
  }

  function ensureCompatLayer() {
    if (!window.bg) window.bg = {};
    if (!window.bg.form) window.bg.form = {};
    if (!window.bg.ui) window.bg.ui = {};
    if (typeof window.bg.ui.toolbar !== 'function') {
      window.bg.ui.toolbar = function() {
        return {
          addHr: function() {},
          addItem: function() {},
          addBack: function() {},
          addPrint: function() {},
          addHelp: function() {},
          setTitle: function() {}
        };
      };
    }

    if (typeof window.bg.form.addInput !== 'function') {
      window.bg.form.addInput = function(form, name, value) {
        if (!form || !name) return null;
        var field = form.querySelector('input[name="' + name + '"]');
        if (!field) {
          field = document.createElement('input');
          field.type = 'hidden';
          field.name = name;
          form.appendChild(field);
        }
        field.value = value || '';
        try { field.setAttribute('value', value || ''); } catch (_) {}
        return field;
      };
    }

    if (typeof window.bg.form.submit !== 'function') {
      window.bg.form.submit = function(form, action) {
        if (!form) return false;
        if (action) form.setAttribute('action', action);
        if (typeof form.requestSubmit === 'function') {
          form.requestSubmit();
        } else {
          form.submit();
        }
        return true;
      };
    }

    if (typeof window.jQuery !== 'function') {
      var miniQuery = function(selector) {
        var elements = [];
        if (typeof selector === 'string') {
          elements = Array.prototype.slice.call(document.querySelectorAll(selector));
        } else if (selector && selector.nodeType) {
          elements = [selector];
        } else if (selector && typeof selector.length === 'number') {
          elements = Array.prototype.slice.call(selector);
        }

        return {
          length: elements.length,
          get: function(index) {
            return elements[index];
          },
          val: function(nextValue) {
            if (!elements.length) return nextValue === undefined ? '' : this;
            if (nextValue === undefined) {
              return elements[0].value || '';
            }
            elements.forEach(function(element) {
              element.value = nextValue;
            });
            return this;
          },
          click: function() {
            elements.forEach(function(element) {
              if (typeof element.click === 'function') {
                element.click();
              }
            });
            return this;
          },
          submit: function() {
            elements.forEach(function(element) {
              if (typeof element.submit === 'function') {
                element.submit();
              } else if (element.form && typeof element.form.submit === 'function') {
                element.form.submit();
              }
            });
            return this;
          }
        };
      };

      window.jQuery = miniQuery;
      window.\$ = miniQuery;
    } else if (typeof window.\$ !== 'function') {
      window.\$ = window.jQuery;
    }
  }

  var form =
      document.querySelector('#courseTableForm') ||
      document.querySelector('form[action*="courseTableForStd.action"]') ||
      document.querySelector('form[action*="courseTableForm!action"]') ||
      document.querySelector('form');
  if (!form) return JSON.stringify({ok: false, error: 'form not found'});

  var html = document.documentElement.outerHTML;
  var dynamicToken = pickDynamicToken(html);
  var defaultSubmitAction = buildCourseTableAction(dynamicToken);
  ensureCompatLayer();
  var idsMatch = html.match(/bg\\.form\\.addInput\\(form,"ids","(\\d+)"/);
  var ids = idsMatch ? idsMatch[1] : '';
  var semesterId = __SEMESTER_PLACEHOLDER__;
  if (!semesterId) semesterId = pickSemesterId(html);

  var hiddenIds = form.querySelector('input[name="ids"]');
  if (!hiddenIds) {
    hiddenIds = document.createElement('input');
    hiddenIds.type = 'hidden';
    hiddenIds.name = 'ids';
    form.appendChild(hiddenIds);
  }
  if (ids) hiddenIds.value = ids;
  try { hiddenIds.setAttribute('value', ids); } catch (_) {}

  var projectField = form.querySelector('[name="project.id"]');
  if (!projectField) {
    projectField = document.createElement('input');
    projectField.type = 'hidden';
    projectField.name = 'project.id';
    form.appendChild(projectField);
  }
  projectField.value = projectField.value || '1';

  var kindField = form.querySelector('[name="setting.kind"]');
  if (kindField) {
    kindField.value = 'std';
    try { kindField.setAttribute('value', 'std'); } catch (_) {}
  }

  var courseTableType = document.querySelector('#courseTableType');
  if (courseTableType && typeof courseTableType.value === 'string') {
    courseTableType.value = 'std';
  }

  var semesterFields = form.querySelectorAll('[name="semester.id"]');
  if (semesterFields.length > 1) {
    semesterFields.forEach(function(field, index) {
      if (index > 0) field.remove();
    });
    semesterFields = form.querySelectorAll('[name="semester.id"]');
  }
  if (semesterFields.length === 0) {
    var createdField = document.createElement('input');
    createdField.type = 'hidden';
    createdField.name = 'semester.id';
    form.appendChild(createdField);
    semesterFields = [createdField];
  }
  for (var i = 0; i < semesterFields.length; i++) {
    var field = semesterFields[i];
    if (!semesterId) continue;
    field.value = semesterId;
    try { field.setAttribute('value', semesterId); } catch (_) {}
    try {
      var changeEvent = document.createEvent('HTMLEvents');
      changeEvent.initEvent('change', true, false);
      field.dispatchEvent(changeEvent);
    } catch (_) {}
  }

  document.cookie = 'semester.id=' + semesterId + '; path=/';

  var originalAction = form.getAttribute('action') || '';
  var submitAction = originalAction;
  if (!submitAction || submitAction.indexOf('courseTableForStd.action') !== -1) {
    submitAction = defaultSubmitAction;
    form.setAttribute('action', submitAction);
  }
  form.setAttribute('method', 'post');

  var submitState = {
    called: false,
    action: '',
    method: '',
    via: '',
    triggerLabel: '',
    searchTableError: ''
  };

  if (!window.__ddogeOriginalRequestSubmit) {
    window.__ddogeOriginalRequestSubmit = HTMLFormElement.prototype.requestSubmit;
  }
  if (!window.__ddogeOriginalSubmit) {
    window.__ddogeOriginalSubmit = HTMLFormElement.prototype.submit;
  }

  HTMLFormElement.prototype.requestSubmit = function(submitter) {
    submitState.called = true;
    submitState.via = submitState.via || 'requestSubmit';
    submitState.action = this.getAttribute('action') || this.action || '';
    submitState.method = (this.getAttribute('method') || this.method || 'POST').toUpperCase();
    return window.__ddogeOriginalRequestSubmit
        ? window.__ddogeOriginalRequestSubmit.call(this, submitter)
        : window.__ddogeOriginalSubmit.call(this);
  };

  HTMLFormElement.prototype.submit = function() {
    submitState.called = true;
    submitState.via = submitState.via || 'submit';
    submitState.action = this.getAttribute('action') || this.action || '';
    submitState.method = (this.getAttribute('method') || this.method || 'POST').toUpperCase();
    return window.__ddogeOriginalSubmit.call(this);
  };

  function pickQueryTrigger(root) {
    var candidates = root.querySelectorAll(
      'button, input[type="submit"], input[type="button"], a'
    );
    for (var i = 0; i < candidates.length; i++) {
      var node = candidates[i];
      var label = (
        node.innerText ||
        node.textContent ||
        node.value ||
        node.getAttribute('title') ||
        ''
      ).replace(/\\s+/g, '');
      var onclick = (node.getAttribute && node.getAttribute('onclick')) || '';
      if (
          label.indexOf('查询') !== -1 ||
          label.indexOf('课表') !== -1 ||
          onclick.indexOf('searchTable') !== -1 ||
          onclick.indexOf('courseTableForStd!courseTable.action') !== -1 ||
          onclick.indexOf('bookOrderCheckAjax') !== -1) {
        return {
          node: node,
          label: label,
          onclick: onclick
        };
      }
    }
    return null;
  }

  var triggerMethod = '';
  var triggerLabel = '';
  var searchTableError = '';
  if (typeof searchTable === 'function') {
    try {
      searchTable();
    } catch (error) {
      searchTableError = String(error);
    }
  }

  var trigger = pickQueryTrigger(form);
  if (trigger && trigger.node && typeof trigger.node.click === 'function') {
    try {
      trigger.node.click();
      triggerMethod = 'queryTrigger.click';
      triggerLabel = trigger.label || '';
    } catch (error) {
      if (!searchTableError) searchTableError = String(error);
    }
  }

  if (!submitState.called) {
    try {
      if (typeof window.bg.form.submit === 'function') {
        window.bg.form.submit(form, submitAction);
        triggerMethod = triggerMethod || 'bg.form.submit';
      } else if (typeof form.requestSubmit === 'function') {
        form.requestSubmit();
        triggerMethod = triggerMethod || 'form.requestSubmit';
      } else {
        form.submit();
        triggerMethod = triggerMethod || 'form.submit';
      }
    } catch (error) {
      HTMLFormElement.prototype.requestSubmit = window.__ddogeOriginalRequestSubmit;
      HTMLFormElement.prototype.submit = window.__ddogeOriginalSubmit;
      return JSON.stringify({
        ok: false,
        error: 'form trigger failed',
        details: String(error),
        action: submitAction,
        originalAction: originalAction,
        dynamicToken: dynamicToken,
        searchTableType: typeof searchTable,
        searchTableError: searchTableError
      });
    }
  }

  HTMLFormElement.prototype.requestSubmit = window.__ddogeOriginalRequestSubmit;
  HTMLFormElement.prototype.submit = window.__ddogeOriginalSubmit;

  return JSON.stringify({
    ok: submitState.called,
    ids: hiddenIds.value || ids,
    semesterId: semesterId,
    triggerMethod: submitState.via || triggerMethod,
    triggerLabel: triggerLabel,
    searchTableType: typeof searchTable,
    searchTableError: searchTableError,
    dynamicToken: dynamicToken,
    originalAction: originalAction,
    action: submitState.action || form.getAttribute('action') || '',
    method: submitState.method || (form.getAttribute('method') || 'POST').toUpperCase()
  });
})()
'''
              .replaceFirst(
                '__SEMESTER_PLACEHOLDER__',
                json.encode(preferredSemesterId ?? ''),
              );
      final raw = await controller.evaluateJavascript(source: sourceScript);

      if (raw == null) return null;
      final decoded = json.decode(raw.toString());
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      return {
        'ok': false,
        'error': 'submit exception',
        'details': e.toString(),
      };
    }

    return {'ok': false, 'error': 'submit returned unexpected payload'};
  }

  Future<Map<String, dynamic>?> _runUestcProbe() async {
    try {
      final raw = await _controller?.evaluateJavascript(
        source: _uestcProbeScript,
      );
      if (raw == null) return null;

      final decoded = json.decode(raw.toString());
      if (decoded is Map) {
        final payload = _mergeUestcClientDiagnostics(
          Map<String, dynamic>.from(decoded),
        );
        final debug = payload['debug'];
        debugPrint('[UESTC_IMPORT] ${json.encode(debug ?? const {})}');
        _lastUestcProbePayload = payload;
        return payload;
      }
    } catch (e) {
      debugPrint('[UESTC_IMPORT] {"probeError":${json.encode(e.toString())}}');
    }

    return null;
  }

  Future<void> _showUestcDebugPanel() async {
    final payload = await _runUestcProbe();
    if (!mounted) return;

    final effectivePayload =
        payload ??
        _lastUestcProbePayload ??
        _mergeUestcClientDiagnostics({
          'error': 'probe unavailable',
          'debug': <String, dynamic>{},
        });
    final content = const JsonEncoder.withIndent(
      '  ',
    ).convert(effectivePayload);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'UESTC 调试信息',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(
                    content,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String get _uestcProbeScript => '''
(function() {
  var pageHtml = document.documentElement.outerHTML;
  var currentUrl = window.location.href || '';
  var workingHtml = pageHtml;
  var workingUrl = currentUrl;
  var workingDoc = null;

  function rebuildWorkingDoc() {
    try {
      workingDoc = new DOMParser().parseFromString(workingHtml, 'text/html');
    } catch (_) {
      workingDoc = null;
    }
  }

  rebuildWorkingDoc();

  function isErrorPage(html) {
    return /HTTP状态\\s*500|Exception report|java\\.lang\\./i.test(html || '');
  }

  function reloadCourseTablePage() {
    var xhr = new XMLHttpRequest();
    xhr.open(
      'GET',
      '/eams/courseTableForStd.action?_=' + Date.now(),
      false
    );
    xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
    xhr.send(null);

    return {
      status: xhr.status,
      html: xhr.responseText || '',
      url: '/eams/courseTableForStd.action'
    };
  }

  function pickDynamicToken() {
    var patterns = [
      /[?&]4oY1vBSn=([^&#"'\\s]+)/i,
      /4oY1vBSn["']?\\s*[:=]\\s*["']?([^"'&\\s]+)/i
    ];

    var sources = [workingUrl, workingHtml];
    document.querySelectorAll('script').forEach(function(script) {
      sources.push(script.textContent || '');
      sources.push(script.getAttribute('src') || '');
    });
    if (workingDoc) {
      workingDoc.querySelectorAll('script').forEach(function(script) {
        sources.push(script.textContent || '');
        sources.push(script.getAttribute('src') || '');
      });
    }

    for (var i = 0; i < sources.length; i++) {
      var source = sources[i];
      if (!source) continue;
      for (var j = 0; j < patterns.length; j++) {
        var tokenMatch = source.match(patterns[j]);
        if (tokenMatch && tokenMatch[1]) return tokenMatch[1];
      }
    }

    return '';
  }

  function pickSemesterId() {
    var cookieMatch = document.cookie.match(/(?:^|;\\s*)semester\\.id=(\\d+)/);
    if (cookieMatch) return cookieMatch[1];

    var roots = [];
    if (workingDoc) roots.push(workingDoc);
    roots.push(document);

    var selectors = [
      'select[name="semester.id"]',
      'input[name="semester.id"]',
      'select[id*="semester"]',
      'input[id*="semester"]',
      'select[name*="semester"]',
      'input[name*="semester"]'
    ];

    for (var rootIndex = 0; rootIndex < roots.length; rootIndex++) {
      var root = roots[rootIndex];
      for (var i = 0; i < selectors.length; i++) {
        var node = root.querySelector(selectors[i]);
        var value = node && typeof node.value === 'string' ? node.value.trim() : '';
        if (/^\\d+\$/.test(value)) return value;
      }
    }

    var htmlPatterns = [
      /semesterId["']?\\s*[:=]\\s*["']?(\\d+)/i,
      /semester\\.id=(\\d+)/i,
      /name=["']semester\\.id["'][^>]*value=["']?(\\d+)/i
    ];

    for (var j = 0; j < htmlPatterns.length; j++) {
      var htmlMatch = workingHtml.match(htmlPatterns[j]);
      if (htmlMatch) return htmlMatch[1];
    }

    var candidateValues = [];
    (workingDoc || document).querySelectorAll('select option').forEach(function(option) {
      var parent = option.parentElement;
      var parentHint = ((parent && (parent.name || parent.id)) || '').toLowerCase();
      if (parentHint.indexOf('semester') == -1) return;
      var optionValue = (option.value || '').trim();
      if (/^\\d+\$/.test(optionValue)) {
        candidateValues.push(parseInt(optionValue, 10));
      }
    });

    if (candidateValues.length > 0) {
      candidateValues.sort(function(a, b) { return b - a; });
      return String(candidateValues[0]);
    }

    var looseOptionValues = [];
    (workingDoc || document).querySelectorAll('select option').forEach(function(option) {
      var optionValue = (option.value || '').trim();
      if (!/^\\d+\$/.test(optionValue)) return;
      var numericValue = parseInt(optionValue, 10);
      if (!isNaN(numericValue) && numericValue >= 100 && numericValue <= 9999) {
        looseOptionValues.push(numericValue);
      }
    });

    if (looseOptionValues.length > 0) {
      looseOptionValues.sort(function(a, b) { return b - a; });
      return String(looseOptionValues[0]);
    }

    var scriptPatterns = [
      /semesterBar\\d+Semester[^]*?value["']?\\s*[:=]\\s*["']?(\\d+)/i,
      /semesterBar\\d+Semester[^]*?defaultValue["']?\\s*[:=]\\s*["']?(\\d+)/i,
      /semesterBar\\d+Semester[^]*?selected["']?\\s*[:=]\\s*["']?(\\d+)/i
    ];

    for (var k = 0; k < scriptPatterns.length; k++) {
      var scriptMatch = workingHtml.match(scriptPatterns[k]);
      if (scriptMatch) return scriptMatch[1];
    }

    return '';
  }

  function querySemesterId(dynamicToken) {
    var tagIdMatch = workingHtml.match(/semesterBar\\d+Semester/i);
    var tagId = tagIdMatch ? tagIdMatch[0] : '';

    var xhr = new XMLHttpRequest();
    var queryUrl = dynamicToken
        ? '/eams/dataQuery.action?4oY1vBSn=' + encodeURIComponent(dynamicToken)
        : '/eams/dataQuery.action';
    xhr.open(
      'POST',
      queryUrl,
      false
    );
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');

    var bodyParts = ['dataType=semesterCalendar', 'empty=false'];
    if (tagId) bodyParts.unshift('tagId=' + encodeURIComponent(tagId));
    xhr.send(bodyParts.join('&'));

    var responseText = xhr.responseText || '';
    if (xhr.status !== 200) {
      return {
        semesterId: '',
        responsePreview: responseText.slice(0, 500),
        status: xhr.status
      };
    }

    var semesterIdMatch = responseText.match(/semesterId["']?\\s*[:=]\\s*["']?(\\d+)/i);
    if (semesterIdMatch) {
      return {
        semesterId: semesterIdMatch[1],
        responsePreview: responseText.slice(0, 500),
        status: xhr.status
      };
    }

    var idMatches = Array.from(responseText.matchAll(/id["']?\\s*[:=]\\s*(\\d+)/gi));
    if (idMatches.length > 0) {
      var values = idMatches
          .map(function(match) { return parseInt(match[1], 10); })
          .filter(function(value) { return !isNaN(value); });
      if (values.length > 0) {
        values.sort(function(a, b) { return b - a; });
        return {
          semesterId: String(values[0]),
          responsePreview: responseText.slice(0, 500),
          status: xhr.status
        };
      }
    }

    return {
      semesterId: '',
      responsePreview: responseText.slice(0, 500),
      status: xhr.status
    };
  }

  function extractFormPayload() {
    var root = workingDoc || document;
    var form =
        root.querySelector('#courseTableForm') ||
        root.querySelector('form[action*="courseTableForStd.action"]') ||
        root.querySelector('form[action*="courseTableForm"]') ||
        root.querySelector('form[name="courseTableForm"]') ||
        root.querySelector('form');
    if (!form) {
      return {
        action: '',
        method: 'POST',
        body: '',
        fieldNames: []
      };
    }

    var pairs = [];
    var fieldNames = [];
    var formData = new FormData(form);
    formData.forEach(function(value, key) {
      if (typeof value !== 'string') return;
      pairs.push([key, value]);
      fieldNames.push(key);
    });

    return {
      action: form.getAttribute('action') || '',
      method: (form.getAttribute('method') || 'POST').toUpperCase(),
      body: pairs.map(function(entry) {
        return encodeURIComponent(entry[0]) + '=' + encodeURIComponent(entry[1]);
      }).join('&'),
      fieldNames: fieldNames
    };
  }

  function collectAttribute(root, selector, attribute, limit) {
    var nodes = root.querySelectorAll(selector);
    var values = [];
    for (var i = 0; i < nodes.length && values.length < limit; i++) {
      var value = nodes[i].getAttribute(attribute) || '';
      if (value) values.push(value);
    }
    return values;
  }

  function submitViaFormAction(formPayload, ids, semesterId) {
    if (!formPayload.action) {
      return {status: 0, html: '', url: ''};
    }

    function hasOwn(obj, key) {
      return Object.prototype.hasOwnProperty.call(obj, key);
    }

    var params = {};
    (formPayload.body || '').split('&').forEach(function(part) {
      if (!part) return;
      var separatorIndex = part.indexOf('=');
      var rawKey = separatorIndex >= 0 ? part.slice(0, separatorIndex) : part;
      var rawValue = separatorIndex >= 0 ? part.slice(separatorIndex + 1) : '';
      var key = decodeURIComponent(rawKey || '');
      var value = decodeURIComponent(rawValue || '');
      if (!key) return;
      params[key] = value;
    });

    if (ids) params['ids'] = ids;
    if (semesterId) params['semester.id'] = semesterId;
    if (!hasOwn(params, 'ignoreHead')) params['ignoreHead'] = '1';
    if (!hasOwn(params, 'setting.kind')) params['setting.kind'] = 'std';
    if (!hasOwn(params, 'project.id')) params['project.id'] = '1';
    if (!hasOwn(params, 'isEng')) params['isEng'] = '0';

    var submitUrl = formPayload.action || '';
    if (submitUrl.indexOf('courseTableForStd.action') !== -1) {
      submitUrl = '/eams/courseTableForStd!courseTable.action';
      if (dynamicToken) {
        submitUrl += '?4oY1vBSn=' + encodeURIComponent(dynamicToken);
      }
    }

    var orderedKeys = [
      'ignoreHead',
      'setting.kind',
      'startWeek',
      'isEng',
      'semester.id',
      'ids',
      'project.id'
    ];
    var appendedKeys = {};
    var bodyParts = [];
    orderedKeys.forEach(function(key) {
      if (!hasOwn(params, key)) return;
      appendedKeys[key] = true;
      bodyParts.push(encodeURIComponent(key) + '=' + encodeURIComponent(params[key] || ''));
    });
    Object.keys(params).forEach(function(key) {
      if (appendedKeys[key]) return;
      bodyParts.push(encodeURIComponent(key) + '=' + encodeURIComponent(params[key] || ''));
    });
    var body = bodyParts.join('&');

    var xhr = new XMLHttpRequest();
    xhr.open(formPayload.method || 'POST', submitUrl, false);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
    xhr.send(body);

    return {
      status: xhr.status,
      html: xhr.responseText || '',
      url: submitUrl,
      body: body
    };
  }

  var initialIdsMatch = workingHtml.match(/bg\\.form\\.addInput\\(form,"ids","(\\d+)"/);
  var initialToken = pickDynamicToken();
  if (isErrorPage(workingHtml) || !initialIdsMatch || !initialToken) {
    var freshPage = reloadCourseTablePage();
    if (freshPage.status === 200 && freshPage.html) {
      workingHtml = freshPage.html;
      workingUrl = freshPage.url;
      rebuildWorkingDoc();
    }
  }

  var idsMatch = workingHtml.match(/bg\\.form\\.addInput\\(form,"ids","(\\d+)"/);
  var ids = idsMatch ? idsMatch[1] : '';
  var dynamicToken = pickDynamicToken();
  var semesterId = pickSemesterId();
  var semesterQuery = {semesterId: '', responsePreview: '', status: null};
  var formPayload = extractFormPayload();
  if (!semesterId) {
    semesterQuery = querySemesterId(dynamicToken);
    semesterId = semesterQuery.semesterId || '';
  }

  var payload = {
    url: currentUrl,
    workingUrl: workingUrl,
    userAgent: navigator.userAgent || '',
    readyState: document.readyState || '',
    cookie: document.cookie,
    ids: ids,
    token: dynamicToken,
    semesterId: semesterId,
    formAction: formPayload.action,
    formMethod: formPayload.method,
    formFields: formPayload.fieldNames,
    workingFormCount: workingDoc && workingDoc.forms ? workingDoc.forms.length : 0,
    workingSelectCount: workingDoc ? workingDoc.querySelectorAll('select').length : 0,
    workingSemesterFieldCount: workingDoc
        ? workingDoc.querySelectorAll('[name="semester.id"], [id*="semester"], [name*="semester"]').length
        : 0,
    bgType: typeof window.bg,
    toolbarType: window.bg && window.bg.ui && window.bg.ui.toolbar
        ? typeof window.bg.ui.toolbar
        : 'missing',
    searchTableType: typeof window.searchTable,
    formCount: document.forms ? document.forms.length : 0,
    selectCount: document.querySelectorAll('select').length,
    semesterFieldCount: document.querySelectorAll(
      '[name="semester.id"], [id*="semester"], [name*="semester"]'
    ).length,
    scriptSources: collectAttribute(document, 'script[src]', 'src', 8),
    stylesheets: collectAttribute(document, 'link[rel="stylesheet"]', 'href', 8),
    workingScriptSources: workingDoc
        ? collectAttribute(workingDoc, 'script[src]', 'src', 8)
        : [],
    workingStylesheets: workingDoc
        ? collectAttribute(workingDoc, 'link[rel="stylesheet"]', 'href', 8)
        : [],
    semesterTagId: (workingHtml.match(/semesterBar\\d+Semester/i) || [''])[0],
    semesterQueryStatus: semesterQuery.status,
    semesterQueryPreview: semesterQuery.responsePreview,
    pagePreview: workingHtml.slice(0, 500)
  };

  if (!ids) return JSON.stringify({error: 'ids not found', debug: payload});
  if (!semesterId) {
    return JSON.stringify({error: 'semester id not found', debug: payload});
  }
  if (!dynamicToken && !formPayload.action) {
    return JSON.stringify({error: 'dynamic token not found', debug: payload});
  }

  var responseHtml = '';
  if (dynamicToken) {
    if (semesterId) {
      var xhr = new XMLHttpRequest();
      xhr.open('POST', '/eams/courseTableForStd!courseTable.action?4oY1vBSn=' + encodeURIComponent(dynamicToken), false);
      xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
      xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
      xhr.send('ignoreHead=1&setting.kind=std&startWeek=&project.id=1&isEng=0&semester.id=' + semesterId + '&ids=' + ids);

      responseHtml = xhr.responseText || '';
      payload.courseQueryStatus = xhr.status;
      payload.responsePreview = responseHtml.slice(0, 500);

      if (xhr.status !== 200) return JSON.stringify({error: 'HTTP ' + xhr.status, debug: payload});
      if (/Exception report|java\\.lang\\./i.test(responseHtml)) {
        payload.directQueryFailed = true;
      }
    } else {
      payload.directQuerySkipped = true;
    }
  } else {
    payload.directQuerySkipped = true;
  }

  if (!responseHtml || /Exception report|java\\.lang\\./i.test(responseHtml)) {
    var formResult = submitViaFormAction(formPayload, ids, semesterId);
    responseHtml = formResult.html || '';
    payload.formSubmitStatus = formResult.status;
    payload.formSubmitUrl = formResult.url;
    payload.formSubmitBody = formResult.body;
    payload.responsePreview = responseHtml.slice(0, 500);
    if (formResult.status !== 200) {
      return JSON.stringify({error: 'form submit failed', debug: payload});
    }
    if (/Exception report|java\\.lang\\./i.test(responseHtml)) {
      return JSON.stringify({error: 'backend exception', debug: payload});
    }
  }

  var results = [];
  var currentActivity = null;
  var lines = responseHtml.split('\\n');
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

  payload.courseCount = results.length;
  if (results.length === 0) {
    return JSON.stringify({error: 'course data not found', debug: payload});
  }

  return JSON.stringify({
    courses: results,
    semesterId: semesterId,
    debug: payload
  });
})()
''';

  Future<String?> _uestcExtractData({bool updateStatus = true}) async {
    if (updateStatus) {
      setState(() {
        _uestcState = _UestcState.extractingData;
        _uestcStatusText = '正在提取课表数据...';
      });
    }

    try {
      final decoded = await _runUestcProbe();
      if (decoded == null) {
        _lastUestcProbePayload = _mergeUestcClientDiagnostics({
          'error': 'probe returned null',
          'debug': {
            'url': _currentUrl,
            'statusText': _uestcStatusText,
            'state': _uestcState.name,
          },
        });
        if (updateStatus) {
          setState(() {
            _uestcStatusText = '提取失败: 页面未返回课表数据';
            _uestcState = _UestcState.courseTablePage;
          });
        }
        return null;
      }

      final jsonStr = json.encode(decoded);
      _lastUestcProbePayload = decoded;
      if (decoded['error'] != null) {
        final rawError = decoded['error'].toString();
        final debug = decoded['debug'];
        final formSubmitStatus = debug is Map<String, dynamic>
            ? debug['formSubmitStatus']
            : null;

        if (rawError == 'form submit failed' &&
            formSubmitStatus == 202 &&
            _isUestcCourseTablePage(_currentUrl)) {
          final preferredSemesterId = debug is Map<String, dynamic>
              ? debug['semesterId']?.toString()
              : null;
          final submitted = await _submitUestcFormWithinPage(
            preferredSemesterId,
          );
          if (submitted != null) {
            final mergedPayload = _mergeUestcClientDiagnostics(
              Map<String, dynamic>.from(decoded),
            );
            final mergedDebug = mergedPayload['debug'] is Map
                ? Map<String, dynamic>.from(mergedPayload['debug'])
                : <String, dynamic>{};
            mergedDebug['pageSubmitAttempt'] = submitted;
            mergedPayload['debug'] = mergedDebug;
            _lastUestcProbePayload = mergedPayload;
          }
          if (submitted?['ok'] == true) {
            if (updateStatus) {
              setState(() {
                _pendingUestcFormSubmit = true;
                _uestcState = _UestcState.loading;
                _uestcStatusText = '正在通过页面内查询方式加载当前学期课表...';
              });
            }
            return null;
          }
        }

        final message = switch (rawError) {
          'ids not found' => '提取失败: 未识别到课表查询参数，请重新打开课表页后再试',
          'semester id not found' => '提取失败: 未识别到当前学期，请直接点下方按钮重试',
          'dynamic token not found' => '提取失败: 未识别到教务系统动态令牌，请刷新课表页后重试',
          'form submit failed' => '提取失败: 页面表单提交未成功，请重新打开课表页后重试',
          'backend exception' => '提取失败: 教务系统返回异常页，请重新打开课表页后重试',
          'course data not found' => '提取失败: 当前响应里没有课表数据，请刷新课表页后重试',
          _ => '提取失败: $rawError',
        };
        if (updateStatus) {
          setState(() {
            _uestcStatusText = message;
            _uestcState = _UestcState.courseTablePage;
          });
        }
        return null;
      }
      _uestcJsonResult = jsonStr;

      if (updateStatus) {
        setState(() {
          _uestcState = _UestcState.done;
          _uestcStatusText = '课表数据提取完成，正在导入';
        });
      }
      return jsonStr;
    } catch (e) {
      _lastUestcProbePayload = _mergeUestcClientDiagnostics({
        'error': 'probe exception',
        'debug': {
          'url': _currentUrl,
          'statusText': _uestcStatusText,
          'state': _uestcState.name,
          'exception': e.toString(),
        },
      });
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
      var parseResult = const ImportParseResult(courses: <Course>[]);

      if ((widget.system == SchoolSystem.uestc ||
              widget.system == SchoolSystem.generic) &&
          _isUestcCourseTablePage(_currentUrl)) {
        final extracted = await _uestcExtractData();
        if (extracted != null) {
          parseResult = UestcEamsParser().parseImportResultFromJson(
            extracted,
            semester.id,
          );
        }
      } else if (widget.system == SchoolSystem.uestc &&
          _uestcJsonResult != null &&
          _uestcState == _UestcState.done) {
        // UESTC: parse from extracted JSON
        parseResult = UestcEamsParser().parseImportResultFromJson(
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
          case SchoolSystem.generic:
            parseResult = _autoDetectAndParse(decodedHtml, semester.id);
            break;
          case SchoolSystem.uestc:
            parseResult = UestcEamsParser().parseImportResult(
              decodedHtml,
              semester.id,
            );
            break;
          case SchoolSystem.zhengfang:
            parseResult = ImportParseResult(
              courses: ZhengfangParser().parse(decodedHtml, semester.id),
            );
            break;
          case SchoolSystem.qiangzhi:
            parseResult = ImportParseResult(
              courses: QiangzhiParser().parse(decodedHtml, semester.id),
            );
            break;
          case SchoolSystem.urp:
            parseResult = ImportParseResult(
              courses: UrpParser().parse(decodedHtml, semester.id),
            );
            break;
        }
      }

      final parsedCourses = parseResult.courses;
      if (parsedCourses.isEmpty) {
        if (_pendingUestcFormSubmit) {
          return;
        }
        throw Exception('未找到课表数据，请确保已进入查询结果页面');
      }

      final database = ref.read(databaseProvider);
      final courseDao = ref.read(courseDaoProvider);
      final timeSlotDao = ref.read(timeSlotDaoProvider);
      final settingsStorage = ref.read(settingsStorageProvider);
      final names = <String>{};
      final courseColorByName = <String, int>{};

      await database.transaction(() async {
        await courseDao.deleteCoursesForSemester(semester.id);

        for (final c in parsedCourses) {
          names.add(c.name);
          final colorIndex = courseColorByName.putIfAbsent(
            c.name,
            () => courseColorByName.length % 10,
          );

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
              colorIndex: drift.Value(colorIndex),
              semesterId: drift.Value(semester.id),
            ),
          );
        }
      });

      if (parseResult.timeSlotTemplate != null) {
        await _applyImportedTimeSlotTemplate(
          semester.id,
          parseResult.timeSlotTemplate!,
          timeSlotDao,
          settingsStorage,
        );
      }

      if (mounted) {
        final importedTimeSlotsText = parseResult.timeSlotTemplate == null
            ? ''
            : '，并同步了节次模板';
        final weekOffsetText = parseResult.normalizedWeekOffset > 0
            ? '（周次已整体前移 ${parseResult.normalizedWeekOffset} 周）'
            : '';
        final importSummary =
            '导入成功：${names.length} 门课程，共 ${parsedCourses.length} 条记录'
            '$importedTimeSlotsText$weekOffsetText';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(importSummary)));
        context.pop();
      }
    } catch (e) {
      if (_usesUestcFlow) {
        _lastUestcProbePayload = _mergeUestcClientDiagnostics({
          'error': 'import exception',
          'debug': {
            'url': _currentUrl,
            'statusText': _uestcStatusText,
            'state': _uestcState.name,
            'exception': e.toString(),
          },
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  ImportParseResult _autoDetectAndParse(String html, String semesterId) {
    final parsers = <ImportParseResult Function()>[
      () => UestcEamsParser().parseImportResult(html, semesterId),
      () =>
          ImportParseResult(courses: ZhengfangParser().parse(html, semesterId)),
      () =>
          ImportParseResult(courses: QiangzhiParser().parse(html, semesterId)),
      () => ImportParseResult(courses: UrpParser().parse(html, semesterId)),
    ];

    for (final parse in parsers) {
      final result = parse();
      if (result.courses.isNotEmpty) return result;
    }
    return const ImportParseResult(courses: <Course>[]);
  }

  Future<void> _applyImportedTimeSlotTemplate(
    String semesterId,
    TimeSlotTemplate template,
    TimeSlotDao timeSlotDao,
    SettingsStorage settingsStorage,
  ) async {
    if (!template.isBuiltin) {
      await settingsStorage.upsertTimeSlotTemplate(template);
    }
    await timeSlotDao.replaceTimeSlotsForSemester(semesterId, template.slots);
    await settingsStorage.setSemesterTimeSlotTemplateId(
      semesterId,
      template.id,
    );
  }

  bool _isSupportedNavigationUri(WebUri uri) {
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https' || scheme == 'about';
  }

  Future<void> _refreshCurrentPage() async {
    final controller = _controller;
    if (controller == null) return;

    final currentUri = await controller.getUrl();
    final effectiveUrl = (currentUri?.toString().isNotEmpty ?? false)
        ? currentUri.toString()
        : _currentUrl;

    try {
      if (effectiveUrl.isNotEmpty && effectiveUrl != 'about:blank') {
        await controller.loadUrl(
          urlRequest: URLRequest(
            url: WebUri(effectiveUrl),
            headers: const {
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              'Pragma': 'no-cache',
            },
          ),
        );
        return;
      }

      await controller.reload();
    } catch (_) {
      await controller.reload();
    }
  }

  Future<void> _patchNavigationTargets(
    InAppWebViewController controller,
  ) async {
    if (_usesUestcFlow) return;

    try {
      await controller.evaluateJavascript(
        source: '''
(function() {
  try {
    function retargetBlankLinks() {
      document.querySelectorAll('a[target="_blank"], form[target="_blank"]').forEach(function(node) {
        node.setAttribute('target', '_self');
      });
    }

    if (!window.__ddogeWindowOpenPatched) {
      window.__ddogeWindowOpenPatched = true;
      window.open = function(url) {
        if (typeof url === 'string' && url.length > 0 && url !== 'about:blank') {
          window.location.href = url;
        }
        return window;
      };
    }

    retargetBlankLinks();

    if (!window.__ddogeBlankTargetObserver) {
      window.__ddogeBlankTargetObserver = new MutationObserver(function() {
        retargetBlankLinks();
      });
      window.__ddogeBlankTargetObserver.observe(
        document.documentElement || document.body,
        {childList: true, subtree: true}
      );
    }
  } catch (_) {}
})();
''',
      );
    } catch (_) {
      // Ignore page script injection failures.
    }
  }

  Future<void> _loadInitialUrl(InAppWebViewController controller) async {
    final initialUrl = _normalizeUestcEntryUrl(
      _pendingUrl ?? widget.system.url,
    );
    if (initialUrl.isNotEmpty) {
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(initialUrl)));
    }
  }

  Future<void> _clearBrowserDataAndReload() async {
    final controller = _controller;
    if (controller == null) return;

    if (_usesUestcFlow) {
      _resetUestcDebugHistory();
    }

    try {
      await CookieManager.instance().deleteAllCookies();
      final webStorageManager = WebStorageManager.instance();
      await webStorageManager.deleteAllData();
      await InAppWebViewController.clearAllCache();
    } catch (_) {
      // Ignore clearing failures and continue loading the page.
    }

    if (_usesUestcFlow && mounted) {
      setState(() {
        _pendingUestcFormSubmit = false;
        _uestcState = _UestcState.loading;
        _uestcStatusText = '缓存已清除，请重新登录后进入课表查询页';
        _uestcJsonResult = null;
      });
    }

    final reloadUrl = (_pendingUrl ?? widget.system.url).isNotEmpty
        ? _normalizeUestcEntryUrl(_pendingUrl ?? widget.system.url)
        : _currentUrl;
    if (reloadUrl.isNotEmpty && reloadUrl != 'about:blank') {
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(reloadUrl)));
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('浏览器缓存已清除')));
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
