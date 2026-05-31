import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

class AppUpdateService {
  AppUpdateService({Dio? dio, AppUpdateInstaller? installer})
    : _dio = dio ?? Dio(),
      _installer = installer ?? const AppUpdateInstaller();

  static const owner = 'CheemsaDoge';
  static const repo = 'ddoge';
  static const _latestReleaseUrl =
      'https://api.github.com/repos/$owner/$repo/releases/latest';

  final Dio _dio;
  final AppUpdateInstaller _installer;

  Future<AppUpdateCheckResult> checkForUpdate({String? currentVersion}) async {
    final packageInfo = currentVersion == null
        ? await PackageInfo.fromPlatform()
        : null;
    final resolvedCurrentVersion =
        currentVersion ?? '${packageInfo!.version}+${packageInfo.buildNumber}';

    final response = await _dio.get<Map<String, dynamic>>(
      _latestReleaseUrl,
      options: Options(
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      ),
    );

    final data = response.data;
    if (data == null) {
      throw const AppUpdateException('GitHub Release 响应为空');
    }

    return AppUpdateCheckResult.fromRelease(
      currentVersion: resolvedCurrentVersion,
      release: GitHubReleaseInfo.fromJson(data),
    );
  }

  Future<File> downloadApk(
    GitHubReleaseAsset asset, {
    ProgressCallback? onReceiveProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final updatesDir = Directory(p.join(tempDir.path, 'ddoge-updates'));
    if (!updatesDir.existsSync()) {
      updatesDir.createSync(recursive: true);
    }

    final file = File(p.join(updatesDir.path, p.basename(asset.name)));
    await _dio.download(
      asset.downloadUrl,
      file.path,
      deleteOnError: true,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: onReceiveProgress,
    );

    if (!file.existsSync() || file.lengthSync() == 0) {
      throw const AppUpdateException('APK 下载失败，文件为空');
    }

    return file;
  }

  Future<bool> canInstallApks() => _installer.canInstallApks();

  Future<void> openInstallPermissionSettings() {
    return _installer.openInstallPermissionSettings();
  }

  Future<void> installApk(String apkPath) => _installer.installApk(apkPath);
}

class AppUpdateInstaller {
  const AppUpdateInstaller();

  static const _channel = MethodChannel('com.ddoge.ddoge/app_update');

  Future<bool> canInstallApks() async {
    if (!Platform.isAndroid) return false;
    final result = await _channel.invokeMethod<bool>('canInstallApks');
    return result ?? false;
  }

  Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

  Future<void> installApk(String apkPath) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('APK 安装仅支持 Android');
    }
    await _channel.invokeMethod<void>('installApk', {'path': apkPath});
  }
}

class AppVersion implements Comparable<AppVersion> {
  const AppVersion({
    required this.label,
    required this.major,
    required this.minor,
    required this.patch,
    required this.buildNumber,
  });

  factory AppVersion.parse(String raw) {
    final label = raw.trim();
    final parts = label.split('+');
    final withoutBuild = parts.first;
    final buildNumber = parts.length > 1 ? int.tryParse(parts[1]) : null;
    final match = RegExp(
      r'v?(\d+)(?:\.(\d+))?(?:\.(\d+))?',
      caseSensitive: false,
    ).firstMatch(withoutBuild);

    if (match == null) {
      throw FormatException('无法解析版本号: $raw');
    }

    return AppVersion(
      label: label,
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2) ?? '0'),
      patch: int.parse(match.group(3) ?? '0'),
      buildNumber: buildNumber,
    );
  }

  final String label;
  final int major;
  final int minor;
  final int patch;
  final int? buildNumber;

  String get displayLabel => 'v$major.$minor.$patch';

  @override
  int compareTo(AppVersion other) {
    final majorDiff = major.compareTo(other.major);
    if (majorDiff != 0) return majorDiff;

    final minorDiff = minor.compareTo(other.minor);
    if (minorDiff != 0) return minorDiff;

    final patchDiff = patch.compareTo(other.patch);
    if (patchDiff != 0) return patchDiff;

    if (buildNumber != null && other.buildNumber != null) {
      return buildNumber!.compareTo(other.buildNumber!);
    }

    return 0;
  }

  @override
  String toString() => displayLabel;
}

class GitHubReleaseAsset {
  const GitHubReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  factory GitHubReleaseAsset.fromJson(Map<String, dynamic> json) {
    return GitHubReleaseAsset(
      name: json['name'] as String? ?? '',
      downloadUrl:
          json['browser_download_url'] as String? ??
          json['download_url'] as String? ??
          json['url'] as String? ??
          '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }

  final String name;
  final String downloadUrl;
  final int size;

  bool get isAndroidApk =>
      name.toLowerCase().endsWith('.apk') && downloadUrl.isNotEmpty;
}

class GitHubReleaseInfo {
  const GitHubReleaseInfo({
    required this.tagName,
    required this.version,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
    required this.assets,
  });

  factory GitHubReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tagName =
        json['tag_name'] as String? ?? json['tagName'] as String? ?? '';
    final assetsJson = json['assets'] as List<dynamic>? ?? const [];

    return GitHubReleaseInfo(
      tagName: tagName,
      version: AppVersion.parse(tagName),
      name: json['name'] as String? ?? tagName,
      body: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      assets: assetsJson
          .whereType<Map<String, dynamic>>()
          .map(GitHubReleaseAsset.fromJson)
          .toList(growable: false),
    );
  }

  final String tagName;
  final AppVersion version;
  final String name;
  final String body;
  final String htmlUrl;
  final DateTime? publishedAt;
  final List<GitHubReleaseAsset> assets;

  GitHubReleaseAsset? get apkAsset {
    final apkAssets = assets.where((asset) => asset.isAndroidApk).toList();
    if (apkAssets.isEmpty) return null;

    apkAssets.sort((left, right) {
      int score(GitHubReleaseAsset asset) {
        final name = asset.name.toLowerCase();
        return (name.contains('release') ? 0 : 1) +
            (name.contains('debug') ? 4 : 0);
      }

      return score(left).compareTo(score(right));
    });

    return apkAssets.first;
  }
}

enum AppUpdateStatus { available, upToDate, noInstallableAsset }

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.currentVersion,
    required this.release,
    required this.status,
  });

  factory AppUpdateCheckResult.fromRelease({
    required String currentVersion,
    required GitHubReleaseInfo release,
  }) {
    final parsedCurrentVersion = AppVersion.parse(currentVersion);
    if (release.version.compareTo(parsedCurrentVersion) <= 0) {
      return AppUpdateCheckResult(
        currentVersion: parsedCurrentVersion,
        release: release,
        status: AppUpdateStatus.upToDate,
      );
    }

    return AppUpdateCheckResult(
      currentVersion: parsedCurrentVersion,
      release: release,
      status: release.apkAsset == null
          ? AppUpdateStatus.noInstallableAsset
          : AppUpdateStatus.available,
    );
  }

  final AppVersion currentVersion;
  final GitHubReleaseInfo release;
  final AppUpdateStatus status;

  bool get updateAvailable => status == AppUpdateStatus.available;
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
