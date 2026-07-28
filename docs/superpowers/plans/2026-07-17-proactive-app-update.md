# Proactive App Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking. This migration batch remains
> intentionally uncommitted; do not stage or commit.

**Goal:** Reproduce Android's privacy-gated, throttled cold-start and
foreground app-version checks, including the long-resume secondary splash.

**Architecture:** Extend the existing update repository with a nullable
proactive path and shared native timestamp persistence. Observe Flutter app
lifecycle at the root, then reuse the existing update dialog only for an
available result.

**Tech Stack:** Flutter 3.32/Dart 3.8, Material, Dio 5.9, Flutter
MethodChannel, Kotlin/MMKV, flutter_test.

---

### Task 1: Shared timestamp and proactive repository policy

**Files:**
- Modify: `lib/src/app_update/app_update_repository.dart`
- Modify: `test/app_update/app_update_repository_test.dart`

- [x] **Step 1: Write failing repository tests**

Require manual checks to persist the injected current millisecond before a
request, and require proactive checks to return `null` inside the 30-minute
window. Pin non-positive timestamps, the inclusive 30-minute boundary, future
timestamps, persistence-before-network ordering, unchanged query key order,
and `isActive=false`.

- [x] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\app_update\app_update_repository_test.dart
```

Expected: compile failures for `checkProactive`, the clock, and timestamp
persistence constructor contract.

- [x] **Step 3: Implement the minimal repository policy**

Add `Future<AppUpdateCheckResult?> checkProactive()` to the interface. Inject
`int Function() nowMillis` and `Future<void> Function(int millis)
persistCheckTimestamp`, use `30 * 60 * 1000` milliseconds, and share one
ordered request helper between the manual and proactive paths.

- [x] **Step 4: Run Step 2 and verify GREEN**

### Task 2: MethodChannel and exact MMKV persistence

**Files:**
- Modify: `lib/src/network/method_channel_request_context.dart`
- Modify: `android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt`
- Modify: `test/network/method_channel_request_context_test.dart`
- Modify: `test/config/android_shell_config_test.dart`

- [x] **Step 1: Write failing platform contract tests**

Require `persistAppUpdateCheckTimestamp` with a `millis` argument, snapshot
round-tripping of `lastProactiveVersionCheckAt`, Kotlin numeric validation,
`decodeLong`/`encode`, and the literal key
`key_mmkv_last_proactive_version_check_at`.

- [x] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\network\method_channel_request_context_test.dart test\config\android_shell_config_test.dart
```

- [x] **Step 3: Implement the minimal bridge methods**

Add one Dart forwarding method, one Kotlin MethodChannel branch, one snapshot
field, and one private constant. Keep all Android changes inside the Flutter
project's shell.

- [x] **Step 4: Run Step 2 and verify GREEN**

### Task 3: Cold-ready proactive presentation

**Files:**
- Modify: `lib/src/app/startup_app.dart`
- Modify: `test/app/startup_app_test.dart`

- [x] **Step 1: Write failing cold-start widget tests**

Require no check while privacy is awaiting consent, one check after the first
ready frame, silent `null`/latest/error outcomes, an available result opening
the real `AppUpdateDialog`, and one in-flight guard.

- [x] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\app\startup_app_test.dart --plain-name "proactive"
```

Expected: compile failures until the fake and production data sources expose
`checkProactive`, followed by behavioral failures because ready does not yet
schedule a check.

- [x] **Step 3: Implement ready-frame checks and silent handling**

Schedule from the `StartupPhase.ready` transition, get a safe root overlay
context, show only available results, catch failures, and keep one proactive
flow active through dialog dismissal. Wire production timestamp persistence to
`MethodChannelRequestContext`.

- [x] **Step 4: Run Step 2 and verify GREEN**

### Task 4: Foreground timing and secondary splash

**Files:**
- Modify: `lib/src/app/startup_app.dart`
- Modify: `test/app/startup_app_test.dart`

- [x] **Step 1: Write failing lifecycle widget tests**

Use an injected millisecond clock and secondary delay. Require a short resume
to check immediately, exactly 15 seconds to remain immediate, more than 15
seconds to display `StartupSplashPage`, an exact 3-second delay argument before
checking, a splash even when the repository later skips, ignored resumes before
ready, and duplicate lifecycle events to remain single-flight.

- [x] **Step 2: Run and verify RED**

Run the Task 3 command. Expected: missing lifecycle injections and no observer
or secondary overlay behavior.

- [x] **Step 3: Implement lifecycle observation and overlay**

Register and remove `WidgetsBindingObserver`, record `paused`, consume it on
`resumed`, apply the strict greater-than-15-second boundary, and install the
splash through `MaterialApp.builder` so pushed content is covered.

- [x] **Step 4: Run Step 2 and verify GREEN**

### Task 5: Migration evidence and focused regression

**Files:**
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`

- [x] **Step 1: Write the failing evidence assertion**

Replace the pending phrase with evidence for privacy-gated cold-ready checks,
30-minute throttling, foreground checks, and the 15-second/3-second secondary
splash while retaining MainActivity's partial status and payment backlog.

- [x] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\migration\activity_coverage_test.dart
```

- [x] **Step 3: Update evidence and regenerate CSV**

```powershell
dart run tool\migration\source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs\migration\activity_coverage.csv
```

- [x] **Step 4: Run focused regression and verify GREEN**

```powershell
.\tool\flutter_android21.ps1 test test\app_update test\network\method_channel_request_context_test.dart test\app\startup_app_test.dart test\config\android_shell_config_test.dart test\migration\activity_coverage_test.dart
```

### Task 6: Full verification and dev APK

**Files:**
- Verify all files changed above

- [x] **Step 1: Format and prove formatting is stable**

Run `dart format` on changed Dart files, then repeat with
`--output=none --set-exit-if-changed`.

- [x] **Step 2: Run complete verification**

```powershell
.\tool\flutter_android21.ps1 test
.\tool\flutter_android21.ps1 analyze
git diff --check
```

- [x] **Step 3: Build and inspect a fresh dev APK**

```powershell
.\tool\flutter_android21.ps1 build apk --debug --flavor dev
```

Record exact APK bytes and SHA-256, verify migration counts and critical rows,
and confirm the staged index remains empty. Do not stage or commit.
