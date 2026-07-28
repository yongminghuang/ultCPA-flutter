# Category and Subject Selection Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Android-compatible category and subject switching that persists through the legacy bridge and refreshes Home, Course, and Mine without losing tab-local state.

**Architecture:** `MainTabsRepository` remains the source of selection resolution and native persistence. Home initiates changes and reports a successful selection revision to `MainTabsPage`; existing Course and Mine states observe that revision and reload exactly once. A dedicated full-screen selector owns only category presentation and returns an immutable `CategoryOption`.

**Tech Stack:** Flutter 3.32.8, Dart 3.8, Dio 5.9, Android MMKV method channel, flutter_test.

---

### Task 1: Expose category-name mapping through the legacy snapshot

**Files:**
- Modify: `android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt`
- Modify: `lib/src/main_tabs/main_tabs_models.dart`
- Modify: `test/config/android_shell_config_test.dart`
- Modify: `test/main_tabs/main_tabs_repository_test.dart`

- [x] **Step 1: Write failing snapshot contract tests**

Add an Android shell assertion:

```dart
expect(bridge, contains('"appCategoryNameMappingJson"'));
expect(bridge, contains('"app_category_name_mapping"'));
```

Extend the repository fixture snapshot with:

```dart
'appCategoryNameMappingJson': jsonEncode({
  'social-work': '社工',
  'joy-ledger': '会计',
}),
```

and assert `AppSnapshot.fromMap(_snapshot).appCategoryNameMappingJson` preserves the JSON text.

- [x] **Step 2: Run the focused tests and verify RED**

```powershell
& .\tool\flutter_android21.ps1 test --no-pub test\config\android_shell_config_test.dart test\main_tabs\main_tabs_repository_test.dart --reporter compact
```

Expected: failure because the native snapshot key and Dart field do not exist.

- [x] **Step 3: Implement the snapshot field**

Add this native entry in `readAppSnapshot()`:

```kotlin
"appCategoryNameMappingJson" to appKv.decodeString(
    "app_category_name_mapping",
    "",
).orEmpty(),
```

Add the Dart constructor/factory/property wiring:

```dart
required this.appCategoryNameMappingJson,

appCategoryNameMappingJson: _text(map['appCategoryNameMappingJson']),

final String appCategoryNameMappingJson;
```

- [x] **Step 4: Rerun the focused tests and verify GREEN**

Run the command from Step 2 and expect all selected tests to pass.

### Task 2: Parse category groups and resolve explicit selections

**Files:**
- Modify: `lib/src/main_tabs/main_tabs_models.dart`
- Modify: `lib/src/main_tabs/main_tabs_repository.dart`
- Modify: `test/main_tabs/main_tabs_repository_test.dart`
- Modify: all `HomeTabData` fixtures under `test/main_tabs/`

- [x] **Step 1: Write failing category-resolution tests**

Add a second mapped app type plus an unmapped type to `_categoryBody`:

```dart
'joy-ledger': [
  {
    'id': 6,
    'appType': 'joy-ledger',
    'level': '初级会计',
    'children': [
      {'id': 61, 'name': '会计实务'},
      {'id': 62, 'name': '经济法'},
    ],
  },
],
'future-unmapped': [
  {
    'id': 900,
    'level': '隐藏分类',
    'children': [
      {'id': 901, 'name': '隐藏科目'},
    ],
  },
],
```

Call the wished-for API:

```dart
final data = await repository.loadHome(
  preferredCategoryKey: 'joy-ledger_6',
  preferredSubjectId: 62,
);

expect(data.categoryGroups.map((group) => group.label), ['社工', '会计']);
expect(data.selection.category.key, 'joy-ledger_6');
expect(data.selection.subject, const CategorySubject(id: 62, name: '经济法'));
expect(api.requests.last.queryParameters, {'marketId': 62});
expect(store.persistedSelection?.category, 'joy-ledger');
expect(store.persistedSelection?.selectedCategory, _categoryBody['joy-ledger']![0]);
expect(store.persistedSelection?.selectedCategoryKey, 'joy-ledger_6');
expect(store.persistedSelection?.marketId, 62);
expect(store.persistedSelection?.subject, '经济法');
```

Expand `_PersistedSelection` so the test store records all six persistence arguments, then add fallback cases for an invalid preferred key/subject and verify persisted/default selection wins.

- [x] **Step 2: Run repository tests and verify RED**

```powershell
& .\tool\flutter_android21.ps1 test --no-pub test\main_tabs\main_tabs_repository_test.dart --reporter compact
```

Expected: compilation failure because selection models and `loadHome` parameters do not exist.

- [x] **Step 3: Add immutable selection models**

Add value equality to `CategorySubject`, then define:

```dart
final class CategoryGroup {
  const CategoryGroup({required this.label, required this.options});

  final String label;
  final List<CategoryOption> options;
}

final class CategoryOption {
  const CategoryOption({
    required this.key,
    required this.appType,
    required this.id,
    required this.label,
    required this.subjects,
    required this.raw,
  });

  final String key;
  final String appType;
  final int id;
  final String label;
  final List<CategorySubject> subjects;
  final Map<String, dynamic> raw;
}

final class MainTabsSelection {
  const MainTabsSelection({required this.category, required this.subject});

  final CategoryOption category;
  final CategorySubject subject;
}
```

Replace duplicated Home selection fields with `categoryGroups` and `selection`, while preserving computed accessors used by existing widgets:

```dart
final List<CategoryGroup> categoryGroups;
final MainTabsSelection selection;

String get category => selection.category.appType;
String get categoryLabel => selection.category.label;
List<CategorySubject> get subjects => selection.category.subjects;
CategorySubject get selectedSubject => selection.subject;
```

- [x] **Step 4: Implement Android-compatible parsing and fallback rules**

Change the interface to:

```dart
Future<HomeTabData> loadHome({
  String? preferredCategoryKey,
  int? preferredSubjectId,
});
```

Parse `appCategoryNameMappingJson`, with only these built-in fallbacks:

```dart
const fallbackLabels = <String, String>{
  'social-work': '社工',
  'joy-ledger': '会计',
};
```

For every mapped `categoryBody` entry, create options using key `${appType}_${id}` and filter invalid IDs, blank labels, and options without valid subjects. Resolve in this order:

```text
preferred category key
persisted selected category key / category ID / level
static default category app type + level
first valid option
```

Resolve subjects in this order:

```text
preferred subject ID
persisted subject name / market ID when the category is unchanged
first valid subject
```

Persist the chosen option's raw map and fetch `/knowledge/shelf/moduleLis` using the resolved subject ID.

- [x] **Step 5: Update fixtures and verify GREEN**

Update every fake `loadHome` signature and construct `HomeTabData` with shared constants:

```dart
const _categoryOption = CategoryOption(
  key: 'social-work_1016',
  appType: 'social-work',
  id: 1016,
  label: '初级社工',
  subjects: _subjects,
  raw: {'id': 1016, 'appType': 'social-work', 'level': '初级社工'},
);

const _selection = MainTabsSelection(
  category: _categoryOption,
  subject: CategorySubject(id: 1023, name: '社工实务'),
);
```

Rerun the Task 2 test command and expect all tests to pass.

### Task 3: Add the full-screen category selector

**Files:**
- Create: `lib/src/main_tabs/category_selector_page.dart`
- Create: `test/main_tabs/category_selector_page_test.dart`
- Modify: `lib/ultcpa_flutter.dart`

- [x] **Step 1: Write failing selector widget tests**

Pump a `MaterialApp` route containing:

```dart
CategorySelectorPage(
  groups: const [_socialWorkGroup, _accountingGroup],
  selectedKey: 'social-work_1016',
)
```

Assert:

```dart
expect(find.text('切换分类'), findsOneWidget);
expect(find.text('社工'), findsOneWidget);
expect(find.text('会计'), findsOneWidget);
expect(find.text('初级社工'), findsOneWidget);
```

Tap `会计`, choose `初级会计`, and assert the route returns the corresponding `CategoryOption`. Add a close-button test returning null and a selected-style assertion by widget key.

- [x] **Step 2: Run the selector test and verify RED**

```powershell
& .\tool\flutter_android21.ps1 test --no-pub test\main_tabs\category_selector_page_test.dart --reporter compact
```

Expected: import/class failure.

- [x] **Step 3: Implement the selector page**

Create a `StatefulWidget` with:

```dart
final List<CategoryGroup> groups;
final String selectedKey;
```

Initialize the left group index from `selectedKey`. Render a `Scaffold` with a compact `AppBar`, close icon, fixed-width left `ListView` of group labels, and right two-column `GridView` of options. Use `InkWell` and keys:

```dart
ValueKey('category-group-${group.label}')
ValueKey('category-option-${option.key}')
```

Return a choice with:

```dart
Navigator.of(context).pop<CategoryOption>(option);
```

Use the existing blue `0xFF237DED`, white surface, 4-8px radii, and selected fill/border states; do not add explanatory copy or placeholder actions.

- [x] **Step 4: Export and verify GREEN**

Export the page from `lib/ultcpa_flutter.dart`, rerun the Task 3 command, and expect all tests to pass.

### Task 4: Make Home selection interactive and race-safe

**Files:**
- Modify: `lib/src/main_tabs/home_tab_page.dart`
- Modify: `test/main_tabs/home_tab_page_test.dart`

- [x] **Step 1: Write failing Home interaction tests**

Change the fake loader to record named arguments:

```dart
Future<HomeTabData> loadHome({
  String? preferredCategoryKey,
  int? preferredSubjectId,
})
```

Add tests that:

- tap `综合能力` and expect `preferredCategoryKey == 'social-work_1016'`, `preferredSubjectId == 1024`, plus one `onSelectionChanged` call after success;
- inject a category launcher returning `_accountingOption`, then expect a reload using `joy-ledger_6` and subject `61`;
- keep old modules visible and show `LinearProgressIndicator` during selection reload;
- keep old content and show a `SnackBar` when a selection reload fails;
- complete two reload futures out of order and assert only the newest data renders/calls back.

- [x] **Step 2: Run the Home tests and verify RED**

```powershell
& .\tool\flutter_android21.ps1 test --no-pub test\main_tabs\home_tab_page_test.dart --reporter compact
```

Expected: failure because Home has no interactive selection contract.

- [x] **Step 3: Implement the Home callback and launcher contract**

Add:

```dart
typedef CategorySelectorLauncher = Future<CategoryOption?> Function(
  BuildContext context,
  List<CategoryGroup> groups,
  String selectedKey,
);

final VoidCallback? onSelectionChanged;
final CategorySelectorLauncher? categorySelectorLauncher;
```

The default launcher pushes `CategorySelectorPage`. Add `_requestNumber` and implement:

```dart
Future<void> _load({
  String? preferredCategoryKey,
  int? preferredSubjectId,
  bool notifySelectionChanged = false,
}) async
```

Ignore results whose request number is no longer current. Keep `_data` during selection loads, display a top `LinearProgressIndicator`, and call `onSelectionChanged` only after the newest requested selection succeeds.

- [x] **Step 4: Wire category and subject controls**

Add a compact category header button using the current label and `Icons.menu_rounded`. Pass `onSubjectSelected` into `_SubjectHeader` and wrap each non-selected subject in `InkWell`; selecting the active subject is a no-op.

When a category returns, preserve the current subject only if the new option contains its ID; otherwise use the option's first subject. Reload with the option key and resolved subject ID.

- [x] **Step 5: Rerun Home tests and verify GREEN**

Run the Task 4 command and expect all tests to pass.

### Task 5: Propagate selection revisions without losing tab state

**Files:**
- Modify: `lib/src/main_tabs/main_tabs_page.dart`
- Modify: `lib/src/main_tabs/course_tab_page.dart`
- Modify: `lib/src/main_tabs/mine_tab_page.dart`
- Modify: `test/main_tabs/main_tabs_page_test.dart`
- Modify: `test/main_tabs/course_tab_page_test.dart`
- Modify: `test/main_tabs/mine_tab_page_test.dart`

- [x] **Step 1: Write failing revision tests**

Visit Course, choose `技巧密押`, visit Mine, return Home, and trigger a subject change. Assert:

```dart
expect(dataSource.courseCalls, 3);
expect(dataSource.requestedTypes.last, CourseType.secret);
expect(dataSource.requestedSubjects.last, isNull);
expect(dataSource.mineCalls, 2);
```

Also pump Course and Mine directly, update only `selectionRevision`, and assert each reloads once. An unchanged revision must not reload.

- [x] **Step 2: Run the shell/page tests and verify RED**

```powershell
& .\tool\flutter_android21.ps1 test --no-pub test\main_tabs\main_tabs_page_test.dart test\main_tabs\course_tab_page_test.dart test\main_tabs\mine_tab_page_test.dart --reporter compact
```

Expected: constructor/signature failures for `selectionRevision`.

- [x] **Step 3: Implement revision propagation**

In `MainTabsPage`, own:

```dart
int _selectionRevision = 0;

void _handleSelectionChanged() {
  setState(() {
    _selectionRevision += 1;
    if (_pages[1] != null) _pages[1] = _buildCoursePage();
    if (_pages[2] != null) _pages[2] = _buildMinePage();
  });
}
```

Build Home with `onSelectionChanged: _handleSelectionChanged`, and pass the revision into Course and Mine.

In `CourseTabPage.didUpdateWidget`, when the revision changes:

```dart
_selectedSubject = null;
_load();
```

Do not change `_selectedType` or discard existing data while the reload is pending.

In `MineTabPage.didUpdateWidget`, reload when either `reloadToken` or `selectionRevision` changes, but call `_load()` only once when both change in the same update.

- [x] **Step 4: Verify revision behavior GREEN**

Run the Task 5 command and expect all selected tests to pass.

### Task 6: Full verification and scope audit

**Files:**
- Modify: `docs/superpowers/plans/2026-07-16-category-subject-sync.md`

- [x] **Step 1: Format all Dart sources**

```powershell
& 'E:\soft\flutter\flutter_3.32.8_sdk\flutter\bin\cache\dart-sdk\bin\dart.exe' format lib test
```

Expected: formatter exits 0.

- [x] **Step 2: Analyze**

```powershell
& .\tool\flutter_android21.ps1 analyze --no-pub
```

Expected: `No issues found!`.

- [x] **Step 3: Run all tests**

```powershell
& .\tool\flutter_android21.ps1 test --no-pub --reporter compact
```

Expected: all tests pass.

- [x] **Step 4: Build the dev APK**

```powershell
& .\tool\flutter_android21.ps1 build apk --debug --flavor dev --no-pub
```

Expected: `build/app/outputs/flutter-apk/app-dev-debug.apk` is produced with `minSdk 21`, `targetSdk 34`, and `compileSdk 35`.

- [x] **Step 5: Audit scope and working trees**

Run `git diff --check`, inspect every Flutter change, confirm no module-detail/video/payment route was added, and verify:

```powershell
git -C E:\workspace\ultCPA-android status --short --untracked-files=no
```

Expected: the Android reference output is empty. Do not stage, commit, push, install, send SMS, or issue a production request.
