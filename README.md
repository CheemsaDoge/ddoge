# DDoge

DDoge 是一个基于 Flutter 的课程表应用，面向校园场景，支持周课表、今日课程、教务系统导入、课前提醒和高度可定制的课表样式。

当前版本：`1.2.0 beta`

## 功能

- 周课表与今日课程双视图
- 学期管理
- 手动添加、编辑、删除课程
- 教务系统导入
- 节次时间编辑与模板复用
- 课前提醒与桌面小组件刷新
- 主题、背景、网格线、卡片样式等个性化设置
- 课程、学期、节次与样式数据导入导出

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
```

## 开发环境

- Flutter 3.x
- Dart 3.x
- Android Studio 或同等 Android SDK 环境

当前主要在 Windows + Android 环境下开发和验证。

## 快速开始

```powershell
cd D:\dev\ddoge
flutter pub get
flutter run
```

## 构建 Android APK

如果本机 Flutter、JBR 和 Android SDK 没有预先配置到环境变量，可先在 PowerShell 中设置：

```powershell
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
$env:ANDROID_HOME='C:\Users\ywjhn\Android\Sdk'
$env:PUB_CACHE='D:\pub-cache'
$env:PATH='D:\flutter\bin;C:\Program Files\Git\cmd;C:\Users\ywjhn\Android\Sdk\cmdline-tools\latest\bin;C:\Users\ywjhn\Android\Sdk\platform-tools;C:\Program Files\Android\Android Studio\jbr\bin;' + $env:PATH
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
flutter build apk --release
```

产物默认位于：

`build/app/outputs/flutter-apk/`

## 导入说明

- 入口统一为“从教务系统导入”
- 在内置浏览器中登录并打开课表查询结果页
- 应用会尽量接管当前页内的跳转和弹窗
- 进入结果页后执行导入
- 当前已针对 UESTC EAMS 做了专门适配

## 节次模板

- 节次时间支持按模板复用
- 学期实际生效的节次仍存储在数据库中
- 模板库和学期模板绑定存储在本地设置中
- 可以在节次设置页选择已有模板，或把当前节次另存为模板

## 数据导入导出

支持导出和导入以下数据：

- 学期
- 课程
- 节次时间
- 节次模板与学期模板绑定
- 提醒设置
- 课表显示样式与背景设置

## 仓库约定

- 仓库应保持 Flutter 项目本体整洁
- 本地调试缓存、Playwright 依赖、临时计划文档不应进入仓库
- 不要提交 Token、账号信息或其他敏感数据
