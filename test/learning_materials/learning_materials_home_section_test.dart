import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/learning_materials/learning_materials_home_section.dart';
import 'package:ultcpa_flutter/src/learning_materials/learning_materials_models.dart';
import 'package:ultcpa_flutter/src/learning_materials/learning_materials_navigation.dart';
import 'package:ultcpa_flutter/src/learning_materials/learning_materials_repository.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';

void main() {
  testWidgets('loads tabs and launches an immutable clicked feed request', (
    tester,
  ) async {
    final source = _Source(
      snapshot: _snapshot(isLoggedIn: true),
      shelves: [_shelf(11, '每日精选'), _shelf(12, '冲刺资料')],
      pages: {
        (11, 1): _page([
          _item(1, '第一份资料'),
          _item(2, '视频资料', type: '视频'),
        ]),
        (12, 1): _page([_item(3, '第二栏资料')]),
      },
    );
    LearningMaterialsFeedRequest? launched;

    await tester.pumpWidget(
      _app(
        source,
        feedLauncher: (context, request) async => launched = request,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('学习资料'), findsOneWidget);
    expect(find.text('每日精选'), findsOneWidget);
    expect(find.text('冲刺资料'), findsOneWidget);
    expect(find.text('第一份资料'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('learning-material-home-item-11-2')),
    );
    await tester.pump();

    expect(launched, isNotNull);
    expect(launched!.module, _module);
    expect(launched!.shelves.map((shelf) => shelf.id), [11, 12]);
    expect(launched!.initialTabIndex, 0);
    expect(launched!.clickedIndex, 1);
    expect(launched!.snapshotItems.map((item) => item.id), [1, 2]);
    expect(launched!.autoOpenItem?.id, 2);
    expect(launched!.bootstrapForTab(0).map((item) => item.id), [2, 1]);
    expect(
      () => launched!.snapshotItems.add(_item(9, '不可添加')),
      throwsUnsupportedError,
    );
  });

  testWidgets('intercepts a logged-out click and proceeds after login', (
    tester,
  ) async {
    final source = _Source(
      snapshot: _snapshot(isLoggedIn: false),
      shelves: [_shelf(11, '精选')],
      pages: {
        (11, 1): _page([_item(1, '登录后资料')]),
      },
    );
    var loginCalls = 0;
    LearningMaterialsFeedRequest? launched;

    await tester.pumpWidget(
      _app(
        source,
        loginLauncher: (context) async {
          loginCalls += 1;
          return {'token': 'new-token'};
        },
        feedLauncher: (context, request) async => launched = request,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('learning-material-home-item-11-1')),
    );
    await tester.pump();

    expect(loginCalls, 1);
    expect(launched?.appSnapshot.isLoggedIn, isTrue);
  });

  testWidgets('cancelled login keeps the user on the home section', (
    tester,
  ) async {
    final source = _Source(
      snapshot: _snapshot(isLoggedIn: false),
      shelves: [_shelf(11, '精选')],
      pages: {
        (11, 1): _page([_item(1, '受保护资料')]),
      },
    );
    var feedCalls = 0;

    await tester.pumpWidget(
      _app(
        source,
        loginLauncher: (context) async => null,
        feedLauncher: (context, request) async => feedCalls += 1,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('learning-material-home-item-11-1')),
    );
    await tester.pump();

    expect(feedCalls, 0);
    expect(find.text('受保护资料'), findsOneWidget);
  });

  testWidgets('keeps pagination per shelf and exposes a guarded retry footer', (
    tester,
  ) async {
    final source = _Source(
      snapshot: _snapshot(isLoggedIn: true),
      shelves: [_shelf(11, '精选')],
      pages: {
        (11, 1): LearningMaterialsPage(
          total: 2,
          pages: 2,
          size: 1,
          current: 1,
          records: [_item(1, '第一页')],
        ),
        (11, 2): LearningMaterialsPage(
          total: 2,
          pages: 2,
          size: 1,
          current: 2,
          records: [_item(2, '第二页')],
        ),
      },
    );

    await tester.pumpWidget(_app(source));
    await tester.pumpAndSettle();
    expect(find.text('第一页'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('learning-material-home-more-11')),
    );
    await tester.pumpAndSettle();

    expect(find.text('第二页'), findsOneWidget);
    expect(source.pageCalls, [(11, 1), (11, 2)]);
  });

  testWidgets('shows shelf failure and retries the whole section', (
    tester,
  ) async {
    final source = _Source(
      snapshot: _snapshot(isLoggedIn: true),
      shelves: const [],
      pages: const {},
      shelfError: StateError('offline'),
    );

    await tester.pumpWidget(_app(source));
    await tester.pumpAndSettle();

    expect(find.text('学习资料加载失败'), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();
    expect(source.shelfCalls, 2);
  });
}

const _module = HomeModule(
  id: 88,
  name: '学习资料',
  page: '学习资料',
  tag: '',
);

Widget _app(
  LearningMaterialsDataSource source, {
  LearningMaterialsLoginLauncher? loginLauncher,
  LearningMaterialsFeedLauncher? feedLauncher,
}) {
  return MaterialApp(
    home: Scaffold(
      body: LearningMaterialsHomeSection(
        module: _module,
        dataSource: source,
        loginLauncher: loginLauncher,
        feedLauncher: feedLauncher,
        viewportHeight: 360,
      ),
    ),
  );
}

LearningMaterialsAppSnapshot _snapshot({required bool isLoggedIn}) {
  return LearningMaterialsAppSnapshot(
    isLoggedIn: isLoggedIn,
    ossDomain: '',
    categoryLabel: '初级社工',
    isTestEnvironment: false,
  );
}

LearningMaterialsShelf _shelf(int id, String name) {
  return LearningMaterialsShelf(id: id, name: name, children: const []);
}

LearningMaterialsItem _item(int id, String title, {String type = '文档'}) {
  return LearningMaterialsItem.fromMap({
    'id': id,
    'type': type,
    'title': title,
    if (type == '视频') 'videoUrl': 'https://example.com/$id.mp4',
  });
}

LearningMaterialsPage _page(List<LearningMaterialsItem> items) {
  return LearningMaterialsPage(
    total: items.length,
    pages: 1,
    size: 20,
    current: 1,
    records: items,
  );
}

final class _Source implements LearningMaterialsDataSource {
  _Source({
    required this.snapshot,
    required this.shelves,
    required this.pages,
    this.shelfError,
  });

  final LearningMaterialsAppSnapshot snapshot;
  final List<LearningMaterialsShelf> shelves;
  final Map<(int, int), LearningMaterialsPage> pages;
  final Object? shelfError;
  final List<(int, int)> pageCalls = [];
  int shelfCalls = 0;

  @override
  Future<LearningMaterialsAppSnapshot> readSnapshot() async => snapshot;

  @override
  Future<List<LearningMaterialsShelf>> loadShelfTabs({
    required int moduleId,
  }) async {
    shelfCalls += 1;
    if (shelfError case final Object error) throw error;
    return shelves;
  }

  @override
  Future<LearningMaterialsPage> loadPage({
    required int moduleId,
    required int shelfId,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    pageCalls.add((shelfId, pageNumber));
    return pages[(shelfId, pageNumber)] ??
        LearningMaterialsPage(
          total: 0,
          pages: 1,
          size: pageSize,
          current: pageNumber,
          records: const [],
        );
  }
}
