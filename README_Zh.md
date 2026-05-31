# DDoge

DDoge 是一个基于 Flutter 的课程表应用，面向校园场景，支持周课表、今日课程、教务系统导入、课前提醒、桌面小组件和高度可定制的课表样式。

当前版本：`1.3.0`

[English README](README.md)

## 功能

- 周课表与今日课程双视图
- 学期管理：开学日期、总周数、当前学期
- 手动添加、编辑、删除课程
- 教务系统导入，当前已适配 UESTC EAMS
- 节次时间编辑与模板复用
- 课前提醒与桌面小组件刷新
- 主题、背景、网格线、卡片圆角、透明度、字体缩放等个性化设置
- 课程、学期、节次、提醒与样式数据导入导出
- Android 应用内一键检查 GitHub Release，并下载最新 APK 更新

## 技术栈

- Flutter / Dart
- Riverpod
- Drift + SQLite
- GoRouter
- Dio
- flutter_inappwebview
- SharedPreferences

## 目录结构

```text
lib/
  core/          基础常量、路由、存储、主题、工具
  data/          数据库、DAO、服务
  features/      业务功能模块
  shared/        跨模块复用组件
assets/          图片与壁纸资源
android/         Android 工程
ios/             iOS 工程
web/             Web 工程
windows/         Windows 工程
test/            测试
docs/            版本规划、交接文档、发布与 AI 评审记录
```

## 开发环境

- Flutter 3.x
- Dart 3.x
- Android Studio 或同等 Android SDK 环境

当前 Windows 工作站已验证的 Flutter 路径为 `D:\flutter\bin`。

```powershell
cd D:\dev\ddoge
& 'D:\flutter\bin\flutter.bat' pub get
& 'D:\flutter\bin\flutter.bat' test
& 'D:\flutter\bin\flutter.bat' analyze
```

## 构建 Android APK

如果本机 Flutter、JBR 和 Android SDK 没有预先配置到环境变量，可先在 PowerShell 中设置：

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

产物默认位于：

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Android 应用内更新

Android 端会检查：

```text
https://api.github.com/repos/CheemsaDoge/ddoge/releases/latest
```

由于应用使用 GitHub 的 latest release 接口，最新版本必须发布为非草稿、非 prerelease 的 GitHub Release，并包含 `.apk` 资产，例如 `ddoge-v1.3.0.apk`。用户进入“设置”页，点击“检查更新”，确认更新说明后即可下载 APK，并在 Android 系统安装界面确认安装。

已接入的 Android 能力：

- `REQUEST_INSTALL_PACKAGES`
- `FileProvider`
- Flutter method channel `com.ddoge.ddoge/app_update`

## 文档

- [版本规划](docs/VERSION_PLAN.md)
- [交接文档](docs/HANDOFF.md)
- [AI 评审记录](docs/AI_REVIEW_LOG.md)

## 仓库约定

- 仓库应保持 Flutter 项目本体整洁
- 本地调试缓存、临时计划文档、账号数据不应进入仓库
- 不要提交 Token、账号信息或其他敏感数据
- 生产行为变更必须同步更新测试和文档
