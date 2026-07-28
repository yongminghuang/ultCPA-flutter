# Error And Collection Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reproduce Android Mine error-question and collected-question review flows with the shared Flutter practice runner.

**Architecture:** Add request-specific catalog behavior rather than duplicating the session or page. Extend the production repository with the two exact paged endpoints, then pass a typed Mine launcher through `MainTabsPage` to `StartupApp`.

**Tech Stack:** Flutter 3.32.8, Dart 3.8, Material, `AppApiClient`, legacy snapshot state, `flutter_test`.

---

### Task 1: Define review behavior

**Files:**
- Modify: `lib/src/practice/practice_models.dart`
- Modify: `lib/src/practice/practice_session.dart`
- Modify: `test/practice/practice_models_test.dart`
- Modify: `test/practice/practice_session_test.dart`

- [x] **Step 1: Write failing behavior tests**

Require a standard default and a review policy with `restoreServerAnswers=false`, `persistAnswers=false`, `showResults=false`, and mode-specific empty text. Require `PracticeSession` to ignore a response snapshot when restoration is disabled.

- [x] **Step 2: Verify RED**

Run: `./tool/flutter_android21.ps1 test test/practice/practice_models_test.dart test/practice/practice_session_test.dart`

Expected: compile failures for the missing behavior model and session parameter.

- [x] **Step 3: Implement immutable behavior**

Add `PracticeBehavior` to `PracticeCatalog` with a standard default, and make `PracticeSession` consult `catalog.behavior.restoreServerAnswers` during initialization.

- [x] **Step 4: Verify GREEN**

Run the same focused tests. Expected: all pass.

### Task 2: Load Mine review data

**Files:**
- Modify: `lib/src/practice/practice_repository.dart`
- Modify: `test/practice/practice_repository_test.dart`

- [x] **Step 1: Write failing repository tests**

Specify `ErrorPracticeRequest` and `CollectionPracticeRequest`, page size 200, selected subject/level queries, all-page merging using `pages` or `total`, full access, review behavior, and no benefits request.

- [x] **Step 2: Verify RED**

Run: `./tool/flutter_android21.ps1 test test/practice/practice_repository_test.dart`

Expected: missing request classes and endpoint behavior.

- [x] **Step 3: Implement review requests and paging**

Load the snapshot and the appropriate `/app/question/pageErrorQuestion` or `/app/question/pageCollectQuestion` endpoint. Preserve server record order and return the review policy.

- [x] **Step 4: Verify GREEN**

Run the focused repository test. Expected: all pass.

### Task 3: Apply review behavior in the page

**Files:**
- Modify: `lib/src/practice/practice_page.dart`
- Modify: `test/practice/practice_page_test.dart`

- [x] **Step 1: Write failing widget tests**

Assert review empty text, no `saveAnswer` call after submission, and `当前已是最后一题` on the final navigation action with no `PracticeResultPage`.

- [x] **Step 2: Verify RED**

Run: `./tool/flutter_android21.ps1 test test/practice/practice_page_test.dart`

Expected: current standard behavior persists the answer and opens results.

- [x] **Step 3: Implement policy-driven side effects**

Use catalog behavior for the empty copy, persistence decision, and last-item action. Keep the standard flow unchanged.

- [x] **Step 4: Verify GREEN**

Run the focused widget test. Expected: all pass.

### Task 4: Wire Mine entries

**Files:**
- Modify: `lib/src/main_tabs/mine_tab_page.dart`
- Modify: `lib/src/main_tabs/main_tabs_page.dart`
- Modify: `lib/src/app/startup_app.dart`
- Modify: `test/main_tabs/mine_tab_page_test.dart`
- Modify: `test/main_tabs/main_tabs_page_test.dart`
- Modify: `test/app/startup_app_test.dart`

- [x] **Step 1: Write failing entry tests**

Cover logged-out login dispatch, logged-in zero-count messages, exact error/collection launcher types, callback propagation through `MainTabsPage`, and production navigation requests in `StartupApp`.

- [x] **Step 2: Verify RED**

Run: `./tool/flutter_android21.ps1 test test/main_tabs/mine_tab_page_test.dart test/main_tabs/main_tabs_page_test.dart test/app/startup_app_test.dart`

Expected: Mine rows are not interactive and no review launcher exists.

- [x] **Step 3: Implement typed Mine routing**

Add `MineReviewKind`, stable row keys, login/count gating, launcher propagation, and request mapping to the shared `PracticePage`.

- [x] **Step 4: Verify GREEN**

Run the same focused tests. Expected: all pass.

### Task 5: Update evidence and verify

**Files:**
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`
- Update: `docs/superpowers/plans/2026-07-16-error-collection-review.md`

- [x] **Step 1: Write failing ledger expectations**

Require `LearnActivity` evidence to name Mine error/collection review as migrated while retaining every other pending mode and removal/editing gaps.

- [x] **Step 2: Update and regenerate the ledger**

Run: `dart run tool/migration/source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs/migration/activity_coverage.csv`

- [x] **Step 3: Format changed Dart files**

Run `dart format` on the exact modified Dart files.

- [x] **Step 4: Run full verification**

Run: `./tool/flutter_android21.ps1 test`

Run: `./tool/flutter_android21.ps1 analyze`

- [x] **Step 5: Build and hash the dev APK**

Run: `./tool/flutter_android21.ps1 build apk --debug --flavor dev`

Record `build/app/outputs/flutter-apk/app-dev-debug.apk`, SHA-256, and `git diff --check`. Do not stage or commit the dirty migration.
