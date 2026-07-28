# Pre-Exam Secret Paper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking. This migration batch remains
> intentionally uncommitted; do not stage or commit.

**Goal:** Reproduce Android's `最后密押卷` landing page, recursive three-paper
catalog, membership gate, unlock refresh, and normal-exam launch in Flutter.

**Architecture:** A focused `pre_exam_secret_paper` feature owns recursive
shelf parsing, membership resolution, and the bitmap-backed landing surface.
Startup composes it from the existing API/state dependencies and reuses the
already migrated `ExamPage` and `ExamResultPage` instead of creating another
exam runtime.

**Tech Stack:** Flutter 3.32/Dart 3.8, Material widgets, Dio-backed
`AppApiClient`, legacy state snapshot, existing exam domain, flutter_test.

---

### Task 1: Recursive secret-paper catalog models

**Files:**
- Create: `lib/src/pre_exam_secret_paper/pre_exam_secret_paper_models.dart`
- Create: `test/pre_exam_secret_paper/pre_exam_secret_paper_models_test.dart`

- [ ] **Step 1: Write failing recursive parsing tests**

Cover depth-first leaf order, parent exclusion, empty-name and non-positive-ID
exclusion, malformed body/children, immutable catalogs, and the fixed A/B/C
copy table:

```dart
final papers = parsePreExamSecretPapers([
  {
    'id': 10,
    'name': '父节点',
    'children': [
      {'id': 11, 'name': '卷一', 'children': []},
      {
        'id': 12,
        'name': '二级父节点',
        'children': [
          {'id': 13, 'name': '卷二'},
        ],
      },
    ],
  },
]);
expect(papers.map((paper) => paper.id), [11, 13]);
expect(preExamSecretPaperCardCopies, hasLength(3));
```

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\pre_exam_secret_paper\pre_exam_secret_paper_models_test.dart
```

Expected: the imported model file and parser do not exist.

- [ ] **Step 3: Implement immutable models and parser**

Define these public contracts:

```dart
final class PreExamSecretPaper {
  const PreExamSecretPaper({required this.id, required this.name});
  final int id;
  final String name;
}

final class PreExamSecretPaperCatalog {
  PreExamSecretPaperCatalog({
    required this.module,
    required List<PreExamSecretPaper> papers,
    required this.isVip,
  }) : papers = List.unmodifiable(papers);
  final HomeModule module;
  final List<PreExamSecretPaper> papers;
  final bool isVip;
}

final class PreExamSecretPaperCardCopy {
  const PreExamSecretPaperCardCopy({
    required this.title,
    required this.description,
  });
  final String title;
  final String description;
}
```

Add the exact three Android copy records and a recursive parser that treats a
missing or empty `children` list as a leaf, preserves server order, and throws
`FormatException` for a non-list body or non-list `children` value.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 2: Exact repository and VIP degradation

**Files:**
- Create: `lib/src/pre_exam_secret_paper/pre_exam_secret_paper_repository.dart`
- Create: `test/pre_exam_secret_paper/pre_exam_secret_paper_repository_test.dart`

- [ ] **Step 1: Write failing repository tests**

Use recording API/state fakes to verify:

```dart
expect(api.calls.single.path, '/app/shelf/getShelfTree');
expect(api.calls.single.queryParameters, {'shelfId': 81});
expect(catalog.papers.map((paper) => paper.id), [101, 102, 103, 104]);
expect(catalog.isVip, isTrue);
```

Also cover member-prefix access, the three answering benefits, logged-out
behavior, benefit-request failure degrading to `isVip == false`, shelf failure
remaining fatal, and invalid module IDs doing no I/O.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\pre_exam_secret_paper\pre_exam_secret_paper_repository_test.dart
```

Expected: `PreExamSecretPaperRepository` is undefined.

- [ ] **Step 3: Implement the data source**

Create the injectable interface and repository:

```dart
abstract interface class PreExamSecretPaperDataSource {
  Future<PreExamSecretPaperCatalog> loadCatalog(HomeModule module);
}

final class PreExamSecretPaperRepository
    implements PreExamSecretPaperDataSource {
  PreExamSecretPaperRepository({
    required AppApiClient api,
    required LegacyAppStateStore stateStore,
    DateTime Function()? now,
  });
}
```

For positive module IDs, request the shelf tree, parse recursive leaves, then
read the app snapshot. Only logged-in snapshots request
`/app/user/getUserBenefits`. Resolve full membership through
`SkillMnemonicsEntitlementResolver.isVip`; catch only the benefit request and
degrade to non-member.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 3: Android bitmap assets and public surface

**Files:**
- Create: `assets/images/pre_exam_secret_paper/pre_exam_before_exam_bg.png`
- Create: `assets/images/pre_exam_secret_paper/pre_exam_before_exam_ic.png`
- Modify: `pubspec.yaml`
- Create: `test/pre_exam_secret_paper/pre_exam_secret_paper_exports_test.dart`
- Modify: `lib/ultcpa_flutter.dart`

- [ ] **Step 1: Write a failing public-export test**

Import only `package:ultcpa_flutter/ultcpa_flutter.dart` and reference
`PreExamSecretPaper`, `PreExamSecretPaperCatalog`,
`PreExamSecretPaperDataSource`, `PreExamSecretPaperRepository`, and
`PreExamSecretPaperPage`.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\pre_exam_secret_paper\pre_exam_secret_paper_exports_test.dart
```

Expected: the feature symbols are not exported and the page is not defined.

- [ ] **Step 3: Copy authoritative Android assets and register them**

Copy the two PNG files byte-for-byte from:

```text
E:\workspace\ultCPA-android\ultCPA\src\main\res\drawable-xxxhdpi\
```

Register the Flutter directory:

```yaml
flutter:
  assets:
    - assets/images/pre_exam_secret_paper/
```

Export all three feature files from `lib/ultcpa_flutter.dart`. The export test
will become green after Task 4 creates the page.

### Task 4: Landing page, gate, and unlock refresh

**Files:**
- Create: `lib/src/pre_exam_secret_paper/pre_exam_secret_paper_page.dart`
- Create: `test/pre_exam_secret_paper/pre_exam_secret_paper_page_test.dart`

- [ ] **Step 1: Write failing state and visual-contract tests**

Cover the Android title, cream background, both bitmap asset names, loading,
retryable failure, empty catalog, at most three cards, exact A/B/C copy, member
bottom-action hiding, and 320 by 568 overflow safety.

```dart
expect(find.text('最后密押卷'), findsOneWidget);
expect(find.text('密卷A: 新规智能预测卷'), findsOneWidget);
expect(find.byKey(const ValueKey('secret-paper-card-3')), findsNothing);
expect(tester.takeException(), isNull);
```

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\pre_exam_secret_paper\pre_exam_secret_paper_page_test.dart
```

Expected: `PreExamSecretPaperPage` is undefined.

- [ ] **Step 3: Implement the page shell and async states**

Create these injection boundaries:

```dart
typedef PreExamSecretPaperExamLauncher = FutureOr<void> Function(
  BuildContext context,
  ExamRequest request,
);
typedef PreExamSecretPaperUnlockLauncher = FutureOr<void> Function();
```

Build a white AppBar, cream Scaffold, scrollable hero/content area, inline
loading/error/empty states, and a non-member bottom action. Guard generations
so stale load completions are ignored after retry or disposal.

- [ ] **Step 4: Run Step 2 and verify the visual/state tests GREEN**

- [ ] **Step 5: Add failing interaction tests**

Verify member card taps emit the corresponding leaf shelf ID and backend paper
name in an `ExamRequest`; non-member card and bottom taps invoke unlock instead;
missing unlock reports the honest pending message; an injected unlock reloads
membership; duplicate taps and stale completions are ignored; launcher and
unlock failures restore controls and report a message.

- [ ] **Step 6: Run and verify interaction tests RED**

Expected: taps do not yet call the required launchers or refresh the catalog.

- [ ] **Step 7: Implement interaction behavior**

Use separate launching and unlocking guards. Members launch:

```dart
ExamRequest(
  module: widget.module,
  shelfId: paper.id,
  title: paper.name,
)
```

Non-members always use the unlock boundary. After a successful callback,
reload the catalog before re-enabling actions.

- [ ] **Step 8: Run the page tests and verify GREEN**

### Task 5: Exact Home routing

**Files:**
- Modify: `lib/src/main_tabs/home_module_route.dart`
- Modify: `test/main_tabs/home_module_route_test.dart`

- [ ] **Step 1: Write failing exact and historical route tests**

```dart
expect(
  resolveHomeModuleRoute(' 最后密押卷 '),
  const ReadyHomeModuleRoute(HomeDestination.preExamSecretPaper),
);
expect(
  resolveHomeModuleRoute('首页-最后密押卷-推荐'),
  const ReadyHomeModuleRoute(HomeDestination.preExamSecretPaper),
);
```

Keep unrelated pending routes pending.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\main_tabs\home_module_route_test.dart
```

Expected: `HomeDestination.preExamSecretPaper` is undefined.

- [ ] **Step 3: Implement exact and contains-based ready routing**

Add the destination, remove exact `最后密押卷` from `_pendingHomePages`, return
the ready destination for exact text, and replace the historical pending
mapping with a ready contains match.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 6: Startup composition and shared exam path

**Files:**
- Modify: `lib/src/app/startup_app.dart`
- Modify: `test/app/startup_app_test.dart`

- [ ] **Step 1: Write failing Startup integration tests**

Inject recording secret-paper and exam data sources. Verify the Home module
opens the landing page, a member card launches `ExamPage` with exact module and
shelf identity, hand-in reaches the shared result path, the unlock callback is
forwarded and triggers reload, and non-secret routes never touch the new data
source.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\app\startup_app_test.dart
```

Expected: Startup has no secret-paper dependencies or ready destination case.

- [ ] **Step 3: Compose the repository and route**

Add optional constructor fields:

```dart
final PreExamSecretPaperDataSource? preExamSecretPaperDataSource;
final PreExamSecretPaperUnlockLauncher? preExamSecretPaperUnlockLauncher;
```

Construct the default repository from the shared API client/state store. Add
the ready switch case that pushes `PreExamSecretPaperPage`, passing the shared
normal-exam launcher and injected unlock callback.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 7: Migration ledger evidence

**Files:**
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Modify: `docs/migration/activity_coverage.csv` (generated)

- [ ] **Step 1: Write failing ledger tests**

Require `PreExamSecretPaperLandingActivity2` to be partial with
`PreExamSecretPaperPage` and evidence for recursive catalog, VIP gate, unlock
refresh, and exam launch. Require `LearnActivityExam` and `MainActivity`
evidence to mention the secret-paper normal-exam route.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\migration\activity_coverage_test.dart
```

Expected: the landing activity remains pending and has no Flutter surface.

- [ ] **Step 3: Update authoritative overrides and regenerate CSV**

Update the three override records, then run:

```powershell
dart run tool\migration\source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs\migration\activity_coverage.csv
```

Expected:

```text
total=77 flutterPage=69 pluginCallback=3 sdkManaged=3 removed=2
```

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 8: Full verification and dev APK

**Files:**
- Verify all files changed above

- [ ] **Step 1: Format only this slice and its integration files**

```powershell
dart format lib\src\pre_exam_secret_paper test\pre_exam_secret_paper lib\src\main_tabs\home_module_route.dart lib\src\app\startup_app.dart lib\src\migration\activity_coverage.dart lib\ultcpa_flutter.dart test\main_tabs\home_module_route_test.dart test\app\startup_app_test.dart test\migration\activity_coverage_test.dart
```

- [ ] **Step 2: Run focused tests**

```powershell
.\tool\flutter_android21.ps1 test test\pre_exam_secret_paper test\main_tabs\home_module_route_test.dart test\app\startup_app_test.dart test\migration\activity_coverage_test.dart
```

- [ ] **Step 3: Run all tests and Analyzer**

```powershell
.\tool\flutter_android21.ps1 test
.\tool\flutter_android21.ps1 analyze
git diff --check
```

- [ ] **Step 4: Build a fresh dev debug APK**

```powershell
.\tool\flutter_android21.ps1 build apk --debug --flavor dev
```

- [ ] **Step 5: Record artifact evidence and worktree state**

Read exact byte size and SHA-256 for
`build\app\outputs\flutter-apk\app-dev-debug.apk`, validate the CSV disposition
counts, and run `git status --short`. Do not stage, commit, or alter unrelated
working-tree changes.
