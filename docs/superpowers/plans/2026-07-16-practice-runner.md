# Practice Runner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the shared Flutter practice engine used by home `技巧练题` and mnemonic-related questions, including mixed data, answering, records, answer card, and results.

**Architecture:** Extend the existing signed API and legacy snapshot contracts, then keep parsing/loading, pure session transitions, and widgets in separate `practice` files. The application router creates either a module or skill request and both feed the same `PracticePage`.

**Tech Stack:** Flutter 3.32.8, Dart 3.8, Material, Dio through `AppApiClient`, MMKV method channel, `flutter_test`.

---

### Task 1: Preserve module type and practice free count

**Files:**
- Modify: `lib/src/main_tabs/main_tabs_models.dart`
- Modify: `lib/src/main_tabs/main_tabs_repository.dart`
- Modify: `android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt`
- Modify: `test/main_tabs/main_tabs_models_test.dart`
- Modify: `test/main_tabs/main_tabs_repository_test.dart`
- Modify: `test/config/android_shell_config_test.dart`

- [x] **Step 1: Write failing contract tests**

Assert `HomeModule.type` parses `结构化`, and `AppSnapshot.skillQuestionFreeCount` parses strings with default 5. Assert the Kotlin bridge contains:

```kotlin
"skillQuestionFreeCount" to appKv.decodeInt("skill_question_free_count", 5)
```

- [x] **Step 2: Run focused tests and verify RED**

Run: `./tool/flutter_android21.ps1 test test/main_tabs/main_tabs_models_test.dart test/main_tabs/main_tabs_repository_test.dart test/config/android_shell_config_test.dart`

Expected: compile/assertion failures for the missing fields.

- [x] **Step 3: Implement fields without breaking existing fixtures**

Add `this.type = ''` to `HomeModule`, parse `map['type']`, and add `skillQuestionFreeCount` to `AppSnapshot.fromMap` and the native snapshot.

- [x] **Step 4: Rerun focused tests and verify GREEN**

Run the same command. Expected: all pass.

### Task 2: Model mixed practice content

**Files:**
- Create: `lib/src/practice/practice_models.dart`
- Create: `test/practice/practice_models_test.dart`

- [x] **Step 1: Write failing parsing tests**

Cover `大招` skill records, ignored `文件` records, single/multiple/judgment questions, string and decoded options, fallback IDs/titles, normalized answers, server answer snapshots, and paged/list bodies.

```dart
expect(question.kind, PracticeQuestionKind.multiple);
expect(question.options.map((item) => item.key), ['A', 'B', 'C']);
expect(question.normalizedAnswer, 'AC');
expect(question.isCorrect({'C', 'A'}), isTrue);
```

- [x] **Step 2: Run the model test and verify RED**

Run: `./tool/flutter_android21.ps1 test test/practice/practice_models_test.dart`

Expected: compile failure because practice models do not exist.

- [x] **Step 3: Implement immutable models and parsers**

Define `PracticeItem` with `PracticeSkillItem` and `PracticeQuestionItem`, `PracticeQuestion`, `PracticeOption`, `PracticeCatalog`, and `PracticeAccess`. Keep all lists unmodifiable and exclude invalid empty questions.

- [x] **Step 4: Rerun the model test and verify GREEN**

Run the same test file. Expected: all pass.

### Task 3: Load flat, structured, and skill entries

**Files:**
- Create: `lib/src/practice/practice_repository.dart`
- Create: `test/practice/practice_repository_test.dart`
- Modify: `lib/src/skill_mnemonics/skill_mnemonics_entitlement.dart`
- Modify: `test/skill_mnemonics/skill_mnemonics_entitlement_test.dart`

- [x] **Step 1: Write failing repository tests**

Specify these exact requests:

```text
GET /app/goods/pageGoodsData?pageNum=1&pageSize=30&shelfId=<moduleId>
GET /app/shelf/getShelfTree?shelfId=<moduleId>
GET /app/goods/listGoods?shelfIds=<id>&shelfIds=<id>
GET /app/question/queryQuestionsBySkill?skillId=<skillId>
POST /app/question/saveQuestionRecord
```

Test all declared pages are merged, the first structured catalog/chapter is selected, optional benefits failure is non-fatal, home regular access accepts member or `practice_skill`, mnemonic access accepts membership, invalid requests fail before I/O, and save payload fields are exact.

- [x] **Step 2: Run repository/entitlement tests and verify RED**

Run: `./tool/flutter_android21.ps1 test test/practice/practice_repository_test.dart test/skill_mnemonics/skill_mnemonics_entitlement_test.dart`

Expected: missing repository and regular-practice entitlement behavior.

- [x] **Step 3: Implement entry requests and repository**

Use:

```dart
sealed class PracticeRequest { const PracticeRequest(); }
final class ModulePracticeRequest extends PracticeRequest { ... }
final class SkillPracticeRequest extends PracticeRequest { ... }

abstract interface class PracticeDataSource {
  Future<PracticeCatalog> load(PracticeRequest request);
  Future<void> saveAnswer(PracticeQuestion question, PracticeAnswer answer);
}
```

Load snapshot and goods, query benefits only when logged in, loop `pages`, and parse mixed records. Add `hasRegularPracticeAccess` to the entitlement resolver using Android's abstract and level-prefix rules.

- [x] **Step 4: Rerun focused tests and verify GREEN**

Run the same two test files. Expected: all pass.

### Task 4: Implement the pure answer session

**Files:**
- Create: `lib/src/practice/practice_session.dart`
- Create: `test/practice/practice_session_test.dart`

- [x] **Step 1: Write failing transition tests**

Cover immediate single/judgment submission, multiple toggle/confirm, immutable submitted answers, server snapshot restoration, right/wrong totals, mixed-item navigation, answer-card jumps, free boundary, full access, and reset.

```dart
expect(session.select('A'), isA<PracticeSubmitted>());
expect(session.toggleMultiple('C'), isA<PracticeDraftChanged>());
expect(session.confirmMultiple().answer.choose, 'AC');
expect(session.rightCount, 2);
```

- [x] **Step 2: Run the session test and verify RED**

Run: `./tool/flutter_android21.ps1 test test/practice/practice_session_test.dart`

Expected: compile failure because the session does not exist.

- [x] **Step 3: Implement deterministic session transitions**

Return typed transition results (`PracticeDraftChanged`, `PracticeSubmitted`, `PracticeLocked`, `PracticeNoChange`) so widgets never infer state from side effects. Count free usage only for submitted questions and always allow review of answered questions.

- [x] **Step 4: Rerun the session test and verify GREEN**

Run the same test file. Expected: all pass.

### Task 5: Build the practice and result UI

**Files:**
- Create: `lib/src/practice/practice_page.dart`
- Create: `lib/src/practice/practice_result_page.dart`
- Create: `test/practice/practice_page_test.dart`
- Create: `test/practice/practice_result_page_test.dart`

- [x] **Step 1: Write failing widget tests**

Test loading/error/retry/empty, skill card, each question kind, multi confirmation, option state colors, correct answer/analysis, record failure feedback, previous/next, answer card jumps/status cells, locked feedback, last-item result navigation, result totals, and reset.

- [x] **Step 2: Run widget tests and verify RED**

Run: `./tool/flutter_android21.ps1 test test/practice/practice_page_test.dart test/practice/practice_result_page_test.dart`

Expected: compile failures for missing pages.

- [x] **Step 3: Implement stable practice widgets**

Use fixed option-marker dimensions, full-width unframed content, safe-area bottom controls, stable keys (`practice-option-A`, `practice-answer-card`, `practice-next`), and a modal answer card. Submit locally first and invoke `saveAnswer` asynchronously.

- [x] **Step 4: Implement result actions**

`PracticeResultPage` receives the session, displays totals/accuracy, calls `session.reset()` before popping for another attempt, and supports returning without mutating the result.

- [x] **Step 5: Rerun widget tests and verify GREEN**

Run the same two files. Expected: all pass with no pending timers or exceptions.

### Task 6: Wire both navigation entries

**Files:**
- Modify: `lib/src/main_tabs/home_module_route.dart`
- Modify: `lib/src/app/startup_app.dart`
- Modify: `lib/src/skill_mnemonics/skill_mnemonics_detail_page.dart` only if its injected callback contract needs refinement
- Modify: `lib/ultcpa_flutter.dart`
- Modify: `test/main_tabs/home_module_route_test.dart`
- Modify: `test/app/startup_app_test.dart`

- [x] **Step 1: Write failing navigation tests**

Assert `技巧练题`, `推广技巧`, and historical `大招练题` resolve ready. Tap the home module and verify a `ModulePracticeRequest`; tap mnemonic detail CTA and verify a `SkillPracticeRequest` with the exact skill ID.

- [x] **Step 2: Run navigation tests and verify RED**

Run: `./tool/flutter_android21.ps1 test test/main_tabs/home_module_route_test.dart test/app/startup_app_test.dart`

Expected: practice remains pending and mnemonic CTA only shows its migration message.

- [x] **Step 3: Share and route the production repository**

Construct one `PracticeRepository` from the existing shared API/state dependencies. Push `PracticePage` for both request types and keep every unrelated destination unchanged.

- [x] **Step 4: Rerun navigation tests and verify GREEN**

Run the same command. Expected: both entry chains open the real practice page.

### Task 7: Update migration evidence and verify

**Files:**
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`
- Update: `docs/superpowers/plans/2026-07-16-practice-runner.md`

- [x] **Step 1: Write the failing ledger expectations**

Require `LearnActivity` to be `partial` with normal/related modes named in evidence, and `SkillMnemonicsDetailActivity` to become `complete` with the practice CTA evidence.

- [x] **Step 2: Update evidence and regenerate the ledger**

Run: `dart run tool/migration/source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs/migration/activity_coverage.csv`

- [x] **Step 3: Format changed Dart files**

Run `dart format` on the modified `lib`, `test`, and `tool` files from this plan.

- [x] **Step 4: Run the full suite**

Run: `./tool/flutter_android21.ps1 test`

Expected: zero failures.

- [x] **Step 5: Run static analysis**

Run: `./tool/flutter_android21.ps1 analyze`

Expected: `No issues found!`

- [x] **Step 6: Build and hash the dev APK**

Run: `./tool/flutter_android21.ps1 build apk --debug --flavor dev`

Expected: `build/app/outputs/flutter-apk/app-dev-debug.apk` exists. Record SHA-256, inspect `git diff --check`, and do not stage or commit the dirty migration.
