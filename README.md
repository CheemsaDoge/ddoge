# DDoge

DDoge is a Flutter timetable app for campus life. It supports weekly and daily schedule views, semester management, manual course editing, academic-system import, class reminders, widgets, and detailed timetable personalization.

Current version: `1.3.0`

[中文说明](README_Zh.md)

## Features

- Weekly timetable and today's classes
- Semester management with configurable start date and total weeks
- Manual course add, edit, and delete flows
- Academic-system import with a UESTC EAMS adapter
- Class time-slot editing and reusable time-slot templates
- Pre-class reminders and home-screen widget refresh
- Theme, background, grid line, card radius, opacity, and font-scale settings
- Course, semester, time-slot, reminder, and style data import/export
- Android in-app update check from the latest GitHub Release APK

## Tech Stack

- Flutter and Dart
- Riverpod
- Drift + SQLite
- GoRouter
- Dio
- flutter_inappwebview
- SharedPreferences

## Project Layout

```text
lib/
  core/          constants, routing, storage, theme, utilities
  data/          database, DAOs, services
  features/      feature modules
  shared/        shared UI components
assets/          images and wallpapers
android/         Android project
ios/             iOS project
web/             Web project
windows/         Windows project
test/            tests
docs/            planning, handoff, release notes, AI review logs
```

## Development

Expected toolchain:

- Flutter 3.x
- Dart 3.x
- Android Studio or an equivalent Android SDK setup

On this Windows workstation the known working Flutter path is `D:\flutter\bin`.

```powershell
cd D:\dev\ddoge
& 'D:\flutter\bin\flutter.bat' pub get
& 'D:\flutter\bin\flutter.bat' test
& 'D:\flutter\bin\flutter.bat' analyze
```

## Build Android APK

If Flutter, JBR, and Android SDK are not already on `PATH`, set them in PowerShell first:

```powershell
$env:JAVA_HOME='D:\Code\java'
$env:ANDROID_HOME='D:\Tools\AndroidSdk'
$env:ANDROID_SDK_ROOT='D:\Tools\AndroidSdk'
$env:PUB_CACHE='D:\pub-cache'
$env:PATH='D:\flutter\bin;D:\Tools\AndroidSdk\cmdline-tools\latest\bin;D:\Tools\AndroidSdk\platform-tools;D:\Code\java\bin;C:\Program Files\Git\cmd;' + $env:PATH
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
flutter build apk --release
```

Default output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Android In-App Updates

The Android app checks:

```text
https://api.github.com/repos/CheemsaDoge/ddoge/releases/latest
```

The latest release must be a non-draft, non-prerelease GitHub Release because the app uses GitHub's latest-release endpoint. It must include an `.apk` asset, for example `ddoge-v1.3.0.apk`. Users can open Settings, tap "检查更新", review the release notes, download the APK, and confirm installation in the Android system installer.

Required Android pieces are already wired:

- `REQUEST_INSTALL_PACKAGES`
- `FileProvider`
- Flutter method channel `com.ddoge.ddoge/app_update`

## Release Notes

Planning and operational docs:

- [Version Plan](docs/VERSION_PLAN.md)
- [Handoff](docs/HANDOFF.md)
- [AI Review Log](docs/AI_REVIEW_LOG.md)

## Repository Rules

- Keep the repository focused on the Flutter project itself.
- Do not commit local debug caches, temporary plans, credentials, tokens, or account data.
- When changing production behavior, update docs and tests in the same change.
