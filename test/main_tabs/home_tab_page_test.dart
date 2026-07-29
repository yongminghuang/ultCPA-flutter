import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/home_tab_page.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_repository.dart';

void main() {
  testWidgets('shows loading then Android home modules from real data', (
    tester,
  ) async {
    final completer = Completer<HomeTabData>();
    final dataSource = _DataSource((_, _) => completer.future);

    await tester.pumpWidget(
      MaterialApp(home: HomeTabPage(dataSource: dataSource)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(_homeData);
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('社工实务'), findsOneWidget);
    expect(find.text('距离考试还有5天'), findsOneWidget);
    expect(find.text('技巧口诀'), findsOneWidget);
    expect(find.text('技巧练题'), findsOneWidget);
    expect(find.text('速成300题'), findsOneWidget);
  });

  testWidgets('dispatches the exact hero and grid modules when tapped', (
    tester,
  ) async {
    final launched = <HomeModule>[];
    final circles = <HomeModule?>[];
    final dataSource = _DataSource((_, _) async => _homeData);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeTabPage(
          dataSource: dataSource,
          moduleLauncher: (context, module, circleModule) async {
            launched.add(module);
            circles.add(circleModule);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('home-module-3')));
    await tester.pump();

    expect(launched, [_homeData.modules.first, _homeData.modules.last]);
    expect(circles, [
      _homeData.bigSkillCircleModule,
      _homeData.bigSkillCircleModule,
    ]);
    expect(find.text('技巧圈题卷'), findsNothing);
  });

  testWidgets('keeps the Android category header fixed and turns it white', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: HomeTabPage(dataSource: _DataSource((_, _) async => _homeData)),
      ),
    );
    await tester.pumpAndSettle();

    final header = find.byKey(const ValueKey('home-category-header'));
    final initialTop = tester.getTopLeft(header).dy;
    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(header).dy, initialTop);
    final container = tester.widget<AnimatedContainer>(header);
    expect((container.decoration! as BoxDecoration).color, Colors.white);
  });

  testWidgets('renders learning materials through its dedicated section', (
    tester,
  ) async {
    const learningModule = HomeModule(
      id: 10,
      name: '学习资料',
      page: '学习资料',
      tag: '',
      type: '信息流',
    );
    const data = HomeTabData(
      categoryGroups: _categoryGroups,
      selection: MainTabsSelection(
        category: _socialOption,
        subject: CategorySubject(id: 1023, name: '社工实务'),
      ),
      modules: [],
      bannerUrl: null,
      examCountdownDays: null,
      learningMaterialsModule: learningModule,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeTabPage(
          dataSource: _DataSource((_, _) async => data),
          learningMaterialsSectionBuilder: (context, module) => SizedBox(
            key: const ValueKey('learning-materials-section'),
            child: Text('LEARNING:${module.id}'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('learning-materials-section')),
      findsOneWidget,
    );
    expect(find.text('LEARNING:10'), findsOneWidget);
    expect(find.text('暂无可用模块'), findsNothing);
  });

  testWidgets('shows an actionable error and retries home loading', (
    tester,
  ) async {
    var shouldFail = true;
    final dataSource = _DataSource((_, _) async {
      if (shouldFail) throw StateError('offline');
      return _homeData;
    });

    await tester.pumpWidget(
      MaterialApp(home: HomeTabPage(dataSource: dataSource)),
    );
    await tester.pumpAndSettle();

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('重新加载'), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();

    expect(find.text('技巧口诀'), findsOneWidget);
    expect(dataSource.requests, hasLength(2));
  });

  testWidgets('selects a subject and reports the persisted selection', (
    tester,
  ) async {
    var selectionChanges = 0;
    final dataSource = _DataSource((_, subjectId) async {
      return subjectId == 1024 ? _secondSubjectHomeData : _homeData;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: HomeTabPage(
          dataSource: dataSource,
          onSelectionChanged: () => selectionChanges += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('综合能力'));
    await tester.pumpAndSettle();

    expect(dataSource.requests.last.categoryKey, 'social-work_1016');
    expect(dataSource.requests.last.subjectId, 1024);
    expect(find.text('综合能力模块'), findsOneWidget);
    expect(selectionChanges, 1);
  });

  testWidgets('selects a category and uses its first valid subject', (
    tester,
  ) async {
    var selectionChanges = 0;
    final dataSource = _DataSource((categoryKey, _) async {
      return categoryKey == _accountingOption.key
          ? _accountingHomeData
          : _homeData;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: HomeTabPage(
          dataSource: dataSource,
          onSelectionChanged: () => selectionChanges += 1,
          categorySelectorLauncher: (_, _, _) async => _accountingOption,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-category-selector')));
    await tester.pumpAndSettle();

    expect(dataSource.requests.last.categoryKey, 'joy-ledger_6');
    expect(dataSource.requests.last.subjectId, 61);
    expect(find.text('初级会计'), findsOneWidget);
    expect(selectionChanges, 1);
  });

  testWidgets('keeps old content visible while selection reloads', (
    tester,
  ) async {
    final selectionCompleter = Completer<HomeTabData>();
    var calls = 0;
    final dataSource = _DataSource((_, _) {
      calls += 1;
      return calls == 1 ? Future.value(_homeData) : selectionCompleter.future;
    });

    await tester.pumpWidget(
      MaterialApp(home: HomeTabPage(dataSource: dataSource)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('综合能力'));
    await tester.pump();

    expect(find.text('技巧口诀'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    selectionCompleter.complete(_secondSubjectHomeData);
    await tester.pumpAndSettle();
    expect(find.text('综合能力模块'), findsOneWidget);
  });

  testWidgets('keeps old content and reports a failed selection reload', (
    tester,
  ) async {
    var calls = 0;
    final dataSource = _DataSource((_, _) async {
      calls += 1;
      if (calls > 1) throw StateError('offline');
      return _homeData;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeTabPage(dataSource: dataSource)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('综合能力'));
    await tester.pumpAndSettle();

    expect(find.text('技巧口诀'), findsOneWidget);
    expect(find.text('切换失败，请重试'), findsOneWidget);
  });

  testWidgets('ignores an older selection response that completes last', (
    tester,
  ) async {
    final subjectCompleter = Completer<HomeTabData>();
    final categoryCompleter = Completer<HomeTabData>();
    var calls = 0;
    var selectionChanges = 0;
    final dataSource = _DataSource((_, _) {
      calls += 1;
      return switch (calls) {
        1 => Future.value(_homeData),
        2 => subjectCompleter.future,
        _ => categoryCompleter.future,
      };
    });

    await tester.pumpWidget(
      MaterialApp(
        home: HomeTabPage(
          dataSource: dataSource,
          onSelectionChanged: () => selectionChanges += 1,
          categorySelectorLauncher: (_, _, _) async => _accountingOption,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('综合能力'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('home-category-selector')));
    await tester.pump();

    categoryCompleter.complete(_accountingHomeData);
    await tester.pump();
    await tester.pump();
    expect(find.text('会计章节模块'), findsOneWidget);

    subjectCompleter.complete(_secondSubjectHomeData);
    await tester.pumpAndSettle();

    expect(find.text('会计章节模块'), findsOneWidget);
    expect(find.text('综合能力模块'), findsNothing);
    expect(selectionChanges, 1);
  });
}

typedef _HomeLoader =
    Future<HomeTabData> Function(String? categoryKey, int? subjectId);

final class _HomeRequest {
  const _HomeRequest({required this.categoryKey, required this.subjectId});

  final String? categoryKey;
  final int? subjectId;
}

final class _DataSource implements MainTabsDataSource {
  _DataSource(this.homeLoader);

  final _HomeLoader homeLoader;
  final List<_HomeRequest> requests = [];

  @override
  Future<HomeTabData> loadHome({
    String? preferredCategoryKey,
    int? preferredSubjectId,
  }) {
    requests.add(
      _HomeRequest(
        categoryKey: preferredCategoryKey,
        subjectId: preferredSubjectId,
      ),
    );
    return homeLoader(preferredCategoryKey, preferredSubjectId);
  }

  @override
  Future<CourseTabData> loadCourses({
    required CourseType courseType,
    String? subject,
  }) => throw UnimplementedError();

  @override
  Future<MineTabData> loadMine() => throw UnimplementedError();
}

const _socialSubjects = [
  CategorySubject(id: 1023, name: '社工实务'),
  CategorySubject(id: 1024, name: '综合能力'),
];

const _accountingSubjects = [
  CategorySubject(id: 61, name: '会计实务'),
  CategorySubject(id: 62, name: '经济法'),
];

const _socialOption = CategoryOption(
  key: 'social-work_1016',
  appType: 'social-work',
  id: 1016,
  label: '初级社工',
  subjects: _socialSubjects,
  raw: {'id': 1016, 'appType': 'social-work', 'level': '初级社工'},
);

const _accountingOption = CategoryOption(
  key: 'joy-ledger_6',
  appType: 'joy-ledger',
  id: 6,
  label: '初级会计',
  subjects: _accountingSubjects,
  raw: {'id': 6, 'appType': 'joy-ledger', 'level': '初级会计'},
);

const _categoryGroups = [
  CategoryGroup(label: '社工', options: [_socialOption]),
  CategoryGroup(label: '会计', options: [_accountingOption]),
];

const _homeData = HomeTabData(
  categoryGroups: _categoryGroups,
  selection: MainTabsSelection(
    category: _socialOption,
    subject: CategorySubject(id: 1023, name: '社工实务'),
  ),
  modules: [
    HomeModule(id: 1, name: '技巧口诀', page: 'mnemonics', tag: 'hot'),
    HomeModule(id: 2, name: '技巧练题', page: 'practice', tag: ''),
    HomeModule(id: 3, name: '速成300题', page: 'fast300', tag: ''),
  ],
  bannerUrl: null,
  examCountdownDays: 5,
  bigSkillCircleModule: HomeModule(
    id: 9,
    name: '技巧圈题卷',
    page: '技巧圈题卷',
    tag: '',
  ),
);

const _secondSubjectHomeData = HomeTabData(
  categoryGroups: _categoryGroups,
  selection: MainTabsSelection(
    category: _socialOption,
    subject: CategorySubject(id: 1024, name: '综合能力'),
  ),
  modules: [HomeModule(id: 4, name: '综合能力模块', page: 'practice', tag: '')],
  bannerUrl: null,
  examCountdownDays: 5,
);

const _accountingHomeData = HomeTabData(
  categoryGroups: _categoryGroups,
  selection: MainTabsSelection(
    category: _accountingOption,
    subject: CategorySubject(id: 61, name: '会计实务'),
  ),
  modules: [HomeModule(id: 5, name: '会计章节模块', page: '章节练习', tag: '')],
  bannerUrl: null,
  examCountdownDays: 12,
);
