import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:ddoge/data/services/app_update_service.dart';

class AppUpdateTile extends ConsumerStatefulWidget {
  const AppUpdateTile({super.key});

  @override
  ConsumerState<AppUpdateTile> createState() => _AppUpdateTileState();
}

class _AppUpdateTileState extends ConsumerState<AppUpdateTile>
    with WidgetsBindingObserver {
  String? _currentVersion;
  String? _currentFullVersion;
  AppUpdateCheckResult? _lastResult;
  GitHubReleaseAsset? _pendingPermissionAsset;
  bool _checking = false;
  bool _downloading = false;
  bool _waitingForInstallPermission = false;
  double? _downloadProgress;
  int _downloadedBytes = 0;
  int _downloadTotalBytes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isAndroid) {
      _loadCurrentVersion();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumePendingInstallIfAllowed();
    }
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _currentVersion = packageInfo.version;
        _currentFullVersion =
            '${packageInfo.version}+${packageInfo.buildNumber}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _currentVersion = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return const SizedBox.shrink();

    return ListTile(
      leading: _leading,
      title: Text(_title),
      subtitle: Text(_subtitle),
      trailing: _trailing,
      enabled: !_checking && !_downloading,
      onTap: _handleTap,
    );
  }

  String get _title {
    if (_downloading) return '正在下载更新...';
    if (_checking) return '正在检查更新...';

    final result = _lastResult;
    if (result == null) return '检查更新';

    return switch (result.status) {
      AppUpdateStatus.available =>
        '发现新版本 ${result.release.version.displayLabel}',
      AppUpdateStatus.upToDate => '已是最新版本',
      AppUpdateStatus.noInstallableAsset => '最新版本未提供 APK',
    };
  }

  String get _subtitle {
    final current = _currentVersion == null
        ? '正在读取当前版本'
        : '当前版本 v$_currentVersion';

    if (_downloading) {
      final progress = _downloadProgress;
      if (progress == null) return '正在准备下载 APK';
      return '已下载 ${_formatBytes(_downloadedBytes)} / '
          '${_formatBytes(_downloadTotalBytes)}，'
          '${(progress * 100).clamp(0, 100).round()}%';
    }

    if (_checking) return current;

    final result = _lastResult;
    if (result == null) return current;

    return switch (result.status) {
      AppUpdateStatus.available => '$current，点击下载并安装',
      AppUpdateStatus.upToDate => '$current，当前已是最新版本',
      AppUpdateStatus.noInstallableAsset => '该版本暂未提供安装包',
    };
  }

  Widget get _leading {
    const icon = Icon(Icons.system_update_alt_outlined);
    if (_lastResult?.updateAvailable ?? false) {
      return const Badge(label: Text('新'), child: icon);
    }
    return icon;
  }

  Widget get _trailing {
    if (_checking) {
      return const SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_downloading) {
      return SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: _downloadProgress,
        ),
      );
    }

    return const Icon(Icons.chevron_right);
  }

  Future<void> _handleTap() async {
    final result = _lastResult;
    if (result?.updateAvailable ?? false) {
      await _confirmAndInstall(result!);
      return;
    }

    await _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _checking = true;
      _lastResult = null;
    });

    try {
      final result = await ref
          .read(appUpdateServiceProvider)
          .checkForUpdate(currentVersion: _currentFullVersion);

      if (!mounted) return;
      setState(() => _lastResult = result);

      if (result.updateAvailable) {
        await _confirmAndInstall(result);
      } else {
        _showSnackBar(
          result.status == AppUpdateStatus.upToDate
              ? '当前已经是最新版本'
              : '该版本暂未提供安装包',
        );
      }
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(_describeUpdateError('检查更新失败', error));
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _confirmAndInstall(AppUpdateCheckResult result) async {
    final asset = result.release.apkAsset;
    if (asset == null) {
      _showSnackBar('该版本暂未提供安装包');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('版本更新 ${result.release.version.displayLabel}'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('安装包：${asset.name}'),
                  const SizedBox(height: 4),
                  Text('大小：${_formatBytes(asset.size)}'),
                  if (result.release.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('更新说明', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SelectableText(result.release.body.trim()),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('以后再说'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.download_outlined),
              label: const Text('下载并安装'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await _downloadAndInstall(asset);
  }

  Future<void> _downloadAndInstall(GitHubReleaseAsset asset) async {
    final service = ref.read(appUpdateServiceProvider);

    try {
      final canInstall = await service.canInstallApks();
      if (!mounted) return;

      if (!canInstall) {
        _pendingPermissionAsset = asset;
        _waitingForInstallPermission = true;
        final openSettings = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('需要安装权限'),
              content: const Text(
                'Android 需要你允许 DDoge 安装来自本应用的安装包。授权后回到 DDoge，会继续下载更新。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('打开系统设置'),
                ),
              ],
            );
          },
        );

        if (openSettings == true) {
          await service.openInstallPermissionSettings();
        } else {
          _pendingPermissionAsset = null;
          _waitingForInstallPermission = false;
        }
        return;
      }

      setState(() {
        _downloading = true;
        _downloadProgress = null;
        _downloadedBytes = 0;
        _downloadTotalBytes = 0;
      });

      final file = await service.downloadApk(
        asset,
        onReceiveProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() {
            _downloadedBytes = received;
            _downloadTotalBytes = total;
            _downloadProgress = received / total;
          });
        },
      );

      await service.installApk(file.path);
      if (!mounted) return;
      _showSnackBar('下载完成，请在系统安装界面确认更新');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(_describeUpdateError('更新失败', error));
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _downloadProgress = null;
          _downloadedBytes = 0;
          _downloadTotalBytes = 0;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resumePendingInstallIfAllowed() async {
    final asset = _pendingPermissionAsset;
    if (!mounted ||
        !_waitingForInstallPermission ||
        asset == null ||
        _downloading) {
      return;
    }

    final service = ref.read(appUpdateServiceProvider);
    final canInstall = await service.canInstallApks();
    if (!mounted) return;

    _pendingPermissionAsset = null;
    _waitingForInstallPermission = false;
    if (canInstall) {
      await _downloadAndInstall(asset);
    } else {
      _showSnackBar('未获得安装权限，无法继续安装更新');
    }
  }

  String _describeUpdateError(String prefix, Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 403) {
        return '$prefix：GitHub 暂时限制了请求，请稍后再试';
      }
      if (statusCode == 404) {
        return '$prefix：没有找到可用的 GitHub Release';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return '$prefix：网络超时，请稍后重试';
      }
      if (error.error is SocketException ||
          error.type == DioExceptionType.connectionError) {
        return '$prefix：网络连接不可用';
      }
      return '$prefix：下载服务暂时不可用';
    }

    if (error is PlatformException) {
      if (error.code == 'FILE_NOT_FOUND') {
        return '$prefix：安装包文件不存在，请重新下载';
      }
      if (error.code == 'INSTALLER_NOT_FOUND') {
        return '$prefix：系统没有可用的安装器';
      }
      return '$prefix：系统安装器返回错误';
    }

    if (error is AppUpdateException) {
      return '$prefix：${error.message}';
    }

    if (error is SocketException) {
      return '$prefix：网络连接不可用';
    }

    return '$prefix：请稍后重试';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '未知';
    final mb = bytes / 1024 / 1024;
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }
}
