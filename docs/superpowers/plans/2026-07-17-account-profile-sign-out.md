# Account Profile And Sign Out Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking. This migration batch remains
> intentionally uncommitted; do not stage or commit.

**Goal:** Reproduce Android's currently reachable read-only account profile
and normal sign-out flow from Mine.

**Architecture:** A focused account-profile feature composes a dispatch-only
Dio logout gateway with an extension of the existing account MethodChannel and
the shared device-session initializer. A typed route result flows from the
profile page through Mine to Startup, which recreates MainTabs from native
state after local cleanup succeeds.

**Tech Stack:** Flutter 3.32/Dart 3.8, Material widgets, Dio, MethodChannel,
Clipboard, Android Kotlin/MMKV/SharedPreferences, flutter_test.

---

### Task 1: Profile models, exact logout dispatch, and repository sequencing

**Files:**
- Create: `lib/src/account_profile/account_profile_models.dart`
- Create: `lib/src/account_profile/account_sign_out_gateway.dart`
- Create: `lib/src/account_profile/account_profile_data_source.dart`
- Create: `test/account_profile/account_sign_out_gateway_test.dart`
- Create: `test/account_profile/account_profile_data_source_test.dart`

- [ ] **Step 1: Write failing gateway and repository tests**

Define the wished-for snapshot and interfaces in tests. Pin
`/app/user/v1/logout`, POST data `''`, JSON content type, signed headers, and
the fact that gateway completion means request dispatch rather than response
completion. Require headers to resolve before native cleanup. Require remote
context, dispatch, or response failure not to block cleanup; cleanup failure
must not report success; anonymous refresh failure must remain best effort.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\account_profile\account_sign_out_gateway_test.dart test\account_profile\account_profile_data_source_test.dart
```

Expected: account-profile libraries do not exist.

- [ ] **Step 3: Implement the minimal contracts**

Define:

```dart
final class AccountProfileSnapshot {
  const AccountProfileSnapshot({
    required this.isLoggedIn,
    required this.userId,
    required this.nickname,
    required this.avatar,
  });
  final bool isLoggedIn;
  final String userId;
  final String nickname;
  final String avatar;
}

enum AccountProfileResult { signedOut }
```

`DioAccountSignOutGateway.dispatch()` must await URL and header providers,
start the Dio POST, swallow its eventual response error, and return immediately.
`AccountProfileRepository.signOut()` catches gateway launch failures, awaits
native cleanup, and swallows only anonymous refresh failures.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 2: Extend the Android account bridge

**Files:**
- Modify: `android/app/src/main/kotlin/com/xmzj/ult/agg/AccountSafetyBridge.kt`
- Modify: `test/config/android_shell_config_test.dart`
- Test: `test/account_profile/account_profile_data_source_test.dart`

- [ ] **Step 1: Write failing channel and native-source contract tests**

Require exact calls `readAccountProfile` and `clearSignedOutSession`; strict
Dart parsing of all four fields; native reads of login, nickname, avatar, and
`userIdString`; and cleanup of authorization, phone, nickname, avatar, login,
VIP, benefits, ad-VIP, login history, last-login type, and user ID. Pin
`isTemp = 1` and `LogOut = true`. Preserve existing deactivation methods.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\account_profile\account_profile_data_source_test.dart test\config\android_shell_config_test.dart
```

Expected: new channel methods and profile fields are absent.

- [ ] **Step 3: Implement the bridge extension**

Reuse the registered `com.xmzj.ult.agg/account_safety` channel. Factor a
private hardened session-clear helper only if it preserves the existing
deactivation contract exactly. Convert exceptions to the existing structured
`account_safety_error` result.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 3: Read-only account profile page

**Files:**
- Create: `lib/src/account_profile/account_profile_page.dart`
- Create: `test/account_profile/account_profile_page_test.dart`

- [ ] **Step 1: Write failing page tests**

Cover loading, retry, stale load, back, exact title and visible rows, absence of
phone/WeChat/edit controls, avatar fallback, disabled empty ID, copying the
full ID with `已复制userId`, the exact sign-out dialog, cancel, not-logged-in
guard, duplicate confirmation/submission guard, progress, cleanup error, typed
success result, and a 320 by 568 viewport.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\account_profile\account_profile_page_test.dart
```

Expected: `AccountProfilePage` is undefined.

- [ ] **Step 3: Implement the page state machine**

Use stable Material rows, a circular network avatar with glyph fallback,
`Clipboard.setData`, one dialog flag, one submission flag, a modal progress
barrier, mounted/generation guards, and `AccountProfileResult.signedOut` only
after local cleanup completes.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 4: Mine and Startup route-result integration

**Files:**
- Modify: `lib/src/main_tabs/mine_tab_page.dart`
- Modify: `lib/src/main_tabs/main_tabs_page.dart`
- Modify: `lib/src/app/startup_app.dart`
- Modify: `test/main_tabs/mine_tab_page_test.dart`
- Modify: `test/main_tabs/main_tabs_page_test.dart`
- Modify: `test/app/startup_app_test.dart`

- [ ] **Step 1: Write failing routing tests**

Require the signed-in profile band to call a profile launcher once, while the
signed-out band still calls login. Require MainTabs to forward the launcher.
Require Startup's default launcher to push the real profile page, injected
launchers to remain supported, and `main-tabs-0` to become `main-tabs-1` only
after `AccountProfileResult.signedOut`.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\main_tabs\mine_tab_page_test.dart test\main_tabs\main_tabs_page_test.dart test\app\startup_app_test.dart
```

- [ ] **Step 3: Wire runtime dependencies and results**

Construct the profile repository from Startup's existing Dio, request context,
native channel, and `DeviceSessionInitializer`. Pass a profile launcher through
MainTabs. On a signed-out result, increment the same `_mainTabsRevision` used by
deactivation; ordinary returns do nothing.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 5: Public exports and migration ledger

**Files:**
- Create: `test/account_profile/account_profile_exports_test.dart`
- Modify: `lib/ultcpa_flutter.dart`
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`

- [ ] **Step 1: Write failing export and ledger tests**

Require public profile models/interfaces/page, complete evidence for
`AccountActivityNew`, updated Main/Mine evidence, and unchanged pending status
for dormant account binding and replacement activities.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\account_profile\account_profile_exports_test.dart test\migration\activity_coverage_test.dart
```

- [ ] **Step 3: Export, update reviewed coverage, and regenerate CSV**

```powershell
dart run tool\migration\source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs\migration\activity_coverage.csv
```

Check the generated disposition and migration-status totals rather than
assuming the previous counts.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 6: Full verification and dev APK

**Files:**
- Verify all files changed above

- [ ] **Step 1: Format this slice and integration files**

Run `dart format` on profile, Mine, MainTabs, Startup, exports, tests, and
migration files. Re-run with `--output=none --set-exit-if-changed`.

- [ ] **Step 2: Run focused and full verification**

```powershell
.\tool\flutter_android21.ps1 test test\account_profile test\main_tabs test\app\startup_app_test.dart test\config\android_shell_config_test.dart test\migration\activity_coverage_test.dart
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
