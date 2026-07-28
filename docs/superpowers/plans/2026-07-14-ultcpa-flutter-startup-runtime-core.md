# ultCPA Flutter Startup Runtime Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the privacy-first startup state machine that gates every SDK/network initializer and preserves the Android three-second post-initialization launch delay.

**Architecture:** Keep startup policy in a pure Dart coordinator with injected consent storage, post-consent initialization, and delay ports. The UI and Android legacy-storage bridge will consume this coordinator in the next startup-runtime slice; tests use deterministic adapters only.

**Tech Stack:** Dart 3.8, Flutter 3.32.8, flutter_test.

---

### Task 1: Privacy-first startup coordinator

**Files:**
- Create: `lib/src/startup/startup_coordinator.dart`
- Create: `test/startup/startup_coordinator_test.dart`
- Modify: `lib/ultcpa_flutter.dart`

- [x] **Step 1: Write the failing coordinator tests**

Cover four Android-derived contracts: an unaccepted user reaches `awaitingConsent` without initialization; acceptance is persisted before initialization and a three-second delay; existing consent starts directly; decline terminates without initialization.

- [x] **Step 2: Run the focused test and verify RED**

Run:

```powershell
& .\tool\flutter_android21.ps1 test --no-pub test\startup\startup_coordinator_test.dart --reporter compact
```

Expected: compilation fails because `startup_coordinator.dart` does not exist.

- [x] **Step 3: Implement the minimal pure-Dart coordinator**

Define `StartupPhase`, `StartupConsentStore`, `StartupPostConsentInitializer`, `StartupDelay`, and `StartupCoordinator`. `start()` reads consent only; `acceptPrivacy()` persists consent before invoking initialization; initialization must finish before the injected delay receives exactly `Duration(seconds: 3)`; `declinePrivacy()` reaches `terminated` without invoking either adapter.

- [x] **Step 4: Export and verify GREEN**

Export the coordinator from `lib/ultcpa_flutter.dart`, rerun the focused test, then run:

```powershell
& .\tool\flutter_android21.ps1 analyze --no-pub
& .\tool\flutter_android21.ps1 test --no-pub --reporter compact
```

Expected: no analyzer issues and all tests pass.

- [x] **Step 5: Do not perform Git operations**

Report the diff and verification output. Do not stage, commit, push, or modify `E:\workspace\ultCPA-android`.
