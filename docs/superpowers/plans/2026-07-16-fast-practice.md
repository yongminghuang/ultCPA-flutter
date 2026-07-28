# Fast Practice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This migration batch is intentionally uncommitted, so do not stage or commit while executing it.

**Goal:** Migrate Android's `速成300题` / `速成N题` entitlement split, visual landing page, recursive leaf list, selected-leaf runner, records, and flat position persistence.

**Architecture:** A dedicated fast-practice repository resolves access and parses the shelf tree; an entry page selects either the asset-backed landing page or the structural leaf catalog. Selecting a leaf creates `FastPracticeRequest`, which reuses `PracticeRepository`, `PracticePage`, and the existing answer engine while adding only Android's leaf record and flat-position contracts.

**Tech Stack:** Flutter/Dart, `flutter_test`, Dio-backed `AppApiClient`, Android Kotlin MethodChannel, MMKV, Android reference bitmap assets.

---

### Task 1: Fast-practice models, entitlement, and repository

**Files:**
- Create: `lib/src/fast_practice/fast_practice_models.dart`
- Create: `lib/src/fast_practice/fast_practice_repository.dart`
- Create: `test/fast_practice/fast_practice_models_test.dart`
- Create: `test/fast_practice/fast_practice_repository_test.dart`
- Modify: `lib/src/skill_mnemonics/skill_mnemonics_entitlement.dart`
- Modify: `test/skill_mnemonics/skill_mnemonics_entitlement_test.dart`

- [ ] **Step 1: Write failing model and entitlement tests**

Exercise recursive server-order leaf parsing, invalid IDs/names, malformed child containers, `practice_speed`, scoped `all`, membership, legacy `<PREFIX>_PRACTICE_SPEED_<LEVEL>`, expiry, and selection mismatch.

```dart
final leaves = parseFastPracticeLeaves(treeBody);
expect(leaves.map((leaf) => leaf.id), [111, 112, 200]);

expect(
  resolver.hasFastPracticeAccess(
    benefits,
    category: 'social-work',
    level: '初级社工',
    subject: '社工实务',
  ),
  isTrue,
);
```

- [ ] **Step 2: Run tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test/fast_practice/fast_practice_models_test.dart test/skill_mnemonics/skill_mnemonics_entitlement_test.dart
```

Expected: compile failure because the fast models and entitlement method do not exist.

- [ ] **Step 3: Implement immutable leaves and speed entitlement**

Define `FastPracticeLeaf`, `FastPracticeCatalog`, and
`FastPracticeEntryDestination { catalog, landing, empty }`. Parse only positive,
named leaves; preserve every valid descendant in root order. Add
`hasFastPracticeAccess` using the resolver's existing expiry and scope helpers.

- [ ] **Step 4: Run model and entitlement tests and verify GREEN**

Run the Step 2 command. Expected: all selected tests pass.

- [ ] **Step 5: Write failing repository tests**

Prove exact contracts:

```dart
expect(api.getRequests.first.path, '/app/user/getUserBenefits');
expect(api.getRequests.last, request(
  '/app/shelf/getShelfTree',
  query: {'shelfId': 42},
));
```

Cover invalid-module empty without I/O, logged-out landing, benefit-failure
landing, full-access catalog, tree empty, tree retryable failure, and nested
leaf order.

- [ ] **Step 6: Run repository tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test/fast_practice/fast_practice_repository_test.dart
```

Expected: compile failure because `FastPracticeRepository` is missing.

- [ ] **Step 7: Implement the repository**

```dart
abstract interface class FastPracticeDataSource {
  Future<FastPracticeEntryDestination> resolveEntry(HomeModule module);
  Future<FastPracticeCatalog> loadCatalog(HomeModule module);
}
```

`resolveEntry` reads the current snapshot and optional benefits. `loadCatalog`
owns only the exact tree request and parser so landing users do not fetch shelf
content.

- [ ] **Step 8: Run repository tests and verify GREEN**

Run the Step 6 command. Expected: all repository tests pass.

### Task 2: Android landing assets and landing page

**Files:**
- Create: `assets/images/fast_practice/img_fast300_hero_title.png`
- Create: `assets/images/fast_practice/ic_fast_300.png`
- Create: `assets/images/fast_practice/ic_fast_80.png`
- Create: `assets/images/fast_practice/img_fast300_bubble.png`
- Create: `assets/images/fast_practice/ic_fast300_vs.png`
- Create: `assets/images/fast_practice/ic_fast300_feature_book.png`
- Create: `assets/images/fast_practice/ic_fast300_feature_medal.png`
- Create: `assets/images/fast_practice/ic_fast300_feature_lightning.png`
- Create: `lib/src/fast_practice/fast_practice_landing_page.dart`
- Create: `test/fast_practice/fast_practice_landing_page_test.dart`
- Modify: `pubspec.yaml`
- Modify: `test/config/android_shell_config_test.dart`

- [ ] **Step 1: Write failing asset and widget tests**

Assert every copied asset exists and the page renders the actual asset paths,
the three Android feature titles, the 2000-versus-300 comparison, a scrollable
body, and fixed CTA `立即领取速成300题`.

```dart
expect(find.byKey(const ValueKey('fast-practice-hero')), findsOneWidget);
expect(find.text('刷1题顶5题'), findsOneWidget);
expect(find.text('立即领取速成300题'), findsOneWidget);
```

CTA without an injected payment callback must show
`速成300题需解锁，会员与支付功能仍在迁移中`.

- [ ] **Step 2: Run landing tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test/fast_practice/fast_practice_landing_page_test.dart test/config/android_shell_config_test.dart
```

Expected: failures because assets, pubspec entry, and page are absent.

- [ ] **Step 3: Copy the authoritative Android bitmaps**

Copy the named files from
`E:\workspace\ultCPA-android\ultCPA\src\main\res\drawable-xxxhdpi` into
`assets/images/fast_practice` without modifying the Android reference. Register
the destination directory in `pubspec.yaml`.

- [ ] **Step 4: Implement the landing page**

Use a `Stack`/`CustomScrollView` with the orange hero image at the top, compact
comparison and feature sections, and a `SafeArea` bottom CTA outside the scroll
view. Use the Android orange/cream/white palette and 4-8 px radii.

- [ ] **Step 5: Run landing tests and verify GREEN**

Run the Step 2 command. Expected: all landing and asset tests pass.

### Task 3: Entry gate and recursive leaf catalog page

**Files:**
- Create: `lib/src/fast_practice/fast_practice_entry_page.dart`
- Create: `lib/src/fast_practice/fast_practice_catalog_page.dart`
- Create: `test/fast_practice/fast_practice_entry_page_test.dart`
- Create: `test/fast_practice/fast_practice_catalog_page_test.dart`

- [ ] **Step 1: Write failing entry and catalog widget tests**

Cover entry loading, catalog/landing/empty destinations, stale disposal,
catalog loading, retry, empty tree, Android title fallback, row order, and exact
selected leaf launch.

Stable keys:

```text
fast-practice-entry-loading
fast-practice-catalog-loading
fast-practice-catalog-error
fast-practice-catalog-retry
fast-practice-catalog-empty
fast-practice-leaf-<id>
```

- [ ] **Step 2: Run widget tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test/fast_practice/fast_practice_entry_page_test.dart test/fast_practice/fast_practice_catalog_page_test.dart
```

Expected: compile failure because both pages and launcher contract are missing.

- [ ] **Step 3: Implement entry and catalog pages**

`FastPracticeEntryPage` resolves once and renders landing, catalog, or invalid
empty state. `FastPracticeCatalogPage` owns its own tree request and a plain
full-width leaf list. Default selection pushes `PracticePage`; tests may inject
a `FastPracticeLauncher`.

- [ ] **Step 4: Run widget tests and verify GREEN**

Run the Step 2 command. Expected: all entry/catalog tests pass.

### Task 4: Android-compatible flat question position store

**Files:**
- Create: `lib/src/practice/flat_practice_progress_store.dart`
- Create: `test/practice/flat_practice_progress_store_test.dart`
- Modify: `lib/src/network/method_channel_request_context.dart`
- Modify: `android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt`
- Modify: `test/config/android_shell_config_test.dart`

- [ ] **Step 1: Write failing MethodChannel tests**

Verify exact methods, arguments, defaults, and validation:

```dart
await store.saveFlatQuestionPosition(shelfId: 111, position: 7);
expect(calls.last.method, 'setFlatPracticeQuestionPosition');
expect(calls.last.arguments, {'shelfId': 111, 'position': 7});
```

- [ ] **Step 2: Run store tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test/practice/flat_practice_progress_store_test.dart
```

Expected: compile failure because the interface and bridge methods are absent.

- [ ] **Step 3: Implement Dart and Kotlin progress bridges**

Use this exact MMKV key and default:

```text
<userId>_<category>_<shelfId>_flatLearnQPos
```

Native reads return `0`; writes reject non-positive shelf IDs and negative
positions. Add a disabled Dart implementation for non-fast runners.

- [ ] **Step 4: Run store and native source tests and verify GREEN**

```powershell
.\tool\flutter_android21.ps1 test test/practice/flat_practice_progress_store_test.dart test/config/android_shell_config_test.dart
```

Expected: all selected tests pass.

### Task 5: Selected-leaf repository loading and answer overlay

**Files:**
- Modify: `lib/src/practice/practice_repository.dart`
- Modify: `test/practice/practice_repository_test.dart`

- [ ] **Step 1: Write failing `FastPracticeRequest` tests**

Test positive module/leaf validation, every flat page, exact query without
`modelId`, the exact record request, optional record failure, answer overlay,
and full runner access.

```dart
final catalog = await repository.load(const FastPracticeRequest(
  module: module,
  shelfId: 111,
  shelfName: '精选一',
  shelfType: '扁平化',
));
expect(api.getRequests.first.query, {
  'pageNum': 1,
  'pageSize': 30,
  'shelfId': 111,
});
expect(api.postRequests.single.body, {
  'modelId': 42,
  'shelfIdList': [111],
});
```

- [ ] **Step 2: Run repository tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test/practice/practice_repository_test.dart
```

Expected: compile failure because `FastPracticeRequest` is missing.

- [ ] **Step 3: Implement the fast request branch**

Load all flat pages, fetch records independently, overlay normalized answers,
return title `shelfName`, standard behavior, and full per-question access. Do
not change existing module, mnemonic, chapter, error, or collection branches.

- [ ] **Step 4: Run practice repository tests and verify GREEN**

Run the Step 2 command. Expected: all repository tests pass.

### Task 6: Flat position restore and navigation persistence

**Files:**
- Modify: `lib/src/practice/practice_page.dart`
- Modify: `test/practice/practice_page_test.dart`

- [ ] **Step 1: Write failing flat-position widget tests**

Inject `FlatPracticeProgressStore`, load a `FastPracticeRequest`, and prove the
saved leaf position is restored/clamped. Verify successful previous, next, and
answer-card jumps save the selected shelf position; ordinary and chapter
requests must not touch the flat store.

- [ ] **Step 2: Run page tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test/practice/practice_page_test.dart
```

Expected: compile/behavior failure because `PracticePage` has no flat store.

- [ ] **Step 3: Implement request-aware flat checkpoints**

Extend the existing session creation and persistence helpers with a separate
`FastPracticeRequest` branch. Reuse the existing navigation call sites; keep
chapter and non-fast behavior unchanged.

- [ ] **Step 4: Run all practice tests and verify GREEN**

```powershell
.\tool\flutter_android21.ps1 test test/practice
```

Expected: all practice tests pass.

### Task 7: Home route, Startup wiring, exports, and migration ledger

**Files:**
- Modify: `lib/src/main_tabs/home_module_route.dart`
- Modify: `test/main_tabs/home_module_route_test.dart`
- Modify: `lib/src/app/startup_app.dart`
- Modify: `test/app/startup_app_test.dart`
- Modify: `lib/ultcpa_flutter.dart`
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`

- [ ] **Step 1: Write failing route, Startup, and ledger tests**

Resolve exact `速成300题`, exact `速成N题`, and historical contains text to
`HomeDestination.fastPractice`. Startup must open `FastPracticeEntryPage` with
the clicked module and shared practice/progress dependencies. Mark
`Crash200QuestionListActivity` complete, `FastLearnLandingActivity` partial
because real payment is pending, and add speed-leaf evidence to
`LearnActivity`.

- [ ] **Step 2: Run integration tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test/main_tabs/home_module_route_test.dart test/app/startup_app_test.dart test/migration/activity_coverage_test.dart
```

Expected: failures because the route, wiring, and reviewed progress are absent.

- [ ] **Step 3: Implement routing, dependency wiring, exports, and ledger**

Instantiate one `FastPracticeRepository`, pass `MethodChannelRequestContext`
as the flat store, export all public fast files, then regenerate CSV with:

```powershell
dart run tool/migration/source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs\migration\activity_coverage.csv
```

- [ ] **Step 4: Run integration tests and verify GREEN**

Run the Step 2 command. Expected: all integration tests pass.

### Task 8: Full verification and APK

**Files:**
- Verify all files changed above.

- [ ] **Step 1: Format the changed Dart sources**

```powershell
dart format lib/src/fast_practice test/fast_practice lib/src/practice lib/src/app/startup_app.dart lib/src/main_tabs/home_module_route.dart lib/src/network/method_channel_request_context.dart lib/src/skill_mnemonics/skill_mnemonics_entitlement.dart test/practice test/app/startup_app_test.dart test/main_tabs/home_module_route_test.dart test/config/android_shell_config_test.dart test/migration/activity_coverage_test.dart
```

- [ ] **Step 2: Run focused and full verification**

```powershell
.\tool\flutter_android21.ps1 test test/fast_practice test/practice test/main_tabs/home_module_route_test.dart test/app/startup_app_test.dart test/config/android_shell_config_test.dart test/migration/activity_coverage_test.dart
.\tool\flutter_android21.ps1 test
.\tool\flutter_android21.ps1 analyze
git diff --check
```

Expected: focused and full suites pass, analyzer reports `No issues found!`,
and diff check exits `0`.

- [ ] **Step 3: Build and hash the dev debug APK**

```powershell
.\tool\flutter_android21.ps1 build apk --debug --flavor dev
(Get-FileHash build\app\outputs\flutter-apk\app-dev-debug.apk -Algorithm SHA256).Hash
```

Expected: build exits `0`; report the complete SHA-256 without staging or
committing files.
