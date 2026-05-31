# DDoge Version Plan

Last updated: 2026-05-31

## Version Policy

- Patch versions fix bugs, parser edge cases, build issues, and documentation errors.
- Minor versions add user-visible features, data compatibility improvements, or new platform capabilities.
- Major versions are reserved for changes that reshape core workflows, data models, or visual identity. A 2.0 or 3.0 release should include a migration note and a compatibility audit.
- Every release that should be discoverable by the Android updater must publish a non-draft, non-prerelease GitHub Release with a version tag and an APK asset named like `ddoge-v1.3.0.apk`.

## Current Release Train

### 1.3.0

Scope:

- Android in-app update check from GitHub Releases.
- APK download and handoff to the Android system installer.
- English `README.md`, Chinese `README_Zh.md`, version plan, handoff, and AI review log.
- Test fixes for the existing UESTC parser fixture and widget startup environment.

Release requirements:

- `flutter analyze`
- `flutter test`
- `flutter build apk --release`
- GitHub Release `v1.3.0` with `ddoge-v1.3.0.apk`
- The release must be non-draft and non-prerelease so GitHub's latest-release endpoint returns it.

### 1.4.x Candidate Themes

- Import robustness: more academic-system fixtures, clearer parse error messages, and preview before import.
- Update experience: cached last-check time, release-note formatting, and optional browser fallback to the release page.
- Release hardening: durable release keystore, APK signature checks, and tag-driven Android build automation.
- Backup safety: richer export metadata and import conflict previews.
- Reminder reliability: explicit timezone diagnostics and notification permission checks.

### 2.0 Criteria

Move to 2.0 only when at least one of these is true:

- The course or semester data schema requires a user-facing migration.
- The main schedule interaction model changes substantially.
- The app adds a new primary platform or sync model.
- The visual system is redesigned across the main timetable, settings, import, and editor flows.

## Release Checklist

1. Update `pubspec.yaml` version and visible version strings.
2. Update `README.md`, `README_Zh.md`, and this plan.
3. Run formatter, analyzer, tests, and Android release build.
4. Ask Gemini for UI feedback when UI changes are included, and log the result in `docs/AI_REVIEW_LOG.md`.
5. Ask subagents for bug, product, and code-review feedback after implementation.
6. Commit, tag, push, and create the GitHub Release with the APK asset.
7. Verify `gh release view --repo CheemsaDoge/ddoge vX.Y.Z --json assets` shows the APK asset.
