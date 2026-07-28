# Review Management Fidelity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete collection editing, wrong-question removal settings, and the authenticated Home wrong-review entry with Android-compatible persistence and requests.

**Architecture:** Keep mutable review presentation state in `PracticeSession`, API commands in `PracticeRepository`, and legacy-compatible local persistence behind `PracticeReviewStore`. Reuse the shared `PracticePage` and typed Home routing instead of introducing a second review runner.

**Tech Stack:** Flutter 3.32.8, Dart 3.8, Material, `AppApiClient`, Android Kotlin MethodChannel, SharedPreferences, SQLite, `flutter_test`.

---

### Task 1: Model review modes and session mutations

**Files:**
- Modify: `lib/src/practice/practice_models.dart`
- Modify: `lib/src/practice/practice_session.dart`
- Modify: `test/practice/practice_models_test.dart`
- Modify: `test/practice/practice_session_test.dart`

- [x] **Step 1: Write failing tests** for `PracticeReviewKind.errors`,
  `PracticeReviewKind.collections`, collection-review forced collected state,
  `setCollected`, and `removeQuestion` index repair.
- [x] **Step 2: Run RED:**
  `./tool/flutter_android21.ps1 test test/practice/practice_models_test.dart test/practice/practice_session_test.dart`.
- [x] **Step 3: Implement the minimal model:** add the review kind to
  `PracticeBehavior`, retain a mutable private item list, expose immutable
  session items/collection state, and remove by stable question ID.
- [x] **Step 4: Run GREEN** with the same command.

### Task 2: Add review storage and exact repository commands

**Files:**
- Create: `lib/src/practice/practice_review_store.dart`
- Modify: `lib/src/network/method_channel_request_context.dart`
- Modify: `lib/src/practice/practice_repository.dart`
- Modify: `android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt`
- Modify: `test/network/method_channel_request_context_test.dart`
- Modify: `test/practice/practice_repository_test.dart`

- [x] **Step 1: Write failing tests** for these APIs:

```dart
Future<void> setCollected(PracticeQuestion question, bool collected);
Future<void> removeWrongQuestion(PracticeQuestion question);
Future<ErrorPracticeAvailability> probeErrorPractice();
Future<int> loadWrongRemovalThreshold();
Future<void> saveWrongRemovalThreshold(int threshold);
Future<bool> recordWrongQuestionCorrect(PracticeQuestion question);
```

  Require exact POST bodies and the exact authenticated page-size-one probe.
  Require MethodChannel calls for threshold read/write and correct recording.
- [x] **Step 2: Run RED:**
  `./tool/flutter_android21.ps1 test test/practice/practice_repository_test.dart test/network/method_channel_request_context_test.dart`.
- [x] **Step 3: Implement the repository/store methods.** Validate positive
  numeric server IDs, use the latest snapshot subject/level, and validate
  thresholds as `-1` or `1..7`.
- [x] **Step 4: Add Android handlers.** Use
  `learn_bank_<userId>/removeErrorNumber`; update an existing
  `learnRecord.questionCount` table transactionally, otherwise use per-user
  preference counter keys.
- [x] **Step 5: Run GREEN** with the focused tests and compile later in the APK
  verification task.

### Task 3: Add collection and wrong-removal controls

**Files:**
- Modify: `lib/src/practice/practice_page.dart`
- Modify: `test/practice/practice_page_test.dart`

- [x] **Step 1: Write failing widget tests** for optimistic collect/uncollect,
  collection-review immediate removal, no rollback on collection failure,
  manual removal success/failure, correct-only threshold removal, stable-ID
  async removal, and the eight threshold choices.
- [x] **Step 2: Run RED:**
  `./tool/flutter_android21.ps1 test test/practice/practice_page_test.dart`.
- [x] **Step 3: Implement minimal UI and orchestration.** Add favorite and
  delete icon actions, an error-review settings icon/bottom sheet, mode-specific
  request timing, and an empty-route exit helper.
- [x] **Step 4: Run GREEN** with the focused widget test.

### Task 4: Wire the Home wrong-review entry

**Files:**
- Modify: `lib/src/main_tabs/home_module_route.dart`
- Modify: `lib/src/app/startup_app.dart`
- Modify: `test/main_tabs/home_module_route_test.dart`
- Modify: `test/app/startup_app_test.dart`

- [x] **Step 1: Write failing tests** that resolve `错题巩固` to a ready typed
  destination, open login without probing when logged out, show `暂无错题` for
  zero, and push `ErrorPracticeRequest` for a positive total.
- [x] **Step 2: Run RED:**
  `./tool/flutter_android21.ps1 test test/main_tabs/home_module_route_test.dart test/app/startup_app_test.dart`.
- [x] **Step 3: Implement the typed destination and Startup gate.** Swallow
  probe failures to match Android and leave every other pending route unchanged.
- [x] **Step 4: Run GREEN** with the same command.

### Task 5: Update evidence and verify

**Files:**
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`
- Update: `docs/superpowers/plans/2026-07-16-review-management-fidelity.md`

- [x] **Step 1: Write a failing ledger expectation** that removes collection
  editing, wrong-removal settings, and Home wrong-entry from the remaining
  `LearnActivity` evidence while retaining unrelated pending modes.
- [x] **Step 2: Regenerate:**
  `dart run tool/migration/source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs/migration/activity_coverage.csv`.
- [x] **Step 3: Format every changed Dart file** with `dart format`.
- [x] **Step 4: Run full verification:**
  `./tool/flutter_android21.ps1 test` and
  `./tool/flutter_android21.ps1 analyze`.
- [x] **Step 5: Build:**
  `./tool/flutter_android21.ps1 build apk --debug --flavor dev`, then run
  `Get-FileHash -Algorithm SHA256 build/app/outputs/flutter-apk/app-dev-debug.apk`
  and `git diff --check`.
