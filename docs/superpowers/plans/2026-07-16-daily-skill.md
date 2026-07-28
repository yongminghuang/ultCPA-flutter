# Daily Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This migration batch is intentionally uncommitted, so do not stage or commit while executing it.

**Goal:** Migrate Android's complete `每日一招` detail, local-progress practice, report, analysis, and improvement flow.

**Architecture:** A dedicated daily repository loads the skill and its related questions; a high-level progress store serializes Android-compatible JSON through the existing MethodChannel. Daily detail and report pages reuse `PracticePage`, which gains one request-aware daily session branch and an injected report launcher.

**Tech Stack:** Flutter/Dart, `flutter_test`, Dio-backed `AppApiClient`, Android Kotlin MethodChannel, MMKV JSON, existing practice and mnemonic surfaces.

---

### Task 1: Daily models and repository

**Files:**
- Create: `lib/src/daily_skill/daily_skill_models.dart`
- Create: `lib/src/daily_skill/daily_skill_repository.dart`
- Create: `test/daily_skill/daily_skill_models_test.dart`
- Create: `test/daily_skill/daily_skill_repository_test.dart`

- [ ] **Step 1: Write failing model tests**

Cover direct and page-first skill bodies, invalid payloads, shelf fallback, and
Android A-F pick conversion:

```dart
expect(dailySkillAnswerPick('ACF'), 37);
expect(dailySkillChooseFromPick(37), 'ACF');
expect(parseDailySkillBody({'records': [skillMap]}).skillId, '11');
```

- [ ] **Step 2: Run model tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\daily_skill\daily_skill_models_test.dart
```

Expected: compile failure because daily models do not exist.

- [ ] **Step 3: Implement immutable daily models and parsers**

Define `DailySkillDetail`, `DailySkillAnswer`, and helpers that reuse
`SkillMnemonic.fromMap`, accept either a direct map or the first page record,
and preserve positive integer IDs.

- [ ] **Step 4: Run model tests and verify GREEN**

Run the Step 2 command. Expected: all daily model tests pass.

- [ ] **Step 5: Write failing repository tests**

Prove the exact detail contract and image resolution:

```dart
expect(api.getRequests.single.path, '/knowledge/skill/dailySkill');
expect(api.getRequests.single.query, {'moduleId': 42});
expect(detail.effectiveShelfId, 42);
expect(detail.imageUrl, 'https://file.xmzhujing.com/daily/a.gif');
```

Also cover persisted `ossDomain`, absolute images, invalid modules without I/O,
empty skill bodies, and the exact related-question request.

- [ ] **Step 6: Run repository tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\daily_skill\daily_skill_repository_test.dart
```

Expected: compile failure because `DailySkillRepository` is absent.

- [ ] **Step 7: Implement `DailySkillRepository`**

Expose:

```dart
abstract interface class DailySkillDataSource {
  Future<DailySkillDetail> loadDetail(HomeModule module);
  Future<List<PracticeQuestion>> loadQuestions(String skillId);
}
```

Use the exact endpoints, read `ossDomain` only for detail image resolution, and
return questions in server order.

- [ ] **Step 8: Run repository tests and verify GREEN**

Run the Step 6 command. Expected: all repository tests pass.

### Task 2: Android-compatible daily progress

**Files:**
- Create: `lib/src/daily_skill/daily_skill_progress_store.dart`
- Create: `test/daily_skill/daily_skill_progress_store_test.dart`
- Modify: `lib/src/network/method_channel_request_context.dart`
- Modify: `android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt`
- Modify: `test/config/android_shell_config_test.dart`

- [ ] **Step 1: Write failing progress-domain tests**

Use an in-memory raw persistence and injected dates. Cover new-day reset,
same-day identifier refresh, Android JSON parsing, corrupt JSON clearing,
question-order persistence, answer replacement, counts, first-unanswered resume,
finished-final resume, retry clear, and idempotent completed dates.

```dart
await store.recordAnswer(
  questionId: 101,
  choose: 'AC',
  isRight: false,
  currentIndex: 1,
  questionOrder: const [101, 102],
);
expect((await store.loadToday())!.answers[101]!.pick, 5);
```

- [ ] **Step 2: Run domain tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\daily_skill\daily_skill_progress_store_test.dart
```

Expected: compile failure because the progress types are missing.

- [ ] **Step 3: Implement the progress domain**

Define `DailySkillProgressPersistence`, `DailySkillProgressStore`, immutable
progress/check-in models, exact Android JSON serializers, and a disabled store.
Use local `yyyy-MM-dd` and millisecond timestamps from injected `now`.

- [ ] **Step 4: Run domain tests and verify GREEN**

Run Step 2. Expected: progress-domain tests pass.

- [ ] **Step 5: Write failing MethodChannel and Kotlin source tests**

Lock these methods and raw arguments:

```text
readDailySkillProgressJson
writeDailySkillProgressJson {json}
readDailySkillCheckInJson
writeDailySkillCheckInJson {json}
```

Lock exact native keys:

```text
daily_skill_progress_<legacyUserId>_<currentCategory>
daily_skill_checkin_<legacyUserId>_<currentCategory>
```

- [ ] **Step 6: Run bridge tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\daily_skill\daily_skill_progress_store_test.dart test\config\android_shell_config_test.dart
```

Expected: bridge behavior/source assertions fail.

- [ ] **Step 7: Implement Dart and Kotlin raw JSON bridges**

Make `MethodChannelRequestContext` implement `DailySkillProgressPersistence`.
Kotlin reads/writes `App` MMKV, uses `legacyUserId().ifBlank { "0" }`, and does
not parse or reshape JSON.

- [ ] **Step 8: Run bridge tests and verify GREEN**

Run Step 6. Expected: all selected tests pass.

### Task 3: Daily detail page

**Files:**
- Create: `lib/src/daily_skill/daily_skill_detail_page.dart`
- Create: `test/daily_skill/daily_skill_detail_page_test.dart`

- [ ] **Step 1: Write failing widget tests**

Cover loading, retry, empty invalid module, stale disposal, keyword highlighting,
optional image/analysis visibility, effective question count, unfinished CTA,
finished message, retry clearing, practice replacement launcher, and mnemonic
improvement launcher. Use stable keys:

```text
daily-skill-loading
daily-skill-error
daily-skill-retry-load
daily-skill-empty
daily-skill-practice
daily-skill-finished
daily-skill-retry-practice
daily-skill-improve
```

- [ ] **Step 2: Run page tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\daily_skill\daily_skill_detail_page_test.dart
```

Expected: compile failure because the page and launch contracts are missing.

- [ ] **Step 3: Implement the detail page**

Use a white `Scaffold`, compact app bar, scrollable content, 4 px section radii,
optional `Image.network`, fixed blue CTA, and the exact completed-state strings.
Ignore async completions after disposal.

- [ ] **Step 4: Run page tests and verify GREEN**

Run Step 2. Expected: all detail widget tests pass.

### Task 4: Daily request and read-only analysis catalog

**Files:**
- Modify: `lib/src/practice/practice_models.dart`
- Modify: `lib/src/practice/practice_repository.dart`
- Modify: `test/practice/practice_models_test.dart`
- Modify: `test/practice/practice_repository_test.dart`

- [ ] **Step 1: Write failing request and behavior tests**

Add `DailySkillPracticeRequest` validation and `PracticeBehavior.dailyReview`:

```dart
const request = DailySkillPracticeRequest(
  module: module,
  skillId: '11',
  shelfId: 111,
);
expect(catalog.access.fullAccess, isTrue);
expect(catalog.behavior.persistAnswers, isTrue);
```

The daily branch must issue only the exact skill-question GET and no benefits or
record request. Daily review must restore provided answers, disable persistence
and results, and use `当前已是最后一题`.

- [ ] **Step 2: Run practice model/repository tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\practice\practice_models_test.dart test\practice\practice_repository_test.dart
```

Expected: compile/behavior failure for the new request and behavior.

- [ ] **Step 3: Implement request-aware loading**

Add the sealed request subtype, positive module/shelf and non-empty skill ID
validation, direct `/app/question/queryQuestionsBySkill` loading, full access,
and a public helper that creates a read-only daily analysis catalog with local
answer overlays and optional wrong-ID filtering.

- [ ] **Step 4: Run selected tests and verify GREEN**

Run Step 2. Expected: all selected practice tests pass.

### Task 5: Daily practice session integration

**Files:**
- Modify: `lib/src/practice/practice_session.dart`
- Modify: `lib/src/practice/practice_page.dart`
- Modify: `test/practice/practice_session_test.dart`
- Modify: `test/practice/practice_page_test.dart`

- [ ] **Step 1: Write failing session/page tests**

Cover restoring local answers without marking them newly submitted, first
unanswered resume, all-answered final resume, local and remote save on new
submission, local-write failure message, daily back opening report, final next
marking complete only when all questions are answered, duplicate launch guard,
and ordinary/chapter/fast requests not touching the daily store.

- [ ] **Step 2: Run page/session tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\practice\practice_session_test.dart test\practice\practice_page_test.dart
```

Expected: missing restore API and daily dependencies/behavior.

- [ ] **Step 3: Implement daily session behavior**

Add `PracticeSession.restoreAnswer`. Inject a daily progress store and report
launcher into `PracticePage`. Restore after question load, save daily progress
from `PracticeSubmitted`, and wrap daily pages in `PopScope` so both back and
last-next use one guarded report transition.

- [ ] **Step 4: Run all practice tests and verify GREEN**

```powershell
.\tool\flutter_android21.ps1 test test\practice
```

Expected: all practice tests pass.

### Task 6: Daily report and analysis

**Files:**
- Create: `lib/src/daily_skill/daily_skill_report_page.dart`
- Create: `test/daily_skill/daily_skill_report_page_test.dart`

- [ ] **Step 1: Write failing report widget tests**

Cover stale/missing progress return, percentage flooring, hidden/visible check-in
days, right/wrong/undone counts, six-column ordered cells, cell colors/keys,
wrong-empty message, exact wrong/all reload and filtering, transport/empty
errors, read-only `PracticePage` launch, and improve navigation.

Stable keys:

```text
daily-skill-report-loading
daily-skill-report-accuracy
daily-skill-report-cell-<index>
daily-skill-report-wrong
daily-skill-report-all
daily-skill-report-improve
```

- [ ] **Step 2: Run report tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\daily_skill\daily_skill_report_page_test.dart
```

Expected: compile failure because the report page is missing.

- [ ] **Step 3: Implement report UI and actions**

Build an unframed scroll report with a stable 142 px accuracy circle, compact
three-action row, counts, and a six-column `GridView`. Load questions only when
analysis is tapped; inject launchers for tests and default to the shared
read-only practice page.

- [ ] **Step 4: Run report tests and verify GREEN**

Run Step 2. Expected: all report tests pass.

### Task 7: Home, Startup, exports, and ledger

**Files:**
- Modify: `lib/src/main_tabs/home_module_route.dart`
- Modify: `test/main_tabs/home_module_route_test.dart`
- Modify: `lib/src/app/startup_app.dart`
- Modify: `test/app/startup_app_test.dart`
- Modify: `lib/ultcpa_flutter.dart`
- Create: `test/daily_skill/daily_skill_exports_test.dart`
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`

- [ ] **Step 1: Write failing integration tests**

Resolve exact `每日一招` to `HomeDestination.dailySkill`. Startup must open the
detail with the clicked module, then drive detail -> practice -> report using the
same repository/progress/practice instances. Verify improvement resolves and
opens the real mnemonic module. Lock public exports and ledger evidence.

- [ ] **Step 2: Run integration tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\main_tabs\home_module_route_test.dart test\app\startup_app_test.dart test\daily_skill\daily_skill_exports_test.dart test\migration\activity_coverage_test.dart
```

Expected: missing route, Startup wiring, exports, and reviewed progress.

- [ ] **Step 3: Implement integration**

Create one `DailySkillRepository` and `DailySkillProgressStore` in Startup. The
mnemonic launcher reloads current Home data, selects the first module resolving
to `skillMnemonics`, and opens `SkillMnemonicsPage`; failures show the Android
loading message. Export all daily files and update reviewed Activity evidence.

- [ ] **Step 4: Regenerate the ledger CSV**

```powershell
dart run tool/migration/source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs\migration\activity_coverage.csv
```

Expected: `total=77 flutterPage=69 pluginCallback=3 sdkManaged=3 removed=2`.

- [ ] **Step 5: Run integration tests and verify GREEN**

Run Step 2. Expected: all integration tests pass.

### Task 8: Full verification and APK

**Files:**
- Verify every file changed above.

- [ ] **Step 1: Format daily and touched shared sources**

```powershell
dart format lib\src\daily_skill test\daily_skill lib\src\practice lib\src\app\startup_app.dart lib\src\main_tabs\home_module_route.dart lib\src\network\method_channel_request_context.dart test\practice test\app\startup_app_test.dart test\main_tabs\home_module_route_test.dart test\config\android_shell_config_test.dart test\migration\activity_coverage_test.dart
```

- [ ] **Step 2: Run focused verification**

```powershell
.\tool\flutter_android21.ps1 test test\daily_skill test\practice test\main_tabs\home_module_route_test.dart test\app\startup_app_test.dart test\config\android_shell_config_test.dart test\migration\activity_coverage_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 3: Run full verification**

```powershell
.\tool\flutter_android21.ps1 test
.\tool\flutter_android21.ps1 analyze
git diff --check
```

Expected: full suite passes, analyzer reports `No issues found!`, and diff check
exits `0`.

- [ ] **Step 4: Build and hash the dev debug APK**

```powershell
.\tool\flutter_android21.ps1 build apk --debug --flavor dev
(Get-FileHash build\app\outputs\flutter-apk\app-dev-debug.apk -Algorithm SHA256).Hash
```

Expected: build exits `0`; report the full SHA-256 without staging or committing.
