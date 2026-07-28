# Purchase History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking. This migration batch remains
> intentionally uncommitted; do not stage or commit.

**Goal:** Reproduce Android's currently reachable Mine purchase-history page,
including its endpoint-specific response, sorting, empty, refresh, and copy
behavior.

**Architecture:** A focused purchase-history feature uses an endpoint-specific
Dio repository so code `0` remains local to this API. Immutable models own
Android parsing/display rules; a Material page is launched through Mine and
Startup without changing root navigation state.

**Tech Stack:** Flutter 3.32/Dart 3.8, Material widgets, Dio, Clipboard,
flutter_test.

---

### Task 1: Android order models and display rules

**Files:**
- Create: `lib/src/purchase_history/purchase_history_models.dart`
- Create: `test/purchase_history/purchase_history_models_test.dart`

- [ ] **Step 1: Write failing model tests**

Pin strict map/list handling, string/number field coercion matching Gson,
commodity-name precedence, newline-joined item fallback, `--`, amount output
such as `¥0`, `¥9.9`, and `¥99`, timestamp parsing, newest-first order, invalid
times last, and stable server order for ties.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\purchase_history\purchase_history_models_test.dart
```

Expected: purchase-history model library does not exist.

- [ ] **Step 3: Implement minimal immutable models and helpers**

Define `PurchaseHistoryOrder`, `PurchaseHistoryItem`,
`parsePurchaseTimeMillis`, `formatPurchaseAmount`, and
`sortPurchaseOrdersNewestFirst`. Keep raw status/time values nullable so page
text can match Java string concatenation.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 2: Exact order-history repository

**Files:**
- Create: `lib/src/purchase_history/purchase_history_data_source.dart`
- Create: `test/purchase_history/purchase_history_data_source_test.dart`

- [ ] **Step 1: Write failing repository tests**

Require a signed GET to `/app/order/v1/getMyOrder`, no query, JSON response,
codes `0`, `200`, and `2001`, null body as empty, string-encoded arrays when
encountered, server-message errors, malformed-envelope errors, invalid-array
errors, null-item filtering, and sorted results.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\purchase_history\purchase_history_data_source_test.dart
```

Expected: data-source types do not exist.

- [ ] **Step 3: Implement the dedicated Dio repository**

Resolve base URL and signed headers, call GET without parameters, decode a
string or map envelope, apply only this endpoint's success codes, parse the
body list, and return a stable newest-first copy. Do not change
`AppApiClient`.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 3: Refreshable purchase-history page

**Files:**
- Create: `lib/src/purchase_history/purchase_history_page.dart`
- Create: `test/purchase_history/purchase_history_page_test.dart`

- [ ] **Step 1: Write failing widget tests**

Cover the exact title, initial Android empty view, loaded cards and labels,
long order ID ellipsis, complete clipboard value, copy feedback, pull refresh,
refresh replacement, server/parsing/network error messages, list clearing,
duplicate-load guard, stale completion, back, and a 320 by 568 viewport.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\purchase_history\purchase_history_page_test.dart
```

Expected: `PurchaseHistoryPage` is undefined.

- [ ] **Step 3: Implement the Android surface**

Use a white Scaffold/AppBar, `RefreshIndicator`, always-scrollable empty
sliver, flat `0xFFF5F5F5` order cards, a text copy command, full-value
clipboard write, mounted/generation guards, and one in-flight load flag.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 4: Mine, MainTabs, and Startup routing

**Files:**
- Modify: `lib/src/main_tabs/mine_tab_page.dart`
- Modify: `lib/src/main_tabs/main_tabs_page.dart`
- Modify: `lib/src/app/startup_app.dart`
- Modify: `test/main_tabs/mine_tab_page_test.dart`
- Modify: `test/main_tabs/main_tabs_page_test.dart`
- Modify: `test/app/startup_app_test.dart`

- [ ] **Step 1: Write failing route tests**

Require logged-out order taps to call login only, logged-in taps to call the
order launcher only, MainTabs forwarding, Startup's real page and injected
repository, normal back behavior, and no MainTabs revision change.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\main_tabs\mine_tab_page_test.dart test\main_tabs\main_tabs_page_test.dart test\app\startup_app_test.dart
```

- [ ] **Step 3: Wire the real route**

Add a `MinePurchaseHistoryLauncher`, key the row as `mine-purchase-history`,
gate it with the existing login callback, forward it through MainTabs, build
the Dio repository in Startup, and push `PurchaseHistoryPage`.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 5: Public exports and migration ledger

**Files:**
- Create: `test/purchase_history/purchase_history_exports_test.dart`
- Modify: `lib/ultcpa_flutter.dart`
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`

- [ ] **Step 1: Write failing export and ledger tests**

Require all public order models/interfaces/repository/page, complete evidence
for `PurchaseHistoryActivity`, updated Main evidence, and unchanged payment
activity statuses.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\purchase_history\purchase_history_exports_test.dart test\migration\activity_coverage_test.dart
```

- [ ] **Step 3: Export, update reviewed progress, and regenerate CSV**

```powershell
dart run tool\migration\source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs\migration\activity_coverage.csv
```

Read the generated counts and critical rows rather than assuming them.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 6: Full verification and dev APK

**Files:**
- Verify all files changed above

- [ ] **Step 1: Format and check this slice**

Run `dart format`, then repeat with `--output=none --set-exit-if-changed`.

- [ ] **Step 2: Run focused and full verification**

```powershell
.\tool\flutter_android21.ps1 test test\purchase_history test\main_tabs test\app\startup_app_test.dart test\migration\activity_coverage_test.dart
.\tool\flutter_android21.ps1 test
.\tool\flutter_android21.ps1 analyze
git diff --check
```

- [ ] **Step 3: Build and inspect a fresh dev APK**

```powershell
.\tool\flutter_android21.ps1 build apk --debug --flavor dev
```

Record exact APK bytes and SHA-256, verify CSV counts and order rows, and
confirm the staged index remains empty. Do not stage or commit.
