import 'package:flutter_test/flutter_test.dart';

import 'package:ddoge/data/services/app_update_service.dart';

void main() {
  group('AppVersion', () {
    test('parses GitHub tags and compares semantic versions', () {
      final current = AppVersion.parse('1.2.0+7');
      final latest = AppVersion.parse('v1.3.0');

      expect(latest.compareTo(current), greaterThan(0));
      expect(AppVersion.parse('v1.2.0').compareTo(current), 0);
    });

    test('uses build numbers when semantic versions are equal', () {
      final current = AppVersion.parse('1.3.0+8');
      final latestBuild = AppVersion.parse('v1.3.0+9');

      expect(latestBuild.compareTo(current), greaterThan(0));
    });
  });

  group('GitHubReleaseInfo', () {
    test('selects the Android APK asset from a GitHub release payload', () {
      final release = GitHubReleaseInfo.fromJson({
        'tag_name': 'v1.3.0',
        'name': 'DDoge v1.3.0',
        'body': 'Update notes',
        'html_url': 'https://github.com/CheemsaDoge/ddoge/releases/tag/v1.3.0',
        'published_at': '2026-05-31T08:00:00Z',
        'assets': [
          {
            'name': 'source.zip',
            'browser_download_url': 'https://example.com/source.zip',
            'size': 10,
          },
          {
            'name': 'ddoge-v1.3.0.apk',
            'browser_download_url': 'https://example.com/ddoge.apk',
            'size': 42,
          },
        ],
      });

      expect(release.version.label, 'v1.3.0');
      expect(release.apkAsset?.name, 'ddoge-v1.3.0.apk');
      expect(release.apkAsset?.downloadUrl, 'https://example.com/ddoge.apk');
    });
  });

  group('AppUpdateCheckResult', () {
    test('marks newer APK release as available', () {
      final release = GitHubReleaseInfo.fromJson({
        'tag_name': 'v1.3.0',
        'name': 'DDoge v1.3.0',
        'body': '',
        'assets': [
          {
            'name': 'ddoge-v1.3.0.apk',
            'browser_download_url': 'https://example.com/ddoge.apk',
            'size': 42,
          },
        ],
      });

      final result = AppUpdateCheckResult.fromRelease(
        currentVersion: '1.2.0+7',
        release: release,
      );

      expect(result.status, AppUpdateStatus.available);
      expect(result.updateAvailable, isTrue);
    });

    test('marks same version with newer build metadata as available', () {
      final release = GitHubReleaseInfo.fromJson({
        'tag_name': 'v1.3.0+9',
        'name': 'DDoge v1.3.0 build 9',
        'body': '',
        'assets': [
          {
            'name': 'ddoge-v1.3.0.apk',
            'browser_download_url': 'https://example.com/ddoge.apk',
            'size': 42,
          },
        ],
      });

      final result = AppUpdateCheckResult.fromRelease(
        currentVersion: '1.3.0+8',
        release: release,
      );

      expect(result.status, AppUpdateStatus.available);
      expect(result.updateAvailable, isTrue);
    });

    test('keeps equal versions up to date', () {
      final release = GitHubReleaseInfo.fromJson({
        'tag_name': 'v1.2.0',
        'name': 'DDoge v1.2.0',
        'body': '',
        'assets': [
          {
            'name': 'ddoge-v1.2.0.apk',
            'browser_download_url': 'https://example.com/ddoge.apk',
            'size': 42,
          },
        ],
      });

      final result = AppUpdateCheckResult.fromRelease(
        currentVersion: '1.2.0+7',
        release: release,
      );

      expect(result.status, AppUpdateStatus.upToDate);
      expect(result.updateAvailable, isFalse);
    });
  });
}
