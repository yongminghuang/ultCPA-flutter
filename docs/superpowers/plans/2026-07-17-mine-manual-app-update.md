# Mine Manual App Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking. This migration batch remains
> intentionally uncommitted; do not stage or commit.

**Goal:** Reproduce Android's reachable Mine manual app-update flow through
version lookup, update presentation, target routing, APK download, and install.

**Architecture:** Pure Dart models and a repository own version policy; a
testable Dio/native transfer owns platform handoff; a focused dialog owns
state; Mine/MainTabs/Startup forward one launcher without rebuilding tabs.

**Tech Stack:** Flutter 3.32/Dart 3.8, Material, Dio 5.9, Flutter
MethodChannel, Kotlin/FileProvider, flutter_test.

---

### Task 1: Update models and exact repository request

**Files:**
- Create: `lib/src/app_update/app_update_models.dart`
- Create: `lib/src/app_update/app_update_repository.dart`
- Create: `test/app_update/app_update_models_test.dart`
- Create: `test/app_update/app_update_repository_test.dart`

- [x] **Step 1: Write failing model and repository tests**

Pin latest/update results, scalar parsing, target precedence, case-insensitive
APK paths with query strings, relative URL resolution and fallback, plus the
exact signed `GET /currency/version` query order and snapshot values.

- [x] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\app_update\app_update_models_test.dart test\app_update\app_update_repository_test.dart
```

Expected: the app-update libraries do not exist.

- [x] **Step 3: Implement immutable results and repository**

Use `AppApiClient`, `LegacyAppStateStore`, and `AppIdentity.versionName`.
Return latest only for an explicit false update flag; reject malformed update
bodies so Mine can restore silently.

- [x] **Step 4: Run Step 2 and verify GREEN**

### Task 2: Download transfer and Android platform bridge

**Files:**
- Create: `lib/src/app_update/app_update_file_transfer.dart`
- Create: `test/app_update/app_update_file_transfer_test.dart`
- Modify: `android/app/src/main/kotlin/com/xmzj/ult/agg/MineActionsBridge.kt`
- Modify: `android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/res/xml/pre_exam_six_paper_file_paths.xml`
- Modify: `test/config/android_shell_config_test.dart`

- [x] **Step 1: Write failing transfer and native contract tests**

Require `appChannel` snapshot export, the four exact MethodChannel methods,
Dio bytes/progress, external/market/install forwarding, update directory
confinement, canonical APK validation, FileProvider exposure, and install
permission.

- [x] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\app_update\app_update_file_transfer_test.dart test\config\android_shell_config_test.dart
```

- [x] **Step 3: Implement the transfer and minimal native capabilities**

Generate update files below `externalFilesDir/update`, validate installation
paths against that canonical directory, grant read permission through
FileProvider, and preserve market fallback to the Tencent web listing.

- [x] **Step 4: Run Step 2 and verify GREEN**

### Task 3: Android-compatible update dialog

**Files:**
- Create: `lib/src/app_update/app_update_dialog.dart`
- Create: `test/app_update/app_update_dialog_test.dart`

- [x] **Step 1: Write failing widget tests**

Require exact copy and versions, optional close, forced barrier/back blocking,
external and market dismissal, APK progress, automatic install, install retry,
download-failure dismissal, single action, safe disposal, and 320 by 568 fit.

- [x] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\app_update\app_update_dialog_test.dart
```

- [x] **Step 3: Implement the dialog state machine**

Keep the dialog focused on presentation and transfer calls. Do not introduce
proactive checks or payment behavior.

- [x] **Step 4: Run Step 2 and verify GREEN**

### Task 4: Mine, MainTabs, and Startup integration

**Files:**
- Modify: `lib/src/main_tabs/mine_tab_page.dart`
- Modify: `lib/src/main_tabs/main_tabs_page.dart`
- Modify: `lib/src/app/startup_app.dart`
- Modify: `test/main_tabs/mine_tab_page_test.dart`
- Modify: `test/main_tabs/main_tabs_page_test.dart`
- Modify: `test/app/startup_app_test.dart`

- [x] **Step 1: Write failing integration tests**

Require the keyed row in Android order for both login states, no login gate,
single in-flight check, silent failure recovery, MainTabs forwarding, Startup
latest feedback, real optional/forced dialog routing, and unchanged tab state.

- [x] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\main_tabs\mine_tab_page_test.dart test\main_tabs\main_tabs_page_test.dart test\app\startup_app_test.dart
```

- [x] **Step 3: Wire the typed launcher end to end**

Inject update data/transfer boundaries in Startup tests and construct real
defaults from the shared API client, legacy state store, Dio, and native bridge.

- [x] **Step 4: Run Step 2 and verify GREEN**

### Task 5: Public exports and migration evidence

**Files:**
- Modify: `lib/ultcpa_flutter.dart`
- Create: `test/app_update/app_update_exports_test.dart`
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`

- [x] **Step 1: Write failing export and ledger tests**

Require the public model/repository/dialog/transfer surface and MainActivity
manual-update evidence while retaining partial status, proactive/payment
pending evidence, and unchanged overall migration counts.

- [x] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\app_update\app_update_exports_test.dart test\migration\activity_coverage_test.dart
```

- [x] **Step 3: Export, update evidence, and regenerate CSV**

```powershell
dart run tool\migration\source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs\migration\activity_coverage.csv
```

- [x] **Step 4: Run Step 2 and verify GREEN**

### Task 6: Full verification and dev APK

**Files:**
- Verify all files changed above

- [x] **Step 1: Format and check this slice**

Run `dart format`, then repeat with `--output=none --set-exit-if-changed`.

- [x] **Step 2: Run focused and full verification**

```powershell
.\tool\flutter_android21.ps1 test test\app_update test\main_tabs test\app\startup_app_test.dart test\config\android_shell_config_test.dart test\migration\activity_coverage_test.dart
.\tool\flutter_android21.ps1 test
.\tool\flutter_android21.ps1 analyze
git diff --check
```

- [x] **Step 3: Build and inspect a fresh dev APK**

```powershell
.\tool\flutter_android21.ps1 build apk --debug --flavor dev
```

Record exact APK bytes and SHA-256, verify critical ledger rows, and confirm
the staged index remains empty. Do not stage or commit.
