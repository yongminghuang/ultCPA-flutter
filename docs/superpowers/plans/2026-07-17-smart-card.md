# Smart Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for
> tracking. This migration batch remains intentionally uncommitted; do not
> stage or commit.

**Goal:** Reproduce Android's `SmartCardActivity` Home flow, skill-card pager,
three-card trial boundary, and injectable unlock action in Flutter.

**Architecture:** A dedicated `smart_card` feature reuses existing mnemonic
models, highlighted text, and entitlement resolution. An entry page owns Home
probing and unavailable routing; the content page owns one exact goods request
and responsive PageView state.

**Tech Stack:** Flutter 3.32/Dart 3.8, Material widgets, Dio-backed
`AppApiClient`, Android-compatible state snapshot, flutter_test.

---

### Task 1: Request and entry models

**Files:**
- Create: `lib/src/smart_card/smart_card_models.dart`
- Create: `test/smart_card/smart_card_models_test.dart`

- [ ] **Step 1: Write failing model tests**

Require `SmartCardRequest` to preserve the module and optional leaf shelf ID.
Its query getter rejects a non-positive module ID or negative leaf shelf ID,
while `shelfId == 0` selects flat mode. Require flat/nested exact query maps and
`SmartCardEntryDestination.page`, `unavailable`, and `empty`, plus optional
prefetched `SkillMnemonicsCatalog` and resolved VIP state.

```dart
expect(
  const SmartCardRequest(module: module).queryParameters,
  {'pageNum': 1, 'pageSize': 200, 'shelfId': 51},
);
expect(
  const SmartCardRequest(module: module, shelfId: 901).queryParameters,
  {'pageNum': 1, 'pageSize': 200, 'modelId': 51, 'shelfId': 901},
);
```

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\smart_card\smart_card_models_test.dart
```

Expected: missing smart-card model library and types.

- [ ] **Step 3: Implement minimal immutable models**

Validate IDs before query creation, use page 1 and size 200, and keep entry
catalog nullable.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 2: Repository, entitlement, and social-work probe

**Files:**
- Create: `lib/src/smart_card/smart_card_repository.dart`
- Create: `test/smart_card/smart_card_repository_test.dart`

- [ ] **Step 1: Write failing repository tests**

Cover:

- invalid module performs no state/network I/O and resolves empty;
- logged-out resolves non-VIP page without benefits/goods I/O;
- logged-in benefit request is exactly `/app/user/getUserBenefits`;
- non-social and non-VIP users do not probe goods;
- social-work VIP uses the exact flat query and returns a prefetched catalog;
- social probe failure/malformed/empty resolves unavailable;
- benefit failure propagates for entry retry;
- on-demand flat and nested catalog loads use exact queries;
- catalog free count is exactly three and VIP is preserved.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\smart_card\smart_card_repository_test.dart
```

- [ ] **Step 3: Implement `SmartCardDataSource` and repository**

Use `SkillMnemonicsEntitlementResolver.isVip`, `LegacyAppStateStore`, and
`SkillMnemonicsCatalog.fromBody`. Do not catch benefit failures. Catch only the
social goods probe when mapping it to unavailable.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 3: Authoritative assets and card PageView

**Files:**
- Copy: `assets/images/smart_card/bg_smard_card_top.png`
- Copy: `assets/images/smart_card/ic_lock.png`
- Create: `lib/src/smart_card/smart_card_page.dart`
- Create: `test/smart_card/smart_card_page_test.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Copy Android PNGs and verify SHA-256 equality**

Source directory:

```text
E:\workspace\ultCPA-android\ultCPA\src\main\res\drawable-xxxhdpi
```

- [ ] **Step 2: Write failing asset/widget tests**

Require:

- registered hero and lock assets;
- loading, retry, empty, and disposed completion states;
- prefetched catalog skips the request;
- PageView preserves server order and card text/note;
- keyword terms are red/bold;
- non-VIP cards 1-3 use `体验卡片`, later cards use `技巧卡片` plus lock;
- locked tap reports `开通会员以解锁所有技巧卡片`;
- non-VIP fixed CTA invokes the injected callback or reports
  `技巧卡片需解锁，会员与支付功能仍在迁移中`;
- VIP hides all badges, locks, and CTA;
- back action returns;
- a 320 x 568 viewport has no overflow exception.

Stable keys:

```text
smart-card-loading
smart-card-error
smart-card-retry
smart-card-empty
smart-card-pager
smart-card-item-<index>
smart-card-lock-<index>
smart-card-unlock
smart-card-back
```

- [ ] **Step 3: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\smart_card\smart_card_page_test.dart
```

- [ ] **Step 4: Implement the responsive Android card surface**

Use `PageController(viewportFraction: ...)`, fixed responsive constraints,
`SkillMnemonicHighlightedText`, a clipped `BackdropFilter`/veil for locked
cards, and a bottom `SafeArea` CTA. Guard duplicate loads/actions and ignore
stale completions.

- [ ] **Step 5: Run Step 3 and verify GREEN**

### Task 4: Entry page and Home/Startup integration

**Files:**
- Create: `lib/src/smart_card/smart_card_entry_page.dart`
- Create: `test/smart_card/smart_card_entry_page_test.dart`
- Modify: `lib/src/main_tabs/home_module_route.dart`
- Modify: `test/main_tabs/home_module_route_test.dart`
- Modify: `lib/src/app/startup_app.dart`
- Modify: `test/app/startup_app_test.dart`

- [ ] **Step 1: Write failing entry and integration tests**

Cover loading/retry, empty, unavailable pop/message, prefetched page,
exact `技巧卡片`, historical contains `大招卡片`, clicked-module propagation,
shared repository identity, injected unlock callback, and proof that non-card
routes never resolve a smart-card entry.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\smart_card\smart_card_entry_page_test.dart test\main_tabs\home_module_route_test.dart test\app\startup_app_test.dart
```

- [ ] **Step 3: Implement entry and Startup wiring**

Add `HomeDestination.smartCard`, construct one default repository in Startup,
and push `SmartCardEntryPage` with `SmartCardRequest(module: clickedModule)`.
Keep the unlock launcher injectable and default message honest.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 5: Public exports and migration ledger

**Files:**
- Modify: `lib/ultcpa_flutter.dart`
- Create: `test/smart_card/smart_card_exports_test.dart`
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`

- [ ] **Step 1: Write failing export/ledger tests**

Require every public model/repository/page type. Mark `SmartCardActivity`
partial with asset/card/lock evidence and explicit shared-payment pending text.
Add the ready smart-card destination to `MainActivity` without overstating
payment or post-payment refresh.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\smart_card\smart_card_exports_test.dart test\migration\activity_coverage_test.dart
```

- [ ] **Step 3: Implement exports and reviewed progress**

- [ ] **Step 4: Regenerate CSV**

```powershell
dart run tool\migration\source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs\migration\activity_coverage.csv
```

Expected:

```text
total=77 flutterPage=69 pluginCallback=3 sdkManaged=3 removed=2
```

- [ ] **Step 5: Run Step 2 and verify GREEN**

### Task 6: Full verification and APK

**Files:** Verify every file above.

- [ ] **Step 1: Format touched Dart files**

```powershell
dart format lib\src\smart_card test\smart_card lib\src\app\startup_app.dart lib\src\main_tabs\home_module_route.dart lib\src\migration\activity_coverage.dart test\app\startup_app_test.dart test\main_tabs\home_module_route_test.dart test\migration\activity_coverage_test.dart
```

- [ ] **Step 2: Run focused verification**

```powershell
.\tool\flutter_android21.ps1 test test\smart_card test\main_tabs\home_module_route_test.dart test\app\startup_app_test.dart test\migration\activity_coverage_test.dart
```

- [ ] **Step 3: Run full gates**

```powershell
.\tool\flutter_android21.ps1 test
.\tool\flutter_android21.ps1 analyze
git diff --check
```

- [ ] **Step 4: Build and hash devDebug**

```powershell
.\tool\flutter_android21.ps1 build apk --debug --flavor dev
(Get-FileHash build\app\outputs\flutter-apk\app-dev-debug.apk -Algorithm SHA256).Hash
```

Report the exact test count, analyzer result, CSV counts, APK path/size/hash,
and preserve the intentionally uncommitted worktree.
