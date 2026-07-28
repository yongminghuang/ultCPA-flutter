import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_repository.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';
import 'package:ultcpa_flutter/src/storage/legacy_app_state_store.dart';

void main() {
  test('preserves the category name mapping from the legacy snapshot', () {
    final snapshot = AppSnapshot.fromMap(_snapshot);

    expect(
      snapshot.appCategoryNameMappingJson,
      jsonEncode({'social-work': '社工', 'joy-ledger': '会计'}),
    );
  });

  test('loads home categories, modules, banner, and exam countdown', () async {
    final api = _Api({
      'GET /knowledge/market/appCategory': _categoryBody,
      'GET /knowledge/shelf/moduleLis': [
        {'id': 9, 'name': '技巧圈题卷', 'type': '结构化', 'page': '技巧圈题卷', 'tag': ''},
        {
          'id': 1,
          'name': '技巧口诀',
          'type': '扁平化',
          'page': 'mnemonics',
          'tag': 'hot',
        },
        {'id': 10, 'name': '学习资料', 'type': '信息流', 'page': '学习资料', 'tag': ''},
        {'id': 2, 'name': '技巧练题', 'type': '结构化', 'page': 'practice', 'tag': ''},
      ],
    });
    final store = _Store(_snapshot);
    final repository = MainTabsRepository(
      api: api,
      stateStore: store,
      now: () => DateTime(2026, 7, 15),
    );

    final data = await repository.loadHome();

    expect(data.categoryLabel, '初级社工');
    expect(data.subjects.map((item) => item.name), ['社工实务', '综合能力']);
    expect(data.selectedSubject.name, '社工实务');
    expect(data.modules.map((item) => item.name), ['技巧口诀', '技巧练题']);
    expect(data.modules.map((item) => item.type), ['扁平化', '结构化']);
    expect(data.bigSkillCircleModule?.id, 9);
    expect(data.bigSkillCircleModule?.page, '技巧圈题卷');
    expect(data.learningMaterialsModule?.id, 10);
    expect(data.learningMaterialsModule?.page, '学习资料');
    expect(data.bannerUrl, 'https://img.jx885.com/banner/home.png');
    expect(data.examCountdownDays, 5);
    expect(api.requests[0].queryParameters, {'marketType': '模块管理'});
    expect(api.requests[1].queryParameters, {'marketId': 1023});
    expect(store.persistedSelection?.marketId, 1023);
  });

  test('loads a preferred mapped category and subject', () async {
    final api = _Api({
      'GET /knowledge/market/appCategory': _categoryBody,
      'GET /knowledge/shelf/moduleLis': [
        {'id': 3, 'name': '章节练习', 'page': '章节练习', 'tag': ''},
      ],
    });
    final store = _Store(_snapshot);
    final repository = MainTabsRepository(
      api: api,
      stateStore: store,
      now: () => DateTime(2026, 7, 15),
    );

    final data = await repository.loadHome(
      preferredCategoryKey: 'joy-ledger_6',
      preferredSubjectId: 62,
    );

    expect(data.categoryGroups.map((group) => group.label), ['社工', '会计']);
    expect(data.selection.category.key, 'joy-ledger_6');
    expect(data.selection.subject, const CategorySubject(id: 62, name: '经济法'));
    expect(api.requests.last.queryParameters, {'marketId': 62});
    expect(store.persistedSelection?.category, 'joy-ledger');
    expect(
      store.persistedSelection?.selectedCategory,
      (_categoryBody['joy-ledger']! as List).first,
    );
    expect(store.persistedSelection?.selectedCategoryKey, 'joy-ledger_6');
    expect(store.persistedSelection?.marketId, 62);
    expect(store.persistedSelection?.subject, '经济法');
  });

  test('uses the learning-materials name only when page is empty', () async {
    final repository = MainTabsRepository(
      api: _Api({
        'GET /knowledge/market/appCategory': _categoryBody,
        'GET /knowledge/shelf/moduleLis': [
          {'id': 10, 'name': '学习资料', 'page': '', 'tag': ''},
          {'id': 11, 'name': '学习资料', 'page': '其他页面', 'tag': ''},
        ],
      }),
      stateStore: _Store(_snapshot),
      now: () => DateTime(2026, 7, 15),
    );

    final data = await repository.loadHome();

    expect(data.learningMaterialsModule?.id, 10);
    expect(data.modules.map((module) => module.id), [11]);
  });

  test(
    'falls back to the persisted selection for invalid preferences',
    () async {
      final api = _Api({
        'GET /knowledge/market/appCategory': _categoryBody,
        'GET /knowledge/shelf/moduleLis': const [],
      });
      final repository = MainTabsRepository(
        api: api,
        stateStore: _Store(_snapshot),
        now: () => DateTime(2026, 7, 15),
      );

      final data = await repository.loadHome(
        preferredCategoryKey: 'missing_999',
        preferredSubjectId: 999,
      );

      expect(data.selection.category.key, 'social-work_1016');
      expect(data.selection.subject.id, 1023);
      expect(api.requests.last.queryParameters, {'marketId': 1023});
    },
  );

  test('uses built-in labels when a known mapping value is blank', () async {
    final snapshot = Map<String, dynamic>.from(_snapshot)
      ..['appCategoryNameMappingJson'] = jsonEncode({
        'social-work': '   ',
        'joy-ledger': '会计',
      });
    final repository = MainTabsRepository(
      api: _Api({
        'GET /knowledge/market/appCategory': _categoryBody,
        'GET /knowledge/shelf/moduleLis': const [],
      }),
      stateStore: _Store(snapshot),
      now: () => DateTime(2026, 7, 15),
    );

    final data = await repository.loadHome();

    expect(data.categoryGroups.map((group) => group.label), ['社工', '会计']);
    expect(data.selection.category.key, 'social-work_1016');
  });

  test('loads the selected real course type and subject', () async {
    final api = _Api({
      'GET /knowledge/market/appCategory': _categoryBody,
      'POST /app/tempMedia/query': [
        {
          'id': 9007199254740993,
          'subject': '综合能力',
          'courseType': '大招精讲',
          'title': '综合能力技巧精讲',
          'coverUrl': 'cover/course.png',
          'mediaUrl': 'video/course.m3u8',
        },
      ],
    });
    final repository = MainTabsRepository(
      api: api,
      stateStore: _Store(_snapshot),
      now: () => DateTime(2026, 7, 15),
    );

    final data = await repository.loadCourses(
      courseType: CourseType.intensive,
      subject: '综合能力',
    );

    expect(data.courseType, CourseType.intensive);
    expect(data.selectedSubject.name, '综合能力');
    expect(data.items.single.id, 9007199254740993);
    expect(
      data.items.single.coverUrl,
      'https://img.jx885.com/cover/course.png',
    );
    expect(api.requests.last.body, {
      'subject': '综合能力',
      'courseType': '大招精讲',
      'level': '初级社工',
      'showOnHome': '0',
    });
  });

  test('loads legacy profile and real error and collection totals', () async {
    final api = _Api({
      'GET /app/question/pageErrorQuestion': {'total': 12},
      'GET /app/question/pageCollectQuestion': {'total': 3},
      'GET /app/user/getUserRole': {
        'userRole': 'creator,teacher',
        'commissionRate': 0.25,
      },
    });
    final persisted = <({String userRole, String commissionRate})>[];
    final repository = MainTabsRepository(
      api: api,
      stateStore: _Store(_snapshot),
      now: () => DateTime(2026, 7, 15),
      persistMineReferralProfile:
          ({required userRole, required commissionRate}) async {
            persisted.add((userRole: userRole, commissionRate: commissionRate));
          },
    );

    final data = await repository.loadMine();

    expect(data.isLoggedIn, isTrue);
    expect(data.profile.userId, '2038529229062426626');
    expect(data.profile.nickname, '考友');
    expect(data.errorCount, 12);
    expect(data.collectionCount, 3);
    expect(data.collectBookRequest?.url, 'https://example.com/collect-book');
    expect(data.collectBookRequest?.title, '领取书籍');
    expect(
      data.inviteFriendsRequest?.url,
      'https://img.jx885.com/pass-license/html/invite/index.html'
      '?t=cached-token&env=test&userRole=creator%2Cteacher'
      '&commissionRate=0.25',
    );
    expect(data.inviteFriendsRequest?.hideTitleBar, isTrue);
    expect(persisted, [(userRole: 'creator,teacher', commissionRate: '0.25')]);
    expect(
      api.requests.where((request) => request.path == '/app/user/getUserRole'),
      hasLength(1),
    );
    expect(api.requests.first.queryParameters, {
      'pageNum': 1,
      'pageSize': 1,
      'subject': '社工实务',
      'level': '初级社工',
    });
  });

  test('logged-out Mine never refreshes referral metadata', () async {
    final snapshot = Map<String, dynamic>.from(_snapshot)
      ..['isLoggedIn'] = false;
    final api = _Api({
      'GET /app/question/pageErrorQuestion': {'total': 0},
      'GET /app/question/pageCollectQuestion': {'total': 0},
      'GET /app/user/getUserRole': () => throw StateError('unexpected role'),
    });

    final data = await MainTabsRepository(
      api: api,
      stateStore: _Store(snapshot),
    ).loadMine();

    expect(data.inviteFriendsRequest?.url, contains('userRole=student'));
    expect(
      api.requests.where((request) => request.path == '/app/user/getUserRole'),
      isEmpty,
    );
  });

  test('referral refresh failures use the complete cached profile', () async {
    for (final failure in <String>['request', 'parse', 'persist']) {
      final api = _Api({
        'GET /app/question/pageErrorQuestion': {'total': 0},
        'GET /app/question/pageCollectQuestion': {'total': 0},
        'GET /app/user/getUserRole': switch (failure) {
          'request' => () => throw StateError('offline'),
          'parse' => const <Object?>[],
          _ => const {'userRole': 'fresh', 'commissionRate': '0.99'},
        },
      });
      final repository = MainTabsRepository(
        api: api,
        stateStore: _Store(_snapshot),
        persistMineReferralProfile:
            ({required userRole, required commissionRate}) async {
              if (failure == 'persist') throw StateError('MMKV unavailable');
            },
      );

      final data = await repository.loadMine();

      expect(
        data.inviteFriendsRequest?.url,
        'https://img.jx885.com/pass-license/html/invite/index.html'
        '?t=cached-token&env=test&userRole=student&commissionRate=0.10',
        reason: failure,
      );
    }
  });
}

final _categoryBody = <String, dynamic>{
  'social-work': [
    {
      'id': 1016,
      'appType': 'social-work',
      'level': '初级社工',
      'children': [
        {'id': 1023, 'name': '社工实务'},
        {'id': 1024, 'name': '综合能力'},
      ],
    },
  ],
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
};

final _snapshot = <String, dynamic>{
  'category': 'social-work',
  'selectedCategoryJson': jsonEncode({
    'id': 1016,
    'appType': 'social-work',
    'level': '初级社工',
  }),
  'selectedCategoryKey': 'social-work_1016',
  'selectedLevel': '初级社工',
  'selectedMarketId': 1023,
  'selectedSubject': '社工实务',
  'staticDefaultCategory': 'social-work&初级社工',
  'appCategoryNameMappingJson': jsonEncode({
    'social-work': '社工',
    'joy-ledger': '会计',
  }),
  'ossDomain': 'https://img.jx885.com/',
  'homeTopBannerJson': jsonEncode({
    'social-work': [
      {'初级社工': 'banner/home.png'},
    ],
  }),
  'examTimeJson': jsonEncode({
    'social-work': [
      {
        '初级社工': [
          {'社工实务': '2026-07-20'},
        ],
      },
    ],
  }),
  'inviteFissionActivity': 1,
  'collectBookH5Url': '  https://example.com/collect-book  ',
  'accessToken': 'cached-token',
  'commissionRate': '0.10',
  'isTestEnvironment': true,
  'isLoggedIn': true,
  'userId': '2038529229062426626',
  'nickname': '考友',
  'phone': '13800138000',
  'avatar': 'https://img.jx885.com/avatar.png',
  'userRole': 'student',
};

final class _Request {
  const _Request({
    required this.method,
    required this.path,
    required this.queryParameters,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, dynamic> queryParameters;
  final Map<String, dynamic>? body;
}

final class _Api implements AppApiClient {
  _Api(this.responses);

  final Map<String, Object?> responses;
  final List<_Request> requests = [];

  @override
  Future<Object?> getBody(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    requests.add(
      _Request(
        method: 'GET',
        path: path,
        queryParameters: queryParameters ?? const {},
        body: null,
      ),
    );
    final response = responses['GET $path'];
    if (response is Object? Function()) return response();
    return response;
  }

  @override
  Future<Object?> postBody(String path, Map<String, dynamic> body) async {
    requests.add(
      _Request(
        method: 'POST',
        path: path,
        queryParameters: const {},
        body: body,
      ),
    );
    return responses['POST $path'];
  }
}

final class _PersistedSelection {
  const _PersistedSelection({
    required this.categoryBodyJson,
    required this.category,
    required this.selectedCategory,
    required this.selectedCategoryKey,
    required this.marketId,
    required this.subject,
  });

  final String categoryBodyJson;
  final String category;
  final Map<String, dynamic> selectedCategory;
  final String selectedCategoryKey;
  final int marketId;
  final String subject;
}

final class _Store implements LegacyAppStateStore {
  _Store(this.snapshot);

  final Map<String, dynamic> snapshot;
  _PersistedSelection? persistedSelection;

  @override
  Future<Map<String, dynamic>> readAppSnapshot() async => snapshot;

  @override
  Future<void> persistCategorySelection({
    required String categoryBodyJson,
    required String category,
    required Map<String, dynamic> selectedCategory,
    required String selectedCategoryKey,
    required int marketId,
    required String subject,
  }) async {
    persistedSelection = _PersistedSelection(
      categoryBodyJson: categoryBodyJson,
      category: category,
      selectedCategory: selectedCategory,
      selectedCategoryKey: selectedCategoryKey,
      marketId: marketId,
      subject: subject,
    );
  }
}
