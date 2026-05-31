# DDoge AI Review Log

## 2026-05-31 - Android In-App Update UI

### Gemini Pre-Implementation UI Guidance

Prompt summary:

- Flutter Material 3 settings UI.
- Add an in-app update feature that checks GitHub Releases and downloads/installs an APK.
- Existing Chinese settings sections: 学期管理, 课前提醒, 个性化, 外观, 数据与导入, 关于.

Relevant guidance received:

- Put the entry in the "关于" section.
- Use a `ListTile` with `Icons.system_update` or `Icons.browser_updated`.
- Show current version in the default subtitle.
- Use a progress indicator while checking.
- Show an update-available state with a visible "NEW" badge.
- Show a confirmation dialog with release notes before downloading.
- Do not show the APK installer path on iOS.
- Declare install permission and handle Android installation restrictions.
- Avoid checking GitHub on every settings page build.

Implementation response:

- Added a manual "检查更新" tile under "关于".
- The tile is Android-only.
- It checks only when tapped.
- It shows checking and download progress states.
- It shows release notes before download.
- It uses Android install permission and a FileProvider bridge.

### Gemini Post-Implementation Review

Relevant feedback received:

- Placement in "关于" matches Android and Material 3 expectations.
- Move the `NEW` badge from the trailing chevron to the leading update icon.
- Replace technical wording such as "没有可安装的 Android APK" with friendlier user text.
- Show downloaded bytes and total size during APK download.
- Consider a later lifecycle improvement so returning from install-permission settings can resume automatically.

Implementation response:

- Moved the `NEW` badge to the leading update icon.
- Changed up-to-date and missing-APK text to more direct user wording.
- Added downloaded-size / total-size progress text.
- Added Android lifecycle handling so returning from the install-permission settings screen can continue the pending download.

### Subagent Review

Product/UX feedback applied:

- Localized the badge from `NEW` to `新`.
- Changed the primary dialog action from `立即更新` to `下载并安装`.
- Reworded install-permission text to explain Android's system setting.
- Replaced raw exception snackbars with friendlier network, GitHub, and installer error messages.
- Added resume-after-permission behavior.

Release/QA feedback applied:

- Removed `beta` wording from `1.3.0` docs because the updater uses GitHub's latest-release endpoint.
- Documented that `v1.3.0` must be published as non-draft and non-prerelease.
- Documented the current debug-signing constraint and the need for durable release signing before CI or machine changes.
- Added version build-number comparison and passed `version+buildNumber` into the update check so same-name higher-build releases can be detected when tags include build metadata.

Deferred to later versions:

- Markdown release-note rendering.
- GitHub release-page fallback actions.
- Mobile-data warning and cancel/retry download controls.
- Release-channel support.
- Tag-driven Android release CI.
