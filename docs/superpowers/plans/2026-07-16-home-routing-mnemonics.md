# Home Routing and Skill Mnemonics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make home modules tappable through an auditable route contract and migrate the Android skill-mnemonics list/detail flow without disguising unfinished practice or payment destinations as complete.

**Architecture:** Keep activity ownership and migration progress as separate ledger concepts. Resolve home protocol strings in a pure module, inject navigation into the home widgets, and implement mnemonics as a focused repository plus two pages. Production wiring shares the existing signed `AppApiClient` and legacy MMKV-backed state store.

**Tech Stack:** Flutter 3.32.8, Dart 3.8, Material widgets, Dio through `AppApiClient`, Android MMKV method channel, `flutter_test`.

---

## File Map

- `lib/src/migration/activity_coverage.dart`: activity ownership plus reviewed progress metadata.
- `tool/migration/source_manifest.dart`: deterministic authoritative ledger generator.
- `docs/migration/activity_coverage.csv`: generated activity ledger.
- `lib/src/main_tabs/home_module_route.dart`: pure canonical home-route resolution.
- `lib/src/main_tabs/home_tab_page.dart`: tappable hero/grid modules with an injected launcher.
- `lib/src/main_tabs/main_tabs_page.dart`: passes the launcher into the preserved home tab.
- `lib/src/skill_mnemonics/skill_mnemonics_models.dart`: tolerant immutable API and access models.
- `lib/src/skill_mnemonics/skill_mnemonics_entitlement.dart`: Android-compatible current-selection VIP resolver.
- `lib/src/skill_mnemonics/skill_mnemonics_repository.dart`: exact page-goods request and app-snapshot access configuration.
- `lib/src/skill_mnemonics/skill_mnemonics_page.dart`: list/loading/error/empty/locked UI.
- `lib/src/skill_mnemonics/skill_mnemonics_detail_page.dart`: detail rendering and countdown lifecycle.
- `lib/src/app/startup_app.dart`: production route dispatch and repository wiring.
- Corresponding tests under `test/migration`, `test/main_tabs`, and `test/skill_mnemonics`.

### Task 1: Separate ledger ownership from progress

**Files:**
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `tool/migration/source_manifest.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`

- [x] **Step 1: Write failing progress tests**

Add expectations that Flutter-owned pages default to `pending`, SDK/plugin rows become `external`, removals become `removed`, reviewed entries expose status/surface/evidence, and CSV has six columns.

```dart
expect(progressFor('com.example.UnknownActivity').status,
    ActivityMigrationStatus.pending);
expect(progressFor('com.jx885.lrjk.cg.ui.SplashActivity').status,
    ActivityMigrationStatus.complete);
expect(row.toCsv(),
    'a.xml,com.example.Activity,flutterPage,pending,,');
```

- [x] **Step 2: Run the focused test and verify RED**

Run: `./tool/flutter_android21.ps1 test test/migration/activity_coverage_test.dart`

Expected: compile failure because progress types and fields do not exist.

- [x] **Step 3: Add the minimal progress model and reviewed map**

Create `ActivityMigrationStatus`, `ActivityMigrationProgress`, `progressFor`, and fields on `ActivityRegistration`. Keep classification independent. Initially record evidence for startup/privacy/login shell and current main shell; do not mark business pages complete.

- [x] **Step 4: Extend the generator and regenerate the ledger**

Change the header to:

```text
source,activity,disposition,migrationStatus,flutterSurface,evidence
```

Run:

```powershell
dart run tool/migration/source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs/migration/activity_coverage.csv
```

- [x] **Step 5: Run the focused test and verify GREEN**

Run: `./tool/flutter_android21.ps1 test test/migration/activity_coverage_test.dart`

Expected: all migration ledger tests pass.

### Task 2: Define the home route protocol

**Files:**
- Create: `lib/src/main_tabs/home_module_route.dart`
- Create: `test/main_tabs/home_module_route_test.dart`

- [x] **Step 1: Write failing resolver tests**

Cover whitespace normalization, `技巧口诀` as ready, every Android canonical key as known-pending, and empty/unknown values as unsupported.

```dart
expect(resolveHomeModuleRoute(' 技巧口诀 '),
    const ReadyHomeModuleRoute(HomeDestination.skillMnemonics));
expect(resolveHomeModuleRoute('章节练习'),
    const PendingHomeModuleRoute('章节练习'));
expect(resolveHomeModuleRoute('mystery'), isA<UnsupportedHomeModuleRoute>());
```

- [x] **Step 2: Run the focused test and verify RED**

Run: `./tool/flutter_android21.ps1 test test/main_tabs/home_module_route_test.dart`

Expected: compile failure because the resolver module is absent.

- [x] **Step 3: Implement the sealed route result and canonical key set**

Use a sealed result with `ReadyHomeModuleRoute`, `PendingHomeModuleRoute`, and `UnsupportedHomeModuleRoute`. Do not add fuzzy English aliases not accepted by Android.

- [x] **Step 4: Run the focused test and verify GREEN**

Run: `./tool/flutter_android21.ps1 test test/main_tabs/home_module_route_test.dart`

Expected: all resolver tests pass.

### Task 3: Dispatch both home tile types

**Files:**
- Modify: `lib/src/main_tabs/home_tab_page.dart`
- Modify: `lib/src/main_tabs/main_tabs_page.dart`
- Modify: `test/main_tabs/home_tab_page_test.dart`
- Modify: `test/main_tabs/main_tabs_page_test.dart`

- [x] **Step 1: Write failing widget tests**

Inject `Future<void> Function(BuildContext, HomeModule)` and verify that tapping the first hero and a grid item dispatches the exact module once. Use stable keys `home-module-<id>`.

- [x] **Step 2: Run focused tests and verify RED**

Run:

```powershell
./tool/flutter_android21.ps1 test test/main_tabs/home_tab_page_test.dart test/main_tabs/main_tabs_page_test.dart
```

Expected: compile failure because the launcher parameters and keys are absent.

- [x] **Step 3: Add launcher plumbing and Material tap targets**

Pass the launcher through `_HomeContent`, wrap both tile types in `InkResponse`/`InkWell`, preserve fixed dimensions, and leave loading/category behavior untouched.

- [x] **Step 4: Run focused tests and verify GREEN**

Run the same two test files. Expected: all pass.

### Task 4: Parse and load mnemonics

**Files:**
- Create: `lib/src/skill_mnemonics/skill_mnemonics_models.dart`
- Create: `lib/src/skill_mnemonics/skill_mnemonics_repository.dart`
- Create: `test/skill_mnemonics/skill_mnemonics_models_test.dart`
- Create: `test/skill_mnemonics/skill_mnemonics_repository_test.dart`
- Modify: `android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt`
- Modify: `lib/src/main_tabs/main_tabs_models.dart`
- Modify: native snapshot tests that assert exported keys.

- [x] **Step 1: Write failing model/repository tests**

Assert tolerant parsing of string/numeric IDs, `text` falling back to `name`, comma-delimited keywords, immutable records, the exact flat query, invalid module rejection, and default/free-count snapshot parsing.

```dart
expect(api.lastQuery, {
  'pageNum': 1,
  'pageSize': 200,
  'shelfId': 42,
});
expect(catalog.freeCount, 3);
```

- [x] **Step 2: Run focused tests and verify RED**

Run: `./tool/flutter_android21.ps1 test test/skill_mnemonics`

Expected: compile failure because the feature files do not exist.

- [x] **Step 3: Implement immutable parsing and repository**

The data source API is:

```dart
abstract interface class SkillMnemonicsDataSource {
  Future<SkillMnemonicsCatalog> load(HomeModule module);
}
```

The repository loads goods with `GET /app/goods/pageGoodsData` using the Android flat query. It reads `skillFormulaFreeCount` from `LegacyAppStateStore` and clamps it to zero or greater.

For logged-in snapshots it additionally reads `GET /app/user/getUserBenefits`, resolves current-level member prefixes or the three answering benefits, and treats entitlement failure as non-fatal.

- [x] **Step 4: Expose the persisted free count in the method-channel snapshot**

Add `skillFormulaFreeCount` to `readAppSnapshot()` from MMKV key `skill_formula_free_question_count`, default 3, and parse it in `AppSnapshot`.

- [x] **Step 5: Run focused tests and verify GREEN**

Run the model/repository and affected bridge/config tests. Expected: all pass.

### Task 5: Build the list page

**Files:**
- Create: `lib/src/skill_mnemonics/skill_mnemonics_page.dart`
- Create: `test/skill_mnemonics/skill_mnemonics_page_test.dart`

- [x] **Step 1: Write failing list widget tests**

Cover title mapping, loading, retryable failure, empty catalog, numbered rows, keyword spans, question counts, free boundary, VIP override through injected access, unlocked detail dispatch, and locked membership feedback without detail dispatch.

- [x] **Step 2: Run the page test and verify RED**

Run: `./tool/flutter_android21.ps1 test test/skill_mnemonics/skill_mnemonics_page_test.dart`

Expected: compile failure because the page is absent.

- [x] **Step 3: Implement the Android-aligned page states and rows**

Use one `Scaffold`, an 18sp title, numbered blue circles, three-line text limit, red keyword spans, `N题`, a visible lock treatment, and explicit `会员与支付功能仍在迁移中` feedback. Keep the bottom payment panel absent because Android currently forces it `GONE`.

- [x] **Step 4: Run the page test and verify GREEN**

Run the same test file. Expected: all pass.

### Task 6: Build the detail page and timer

**Files:**
- Create: `lib/src/skill_mnemonics/skill_mnemonics_detail_page.dart`
- Create: `test/skill_mnemonics/skill_mnemonics_detail_page_test.dart`

- [x] **Step 1: Write failing detail tests**

Verify title `技巧记忆`, initial `00:30`, countdown to `00:29`, keyword highlighting in mnemonic and explanation, related-question count, back navigation, and explicit pending feedback from the practice CTA.

- [x] **Step 2: Run the detail test and verify RED**

Run: `./tool/flutter_android21.ps1 test test/skill_mnemonics/skill_mnemonics_detail_page_test.dart`

Expected: compile failure because the detail page is absent.

- [x] **Step 3: Implement rendering and timer disposal**

Use a periodic one-second timer owned by state, cancel it in `dispose`, and keep a test-injectable tick duration. Render the gold mnemonic section, blue-gray explanation section, and fixed blue CTA with safe-area padding.

- [x] **Step 4: Run the detail test and verify GREEN**

Run the same test file. Expected: all pass with no pending timers.

### Task 7: Wire production navigation and update evidence

**Files:**
- Modify: `lib/src/app/startup_app.dart`
- Modify: `lib/ultcpa_flutter.dart`
- Modify: `test/app/startup_app_test.dart`
- Modify: `lib/src/migration/activity_coverage.dart`
- Regenerate: `docs/migration/activity_coverage.csv`

- [x] **Step 1: Write failing app-wiring tests**

Tap a real `技巧口诀` module and assert `SkillMnemonicsPage` opens with its exact module. Tap `章节练习` and unknown modules and assert distinct pending/unsupported messages without a new fake page.

- [x] **Step 2: Run the app test and verify RED**

Run: `./tool/flutter_android21.ps1 test test/app/startup_app_test.dart`

Expected: the tiles do not navigate yet.

- [x] **Step 3: Share API/state dependencies and dispatch route results**

Construct one `DioAppApiClient`, one `MethodChannelRequestContext`, and one `SkillMnemonicsRepository`. Route ready mnemonics with `Navigator.push`; show a snack bar for pending/unsupported results.

- [x] **Step 4: Record reviewed mnemonics evidence and regenerate CSV**

Mark `SkillMnemonicsActivity` complete with list-page evidence and `SkillMnemonicsDetailActivity` partial with the pending `LearnActivity` dependency stated in evidence. Regenerate the ledger.

- [x] **Step 5: Run focused tests and verify GREEN**

Run app, home, mnemonics, and migration tests. Expected: all pass.

### Task 8: Full verification

**Files:**
- Modify only files required by failures found during verification.

- [x] **Step 1: Format changed Dart files**

Run: `dart format lib test tool`

- [x] **Step 2: Run all tests**

Run: `./tool/flutter_android21.ps1 test`

Expected: zero failures.

- [x] **Step 3: Run static analysis**

Run: `./tool/flutter_android21.ps1 analyze`

Expected: `No issues found!`

- [x] **Step 4: Build the required dev APK**

Run: `./tool/flutter_android21.ps1 build apk --debug --flavor dev`

Expected: `build/app/outputs/flutter-apk/app-dev-debug.apk` is produced.

- [x] **Step 5: Inspect the final diff and ledger counts**

Run `git diff --check`, inspect `git status --short`, and report the APK path/hash plus remaining pending routes. Do not stage or commit the existing dirty migration unless the user explicitly requests it.
