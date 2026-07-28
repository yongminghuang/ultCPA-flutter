# Account Safety And Deactivation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking. This migration batch remains
> intentionally uncommitted; do not stage or commit.

**Goal:** Reproduce Android's currently reachable account-safety and account
deactivation flow, including exact confirmation, server, legacy-session, and
root-refresh behavior.

**Architecture:** A focused account-safety feature composes a Dio deactivation
gateway with a MethodChannel legacy store and the shared device-session
initializer. Two Material pages return a typed deactivation result through
Settings to Startup, which recreates MainTabs from native state.

**Tech Stack:** Flutter 3.32/Dart 3.8, Material widgets, Dio, MethodChannel,
Android Kotlin/MMKV/SharedPreferences, flutter_test.

---

### Task 1: Models, exact remote request, and repository ordering

**Files:**
- Create: `lib/src/account_safety/account_safety_models.dart`
- Create: `lib/src/account_safety/account_deactivation_gateway.dart`
- Create: `lib/src/account_safety/account_safety_data_source.dart`
- Create: `test/account_safety/account_deactivation_gateway_test.dart`
- Create: `test/account_safety/account_safety_data_source_test.dart`

- [ ] **Step 1: Write failing gateway and repository tests**

Pin `/app/user/deactivate`, signed headers, POST data `''`, codes 200/2001,
server error propagation, snapshot loading, and this order:

```dart
await remote.deactivate();
await nativeStore.clearDeactivatedSession();
try {
  await refreshDeviceSession();
} catch (_) {}
```

Remote failure must skip cleanup and refresh. Cleanup failure must skip refresh.
Refresh failure must still complete after cleanup.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\account_safety\account_deactivation_gateway_test.dart test\account_safety\account_safety_data_source_test.dart
```

Expected: account-safety libraries do not exist.

- [ ] **Step 3: Implement the minimal contracts**

Define:

```dart
final class AccountSafetySnapshot {
  const AccountSafetySnapshot({required this.isLoggedIn, required this.phone});
  final bool isLoggedIn;
  final String phone;
}

enum AccountSafetyResult { deactivated }

abstract interface class AccountSafetyDataSource {
  Future<AccountSafetySnapshot> load();
  Future<void> deactivateAccount();
}
```

Use a dedicated Dio gateway so the empty-string body is not weakened to `{}`.
Implement strict MethodChannel snapshot parsing and repository sequencing.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 2: Shared device-session initializer

**Files:**
- Modify: `lib/src/startup/startup_remote_initializer.dart`
- Modify: `test/startup/startup_remote_initializer_test.dart`

- [ ] **Step 1: Write a failing device-only initialization test**

Require `DeviceSessionInitializer.initialize()` to call only
`/app/device/hardware/<suffix>`, send the encrypted body, validate the envelope,
and persist `accessToken` plus `user.id`.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\startup\startup_remote_initializer_test.dart
```

Expected: `DeviceSessionInitializer` is undefined.

- [ ] **Step 3: Extract device login without changing startup behavior**

`StartupRemoteInitializer` still loads static dictionaries first, then delegates
hardware login to the extracted initializer. Keep UUID suffix generation and
all response checks in one implementation.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 3: Android legacy account-safety bridge

**Files:**
- Create: `android/app/src/main/kotlin/com/xmzj/ult/agg/AccountSafetyBridge.kt`
- Modify: `android/app/src/main/kotlin/com/xmzj/ult/agg/MainActivity.kt`
- Modify: `test/config/android_shell_config_test.dart`

- [ ] **Step 1: Write a failing native-source contract test**

Require channel `com.xmzj.ult.agg/account_safety`, both methods, MMKV IDs
`mmkvLazy` and `User`, every Android cleanup key, `isTemp = 1`, cleared
`userIdString`, `LogOut = true`, and MainActivity registration.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\config\android_shell_config_test.dart
```

Expected: `AccountSafetyBridge.kt` is absent.

- [ ] **Step 3: Implement and register the bridge**

Return strict booleans/strings, remove the reviewed legacy keys atomically as
far as MMKV permits, synchronously commit SharedPreferences, and convert native
exceptions to structured channel errors.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 4: Account safety summary page

**Files:**
- Create: `lib/src/account_safety/account_safety_page.dart`
- Create: `test/account_safety/account_safety_page_test.dart`

- [ ] **Step 1: Write failing page tests**

Cover loading, retry, stale load, exact visible rows, hidden WeChat and phone
actions, Android phone masking, back, deactivation result forwarding, and a
320 by 568 viewport.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\account_safety\account_safety_page_test.dart
```

Expected: `AccountSafetyPage` is undefined.

- [ ] **Step 3: Implement the page**

Render a white AppBar and stable 52-pixel rows on `0xFFF3F3F3`. The phone row
has no tap target or arrow. Push `AccountDeactivationPage` from the deactivation
row and pop the page when it returns `AccountSafetyResult.deactivated`.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 5: Notice and two-stage confirmation

**Files:**
- Create: `lib/src/account_safety/account_deactivation_page.dart`
- Create: `test/account_safety/account_deactivation_page_test.dart`

- [ ] **Step 1: Write failing interaction tests**

Pin notice copy, first dialog actions, second dialog copy, exact trimmed phrase,
wrong-input error, disabled/enabled confirmation, duplicate guard, progress,
server/local failure message, success result, back/cancel, and narrow viewport
with keyboard insets.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\account_safety\account_deactivation_page_test.dart
```

Expected: the page and dialogs are undefined.

- [ ] **Step 3: Implement the state machine**

Use two Material dialogs, a disposable `TextEditingController`, an exact
trimmed equality check, one in-flight submission flag, and mounted checks.
Return `AccountSafetyResult.deactivated` only after the repository succeeds.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 6: Settings and Startup route-result integration

**Files:**
- Modify: `lib/src/settings/settings_navigation.dart`
- Modify: `lib/src/settings/settings_page.dart`
- Modify: `lib/src/app/startup_app.dart`
- Modify: `test/settings/settings_page_test.dart`
- Modify: `test/app/startup_app_test.dart`

- [ ] **Step 1: Write failing propagation tests**

Require the launcher to return `AccountSafetyResult?`, Settings to pop on
deactivation, Startup's default launcher to push the real page, injected
launchers to remain supported, and the ready `MainTabsPage` key/repository load
to refresh after deactivation but not after ordinary back.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\settings\settings_page_test.dart test\app\startup_app_test.dart
```

- [ ] **Step 3: Wire runtime dependencies and results**

Construct one native store, Dio gateway, repository, and device initializer
from Startup's existing Dio/request context. Pass the default launcher to
Settings, await the route result, and increment a MainTabs revision key only
for deactivation.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 7: Exports and migration ledger

**Files:**
- Create: `test/account_safety/account_safety_exports_test.dart`
- Modify: `lib/ultcpa_flutter.dart`
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`

- [ ] **Step 1: Write failing export and ledger tests**

Require public models/interfaces/pages, complete entries for
`AccountSettingActivity` and `AccountUnbindSettingActivity`, updated
`SettingActivity` and `MainActivity` evidence, and unchanged pending dormant
binding/replacement activities.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\account_safety\account_safety_exports_test.dart test\migration\activity_coverage_test.dart
```

- [ ] **Step 3: Export, update reviewed progress, and regenerate CSV**

```powershell
dart run tool\migration\source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs\migration\activity_coverage.csv
```

Expected disposition totals remain `77/69/3/3/2`.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 8: Full verification and dev APK

**Files:**
- Verify all files changed above

- [ ] **Step 1: Format this slice and integration files**

Run `dart format` across account safety, Startup, Settings, exports, tests, and
migration files. Re-run with `--output=none --set-exit-if-changed`.

- [ ] **Step 2: Run focused and full verification**

```powershell
.\tool\flutter_android21.ps1 test test\account_safety test\settings test\startup\startup_remote_initializer_test.dart test\config\android_shell_config_test.dart test\app\startup_app_test.dart test\migration\activity_coverage_test.dart
.\tool\flutter_android21.ps1 test
.\tool\flutter_android21.ps1 analyze
git diff --check
```

- [ ] **Step 3: Build and inspect a fresh dev APK**

```powershell
.\tool\flutter_android21.ps1 build apk --debug --flavor dev
```

Record exact APK bytes and SHA-256, verify CSV counts and account rows, and
confirm the staged index remains empty. Do not stage or commit.
