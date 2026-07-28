# Pre-Exam Six-Paper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This migration batch remains intentionally uncommitted; do not stage or commit.

**Goal:** Migrate Android's complete usable `考前6页纸` landing, preview, download, and share flow while keeping the shared payment boundary explicit.

**Architecture:** A dedicated feature package parses the first file and resolves entry entitlement. Entry, landing, and preview pages remain separate; preview delegates file I/O to a Dio/native bridge abstraction so all behavior is testable without a platform WebView or Android filesystem.

**Tech Stack:** Flutter/Dart, `flutter_test`, Dio, `webview_flutter`, Android Kotlin MethodChannel, FileProvider, existing Home and entitlement infrastructure.

---

### Task 1: File and entry models

**Files:**
- Create: `lib/src/pre_exam_six_paper/pre_exam_six_paper_models.dart`
- Create: `test/pre_exam_six_paper/pre_exam_six_paper_models_test.dart`

- [ ] **Step 1: Write failing parser/helper tests**

Cover first-record-only `文件` parsing, top-level and `extend.text` fallback,
malformed/empty bodies, immutable entry destinations, title limiting, OSS URL
resolution, HTML wrapping/image normalization, filename sanitizing/suffix rules,
and MIME selection.

```dart
expect(parsePreExamSixPaperFileBody(body)?.text, '<p>重点</p>');
expect(limitPreExamSixPaperTitle('12345678901'), '1234567890..');
expect(
  preExamSixPaperDownloadFileName(file, now: () => DateTime(2026)),
  '考前_重点.pdf',
);
```

- [ ] **Step 2: Run tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\pre_exam_six_paper\pre_exam_six_paper_models_test.dart
```

Expected: compile failure because the feature models do not exist.

- [ ] **Step 3: Implement immutable models and pure helpers**

Define:

```dart
enum PreExamSixPaperEntryDestination { landing, preview, unavailable, empty }

final class PreExamSixPaperEntry {
  const PreExamSixPaperEntry(this.destination, {this.file});
  final PreExamSixPaperEntryDestination destination;
  final PreExamSixPaperFile? file;
}

final class PreExamSixPaperFile {
  const PreExamSixPaperFile({
    required this.name,
    required this.text,
    required this.textUrl,
    required this.fileUrl,
    required this.htmlBaseUrl,
  });
}
```

Accept page maps only, require the first record's type to be `文件`, decode
`extend` only when needed, and keep all helpers deterministic with injected time.

- [ ] **Step 4: Run model tests and verify GREEN**

Run Step 2. Expected: all model tests pass.

### Task 2: Repository and entitlement split

**Files:**
- Create: `lib/src/pre_exam_six_paper/pre_exam_six_paper_repository.dart`
- Create: `test/pre_exam_six_paper/pre_exam_six_paper_repository_test.dart`

- [ ] **Step 1: Write failing repository tests**

Lock these contracts:

```text
GET /app/user/getUserBenefits
GET /app/goods/pageGoodsData?pageNum=1&pageSize=1&shelfId=<moduleId>
```

Cover invalid module without I/O, logged-out/non-VIP landing, non-social VIP
preview without probe, social-work VIP preview with prefetched file, probe
failure/empty as unavailable, exact OSS fallback, and on-demand file loading.

- [ ] **Step 2: Run tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\pre_exam_six_paper\pre_exam_six_paper_repository_test.dart
```

Expected: missing repository types.

- [ ] **Step 3: Implement the data source**

Expose:

```dart
abstract interface class PreExamSixPaperDataSource {
  Future<PreExamSixPaperEntry> resolveEntry(HomeModule module);
  Future<PreExamSixPaperFile> loadFile(HomeModule module);
}
```

Reuse `SkillMnemonicsEntitlementResolver.isVip`, propagate required state/benefit
failures for entry retry, convert only social-work probe failures to unavailable,
and throw `FormatException('考前6页纸数据为空')` from `loadFile` for invalid data.

- [ ] **Step 4: Run repository tests and verify GREEN**

Run Step 2. Expected: all repository tests pass.

### Task 3: Native cache/share bridge and Dio transfer

**Files:**
- Create: `lib/src/pre_exam_six_paper/pre_exam_six_paper_file_transfer.dart`
- Create: `test/pre_exam_six_paper/pre_exam_six_paper_file_transfer_test.dart`
- Modify: `android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/src/main/res/xml/pre_exam_six_paper_file_paths.xml`
- Modify: `test/config/android_shell_config_test.dart`

- [ ] **Step 1: Write failing Dart bridge/transfer tests**

Lock exact channel calls:

```text
createPreExamSixPaperDownloadPath {fileName}
sharePreExamSixPaperFile {path, mimeType}
```

Use a Dio test adapter and temporary directory to prove byte persistence,
progress callbacks, cancellation, and share delegation.

- [ ] **Step 2: Run Dart tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\pre_exam_six_paper\pre_exam_six_paper_file_transfer_test.dart
```

Expected: missing transfer and native bridge types.

- [ ] **Step 3: Implement Dart transfer abstractions**

Define `PreExamSixPaperFileTransfer`,
`MethodChannelPreExamSixPaperNativeBridge`, and
`DioPreExamSixPaperFileTransfer`. Use a fresh `CancelToken` per download and
make `cancel()` idempotent.

- [ ] **Step 4: Run Dart tests and verify GREEN**

Run Step 2.

- [ ] **Step 5: Write failing Kotlin/manifest source assertions**

Require cache containment checks, external/internal cache fallback,
`${applicationId}.fileprovider`, `FLAG_GRANT_READ_URI_PERMISSION`, `ACTION_SEND`,
and both cache path declarations.

- [ ] **Step 6: Run source tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\config\android_shell_config_test.dart
```

- [ ] **Step 7: Implement the Android bridge and FileProvider**

Create only leaf filenames under `pre_exam_six_paper`; canonicalize both the
root and result before returning/sharing. Reject nonexistent/out-of-cache files,
then launch an Android chooser with the requested MIME type.

- [ ] **Step 8: Run source tests and verify GREEN**

Run Step 6.

### Task 4: Android asset-backed landing page

**Files:**
- Create: `assets/images/pre_exam_six_paper/*.png`
- Create: `lib/src/pre_exam_six_paper/pre_exam_six_paper_landing_page.dart`
- Create: `test/pre_exam_six_paper/pre_exam_six_paper_landing_page_test.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Copy authoritative bitmap assets**

Copy the referenced hero, `80+`, feature, and decorative PNGs from Android's
`drawable-xxxhdpi` directory without modifying the Android reference project.

- [ ] **Step 2: Write failing asset/widget tests**

Require every registered file to exist and cover the hero, comparison labels,
three benefit rows, fixed unlock CTA, back action, injected unlock callback, and
default `考前6页纸需解锁，会员与支付功能仍在迁移中` message.

- [ ] **Step 3: Run tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\pre_exam_six_paper\pre_exam_six_paper_landing_page_test.dart
```

- [ ] **Step 4: Implement the landing page and asset registration**

Use stable responsive dimensions, Android colors/text, 4 px CTA radius, real
bitmap assets, and no nested/floating cards.

- [ ] **Step 5: Run tests and verify GREEN**

Run Step 3.

### Task 5: Preview, download, and share page

**Files:**
- Create: `lib/src/pre_exam_six_paper/pre_exam_six_paper_preview_page.dart`
- Create: `test/pre_exam_six_paper/pre_exam_six_paper_preview_page_test.dart`

- [ ] **Step 1: Write failing preview tests**

Cover prefetched/no-request loading, on-demand loading, loading/error/empty and
disposed states, title limiting, `textUrl` precedence, inline HTML/base URL,
missing file URL, progress dialog, completed path dialog, repeat-download reuse,
deleted-file redownload, share MIME/path, and download/share failures.

Stable keys:

```text
pre-exam-six-preview-loading
pre-exam-six-preview-content
pre-exam-six-preview-empty
pre-exam-six-preview-download
pre-exam-six-download-progress
pre-exam-six-download-complete
pre-exam-six-download-share
```

- [ ] **Step 2: Run tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\pre_exam_six_paper\pre_exam_six_paper_preview_page_test.dart
```

- [ ] **Step 3: Implement preview and transfer state**

Use an injected `PreExamSixPaperContentBuilder` for tests and a default
`WebViewController` for URL/HTML rendering. Ignore stale completions, cancel on
dispose, guard duplicate download/share actions, and preserve a successful file
for retrying share.

- [ ] **Step 4: Run tests and verify GREEN**

Run Step 2.

### Task 6: Entry page and Home/Startup integration

**Files:**
- Create: `lib/src/pre_exam_six_paper/pre_exam_six_paper_entry_page.dart`
- Create: `test/pre_exam_six_paper/pre_exam_six_paper_entry_page_test.dart`
- Modify: `lib/src/main_tabs/home_module_route.dart`
- Modify: `test/main_tabs/home_module_route_test.dart`
- Modify: `lib/src/app/startup_app.dart`
- Modify: `test/app/startup_app_test.dart`

- [ ] **Step 1: Write failing entry and integration tests**

Cover loading/retry, empty, unavailable pop/message, landing, prefetched preview,
exact/contains Home routes, and Startup dependency sharing with the clicked
module. Prove non-six-paper routes never touch the new repository.

- [ ] **Step 2: Run tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\pre_exam_six_paper\pre_exam_six_paper_entry_page_test.dart test\main_tabs\home_module_route_test.dart test\app\startup_app_test.dart
```

- [ ] **Step 3: Implement entry and Startup wiring**

Add `HomeDestination.preExamSixPaper`, construct one repository/native
bridge/transfer in Startup, and push `PreExamSixPaperEntryPage`. Keep payment
launcher injectable and leave the default boundary honest.

- [ ] **Step 4: Run tests and verify GREEN**

Run Step 2.

### Task 7: Public exports and migration ledger

**Files:**
- Modify: `lib/ultcpa_flutter.dart`
- Create: `test/pre_exam_six_paper/pre_exam_six_paper_exports_test.dart`
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`

- [ ] **Step 1: Write failing export/ledger tests**

Require every public model/repository/transfer/page type. Mark preview complete,
landing partial with payment evidence, and add the ready destination to
`MainActivity` without overstating shared payment completion.

- [ ] **Step 2: Run tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\pre_exam_six_paper\pre_exam_six_paper_exports_test.dart test\migration\activity_coverage_test.dart
```

- [ ] **Step 3: Implement exports and reviewed progress**

Update public exports and exact evidence strings.

- [ ] **Step 4: Regenerate CSV**

```powershell
dart run tool\migration\source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs\migration\activity_coverage.csv
```

Expected: `total=77 flutterPage=69 pluginCallback=3 sdkManaged=3 removed=2`.

- [ ] **Step 5: Run tests and verify GREEN**

Run Step 2.

### Task 8: Full verification and APK

**Files:**
- Verify every file above.

- [ ] **Step 1: Format touched files**

```powershell
dart format lib\src\pre_exam_six_paper test\pre_exam_six_paper lib\src\app\startup_app.dart lib\src\main_tabs\home_module_route.dart lib\src\migration\activity_coverage.dart test\app\startup_app_test.dart test\main_tabs\home_module_route_test.dart test\migration\activity_coverage_test.dart
```

- [ ] **Step 2: Run focused verification**

```powershell
.\tool\flutter_android21.ps1 test test\pre_exam_six_paper test\main_tabs\home_module_route_test.dart test\app\startup_app_test.dart test\config\android_shell_config_test.dart test\migration\activity_coverage_test.dart
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

Report the exact test count, analyzer result, CSV counts, APK path/size/hash, and
preserve the intentionally uncommitted worktree.
