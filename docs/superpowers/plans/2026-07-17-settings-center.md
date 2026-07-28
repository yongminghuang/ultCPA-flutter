# Settings Center Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking. This migration batch remains
> intentionally uncommitted; do not stage or commit.

**Goal:** Make Flutter's Mine settings entry usable with Android-compatible
notification and personalization preferences, cache clearing, privacy, and
about flows.

**Architecture:** A focused `settings` feature owns state, MethodChannel
persistence, and three Material pages. A native `SettingsBridge` writes the
original MMKV keys and performs cache/market/browser actions. Mine and Startup
only compose callbacks and reuse the existing agreement web surface.

**Tech Stack:** Flutter 3.32/Dart 3.8, Material widgets, MethodChannel, Android
Kotlin/MMKV/WebView, existing `AgreementWebViewPage`, flutter_test.

---

### Task 1: Settings snapshot and MethodChannel contract

**Files:**
- Create: `lib/src/settings/settings_models.dart`
- Create: `lib/src/settings/settings_data_source.dart`
- Create: `test/settings/settings_data_source_test.dart`

- [ ] **Step 1: Write failing channel tests**

Pin the channel and every call:

```dart
expect(MethodChannelSettingsDataSource.channelName,
    'com.xmzj.ult.agg/settings');
expect(await source.load(),
    const SettingsSnapshot(
      notificationEnabled: true,
      personalizedRecommendations: false,
    ));
await source.setNotificationEnabled(false);
await source.setPersonalizedRecommendations(true);
await source.clearCaches();
await source.openStoreRating();
await source.openExternalUrl(Uri.parse('https://beian.miit.gov.cn'));
```

Assert exact method names and argument maps. Also require malformed
`readSettings` values and non-HTTP(S) external URLs to throw.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\settings\settings_data_source_test.dart
```

Expected: settings model and data-source files do not exist.

- [ ] **Step 3: Implement the immutable model and interface**

```dart
final class SettingsSnapshot {
  const SettingsSnapshot({
    required this.notificationEnabled,
    required this.personalizedRecommendations,
  });
  final bool notificationEnabled;
  final bool personalizedRecommendations;
}

abstract interface class SettingsDataSource {
  Future<SettingsSnapshot> load();
  Future<void> setNotificationEnabled(bool enabled);
  Future<void> setPersonalizedRecommendations(bool enabled);
  Future<void> clearCaches();
  Future<void> openStoreRating();
  Future<void> openExternalUrl(Uri url);
}
```

Implement `MethodChannelSettingsDataSource` with the exact contract from the
design. Reject missing/non-boolean snapshot fields and non-HTTP(S) URLs.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 2: Android native settings bridge

**Files:**
- Create: `android/app/src/main/kotlin/com/xmzj/ult/agg/SettingsBridge.kt`
- Modify: `android/app/src/main/kotlin/com/xmzj/ult/agg/MainActivity.kt`
- Modify: `test/config/android_shell_config_test.dart`

- [ ] **Step 1: Write a failing native-source contract test**

Require the settings channel, `MMKV("User")`, `NotificationEnabled`,
`MMKV("ad")`, `setIndividuation`, all six methods, WebView/WebStorage cache
clearing, market URI with HTTPS fallback, and registration from MainActivity.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\config\android_shell_config_test.dart
```

Expected: `SettingsBridge.kt` is absent.

- [ ] **Step 3: Implement and register `SettingsBridge`**

Use `MMKV.mmkvWithID("User")` and `MMKV.mmkvWithID("ad")`. Default both
booleans to true. Validate boolean arguments. Clear the `ACache` directory,
WebView cache, and WebStorage. Open market/browser intents with
`FLAG_ACTIVITY_NEW_TASK` and return structured MethodChannel errors for invalid
arguments or unavailable actions.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 3: Main settings page

**Files:**
- Create: `lib/src/settings/settings_page.dart`
- Create: `test/settings/settings_page_test.dart`

- [ ] **Step 1: Write failing state and action tests**

Cover initial loading, retryable read failure, Android row order, notification
toggle persistence and rollback, duplicate clear-cache guard, success/failure
messages, logged-out account guard, logged-in injected account launch, default
pending boundary, back, and 320 by 568 fit.

```dart
expect(find.text('我的设置'), findsOneWidget);
expect(find.byKey(const ValueKey('settings-notification-switch')),
    findsOneWidget);
expect(find.text('清理成功'), findsOneWidget);
```

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\settings\settings_page_test.dart
```

Expected: `SettingsPage` and its launcher types are undefined.

- [ ] **Step 3: Implement page states and actions**

Define injectable agreement and account launchers. Build the white AppBar,
gray background, switch row, and four command rows. Use per-action guards,
mounted checks, rollback on write failure, and stable ValueKeys.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 4: Privacy settings page

**Files:**
- Create: `lib/src/settings/privacy_settings_page.dart`
- Create: `test/settings/privacy_settings_page_test.dart`

- [ ] **Step 1: Write failing tests**

Verify a fresh load, loading/error/retry, exact `个性化推荐` switch, write
rollback, privacy agreement launch identity, back, and narrow viewport.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\settings\privacy_settings_page_test.dart
```

Expected: `PrivacySettingsPage` is undefined.

- [ ] **Step 3: Implement the page**

Use the shared data source, persist only personalization, and call the
agreement launcher with `AgreementDocument.privacyPolicy`.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 5: About page and authoritative icon

**Files:**
- Create: `assets/images/settings/app_icon.png`
- Create: `lib/src/settings/about_page.dart`
- Create: `test/settings/about_page_test.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Write failing identity/action tests**

Pin the icon asset, app/version/build text, user/privacy agreement identities,
market action, Android-equivalent error-report success message, ICP confirm and
external URL, footer strings, back, platform-action failures, and 320 by 568
fit.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\settings\about_page_test.dart
```

Expected: `AboutPage` is undefined.

- [ ] **Step 3: Copy and register the Android icon**

Copy byte-for-byte from:

```text
E:\workspace\ultCPA-android\ultCPA\src\main\res\mipmap-xxxhdpi\ic_launcher.png
```

to `assets/images/settings/app_icon.png` and register the directory.

- [ ] **Step 4: Implement AboutPage**

Use `AppIdentity.versionName` and `versionCode`, exact Android copy, the shared
agreement launcher, native store/external actions, and a confirmation dialog
before the ICP URL.

- [ ] **Step 5: Run Step 2 and verify GREEN**

### Task 6: Compose settings subpages

**Files:**
- Modify: `lib/src/settings/settings_page.dart`
- Modify: `test/settings/settings_page_test.dart`

- [ ] **Step 1: Add failing navigation tests**

Tap `关于我们` and `隐私设置`; require the pages to receive the same data source
and agreement launcher. Back must return to the same settings snapshot.

- [ ] **Step 2: Run and verify RED**

Expected: rows do not yet push the subpages.

- [ ] **Step 3: Push `AboutPage` and `PrivacySettingsPage`**

Use `MaterialPageRoute<void>` and await each route. Do not reload the main
settings snapshot unless its own notification state changed.

- [ ] **Step 4: Run and verify GREEN**

### Task 7: Mine, MainTabs, and Startup composition

**Files:**
- Modify: `lib/src/main_tabs/mine_tab_page.dart`
- Modify: `lib/src/main_tabs/main_tabs_page.dart`
- Modify: `lib/src/app/startup_app.dart`
- Modify: `test/main_tabs/mine_tab_page_test.dart`
- Modify: `test/main_tabs/main_tabs_page_test.dart`
- Modify: `test/app/startup_app_test.dart`

- [ ] **Step 1: Write failing callback-forwarding tests**

Require the keyed Mine settings row to forward the current login state,
MainTabs to preserve the callback, and Startup to push `SettingsPage` with the
injected source. Walk into Privacy/About and verify agreement navigation uses
the existing `AgreementWebViewPage`. Non-settings rows must not load settings.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\main_tabs\mine_tab_page_test.dart test\main_tabs\main_tabs_page_test.dart test\app\startup_app_test.dart
```

Expected: settings launcher parameters and route are absent.

- [ ] **Step 3: Wire all three composition layers**

Add `MineSettingsLauncher`, forward it through MainTabs, construct
`MethodChannelSettingsDataSource` in Startup, and push `SettingsPage` while
preserving injected agreement handling.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 8: Exports and migration ledger

**Files:**
- Create: `test/settings/settings_exports_test.dart`
- Modify: `lib/ultcpa_flutter.dart`
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Modify: `docs/migration/activity_coverage.csv` (generated)

- [ ] **Step 1: Write failing export and ledger tests**

Require all settings models/interfaces/pages/launcher types from the package
barrel. Require `SettingActivity` partial on `SettingsPage`,
`PrivacySettingActivity` complete on `PrivacySettingsPage`,
`FrameLayoutActivity` partial on `AboutPage`, and Main settings evidence.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\settings\settings_exports_test.dart test\migration\activity_coverage_test.dart
```

- [ ] **Step 3: Add exports, reviewed progress, and regenerate CSV**

```powershell
dart run tool\migration\source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs\migration\activity_coverage.csv
```

Expected: `total=77 flutterPage=69 pluginCallback=3 sdkManaged=3 removed=2`.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 9: Full verification and dev APK

**Files:**
- Verify all files changed above

- [ ] **Step 1: Format this slice and integration files**

Run `dart format` over `lib/src/settings`, `test/settings`, the three
composition files/tests, native-contract test, migration files/tests, and the
package barrel.

- [ ] **Step 2: Run focused and full verification**

```powershell
.\tool\flutter_android21.ps1 test test\settings test\config\android_shell_config_test.dart test\main_tabs\mine_tab_page_test.dart test\main_tabs\main_tabs_page_test.dart test\app\startup_app_test.dart test\migration\activity_coverage_test.dart
.\tool\flutter_android21.ps1 test
.\tool\flutter_android21.ps1 analyze
git diff --check
```

- [ ] **Step 3: Build and inspect a fresh dev APK**

```powershell
.\tool\flutter_android21.ps1 build apk --debug --flavor dev
```

Confirm the settings icon is bundled, record exact APK bytes and SHA-256,
validate CSV counts, and run `git status --short`. Do not stage or commit.
