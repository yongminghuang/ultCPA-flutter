# Mine Customer Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking. This migration batch remains
> intentionally uncommitted; do not stage or commit.

**Goal:** Reproduce Android's reachable Mine customer-service action, including
the signed URL lookup, silent fallback, and WeChat mini-program launch.

**Architecture:** A small Dart repository reads the URL through the shared
signed API client. A coordinator owns fallback policy and calls a MethodChannel
gateway; a focused Kotlin bridge owns the WeChat SDK request. Mine owns action
busy/error UI and Startup composes the real dependencies.

**Tech Stack:** Flutter 3.32/Dart 3.8, Dio-backed `AppApiClient`, Flutter
MethodChannel, Kotlin, WeChat Open SDK 6.8.30, flutter_test.

---

### Task 1: Customer URL and fallback coordinator

**Files:**
- Create: `lib/src/customer_service/customer_service_data_source.dart`
- Create: `lib/src/customer_service/customer_service_launcher.dart`
- Create: `test/customer_service/customer_service_data_source_test.dart`
- Create: `test/customer_service/customer_service_launcher_test.dart`

- [x] **Step 1: Write failing repository and coordinator tests**

Require `getBody('/app/v2/getWxCustomerUrl')` with no query, accept only a
nullable string body, preserve a non-empty URL exactly, and use the fixed
fallback for null, empty, malformed, unsuccessful, or thrown remote results.
Require platform launch errors to propagate instead of being swallowed.

- [x] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\customer_service\customer_service_data_source_test.dart test\customer_service\customer_service_launcher_test.dart
```

Expected: the customer-service libraries and types do not exist.

- [x] **Step 3: Implement the minimal repository and coordinator**

Define `CustomerServiceDataSource`, `AppApiCustomerServiceDataSource`,
`CustomerServiceMiniProgramGateway`, `MethodChannelCustomerServiceGateway`,
and `CustomerServiceCoordinator`. Keep the fallback catch around remote lookup
only so a platform failure reaches Mine.

- [x] **Step 4: Run Step 2 and verify GREEN**

### Task 2: Android WeChat bridge contract

**Files:**
- Create: `android/app/src/main/kotlin/com/xmzj/ult/agg/MineActionsBridge.kt`
- Modify: `android/app/src/main/kotlin/com/xmzj/ult/agg/MainActivity.kt`
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `test/config/android_shell_config_test.dart`

- [x] **Step 1: Write failing Android-shell contract tests**

Pin the channel and method, non-empty URL validation, fixed app ID and original
ID, `Uri.encode`, exact mini-program path, `dev` preview versus other-flavor
release, installed-WeChat check, rejected-request error, MainActivity
registration, SDK `6.8.30`, and the `com.tencent.mm` manifest query.

- [x] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\config\android_shell_config_test.dart
```

Expected: `MineActionsBridge.kt` is absent and the new assertions fail.

- [x] **Step 3: Implement the minimal native bridge and configuration**

Create the WeChat request in Kotlin, register it beside the existing bridges,
add the exact SDK dependency, and add package visibility without changing the
Android reference project.

- [x] **Step 4: Run Step 2 and verify GREEN**

### Task 3: Mine action and MainTabs forwarding

**Files:**
- Modify: `lib/src/main_tabs/mine_tab_page.dart`
- Modify: `lib/src/main_tabs/main_tabs_page.dart`
- Modify: `test/main_tabs/mine_tab_page_test.dart`
- Modify: `test/main_tabs/main_tabs_page_test.dart`

- [x] **Step 1: Write failing widget tests**

Require the keyed row to launch for both login states without invoking login,
show one busy indicator, ignore a second tap until completion, recover after
success, show the stable platform-error message, avoid stale post-dispose UI,
and forward the callback through MainTabs.

- [x] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\main_tabs\mine_tab_page_test.dart test\main_tabs\main_tabs_page_test.dart
```

- [x] **Step 3: Implement action state and forwarding**

Add `MineCustomerServiceLauncher`, one in-flight flag in `MineTabPage`, a keyed
interactive row, guarded async handling, and the corresponding optional
`MainTabsPage` callback.

- [x] **Step 4: Run Step 2 and verify GREEN**

### Task 4: Startup composition, exports, and migration evidence

**Files:**
- Modify: `lib/src/app/startup_app.dart`
- Modify: `lib/ultcpa_flutter.dart`
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/app/startup_app_test.dart`
- Create: `test/customer_service/customer_service_exports_test.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`

- [x] **Step 1: Write failing integration, export, and ledger tests**

Inject a remote source and platform gateway into Startup, tap the real Mine
row, verify exact remote/fallback launch without navigation or root revision,
require all public customer-service types, and require MainActivity evidence
while preserving its `partial` status and payment statuses.

- [x] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\app\startup_app_test.dart test\customer_service\customer_service_exports_test.dart test\migration\activity_coverage_test.dart
```

- [x] **Step 3: Compose, export, update evidence, and regenerate CSV**

```powershell
dart run tool\migration\source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs\migration\activity_coverage.csv
```

Read generated counts and critical rows. Do not infer them from the in-memory
ledger.

- [x] **Step 4: Run Step 2 and verify GREEN**

### Task 5: Full verification and dev APK

**Files:**
- Verify all files changed above

- [x] **Step 1: Format and check this slice**

Run `dart format`, then repeat with `--output=none --set-exit-if-changed`.

- [x] **Step 2: Run focused and full verification**

```powershell
.\tool\flutter_android21.ps1 test test\customer_service test\main_tabs test\app\startup_app_test.dart test\config\android_shell_config_test.dart test\migration\activity_coverage_test.dart
.\tool\flutter_android21.ps1 test
.\tool\flutter_android21.ps1 analyze
git diff --check
```

- [x] **Step 3: Build and inspect a fresh dev APK**

```powershell
.\tool\flutter_android21.ps1 build apk --debug --flavor dev
```

Record the exact APK bytes and SHA-256, verify CSV counts and the MainActivity
row, and confirm the staged index remains empty. Do not stage or commit.
