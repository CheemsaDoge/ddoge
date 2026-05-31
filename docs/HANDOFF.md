# DDoge Handoff

Last updated: 2026-05-31

## Current State

- Repository: `D:\dev\ddoge`
- Remote: `https://github.com/CheemsaDoge/ddoge.git`
- Main branch: `main`
- Current app version: `1.3.0+8`
- Latest previously published release before this work: `v1.2.0`

## Toolchain

Known working local commands:

```powershell
& 'D:\flutter\bin\flutter.bat' pub get
& 'D:\flutter\bin\flutter.bat' analyze
& 'D:\flutter\bin\flutter.bat' test
```

Android release build environment:

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

## Android Update Architecture

Android SDK note:

- The SDK was installed at `D:\Tools\AndroidSdk` with command-line tools, `platform-tools`, `platforms;android-36`, and `build-tools;36.0.0`.
- Flutter was configured with `flutter config --android-sdk D:\Tools\AndroidSdk`.

- UI entry: Settings -> About -> `检查更新`
- Dart service: `lib/data/services/app_update_service.dart`
- Settings tile: `lib/features/settings/widgets/app_update_tile.dart`
- Android method channel: `com.ddoge.ddoge/app_update`
- Native bridge: `android/app/src/main/kotlin/com/ddoge/ddoge/MainActivity.kt`
- FileProvider paths: `android/app/src/main/res/xml/apk_update_paths.xml`

Flow:

1. Read current app version with `package_info_plus`.
2. Call GitHub latest release API for `CheemsaDoge/ddoge`.
3. Parse the release tag and select the first installable APK asset.
4. Compare semantic versions.
5. Show release notes and ask for confirmation.
6. Check Android install permission.
7. Download APK to app cache.
8. Launch the Android package installer through `FileProvider`.

## Test Coverage

- `test/unit/app_update_service_test.dart`
  - version parsing and comparison
  - GitHub Release APK asset selection
  - update availability decision
- Existing tests were repaired where needed:
  - UESTC parser fixture now uses realistic code-like course names.
  - Widget smoke test now overrides `sharedPreferencesProvider` like `main.dart`.

## v1.3.0 APK Verification

- Release asset path: `build/release/ddoge-v1.3.0.apk`
- SHA-256: `3CC219E60B5937A71183CE3E0D51A23A0F8E3577823C197643035AAF7F6C3C8C`
- Package: `com.ddoge.ddoge`
- Version code: `8`
- Version name: `1.3.0`
- minSdk: `24`
- targetSdk: `36`
- Signing certificate SHA-256: `23503d203607c6c5e882aef0b89280f79dc207964667b5e06ca798986e243a46`
- The checked local `ddoge-v1.2.0.apk` has the same signing certificate SHA-256.

## Known Constraints

- Android system rules still require the user to approve unknown-app installation for DDoge before APK installation can proceed.
- The update tile is hidden outside Android because GitHub APK installation is Android-only.
- Release notes are rendered as plain selectable text; markdown rendering can be considered in a later version.
- The current release signing config still uses the debug signing config, matching the pre-existing project setup. The local `v1.3.0` APK must be uploaded as-is for update compatibility with the previous GitHub APK until a durable release keystore migration is planned.
- No Android device was attached during this pass, so the system installer path still needs manual device verification before broad distribution.

## Next Best Iterations

1. Add cached last-check time and a manual "open release page" fallback.
2. Add an Android instrumentation/manual test checklist for install-permission branches.
3. Add a GitHub Actions workflow that builds Android APKs for tags.
4. Improve release-note rendering and mobile-data warning before large APK downloads.
5. Migrate release signing to a durable keystore and document the certificate fingerprint before building APKs from CI or another machine.
