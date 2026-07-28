# VIP Purchase Success Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking. This migration batch remains
> intentionally uncommitted; do not stage or commit.

**Goal:** Reproduce Android's normal VIP purchase-success page, post-payment
benefit refresh, customer-service action, and Mine-to-Home return behavior.

**Architecture:** Extend the existing purchase data source with one typed
success-summary request, keep benefit parsing pure beside the existing benefit
resolver, and render the success page as the final state of the same purchase
route. MainTabs consumes the existing paid result, refreshes only Mine, and
selects Home.

**Tech Stack:** Flutter 3.32/Dart 3.8, Material widgets, signed `AppApiClient`,
flutter_test, Android reference resources.

---

### Task 1: Success summary model and Android matching rules

**Files:**
- Modify: `lib/src/vip_purchase/vip_purchase_models.dart`
- Modify: `test/vip_purchase/vip_purchase_models_test.dart`

- [ ] **Step 1: Write failing pure-model tests**

Require this public API:

```dart
const generic = VipPurchaseSuccessSummary.generic();
expect(generic.title, '恭喜！会员开通成功');
expect(generic.expiresOn, isEmpty);
expect(generic.hasMemberTier, isFalse);

final summary = resolveVipPurchaseSuccessSummary(
  rawBenefits,
  category: 'joy-ledger',
  level: '初级会计',
  now: () => DateTime(2026, 7, 17),
);
expect(summary.title, '恭喜！【初级会计畅学卡】开通成功');
expect(summary.expiresOn, '2026-08-01');
expect(summary.hasMemberTier, isTrue);
```

Pin legacy member prefixes and abstract `category:level:subject:all`, input
order, description trimming, seconds/milliseconds/date expiry formats, expired
items, other scopes, practice/course-only packages, malformed JSON/body/items,
empty description, and immutable value equality.

- [ ] **Step 2: Run model tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_purchase_models_test.dart
```

Expected: `VipPurchaseSuccessSummary` and its resolver are undefined.

- [ ] **Step 3: Implement the minimal pure resolver**

Add the immutable summary and resolver to `vip_purchase_models.dart`, reusing
the existing `_VipLevelBenefitProfile`, benefit decoding, scope matching,
expiry parsing, and date formatting helpers. Stop on the first valid full
member item and never treat practice/course-only items as a member tier.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 2: Post-payment benefit refresh

**Files:**
- Modify: `lib/src/vip_purchase/vip_purchase_repository.dart`
- Modify: `test/vip_purchase/vip_purchase_repository_test.dart`
- Modify: `test/vip_purchase/vip_purchase_page_test.dart`
- Modify: `test/app/startup_app_test.dart`

- [ ] **Step 1: Write failing repository tests**

Extend the wished-for interface with:

```dart
Future<VipPurchaseSuccessSummary> loadSuccessSummary(
  VipPurchaseSession session,
);
```

Require exactly one parameterless signed GET to
`/app/user/getUserBenefits`, current session category/level resolution, and a
generic summary for thrown API errors, null, maps, malformed lists, or no
matching member tier. Require valid list bodies to preserve Android first-match
ordering.

- [ ] **Step 2: Run repository tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_purchase_repository_test.dart
```

Expected: the data-source method is missing.

- [ ] **Step 3: Implement repository refresh and update existing fakes**

Add the method to `VipPurchaseDataSource` and `VipPurchaseRepository`. Catch
all request/protocol parsing failures inside this method and return
`const VipPurchaseSuccessSummary.generic()`. Add explicit success-summary
handlers/counters to the two widget-test fakes without adding production-only
test hooks.

- [ ] **Step 4: Run repository, purchase-page, and Startup tests GREEN**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_purchase_repository_test.dart test\vip_purchase\vip_purchase_page_test.dart test\app\startup_app_test.dart
```

### Task 3: Authoritative success asset and page

**Files:**
- Copy: `assets/images/vip_purchase/icon_open_vip_success.png`
- Modify: `test/vip_purchase/vip_purchase_assets_test.dart`
- Create: `lib/src/vip_purchase/vip_purchase_success_page.dart`
- Create: `test/vip_purchase/vip_purchase_success_page_test.dart`

- [ ] **Step 1: Write failing asset and widget tests**

Require the exact success asset basename. Define this page API:

```dart
VipPurchaseSuccessPage(
  summary: summary,
  onFinished: onFinished,
  customerServiceLauncher: launcher,
)
```

Pin the Android background, back key, 72dp asset, title, conditional expiry,
teacher card copy, gold customer-service action, app-bar/system back single
completion, customer-service single-flight/error recovery, disposal guards,
and no overflow at 320x568 and 360x640.

- [ ] **Step 2: Run tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_purchase_assets_test.dart test\vip_purchase\vip_purchase_success_page_test.dart
```

Expected: asset and page are absent.

- [ ] **Step 3: Copy the Android PNG and implement the page**

Copy only:

```text
E:\workspace\ultCPA-android\ultCPA\src\main\res\drawable-xxxhdpi\icon_open_vip_success.png
```

Use a `PopScope`, warm `Scaffold`, scrollable safe content, flat teacher card,
and the existing `VipPurchaseActionLauncher` boundary. Keep finish and service
actions independently single-flight.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 4: Make success the final purchase-route state

**Files:**
- Modify: `lib/src/vip_purchase/vip_purchase_page.dart`
- Modify: `test/vip_purchase/vip_purchase_page_test.dart`

- [ ] **Step 1: Write failing flow tests**

Change Alipay and confirmed WeChat success expectations so the page:

```text
calls loadSuccessSummary once
shows VipPurchaseSuccessPage
does not complete the outer route yet
completes VipPurchaseResult.paid only after success back
keeps native cancellation/failure behavior unchanged
uses generic summary when the refresh throws
ignores late summary completion after disposal
forwards the existing customer-service launcher
```

- [ ] **Step 2: Run the page test and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_purchase_page_test.dart
```

Expected: confirmed payments still pop immediately.

- [ ] **Step 3: Implement the success phase**

Store a nullable `VipPurchaseSuccessSummary`. After payment confirmation, load
the summary with a page-level generic fallback and set it only while mounted.
At the start of `build`, return `VipPurchaseSuccessPage` when present. Its
finish callback pops the outer route with `VipPurchaseResult.paid` once.

- [ ] **Step 4: Run Step 2 and the success-page test GREEN**

### Task 5: Android Mine-to-Home completion behavior

**Files:**
- Modify: `lib/src/main_tabs/main_tabs_page.dart`
- Modify: `test/main_tabs/main_tabs_page_test.dart`
- Modify: `test/app/startup_app_test.dart`

- [ ] **Step 1: Write failing MainTabs and Startup tests**

Require a Mine `paid` result to increment only Mine's load count, preserve
Home/Course instances, and select bottom-navigation index `0`. In the Startup
integration test, require confirmed payment to show the real success page,
leave Mine unchanged until success back, then close the outer flow, select
Home, and reload Mine exactly once. Verify the same customer-service dependency
is forwarded to the success page.

- [ ] **Step 2: Run tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\main_tabs\main_tabs_page_test.dart test\app\startup_app_test.dart
```

Expected: MainTabs remains on Mine and Startup closes before showing success.

- [ ] **Step 3: Select Home on the existing paid result**

In `_openVipPurchaseFromMine`, keep the Mine reload-token update and page
replacement, and set `_selectedIndex = 0` in the same `setState`. Do not rebuild
Home or Course.

- [ ] **Step 4: Run Step 2 GREEN**

### Task 6: Public API and honest migration ledger

**Files:**
- Modify: `lib/ultcpa_flutter.dart`
- Modify: `test/vip_purchase/vip_purchase_exports_test.dart`
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`

- [ ] **Step 1: Write failing export and ledger tests**

Require `VipPurchaseSuccessSummary`, its resolver, and
`VipPurchaseSuccessPage` through the package export. Require
`VipPurchaseSuccessActivity` to become partial on `VipPurchaseSuccessPage`,
with normal success copy, benefit refresh, teacher service, and Mine-to-Home
evidence. Require source-specific destination reopening and
`BigSkillPracticePurchaseSuccessActivity` to remain pending. Remove the stale
`VipPurchaseSuccessActivity pending` claim from `OpenVipMultiPayActivity`.

- [ ] **Step 2: Run tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_purchase_exports_test.dart test\migration\activity_coverage_test.dart
```

- [ ] **Step 3: Export, update reviewed evidence, and regenerate CSV**

```powershell
dart run tool\migration\source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs\migration\activity_coverage.csv
```

Expected counts:

```text
complete=14 partial=17 pending=38 external=6 removed=2
```

Stop and inspect if any other row changes status.

- [ ] **Step 4: Run Step 2 GREEN**

### Task 7: Full verification and fresh dev APK

**Files:**
- Verify all files above

- [ ] **Step 1: Format and verify stability**

```powershell
dart format lib\src\vip_purchase lib\src\main_tabs\main_tabs_page.dart lib\src\app\startup_app.dart lib\ultcpa_flutter.dart test\vip_purchase test\main_tabs\main_tabs_page_test.dart test\app\startup_app_test.dart test\migration\activity_coverage_test.dart
dart format --output=none --set-exit-if-changed lib test tool
```

- [ ] **Step 2: Run focused and full verification**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase test\main_tabs test\app\startup_app_test.dart test\migration\activity_coverage_test.dart
.\tool\flutter_android21.ps1 test
.\tool\flutter_android21.ps1 analyze
git diff --check
```

Expected: zero failures, Analyzer has no issues, and diff check has no errors.

- [ ] **Step 3: Build a fresh dev debug APK and record evidence**

```powershell
.\tool\flutter_android21.ps1 build apk --debug --flavor dev
Get-Item build\app\outputs\flutter-apk\app-dev-debug.apk
Get-FileHash -Algorithm SHA256 build\app\outputs\flutter-apk\app-dev-debug.apk
```

Record the final absolute path, byte length, and SHA-256 without staging or
committing the dirty worktree.
