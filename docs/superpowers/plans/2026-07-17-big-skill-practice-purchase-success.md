# Big Skill Practice Purchase Success Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking. This ongoing migration worktree is
> intentionally uncommitted; do not stage or commit.

**Goal:** Reproduce Android's practice-package purchase-success Activity with
four entitlement kinds, refreshed copy, module fallback, and a typed practice
handoff.

**Architecture:** Add a shared practice-benefit enum, reuse the existing VIP
benefit parsing internals for success copy, and isolate module resolution in a
small signed-API repository. The page owns UI/lifecycle while
`ModulePracticeRequest` carries benefit-kind and circle-module semantics into
the existing runner.

**Tech Stack:** Flutter 3.32/Dart 3.8, Material widgets, signed `AppApiClient`,
native `LegacyAppStateStore`, flutter_test.

---

### Task 1: Practice benefit kind and success-copy resolver

**Files:**
- Create: `lib/src/practice/practice_benefit_kind.dart`
- Modify: `lib/src/vip_purchase/vip_purchase_models.dart`
- Modify: `test/vip_purchase/vip_purchase_models_test.dart`

- [ ] **Step 1: Write failing model tests**

Require `PracticeBenefitKind` with exact Android default names and benefit
types. Require an immutable `BigSkillPracticePurchaseSuccessRequest` carrying
`benefitKind`, `navigateHomeOnBack`, `cachedPracticeModule`, and
`cachedCircleModule`, plus:

```dart
final summary = resolveBigSkillPracticePurchaseSuccessSummary(
  rawBenefits,
  kind: PracticeBenefitKind.chapterPractice,
  category: 'joy-ledger',
  level: '中级会计',
  now: () => DateTime(2026, 7, 17),
);
expect(summary.title, '恭喜！【章节专项包】开通成功');
expect(summary.expiresOn, '2026-08-01');
```

Pin request defaults/field preservation, all four generic titles, matching legacy
prefixes and abstract types,
first valid current-scope ordering, trimmed descriptions, seconds/milliseconds
and date expiry, expiry-only benefits, expired/mismatched/malformed items, and
value equality.

- [ ] **Step 2: Run tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_purchase_models_test.dart
```

Expected: `PracticeBenefitKind` and the new resolver are undefined.

- [ ] **Step 3: Implement the minimal enum, summary, and resolver**

Use `_VipLevelBenefitProfile`, `_decodeBenefitList`, `_parseBenefitExpiry`, and
`_matchesBenefitScope`. Select the profile prefix corresponding to the kind or
the exact abstract type. Return the first valid match and otherwise the
kind-specific generic summary.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 2: Refreshed summary and module destination repository

**Files:**
- Create: `lib/src/vip_purchase/big_skill_practice_purchase_success_repository.dart`
- Create: `test/vip_purchase/big_skill_practice_purchase_success_repository_test.dart`

- [ ] **Step 1: Write failing repository tests**

Define:

```dart
abstract interface class BigSkillPracticePurchaseSuccessDataSource {
  Future<BigSkillPracticePurchaseSuccessSummary> loadSummary(
    PracticeBenefitKind kind,
  );

  Future<BigSkillPracticeDestination?> loadDestination({
    HomeModule? cachedPracticeModule,
    HomeModule? cachedCircleModule,
  });
}
```

Require one parameterless `GET /app/user/getUserBenefits`, current snapshot
category/level resolution, live-list preference, cached-benefit fallback, and
generic fallback. Require a valid cached practice module to skip all reads and
requests. Otherwise require one native snapshot read and one
`GET /knowledge/shelf/moduleLis?marketId=<selectedMarketId>`, first valid
practice/circle selection, and `null` for invalid market, request errors,
malformed bodies, or no practice module.

- [ ] **Step 2: Run the new test and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\big_skill_practice_purchase_success_repository_test.dart
```

- [ ] **Step 3: Implement the repository and immutable destination**

Parse `HomeModule` using positive IDs and trimmed fields. A practice module
matches page `技巧练题` or name `技巧练题`; a circle module matches page
`技巧圈题卷` or name `技巧圈题卷`/`大招圈题卷`. Preserve the first match of each.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 3: Android success page and lifecycle

**Files:**
- Create: `lib/src/vip_purchase/big_skill_practice_purchase_success_page.dart`
- Create: `test/vip_purchase/big_skill_practice_purchase_success_page_test.dart`

- [ ] **Step 1: Write failing widget tests**

Require the warm scaffold, empty-title back bar, 72dp existing success asset,
kind-specific title, conditional expiry, white action card, and blue
`去技巧练题` control. Pin summary refresh, cached/API destination forwarding,
`入口数据加载中，请返回首页后再试`, independent single-flight finish/CTA,
launcher failure recovery, `navigateHomeOnBack`, disposal guards, and no
overflow at 320x568 and 360x640.

- [ ] **Step 2: Run the page test and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\big_skill_practice_purchase_success_page_test.dart
```

- [ ] **Step 3: Implement the page**

Show `BigSkillPracticePurchaseSuccessSummary.generic(request.benefitKind)`
immediately and refresh in `initState`. Use `PopScope`, a scrollable safe body,
and stable button dimensions. After a valid destination, invoke the injected
launcher with destination and kind; when it returns while mounted, finish with
`navigateHome=false`. Back finishes with `request.navigateHomeOnBack`.

- [ ] **Step 4: Run Step 2 and the repository test GREEN**

### Task 4: Carry the Android benefit kind into practice access

**Files:**
- Modify: `lib/src/practice/practice_repository.dart`
- Modify: `lib/src/skill_mnemonics/skill_mnemonics_entitlement.dart`
- Modify: `test/practice/practice_repository_test.dart`
- Modify: `test/skill_mnemonics/skill_mnemonics_entitlement_test.dart`

- [ ] **Step 1: Write failing entitlement and request tests**

Require `ModulePracticeRequest` to default to regular practice and preserve an
explicit `benefitKind` plus `bigSkillCircleModule`. For each kind, construct a
catalog with only its matching benefit and require `fullAccess == true`; other
package kinds must not unlock it. Pin full-member access for every kind.

- [ ] **Step 2: Run tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\practice\practice_repository_test.dart test\skill_mnemonics\skill_mnemonics_entitlement_test.dart
```

- [ ] **Step 3: Implement typed access dispatch**

Add `hasPracticeAccess(..., required PracticeBenefitKind kind)` to the existing
entitlement resolver as a switch over its four proven methods. Extend
`ModulePracticeRequest` with const defaults and use the typed method in
`PracticeRepository`.

- [ ] **Step 4: Run Step 2 and all practice tests GREEN**

### Task 5: Public surface and honest migration ledger

**Files:**
- Modify: `lib/ultcpa_flutter.dart`
- Modify: `test/vip_purchase/vip_purchase_exports_test.dart`
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`

- [ ] **Step 1: Write failing export and ledger tests**

Require the enum, request/summary/destination, data source/repository, and page
from the package export. Require
`BigSkillPracticePurchaseSuccessActivity` to be partial on
`BigSkillPracticePurchaseSuccessPage`, with four-kind copy, benefit refresh,
module fallback, typed practice handoff, and back evidence. Require Home
marketing float, question-package payment, and circle destination to remain
pending.

- [ ] **Step 2: Run tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_purchase_exports_test.dart test\migration\activity_coverage_test.dart
```

- [ ] **Step 3: Export, update evidence, and regenerate CSV**

```powershell
dart run tool\migration\source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs\migration\activity_coverage.csv
```

Expected counts: `complete=14 partial=18 pending=37 external=6 removed=2`.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 6: Full verification and fresh dev APK

**Files:**
- Verify all files above

- [ ] **Step 1: Format and check formatting**

```powershell
dart format lib\src\practice lib\src\vip_purchase lib\src\skill_mnemonics test\practice test\skill_mnemonics test\vip_purchase lib\ultcpa_flutter.dart test\migration\activity_coverage_test.dart
dart format --output=none --set-exit-if-changed lib test tool
```

- [ ] **Step 2: Run focused and full verification**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase test\practice test\skill_mnemonics test\migration\activity_coverage_test.dart
.\tool\flutter_android21.ps1 test
.\tool\flutter_android21.ps1 analyze
git diff --check
```

- [ ] **Step 3: Build and fingerprint a fresh APK**

```powershell
.\tool\flutter_android21.ps1 build apk --debug --flavor dev
Get-Item build\app\outputs\flutter-apk\app-dev-debug.apk
Get-FileHash -Algorithm SHA256 build\app\outputs\flutter-apk\app-dev-debug.apk
```

Record the absolute path, length, and SHA-256. Do not stage or commit the dirty
worktree.
