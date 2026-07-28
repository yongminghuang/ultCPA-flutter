# Past Exams Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking. This migration batch remains
> intentionally uncommitted; do not stage or commit.

**Goal:** Reproduce Android's Home past-exam catalog, two-paper free boundary,
normal timed exam, result report, and all/wrong-question review in Flutter.

**Architecture:** A focused `past_exams` feature owns shelf-tree entitlement
and list UI. A reusable `exam` feature owns the exact question request,
selection-only session, timer, batch submission, result, and read-only review;
Startup composes both from one API client and state store without adding exam
branches to the existing ordinary `PracticePage`.

**Tech Stack:** Flutter 3.32/Dart 3.8, Material widgets, Dio-backed
`AppApiClient`, existing `PracticeQuestion` parsing, legacy state snapshot,
flutter_test.

---

### Task 1: Past-exams entitlement policy

**Files:**
- Modify: `lib/src/skill_mnemonics/skill_mnemonics_entitlement.dart`
- Modify: `test/skill_mnemonics/skill_mnemonics_entitlement_test.dart`

- [ ] **Step 1: Write failing entitlement tests**

Add tests for `hasPastExamsAccess` covering a current member benefit, abstract
`past_exams`, legacy `SW_PRACTICE_PAST_EXAMS_L1`, expired entries, and category,
level, or subject mismatches:

```dart
expect(
  resolver.hasPastExamsAccess(
    [
      {
        'category': 'social-work',
        'benefitsCode': 'social-work:初级社工:社工实务:past_exams',
        'expireTime': '1893456000000',
      },
    ],
    category: 'social-work',
    level: '初级社工',
    subject: '社工实务',
  ),
  isTrue,
);
```

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\skill_mnemonics\skill_mnemonics_entitlement_test.dart
```

Expected: `hasPastExamsAccess` is undefined.

- [ ] **Step 3: Implement the exact policy**

Add the public method and legacy prefix helper:

```dart
bool hasPastExamsAccess(
  Object? rawBenefits, {
  required String category,
  required String level,
  required String subject,
}) {
  if (isVip(rawBenefits, category: category, level: level, subject: subject)) {
    return true;
  }
  // Filter unexpired maps, accept the level prefix or matching abstract
  // fourth segment `all` / `past_exams`.
}

String? _pastExamsPrefix(String category, String level) => _memberPrefix(
  category,
  level,
)?.replaceFirst('_MEMBER_', '_PRACTICE_PAST_EXAMS_');
```

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 2: Paper-list models and Android tree filtering

**Files:**
- Create: `lib/src/past_exams/past_exams_models.dart`
- Create: `test/past_exams/past_exams_models_test.dart`

- [ ] **Step 1: Write failing model tests**

Require immutable paper/catalog types, a fixed free count of two, top-level
only `扁平化` filtering, server order, ID/name normalization, full-access unlock,
and malformed non-list/non-map input failures:

```dart
final papers = parsePastExamPapers(
  [
    {'id': '11', 'name': '真题一', 'type': ' 扁平化 '},
    {
      'id': 12,
      'name': '容器',
      'type': '嵌套化',
      'children': [
        {'id': 13, 'name': '不应递归', 'type': '扁平化'},
      ],
    },
    {'id': 14, 'name': '真题二', 'type': '扁平化'},
    {'id': 15, 'name': '真题三', 'type': '扁平化'},
  ],
  hasFullAccess: false,
);
expect(papers.map((paper) => paper.id), [11, 14, 15]);
expect(papers.map((paper) => paper.locked), [false, false, true]);
```

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\past_exams\past_exams_models_test.dart
```

- [ ] **Step 3: Implement minimal models and parser**

Define:

```dart
const pastExamFreePaperCount = 2;

final class PastExamPaper {
  const PastExamPaper({
    required this.id,
    required this.name,
    required this.type,
    required this.locked,
  });
  final int id;
  final String name;
  final String type;
  final bool locked;
}

final class PastExamsCatalog {
  PastExamsCatalog({
    required this.module,
    required List<PastExamPaper> papers,
    required this.hasFullAccess,
  }) : papers = List.unmodifiable(papers);
  final HomeModule module;
  final List<PastExamPaper> papers;
  final bool hasFullAccess;
}
```

Reject a non-list body and non-map nodes. Skip invalid IDs, blank names, and
all non-flat top-level nodes without descending into `children`.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 3: Catalog repository and benefit degradation

**Files:**
- Create: `lib/src/past_exams/past_exams_repository.dart`
- Create: `test/past_exams/past_exams_repository_test.dart`

- [ ] **Step 1: Write failing repository tests**

Cover:

- invalid ID and non-`嵌套化` type return empty without state/API I/O;
- exact tree request is `/app/shelf/getShelfTree?shelfId=<moduleId>`;
- logged-out users do not request benefits and receive two free papers;
- logged-in users request `/app/user/getUserBenefits` once;
- current past-exams access unlocks every paper;
- benefit transport/format failure preserves the catalog but locks after two;
- shelf transport/parse failures propagate for page retry;
- valid empty tree returns an empty catalog.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\past_exams\past_exams_repository_test.dart
```

- [ ] **Step 3: Implement the data-source boundary**

```dart
abstract interface class PastExamsDataSource {
  Future<PastExamsCatalog> loadCatalog(HomeModule module);
}

final class PastExamsRepository implements PastExamsDataSource {
  PastExamsRepository({
    required AppApiClient api,
    required LegacyAppStateStore stateStore,
    DateTime Function()? now,
  });
}
```

Validate before I/O. Load the tree first. Read the state snapshot only for a
valid nested module; request benefits only when logged in and catch only the
benefit branch. Parse with `parsePastExamPapers` after access is resolved.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 4: Normal-exam request, result, and selection session

**Files:**
- Create: `lib/src/exam/exam_models.dart`
- Create: `lib/src/exam/exam_session.dart`
- Create: `test/exam/exam_models_test.dart`
- Create: `test/exam/exam_session_test.dart`

- [ ] **Step 1: Write failing request/result tests**

Require positive module/shelf validation and the exact Android query:

```dart
expect(request.queryParameters, {
  'pageNum': 1,
  'pageSize': 120,
  'modelId': 51,
  'shelfId': 901,
});
expect(request.duration, const Duration(minutes: 135));
```

Define result status/sections and test floor percentage over every question,
elapsed time, first-seen kind grouping, and wrong/all question lists.

- [ ] **Step 2: Write failing session tests**

Cover replacement for single/judgment answers, option toggling for multiple
choice, freely editable selections, previous/next/jump bounds, unanswered
count, no correctness API before `finish`, and immutable grading after hand-in:

```dart
session.select('A');
session.select('B');
expect(session.selectedFor(question), 'B');
final result = session.finish(elapsed: const Duration(minutes: 7));
expect(result.statusFor(question), ExamQuestionStatus.right);
```

- [ ] **Step 3: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\exam\exam_models_test.dart test\exam\exam_session_test.dart
```

- [ ] **Step 4: Implement minimal exam domain types**

Define:

```dart
final class ExamRequest {
  const ExamRequest({
    required this.module,
    required this.shelfId,
    required this.title,
    this.duration = const Duration(minutes: 135),
  });
  final HomeModule module;
  final int shelfId;
  final String title;
  final Duration duration;
  Map<String, dynamic> get queryParameters;
}

enum ExamQuestionStatus { unanswered, right, wrong }

final class ExamCatalog {
  ExamCatalog({required this.request, required List<PracticeQuestion> questions});
}

final class ExamResult {
  // request, questions, normalized selections, elapsed, counts, percentage,
  // statusFor, allQuestions, wrongQuestions, and grouped sections.
}
```

`ExamSession` owns the mutable map and current index. It must not expose a
right/wrong status until `finish` creates `ExamResult`.

- [ ] **Step 5: Run Step 3 and verify GREEN**

### Task 5: Exact question load and answer-batch upload

**Files:**
- Create: `lib/src/exam/exam_repository.dart`
- Create: `test/exam/exam_repository_test.dart`

- [ ] **Step 1: Write failing repository tests**

Cover exact first-page query, `PracticePageBatch.fromBody` reuse, filtering to
questions only, empty/malformed behavior, validation before I/O, answered-only
batch submission, positive numeric IDs, normalized choice order, state-derived
subject/level, `isRight` integers, and no POST for zero valid answers.

Expected payload:

```dart
{
  'subject': '社工实务',
  'level': '初级社工',
  'questionList': [
    {'questionId': 101, 'choose': 'AC', 'isRight': 1},
  ],
}
```

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\exam\exam_repository_test.dart
```

- [ ] **Step 3: Implement `ExamDataSource` and repository**

```dart
abstract interface class ExamDataSource {
  Future<ExamCatalog> load(ExamRequest request);
  Future<void> submit(ExamResult result);
}
```

GET `/app/goods/pageGoodsData` with `request.queryParameters`. Convert only
`PracticeQuestionItem` records to the catalog. POST answered valid IDs to
`/app/question/saveQuestionRecordBatch`; allow transport failures to propagate
so the page can make them non-blocking.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 6: Timed selection-only exam page

**Files:**
- Create: `lib/src/exam/exam_page.dart`
- Create: `test/exam/exam_page_test.dart`

- [ ] **Step 1: Write failing widget tests**

Require stable keys:

```text
exam-loading
exam-error
exam-retry
exam-empty
exam-back
exam-countdown
exam-progress
exam-question
exam-option-<letter>
exam-previous
exam-next
exam-answer-card
exam-answer-<index>
exam-submit
exam-confirm-submit
```

Cover loading/retry/empty, question order, single replacement, multiple toggle,
no answer/explanation/correctness before hand-in, navigation, six-column answer
card, unanswered confirmation text, duplicate hand-in guard, a three-second
test duration auto-submit, upload success/failure, stale load/submit disposal,
back abandon confirmation, and 320 by 568 overflow.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\exam\exam_page_test.dart
```

- [ ] **Step 3: Implement the page state machine**

Use `Timer.periodic(const Duration(seconds: 1), ...)` only after a non-empty
catalog. Store a generation token and cancel the timer in `dispose`. Render
one question at a time with fixed option rows. Define and inject the result
boundary in this file:

```dart
typedef ExamResultLauncher = FutureOr<void> Function(
  BuildContext context, {
  required ExamResult result,
  required bool uploadFailed,
});

final class ExamPage extends StatefulWidget {
  const ExamPage({
    required this.request,
    required this.dataSource,
    required this.resultLauncher,
    super.key,
  });
}
```

Grade exactly once, await submit, catch its error, then invoke the guarded
result launcher with `uploadFailed`. Timer expiry skips confirmation and uses
the same guarded hand-in function.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 7: Result report and read-only review

**Files:**
- Create: `lib/src/exam/exam_result_page.dart`
- Create: `lib/src/exam/exam_review_page.dart`
- Create: `test/exam/exam_result_page_test.dart`
- Create: `test/exam/exam_review_page_test.dart`

- [ ] **Step 1: Write failing result/review tests**

Require paper title, floored accuracy, elapsed `HH:mm:ss`, right/wrong/unanswered
metrics, first-seen sections, six-column answer tiles, upload-failure notice,
all-question review, wrong-only review, no-wrong message, injected improvement,
and the default migration-boundary message.

Review must show selected answer, official answer, explanation, selected/correct
option styling, previous/next bounds, and no editable controls.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\exam\exam_result_page_test.dart test\exam\exam_review_page_test.dart
```

- [ ] **Step 3: Implement result and review pages**

Define `ExamImproveLauncher = FutureOr<void> Function(BuildContext context)`.
Use full-width unframed report bands, stable six-column grids, and
`ExamReviewPage(result: result, questions: ...)` for both review commands. The
default improve action reports `提升与会员功能仍在迁移中`.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 8: Android paper-list UI and refresh boundary

**Files:**
- Create: `lib/src/past_exams/past_exams_page.dart`
- Create: `test/past_exams/past_exams_page_test.dart`

- [ ] **Step 1: Write failing widget tests**

Cover loading/retry/empty/disposal, exact row order and titles, first two start
buttons, later lock and `去解锁`, locked default message, injected purchase
callback, duplicate callback guard, reload after callback, unlocked exam request
propagation, back, and 320 by 568 fit.

Stable keys:

```text
past-exams-loading
past-exams-error
past-exams-retry
past-exams-empty
past-exams-back
past-exams-list
past-exams-row-<index>
past-exams-start-<index>
past-exams-unlock-<index>
```

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\past_exams\past_exams_page_test.dart
```

- [ ] **Step 3: Implement the list and launch contracts**

```dart
typedef PastExamLauncher = FutureOr<void> Function(
  BuildContext context,
  ExamRequest request,
);
typedef PastExamsUnlockLauncher = FutureOr<void> Function();
```

Render the Android dimensions and colors. An unlocked row creates
`ExamRequest(module: module, shelfId: paper.id, title: paper.name)`. A successful
injected unlock callback always reloads the catalog; the default reports
`历年真题卷需解锁，会员与支付功能仍在迁移中` without changing locks.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 9: Home route and Startup composition

**Files:**
- Modify: `lib/src/main_tabs/home_module_route.dart`
- Modify: `test/main_tabs/home_module_route_test.dart`
- Modify: `lib/src/app/startup_app.dart`
- Modify: `test/app/startup_app_test.dart`

- [ ] **Step 1: Write failing integration tests**

Require exact trimmed `历年真题卷` to resolve
`HomeDestination.pastExams`; keep unrelated historical text pending/unsupported.
Startup tests must prove clicked-module propagation, shared injected catalog and
exam source identity, exact paper-to-exam request, injected purchase callback,
and that non-past routes never load the past source.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\main_tabs\home_module_route_test.dart test\app\startup_app_test.dart
```

- [ ] **Step 3: Implement default composition**

Add optional Startup injection fields for `PastExamsDataSource`,
`ExamDataSource`, `PastExamsUnlockLauncher`, and `ExamImproveLauncher`. Build
one default repository of each from the existing `apiClient` and
`requestContext`. Add `HomeDestination.pastExams`; push `PastExamsPage`, its
default paper launcher pushes `ExamPage` with the shared exam source, and the
exam result launcher replaces it with `ExamResultPage`.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 10: Public exports and migration ledger

**Files:**
- Modify: `lib/ultcpa_flutter.dart`
- Create: `test/exam/exam_exports_test.dart`
- Create: `test/past_exams/past_exams_exports_test.dart`
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`

- [ ] **Step 1: Write failing export/ledger tests**

Require every public model, source, repository, session, page, result, review,
and launcher type. Require:

- `PastExamsPaperListActivity` partial with tree, entitlement, two-free,
  refresh, exam launch, and shared-payment pending evidence;
- `LearnActivityExam` partial with past-exam request, selection-only timer,
  hand-in, batch upload, and unrelated modes pending;
- `BigSkillCircleResultActivity` partial with accuracy, grouped answer card,
  all/wrong review, and prediction/payment pending;
- `MainActivity` partial with ready past-exams destination.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\exam\exam_exports_test.dart test\past_exams\past_exams_exports_test.dart test\migration\activity_coverage_test.dart
```

- [ ] **Step 3: Implement exports and honest reviewed progress**

Add exports for all files under `src/exam/` and `src/past_exams/`. Use
`ActivityMigrationStatus.partial` for all three Android activities described
above and retain explicit pending text.

- [ ] **Step 4: Regenerate CSV**

```powershell
dart run tool\migration\source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs\migration\activity_coverage.csv
```

Expected classification totals remain:

```text
total=77 flutterPage=69 pluginCallback=3 sdkManaged=3 removed=2
```

- [ ] **Step 5: Run Step 2 and verify GREEN**

### Task 11: Full verification and dev APK

**Files:** Verify every file above.

- [ ] **Step 1: Format touched Dart files**

```powershell
dart format lib\src\exam lib\src\past_exams test\exam test\past_exams lib\src\skill_mnemonics\skill_mnemonics_entitlement.dart lib\src\app\startup_app.dart lib\src\main_tabs\home_module_route.dart lib\src\migration\activity_coverage.dart lib\ultcpa_flutter.dart test\skill_mnemonics\skill_mnemonics_entitlement_test.dart test\app\startup_app_test.dart test\main_tabs\home_module_route_test.dart test\migration\activity_coverage_test.dart
```

- [ ] **Step 2: Run focused verification**

```powershell
.\tool\flutter_android21.ps1 test test\exam test\past_exams test\skill_mnemonics\skill_mnemonics_entitlement_test.dart test\main_tabs\home_module_route_test.dart test\app\startup_app_test.dart test\migration\activity_coverage_test.dart
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

Report the exact focused/full test counts, analyzer result, CSV totals, APK
path/size/hash, remaining partial boundaries, and preserve the intentionally
uncommitted worktree.
