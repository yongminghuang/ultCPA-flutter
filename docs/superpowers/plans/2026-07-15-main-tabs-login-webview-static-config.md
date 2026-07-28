# Main Tabs, Login Continuation, WebView, and Static Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the post-startup splash with the real three-tab shell, consume Android-compatible startup configuration, continue phone login back to the originating tab, and open agreements in an in-app WebView.

**Architecture:** Keep native MMKV compatibility behind the existing request-context channel, put signed HTTP behavior in one Dio API client, and expose tab-specific immutable models through a repository interface. The shell owns tab selection and login continuation; individual tabs own loading/error/refresh state. Android remains read-only and no unavailable downstream product route receives a placeholder page.

**Tech Stack:** Flutter 3.32.8, Dart 3.8, Dio 5.9, webview_flutter 4.13.1, MMKV Android bridge, flutter_test.

---

### Task 1: Persist startup configuration and expose the legacy app snapshot

**Files:**
- Modify: `lib/src/network/method_channel_request_context.dart`
- Modify: `lib/src/startup/startup_remote_initializer.dart`
- Modify: `android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt`
- Modify: `test/network/method_channel_request_context_test.dart`
- Modify: `test/startup/startup_remote_initializer_test.dart`
- Modify: `test/config/android_shell_config_test.dart`

- [x] **Step 1: Write failing tests**

Assert that the startup initializer converts `body: [{"key": ..., "value": ...}]` into a string map and invokes `persistStaticConfiguration`. Assert that the request context can read `readAppSnapshot` without converting 16+ digit user IDs to numbers, and can persist category selection.

- [x] **Step 2: Run focused tests and verify RED**

```powershell
& .\tool\flutter_android21.ps1 test --no-pub test\startup\startup_remote_initializer_test.dart test\network\method_channel_request_context_test.dart --reporter compact
```

Expected: missing `persistStaticConfiguration`, `readAppSnapshot`, and `persistCategorySelection` methods.

- [x] **Step 3: Implement native-compatible persistence**

Add request-context methods with these payloads:

```dart
Future<void> persistStaticConfiguration(Map<String, String> values);
Future<Map<String, dynamic>> readAppSnapshot();
Future<void> persistCategorySelection({
  required String categoryBodyJson,
  required String category,
  required Map<String, dynamic> selectedCategory,
  required String selectedCategoryKey,
  required int marketId,
  required String subject,
});
```

The Kotlin bridge writes existing `App`/`mmkvLazy` keys, parses `home_top_banner` into `home_top_banner_{appType}_{level}`, stores raw exam/banner JSON for Flutter, and returns profile/config/category values as strings where precision matters.

- [x] **Step 4: Verify GREEN**

Run the focused command from Step 2 and expect all tests to pass.

### Task 2: Add the signed real API client and tab repository

**Files:**
- Create: `lib/src/network/app_api_client.dart`
- Create: `lib/src/main_tabs/main_tabs_models.dart`
- Create: `lib/src/main_tabs/main_tabs_repository.dart`
- Create: `test/network/app_api_client_test.dart`
- Create: `test/main_tabs/main_tabs_repository_test.dart`

- [x] **Step 1: Write failing client and repository tests**

Cover exact Android endpoints and request shapes:

```text
GET  /knowledge/market/appCategory?marketType=模块管理
GET  /knowledge/shelf/moduleLis?marketId={id}
POST /app/tempMedia/query {subject, courseType, level, showOnHome:"0"}
GET  /app/question/pageErrorQuestion?pageNum=1&pageSize=1&subject=&level=
GET  /app/question/pageCollectQuestion?pageNum=1&pageSize=1&subject=&level=
```

Tests must cover response code `200`/`2001`, selected category/subject restoration, banner URL resolution using `oss_domain`, exam countdown parsing, invite-menu gating, and server error propagation.

- [x] **Step 2: Run tests and verify RED**

```powershell
& .\tool\flutter_android21.ps1 test --no-pub test\network\app_api_client_test.dart test\main_tabs\main_tabs_repository_test.dart --reporter compact
```

Expected: imports/classes do not exist.

- [x] **Step 3: Implement immutable models and repository**

Define `HomeTabData`, `CourseTabData`, `MineTabData`, `HomeModule`, `CourseMedia`, `CategorySubject`, and `MineProfile`. `MainTabsRepository` receives `AppApiClient` plus `MethodChannelRequestContext`; it must not depend on widgets.

- [x] **Step 4: Verify GREEN**

Run the focused command from Step 2 and expect all tests to pass.

### Task 3: Implement the main shell and three real-data tabs

**Files:**
- Create: `lib/src/main_tabs/main_tabs_page.dart`
- Create: `lib/src/main_tabs/home_tab_page.dart`
- Create: `lib/src/main_tabs/course_tab_page.dart`
- Create: `lib/src/main_tabs/mine_tab_page.dart`
- Modify: `lib/src/app/startup_app.dart`
- Modify: `lib/ultcpa_flutter.dart`
- Create: `test/main_tabs/main_tabs_page_test.dart`
- Create: `test/main_tabs/home_tab_page_test.dart`
- Create: `test/main_tabs/course_tab_page_test.dart`
- Create: `test/main_tabs/mine_tab_page_test.dart`
- Modify: `test/app/startup_app_test.dart`

- [x] **Step 1: Write failing widget tests**

Assert bottom labels `技巧练题`, `技巧课程`, `我的`; `IndexedStack` state preservation; home module/loading/error states; course-type reload; mine logged-out/login states; and that startup `ready` renders the shell instead of the splash.

- [x] **Step 2: Run tests and verify RED**

```powershell
& .\tool\flutter_android21.ps1 test --no-pub test\main_tabs test\app\startup_app_test.dart --reporter compact
```

Expected: the new widgets do not exist and startup remains on the splash.

- [x] **Step 3: Implement the shell and tabs**

Use explicit Android-derived dimensions/colors, `RefreshIndicator`, network images, loading/error/empty states, and an `IndexedStack`. Only controls with implemented destinations are interactive; downstream learn/order/video routes remain outside this task rather than opening fake pages.

- [x] **Step 4: Verify GREEN**

Run the focused command from Step 2 and expect all tests to pass.

### Task 4: Continue phone login to the originating shell state

**Files:**
- Modify: `lib/src/authentication/phone_login_page.dart`
- Modify: `lib/src/main_tabs/main_tabs_page.dart`
- Modify: `test/authentication/phone_login_page_test.dart`
- Modify: `test/main_tabs/main_tabs_page_test.dart`

- [x] **Step 1: Write failing continuation tests**

When no custom `onLoggedIn` callback is supplied, successful phone login must `pop` with the login body. The mine login entry must await that result, stay on `我的`, and reload profile/count data exactly once.

- [x] **Step 2: Run tests and verify RED**

```powershell
& .\tool\flutter_android21.ps1 test --no-pub test\authentication\phone_login_page_test.dart test\main_tabs\main_tabs_page_test.dart --reporter compact
```

- [x] **Step 3: Implement result-based continuation**

Keep injected callbacks for embedding/tests. Default route behavior returns the persisted login body through `Navigator.pop`; the shell reloads its mine data after a non-null result.

- [x] **Step 4: Verify GREEN**

Run the focused command from Step 2 and expect all tests to pass.

### Task 5: Replace external agreement opening with an in-app WebView

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/src/web/agreement_webview_page.dart`
- Modify: `lib/src/app/startup_app.dart`
- Modify: `lib/src/authentication/phone_login_page.dart`
- Create: `test/web/agreement_webview_page_test.dart`
- Modify: `test/app/startup_app_test.dart`
- Modify: `test/authentication/phone_login_page_test.dart`

- [x] **Step 1: Add failing route/widget tests**

Inject a test content builder and assert title, real URL, close/back behavior, and that both privacy-popup and login-page links push `AgreementWebViewPage`.

- [x] **Step 2: Run tests and verify RED**

```powershell
& .\tool\flutter_android21.ps1 test --no-pub test\web\agreement_webview_page_test.dart test\app\startup_app_test.dart test\authentication\phone_login_page_test.dart --reporter compact
```

- [x] **Step 3: Add the compatible plugin and implement the page**

Pin `webview_flutter: 4.13.1`. Production uses `WebViewController` with unrestricted JavaScript and real agreement URLs; tests inject a non-platform content widget.

- [x] **Step 4: Resolve dependencies and verify GREEN**

```powershell
& .\tool\flutter_android21.ps1 pub get
& .\tool\flutter_android21.ps1 test --no-pub test\web\agreement_webview_page_test.dart test\app\startup_app_test.dart test\authentication\phone_login_page_test.dart --reporter compact
```

### Task 6: Full verification

**Files:**
- Modify: `docs/superpowers/plans/2026-07-15-main-tabs-login-webview-static-config.md`

- [x] **Step 1: Format and analyze**

```powershell
& 'E:\soft\flutter\flutter_3.32.8_sdk\flutter\bin\cache\dart-sdk\bin\dart.exe' format lib test
& .\tool\flutter_android21.ps1 analyze --no-pub
```

- [x] **Step 2: Run all tests**

```powershell
& .\tool\flutter_android21.ps1 test --no-pub --reporter compact
```

- [x] **Step 3: Build the Android dev APK**

```powershell
& .\tool\flutter_android21.ps1 build apk --debug --flavor dev --no-pub
```

- [x] **Step 4: Check scope and working trees**

Run `git diff --check`, inspect the Flutter diff, and verify `git -C E:\workspace\ultCPA-android status --short --untracked-files=no` is empty. Do not commit, stage, push, install to a device, or send a real SMS without explicit user instruction.
