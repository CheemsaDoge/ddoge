# DDoge

DDoge 是一个基于 Flutter 开发的课程表应用，面向校园场景，支持手动编辑课程、教务系统导入、课前提醒、课表样式自定义和数据导入导出。

当前版本：`1.1.4`

## 功能

- 周课表、今日课程双视图
- 学期管理与节次时间自定义
- 手动添加、编辑、删除课程
- 从教务系统页面导入课程
- 课前提醒与桌面小组件刷新
- 课表背景、网格线、卡片样式、自适应一屏等个性化设置
- 课程数据与样式数据导入导出

## 技术栈

- Flutter
- Riverpod
- Drift + SQLite
- GoRouter
- flutter_inappwebview
- SharedPreferences

## 目录结构

```text
lib/
  app.dart
  core/
    constants/
    router/
    storage/
    theme/
    utils/
  data/
    database/
    services/
  features/
    course_editor/
    import/
    notification/
    schedule/
    settings/
    today/
  shared/
    widgets/
```

## 开发环境

- Flutter SDK：建议使用本机当前已验证可用的 `D:\flutter`
- Dart SDK：随 Flutter
- Android Studio JBR
- Android SDK

本项目当前在 Windows + Android 环境下持续开发和验证。

## 本地运行

进入项目目录：

```powershell
cd D:\dev\ddoge
```

安装依赖：

```powershell
flutter pub get
```

调试运行：

```powershell
flutter run
```

## 构建 APK

当前已验证可用的 Windows 命令：

```powershell
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
$env:ANDROID_HOME='C:\Users\ywjhn\Android\Sdk'
$env:PUB_CACHE='D:\pub-cache'
$env:PATH='D:\flutter\bin;C:\Program Files\Git\cmd;C:\Users\ywjhn\Android\Sdk\cmdline-tools\latest\bin;C:\Users\ywjhn\Android\Sdk\platform-tools;C:\Program Files\Android\Android Studio\jbr\bin;' + $env:PATH
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
& 'D:\flutter\bin\flutter.bat' build apk --release
```

构建产物：

`build/app/outputs/flutter-apk/app-release.apk`

## 教务系统导入说明

- 入口统一为“从教务系统导入”
- 应用会打开内置浏览器，由用户自行登录并进入课表页面
- 导入页每次进入会清理缓存、Cookie 和 Web Storage
- 对 `target="_blank"` / `window.open()` 弹出的页面会尽量接管到当前页打开
- 进入查询结果页后，点击“导入当前页面”完成导入

## 数据导入导出

支持按分类导出：

- 学期
- 节次
- 提醒
- 课表显示样式
- 课程信息

导入时会按 JSON 中实际包含的内容恢复，兼容旧版仅课程数据的导出文件。

## iOS 适配现状

项目已经包含 `ios/` 工程，但目前主要验证平台是 Android。  
理论上这是 Flutter 项目，基础页面迁移成本不高，但通知、小组件、文件选择、WebView 行为和教务系统导入兼容性都需要单独测试和补适配。

## 注意事项

- 仓库外的开发记录文件位于 `D:\dev\ddoge_dev_notes.md`
- `plan.md`、`uestc-eams-api.md` 是本地笔记，不属于正式项目文件
- 不要在仓库中保存 GitHub Token 等敏感信息
