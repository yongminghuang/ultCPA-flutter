# Mine Web Entries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking. This migration batch remains
> intentionally uncommitted; do not stage or commit.

**Goal:** Reproduce Android's reachable Mine collect-book and invite-friends
H5 entries with exact visibility, login, URL, and title-bar behavior.

**Architecture:** Typed Mine route resolution remains pure Dart. Startup and
the native request-context bridge expose the legacy static/referral state, a
reusable `LegacyWebViewPage` owns in-app rendering, and Mine/MainTabs/Startup
forward one typed launcher without rebuilding root navigation.

**Tech Stack:** Flutter 3.32/Dart 3.8, Material, webview_flutter 4.13.1, Dio
`AppApiClient`, Flutter MethodChannel, Kotlin/MMKV, flutter_test.

---

### Task 1: Typed requests and exact URL resolution

**Files:**
- Create: `lib/src/web/legacy_webview_page.dart`
- Create: `lib/src/main_tabs/mine_web_route.dart`
- Create: `test/main_tabs/mine_web_route_test.dart`

- [x] **Step 1: Write failing route tests**

Pin collect-book null/empty/whitespace hiding and trimming; invite activity
visibility; fixed base/title/hidden-title values; parameter order; dev/prod
environment; required empty token; optional role/rate omission; comma, Chinese,
space, plus, and asterisk encoding with Java `URLEncoder` semantics.

- [x] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\main_tabs\mine_web_route_test.dart
```

Expected: typed request and resolver libraries do not exist.

- [x] **Step 3: Implement immutable requests and the pure resolver**

Add `LegacyWebRequest`, `MineWebRouteResolver`, exact constants, and a focused
UTF-8 form encoder. Do not introduce learning-guide behavior.

- [x] **Step 4: Run Step 2 and verify GREEN**

### Task 2: Static dictionary and native referral snapshot

**Files:**
- Modify: `lib/src/startup/startup_remote_initializer.dart`
- Modify: `android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt`
- Modify: `lib/src/network/method_channel_request_context.dart`
- Modify: `test/startup/startup_remote_initializer_test.dart`
- Modify: `test/network/method_channel_request_context_test.dart`
- Modify: `test/config/android_shell_config_test.dart`

- [x] **Step 1: Write failing pipeline contract tests**

Require `collect_book_h5_url` in the exact static request and persisted values;
native clearing/persistence and snapshot export; cached token, role,
commission rate, and `BuildConfig.FLAVOR == "dev"`; and the exact
`persistMineReferralProfile` MethodChannel payload/MMKV keys.

- [x] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\startup\startup_remote_initializer_test.dart test\network\method_channel_request_context_test.dart test\config\android_shell_config_test.dart
```

- [x] **Step 3: Implement the minimal static/snapshot bridge changes**

Preserve all existing keys and defaults. Store collect-book text exactly,
export it for Dart trimming, and persist referral values only after a
successful remote response.

- [x] **Step 4: Run Step 2 and verify GREEN**

### Task 3: Mine repository routes and best-effort role refresh

**Files:**
- Modify: `lib/src/main_tabs/main_tabs_models.dart`
- Modify: `lib/src/main_tabs/main_tabs_repository.dart`
- Modify: `test/main_tabs/main_tabs_models_test.dart`
- Modify: `test/main_tabs/main_tabs_repository_test.dart`

- [x] **Step 1: Write failing model/repository tests**

Require snapshot fields, exact signed `GET /app/user/getUserRole` only while
logged in, response scalar coercion, persistence, cached fallback for every
remote/parse/persist failure, two existing count requests, collect visibility,
and resolved invite parameters.

- [x] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\main_tabs\main_tabs_models_test.dart test\main_tabs\main_tabs_repository_test.dart
```

- [x] **Step 3: Implement route-bearing Mine data**

Replace `showInviteFriends` with nullable typed requests, extend
`AppSnapshot`, add an optional referral persister callback, and keep referral
refresh failures isolated from the Mine page.

- [x] **Step 4: Run Step 2 and verify GREEN**

### Task 4: Reusable in-app WebView

**Files:**
- Complete: `lib/src/web/legacy_webview_page.dart`
- Create: `test/web/legacy_webview_page_test.dart`

- [x] **Step 1: Write failing widget tests**

Require exact visible title and back command, full-screen hidden-title mode,
injected URI content, system back, stable white/progress surface, and a 320 by
568 viewport without overflow.

- [x] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\web\legacy_webview_page_test.dart
```

- [x] **Step 3: Implement the real WebView surface**

Enable JavaScript, load the exact request URI, show top progress, consult web
history before popping, support optional AppBar omission, and keep the content
builder test boundary.

- [x] **Step 4: Run Step 2 and verify GREEN**

### Task 5: Mine, MainTabs, and Startup routing

**Files:**
- Modify: `lib/src/main_tabs/mine_tab_page.dart`
- Modify: `lib/src/main_tabs/main_tabs_page.dart`
- Modify: `lib/src/app/startup_app.dart`
- Modify: `test/main_tabs/mine_tab_page_test.dart`
- Modify: `test/main_tabs/main_tabs_page_test.dart`
- Modify: `test/app/startup_app_test.dart`

- [x] **Step 1: Write failing integration tests**

Require exact row order/visibility, both login gates, typed launch values,
one in-flight navigation, launcher error recovery, MainTabs forwarding, real
Startup page/title modes, back without root revision, and hidden guide text.

- [x] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\main_tabs\mine_tab_page_test.dart test\main_tabs\main_tabs_page_test.dart test\app\startup_app_test.dart
```

- [x] **Step 3: Wire the typed launcher end to end**

Gate collect/invite before launch, forward through MainTabs, inject the web
content builder in Startup tests, and push `LegacyWebViewPage` without changing
the MainTabs key.

- [x] **Step 4: Run Step 2 and verify GREEN**

### Task 6: Exports and migration evidence

**Files:**
- Modify: `lib/ultcpa_flutter.dart`
- Create: `test/web/legacy_webview_exports_test.dart`
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`

- [x] **Step 1: Write failing export and ledger tests**

Require the request/page/resolver public surface, partial WebActivity evidence,
new MainActivity evidence, unchanged hidden guide and payment statuses, and
the remaining generic WebActivity work in the evidence string.

- [x] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\web\legacy_webview_exports_test.dart test\migration\activity_coverage_test.dart
```

- [x] **Step 3: Export, update reviewed progress, and regenerate CSV**

```powershell
dart run tool\migration\source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs\migration\activity_coverage.csv
```

- [x] **Step 4: Run Step 2 and verify GREEN**

### Task 7: Full verification and dev APK

**Files:**
- Verify all files changed above

- [x] **Step 1: Format and check this slice**

Run `dart format`, then repeat with `--output=none --set-exit-if-changed`.

- [x] **Step 2: Run focused and full verification**

```powershell
.\tool\flutter_android21.ps1 test test\main_tabs test\web test\startup\startup_remote_initializer_test.dart test\network\method_channel_request_context_test.dart test\app\startup_app_test.dart test\config\android_shell_config_test.dart test\migration\activity_coverage_test.dart
.\tool\flutter_android21.ps1 test
.\tool\flutter_android21.ps1 analyze
git diff --check
```

- [x] **Step 3: Build and inspect a fresh dev APK**

```powershell
.\tool\flutter_android21.ps1 build apk --debug --flavor dev
```

Record exact APK bytes and SHA-256, verify CSV counts/critical rows, and confirm
the staged index remains empty. Do not stage or commit.
