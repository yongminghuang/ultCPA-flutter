# Chapter Practice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This workspace contains an intentionally uncommitted migration batch, so do not stage or commit while executing this plan.

**Goal:** Migrate Android's Home `章节练习` catalog and selected-chapter learning flow into Flutter, including progress, access locks, persisted state, reset, and automatic next-chapter behavior.

**Architecture:** A chapter-specific model/repository pair loads the shelf tree, answer records, and benefits into an immutable catalog. `ChapterPracticePage` owns catalog interaction, while `PracticeRepository` and `PracticePage` reuse the existing answer engine for one selected chapter and carry a small chapter context for reset and next-chapter transitions. Android-compatible MMKV keys remain behind a dedicated progress-store interface implemented by the existing MethodChannel bridge.

**Tech Stack:** Flutter/Dart, widget tests, `flutter_test`, Dio-backed `AppApiClient`, Android Kotlin MethodChannel, MMKV.

---

### Task 1: Chapter tree, record, and progress models

**Files:**
- Create: `lib/src/chapter_practice/chapter_practice_models.dart`
- Create: `test/chapter_practice/chapter_practice_models_test.dart`

- [ ] **Step 1: Write failing parser and progress tests**

Cover a direct-entry top-level leaf, nested descendant leaves, `status: false` title fallback, duplicate question IDs, answered/right counts, `goodsCount` fallback, completion, and difficulty default/clamping. The public API exercised by the tests is:

```dart
final roots = parseChapterShelfTree(rawTree);
final catalog = ChapterPracticeCatalog.build(
  module: module,
  roots: roots,
  recordsByShelf: recordsByShelf,
  fullAccess: false,
  previewGroupCount: 2,
);

expect(catalog.groups[0].directEntry, isTrue);
expect(catalog.groups[1].chapters[0].leafShelfIds, [211, 212]);
expect(catalog.groups[1].chapters[0].doneCount, 2);
expect(catalog.groups[1].chapters[0].rightCount, 1);
expect(catalog.groups[1].chapters[0].accuracyPercent, 50);
expect(catalog.groups[1].chapters[0].difficulty, 5);
expect(catalog.groups[2].unlocked, isFalse);
```

- [ ] **Step 2: Run the model test and verify RED**

Run:

```powershell
.\tool\flutter_android21.ps1 test test/chapter_practice/chapter_practice_models_test.dart
```

Expected: compilation fails because `chapter_practice_models.dart` and its public types do not exist.

- [ ] **Step 3: Implement immutable chapter models and parsers**

Create these focused types:

```dart
final class ChapterShelfNode {
  const ChapterShelfNode({
    required this.id,
    required this.name,
    required this.goodsCount,
    required this.status,
    required this.difficulty,
    required this.children,
  });

  final int id;
  final String name;
  final int goodsCount;
  final bool? status;
  final int difficulty;
  final List<ChapterShelfNode> children;
  List<int> get leafIds;
}

final class ChapterQuestionRecord {
  const ChapterQuestionRecord({
    required this.questionId,
    required this.shelfId,
    required this.choose,
    required this.isRight,
  });
  final String questionId;
  final int shelfId;
  final String choose;
  final bool isRight;
}

final class ChapterPracticeChapter {
  const ChapterPracticeChapter({
    required this.title,
    required this.sectionShelfId,
    required this.catalogIndex,
    required this.chapterIndex,
    required this.leafShelfIds,
    required this.questionIds,
    required this.recordsByQuestionId,
    required this.unlocked,
    required this.doneCount,
    required this.rightCount,
    required this.totalCount,
    required this.accuracyPercent,
    required this.difficulty,
  });
  bool get isCompleted => totalCount > 0 && doneCount >= totalCount;
  bool get isInProgress => doneCount > 0 && !isCompleted;
}
```

`parseChapterShelfTree` must reject non-list/malformed child containers, preserve server order, and parse difficulty as default `3` clamped to `0..5`. `ChapterPracticeCatalog.build` must unlock whole groups, deduplicate question IDs in record order, and expose `chapterAt` plus `nextChapterAfter`.

- [ ] **Step 4: Run the model tests and verify GREEN**

Run the command from Step 2. Expected: all chapter model tests pass.

### Task 2: Chapter entitlement and catalog repository

**Files:**
- Create: `lib/src/chapter_practice/chapter_practice_repository.dart`
- Create: `test/chapter_practice/chapter_practice_repository_test.dart`
- Modify: `lib/src/skill_mnemonics/skill_mnemonics_entitlement.dart`
- Modify: `test/skill_mnemonics/skill_mnemonics_entitlement_test.dart`

- [ ] **Step 1: Write failing entitlement tests**

Add cases proving `hasChapterPracticeAccess` accepts an unexpired level membership, abstract `practice_chapter`/`all`, and legacy `<PREFIX>_PRACTICE_CHAPTER_<LEVEL>` benefits, while rejecting expired or mismatched category/level/subject benefits.

```dart
expect(
  resolver.hasChapterPracticeAccess(
    benefits,
    category: 'social-work',
    level: '初级社工',
    subject: '社工实务',
  ),
  isTrue,
);
```

- [ ] **Step 2: Run entitlement tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test/skill_mnemonics/skill_mnemonics_entitlement_test.dart
```

Expected: compile failure because `hasChapterPracticeAccess` is missing.

- [ ] **Step 3: Implement chapter entitlement resolution**

Reuse the resolver's expiry and scope matching. Add a `_chapterPrefix` derived from `_memberPrefix` and accept `practice_chapter` or `all` in scoped benefit codes.

- [ ] **Step 4: Run entitlement tests and verify GREEN**

Run the command from Step 2. Expected: all entitlement tests pass.

- [ ] **Step 5: Write failing repository tests**

Exercise these exact requests and failure rules:

```dart
expect(api.getRequests.single, request(
  '/app/shelf/getShelfTree',
  query: {'shelfId': 42},
));
expect(api.postRequests.first, request(
  '/app/question/getQuestionRecordList',
  body: {'modelId': 42, 'shelfIdList': first2000Ids},
));
expect(api.getRequests.last.path, '/app/user/getUserBenefits');
```

Tests must prove 2000-ID chunking, continuation after a failed record chunk, preview default `2`, snapshot override, benefits failure fallback, tree parse failure, empty/invalid module empty state, and full-access unlock.

- [ ] **Step 6: Run repository tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test/chapter_practice/chapter_practice_repository_test.dart
```

Expected: compile failure because `ChapterPracticeRepository` is missing.

- [ ] **Step 7: Implement `ChapterPracticeRepository`**

```dart
abstract interface class ChapterPracticeDataSource {
  Future<ChapterPracticeCatalog> load(HomeModule module);
}

final class ChapterPracticeRepository implements ChapterPracticeDataSource {
  ChapterPracticeRepository({
    required AppApiClient api,
    required LegacyAppStateStore stateStore,
    DateTime Function()? now,
  });
}
```

Read `chapterQuestionFreeCount` with default `2`; request records sequentially in 2000-leaf chunks and catch each chunk independently; only tree errors fail the page. Benefits are optional and use `hasChapterPracticeAccess`.

- [ ] **Step 8: Run repository and related tests and verify GREEN**

```powershell
.\tool\flutter_android21.ps1 test test/chapter_practice/chapter_practice_repository_test.dart test/skill_mnemonics/skill_mnemonics_entitlement_test.dart
```

Expected: all selected tests pass.

### Task 3: Android-compatible chapter progress store

**Files:**
- Create: `lib/src/chapter_practice/chapter_practice_progress_store.dart`
- Create: `test/chapter_practice/chapter_practice_progress_store_test.dart`
- Modify: `lib/src/network/method_channel_request_context.dart`
- Modify: `test/network/method_channel_request_context_test.dart`
- Modify: `android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt`
- Modify: `test/config/android_shell_config_test.dart`

- [ ] **Step 1: Write failing Dart MethodChannel tests**

Verify exact method names and arguments for expansion and position reads/writes:

```dart
await store.saveExpandedCatalog(moduleId: 42, catalogIndex: 3);
await store.saveQuestionPosition(
  moduleId: 42,
  catalogIndex: 3,
  chapterIndex: 2,
  position: 7,
);
expect(calls, containsAll(<MethodCall>[
  const MethodCall('setChapterPracticeExpandedCatalog', {
    'moduleId': 42,
    'catalogIndex': 3,
  }),
  const MethodCall('setChapterPracticeQuestionPosition', {
    'moduleId': 42,
    'catalogIndex': 3,
    'chapterIndex': 2,
    'position': 7,
  }),
]));
```

- [ ] **Step 2: Run MethodChannel tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test/chapter_practice/chapter_practice_progress_store_test.dart test/network/method_channel_request_context_test.dart
```

Expected: compile failure because the progress-store API is missing.

- [ ] **Step 3: Implement the Dart progress store**

Define four methods (`load/saveExpandedCatalog`, `load/saveQuestionPosition`) and a disabled fallback. Have `MethodChannelRequestContext` implement the interface and validate non-negative IDs/indices before invoking native methods.

- [ ] **Step 4: Run Dart MethodChannel tests and verify GREEN**

Run the command from Step 2. Expected: all selected tests pass.

- [ ] **Step 5: Write failing native source-contract tests**

Assert `readAppSnapshot` exports `chapterQuestionFreeCount` and the bridge contains both exact key templates:

```dart
expect(bridge, contains('"chapterQuestionFreeCount" to appKv.decodeInt('));
expect(bridge, contains('"chapter_question_free_count", 2)'));
expect(bridge, contains('chapter_practice_list_expanded_catalog'));
expect(bridge, contains('_learnQPos'));
```

- [ ] **Step 6: Run native source-contract tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test/config/android_shell_config_test.dart
```

Expected: failure because the snapshot export and native methods are absent.

- [ ] **Step 7: Implement Kotlin MMKV bridge methods**

Build keys from `legacyUserId()`, current `category`, module/catalog/chapter indices, and use these exact forms:

```kotlin
"${legacyUserId()}_${currentCategory()}_${moduleId}_chapter_practice_list_expanded_catalog"
"${legacyUserId()}_${currentCategory()}_${moduleId}_${catalogIndex}_${chapterIndex}_learnQPos"
```

Reads default to `-1` for expanded catalog and `0` for question position. Writes reject negative indices/positions. Export `chapter_question_free_count` from `readAppSnapshot` with default `2`.

- [ ] **Step 8: Run native source-contract tests and verify GREEN**

Run the command from Step 6. Expected: all Android shell configuration tests pass.

### Task 4: Selected-chapter loading and chapter-only reset

**Files:**
- Modify: `lib/src/practice/practice_models.dart`
- Modify: `lib/src/practice/practice_repository.dart`
- Modify: `test/practice/practice_models_test.dart`
- Modify: `test/practice/practice_repository_test.dart`

- [ ] **Step 1: Write failing selected-chapter tests**

Add `ChapterPracticeEntryMode { resume, view, redo, automatic }` and `ChapterPracticeRequest(module, catalogIndex, chapterIndex, entryMode)`. Tests must show that a non-first chapter is selected, all its descendant leaves load in order, server records overlay `choose/isRight`, indices are validated, and the returned catalog carries current and next chapter context.

```dart
final catalog = await repository.load(const ChapterPracticeRequest(
  module: structuredModule,
  catalogIndex: 1,
  chapterIndex: 2,
  entryMode: ChapterPracticeEntryMode.resume,
));
expect(questionIds(catalog), ['q-211', 'q-212']);
expect(catalog.chapterContext!.nextChapter!.catalogIndex, 2);
```

- [ ] **Step 2: Run selected repository tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test/practice/practice_models_test.dart test/practice/practice_repository_test.dart
```

Expected: compile failure because the chapter request/context APIs are missing.

- [ ] **Step 3: Implement selected-chapter loading**

Add `PracticeQuestion.withServerAnswer`, `PracticeChapterContext`, and `PracticeChapterTarget`. `PracticeRepository` delegates authoritative catalog loading to `ChapterPracticeRepository`, rejects locked selections, loads one leaf through paged `pageGoodsData` or multiple leaves through `listGoods`, overlays records by question ID, and gives chapter practice unrestricted per-question access because locking is at group level.

- [ ] **Step 4: Run selected loading tests and verify GREEN**

Run the command from Step 2. Expected: all selected tests pass.

- [ ] **Step 5: Write failing redo payload tests**

For `entryMode.redo`, assert the repository posts before returning a cleared catalog:

```dart
expect(api.postRequests.last.body, {
  'questionIds': [9007199254740993, 43],
  'subject': '社工实务',
  'level': '初级社工',
  'type': 1,
});
expect(catalog.items.whereType<PracticeQuestionItem>()
    .every((item) => item.question.serverAnswer == null), isTrue);
```

Also prove a failed delete propagates and does not return a locally reset session.

- [ ] **Step 6: Run redo tests and verify RED**

Run the repository test command from Step 2. Expected: failure because redo does not post the chapter-only reset.

- [ ] **Step 7: Implement redo after authoritative question loading**

Derive positive numeric IDs from every selected question, post `/app/question/deleteQuestionRecord` with selected subject/level and `type: 1`, then remove server answers only after the call succeeds.

- [ ] **Step 8: Run selected repository tests and verify GREEN**

Run the command from Step 2. Expected: all selected tests pass.

### Task 5: Chapter catalog page

**Files:**
- Create: `lib/src/chapter_practice/chapter_practice_page.dart`
- Create: `test/chapter_practice/chapter_practice_page_test.dart`

- [ ] **Step 1: Write failing page state and interaction tests**

Cover loading, retryable failure, empty state, initial saved expansion, exclusive expansion persistence, progress/accuracy/difficulty rendering, locked group gating, unlocked launch, reload after returning, and stale async response disposal.

Use stable keys:

```text
chapter-practice-loading
chapter-practice-error
chapter-practice-retry
chapter-practice-empty
chapter-practice-group-<index>
chapter-practice-chapter-<catalog>-<chapter>
```

- [ ] **Step 2: Run page tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test/chapter_practice/chapter_practice_page_test.dart
```

Expected: compile failure because `ChapterPracticePage` is missing.

- [ ] **Step 3: Implement the catalog page**

Build a quiet full-width list under an AppBar titled `章节练习`; use one expanded group at a time, a lock icon and `去解锁` for locked groups, a linear progress indicator, integer accuracy, and five star icons. Locked taps show `章节练习需解锁，会员与支付功能仍在迁移中` and never invoke the launcher.

- [ ] **Step 4: Run base page tests and verify GREEN**

Run the command from Step 2. Expected: base page tests pass.

- [ ] **Step 5: Write failing completed-chapter dialog tests**

Clicking a completed chapter must first show `本章已全部学完`, `重练本章`, and `进入查看`. Assert redo launches `ChapterPracticeEntryMode.redo`; view launches `view`; normal/in-progress chapters launch `resume` directly.

- [ ] **Step 6: Run completed dialog tests and verify RED**

Run the command from Step 2. Expected: failure because completed choices are absent.

- [ ] **Step 7: Implement completed choices and post-return refresh**

Use an `AlertDialog`; await the injected/default practice launcher; reload the catalog only after the launched route returns and ignore stale/disposed results via a load version.

- [ ] **Step 8: Run chapter page tests and verify GREEN**

Run the command from Step 2. Expected: all chapter page tests pass.

### Task 6: Runner resume, persistence, reset, and automatic next chapter

**Files:**
- Modify: `lib/src/practice/practice_session.dart`
- Modify: `lib/src/practice/practice_page.dart`
- Modify: `test/practice/practice_session_test.dart`
- Modify: `test/practice/practice_page_test.dart`

- [ ] **Step 1: Write failing resume and persistence tests**

Inject `ChapterPracticeProgressStore` into `PracticePage`. Prove resume restores only an in-progress chapter, while `view`, `redo`, and `automatic` start at index `0`. Verify successful previous/next/answer-card jumps persist Android's chapter position and failed jumps do not.

- [ ] **Step 2: Run page/session tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test/practice/practice_session_test.dart test/practice/practice_page_test.dart
```

Expected: failures because chapter resume and position persistence are not wired.

- [ ] **Step 3: Implement request-aware initial position and persistence**

Keep `_activeRequest` in page state. After creating a chapter session, restore/clamp the saved index only for `resume` plus `answeredCount > 0 && unansweredCount > 0`. Persist every successful navigation and write `0` for redo/automatic entry.

- [ ] **Step 4: Run resume tests and verify GREEN**

Run the command from Step 2. Expected: resume and persistence tests pass.

- [ ] **Step 5: Write failing end-of-chapter tests**

At the last item assert:

```text
unlocked next -> load next request at 0; SnackBar "已学完，自动进入<name>"
locked next   -> remain on current item; unlock migration SnackBar
no next + complete -> dialog "本章已全部学完" with "重练本章" and "取消"
no next + incomplete -> existing PracticeResultPage
```

Redo must call `load` with `entryMode.redo`, save position `0`, and replace the session only after loading succeeds.

- [ ] **Step 6: Run end-flow tests and verify RED**

Run the command from Step 2. Expected: failures because the generic result flow still handles every chapter ending.

- [ ] **Step 7: Implement chapter-specific end flow**

Branch only when `catalog.chapterContext != null`; retain all existing non-chapter behavior. Use the context's next target/access state, a load version for chapter transitions, and the existing result page only for the specified incomplete terminal case.

- [ ] **Step 8: Run all practice tests and verify GREEN**

```powershell
.\tool\flutter_android21.ps1 test test/practice
```

Expected: all practice tests pass.

### Task 7: Home routing, Startup dependency wiring, and exports

**Files:**
- Modify: `lib/src/main_tabs/home_module_route.dart`
- Modify: `test/main_tabs/home_module_route_test.dart`
- Modify: `lib/src/app/startup_app.dart`
- Modify: `test/app/startup_app_test.dart`
- Modify: `lib/ultcpa_flutter.dart`

- [ ] **Step 1: Write failing route and Startup navigation tests**

Move exact `章节练习` from pending to `HomeDestination.chapterPractice`. In `StartupApp`, inject chapter data/progress sources, tap a Home module, and assert the full-screen chapter catalog appears rather than a migration SnackBar or direct `PracticePage`.

- [ ] **Step 2: Run route and Startup tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test/main_tabs/home_module_route_test.dart test/app/startup_app_test.dart
```

Expected: failures because the destination and dependency wiring do not exist.

- [ ] **Step 3: Implement Home and Startup wiring**

Add the destination, remove `章节练习` from `_pendingHomePages`, instantiate one `ChapterPracticeRepository`, pass the shared `MethodChannelRequestContext` as progress store, and launch `ChapterPracticePage` with the existing `PracticeDataSource`. Export all chapter-practice public files.

- [ ] **Step 4: Run route and Startup tests and verify GREEN**

Run the command from Step 2. Expected: all selected tests pass.

### Task 8: Migration ledger and full verification

**Files:**
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `docs/migration/activity_coverage.csv`
- Modify: `tool/migration/source_manifest.dart`
- Modify: `test/migration/activity_coverage_test.dart`

- [ ] **Step 1: Write/update the failing activity coverage expectation**

Mark Android `ChapterPracticeListActivity` as migrated to Flutter's chapter catalog/runner flow and add the Flutter source files to the manifest-backed coverage assertion.

- [ ] **Step 2: Run migration tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test/migration/activity_coverage_test.dart
```

Expected: failure until the ledger and generated source are synchronized.

- [ ] **Step 3: Update the coverage source and regenerate the CSV**

Follow the existing `tool/migration/source_manifest.dart` generation path; do not hand-edit unrelated coverage rows.

- [ ] **Step 4: Run migration tests and verify GREEN**

Run the command from Step 2. Expected: migration coverage tests pass.

- [ ] **Step 5: Run formatting and focused verification**

```powershell
dart format lib/src/chapter_practice test/chapter_practice lib/src/practice lib/src/app/startup_app.dart lib/src/main_tabs/home_module_route.dart lib/src/network/method_channel_request_context.dart lib/src/skill_mnemonics/skill_mnemonics_entitlement.dart test/practice test/app/startup_app_test.dart test/main_tabs/home_module_route_test.dart test/network/method_channel_request_context_test.dart test/skill_mnemonics/skill_mnemonics_entitlement_test.dart
.\tool\flutter_android21.ps1 test test/chapter_practice test/practice test/main_tabs/home_module_route_test.dart test/app/startup_app_test.dart test/network/method_channel_request_context_test.dart test/config/android_shell_config_test.dart test/skill_mnemonics/skill_mnemonics_entitlement_test.dart test/migration/activity_coverage_test.dart
```

Expected: formatter exits `0`; all focused tests pass.

- [ ] **Step 6: Run full Flutter verification**

```powershell
.\tool\flutter_android21.ps1 test
.\tool\flutter_android21.ps1 analyze
git diff --check
```

Expected: full test suite passes, analyzer reports `No issues found!`, and diff check exits `0`.

- [ ] **Step 7: Build and hash the dev debug APK**

```powershell
.\tool\flutter_android21.ps1 build apk --debug --flavor dev
Get-FileHash build\app\outputs\flutter-apk\app-dev-debug.apk -Algorithm SHA256
```

Expected: APK build exits `0`; report the resulting SHA-256 without staging or committing files.
