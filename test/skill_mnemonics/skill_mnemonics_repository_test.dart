import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_repository.dart';
import 'package:ultcpa_flutter/src/storage/legacy_app_state_store.dart';

void main() {
  test('loads the Android flat page-goods request and free count', () async {
    final api = _Api({
      'total': 1,
      'pages': 1,
      'current': 1,
      'size': 200,
      'records': [
        {'skillId': '11', 'text': '口诀', 'questionCount': 5},
      ],
    });
    final repository = SkillMnemonicsRepository(
      api: api,
      stateStore: _Store({'skillFormulaFreeCount': '4'}),
    );

    final catalog = await repository.load(_module);

    expect(api.path, '/app/goods/pageGoodsData');
    expect(api.query, {'pageNum': 1, 'pageSize': 200, 'shelfId': 42});
    expect(catalog.freeCount, 4);
    expect(catalog.records.single.displayText, '口诀');
  });

  test('uses the Android default and clamps negative free counts', () async {
    final missing = SkillMnemonicsRepository(
      api: _Api({'records': const []}),
      stateStore: _Store(const {}),
    );
    final negative = SkillMnemonicsRepository(
      api: _Api({'records': const []}),
      stateStore: _Store({'skillFormulaFreeCount': -2}),
    );

    expect((await missing.load(_module)).freeCount, 3);
    expect((await negative.load(_module)).freeCount, 0);
  });

  test('rejects an invalid module before making a request', () async {
    final api = _Api({'records': const []});
    final repository = SkillMnemonicsRepository(
      api: api,
      stateStore: _Store(const {}),
    );

    await expectLater(
      repository.load(
        const HomeModule(id: 0, name: '技巧口诀', page: '技巧口诀', tag: ''),
      ),
      throwsArgumentError,
    );
    expect(api.calls, 0);
  });

  test(
    'unlocks members from Android user benefits without blocking goods',
    () async {
      final api = _BenefitsApi();
      final repository = SkillMnemonicsRepository(
        api: api,
        stateStore: _Store({
          'skillFormulaFreeCount': 3,
          'isLoggedIn': true,
          'category': 'social-work',
          'selectedLevel': '初级社工',
          'selectedSubject': '社工实务',
        }),
        now: () => DateTime(2026, 7, 16),
      );

      final catalog = await repository.load(_module);

      expect(api.paths, [
        '/app/goods/pageGoodsData',
        '/app/user/getUserBenefits',
      ]);
      expect(catalog.isVip, isTrue);
      expect(catalog.isUnlocked(99), isTrue);
    },
  );

  test(
    'keeps goods available when the optional benefits request fails',
    () async {
      final repository = SkillMnemonicsRepository(
        api: _BenefitsApi(failBenefits: true),
        stateStore: _Store({
          'isLoggedIn': true,
          'category': 'social-work',
          'selectedLevel': '初级社工',
          'selectedSubject': '社工实务',
        }),
      );

      final catalog = await repository.load(_module);

      expect(catalog.records, hasLength(1));
      expect(catalog.isVip, isFalse);
    },
  );
}

const _module = HomeModule(id: 42, name: '技巧口诀', page: '技巧口诀', tag: 'hot');

final class _Api implements AppApiClient {
  _Api(this.response);

  final Object? response;
  int calls = 0;
  String? path;
  Map<String, dynamic>? query;

  @override
  Future<Object?> getBody(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    calls += 1;
    this.path = path;
    query = queryParameters;
    return response;
  }

  @override
  Future<Object?> postBody(String path, Map<String, dynamic> body) {
    throw UnimplementedError();
  }
}

final class _Store implements LegacyAppStateStore {
  _Store(this.snapshot);

  final Map<String, dynamic> snapshot;

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
  }) async {}
}

final class _BenefitsApi implements AppApiClient {
  _BenefitsApi({this.failBenefits = false});

  final bool failBenefits;
  final List<String> paths = [];

  @override
  Future<Object?> getBody(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    paths.add(path);
    if (path == '/app/goods/pageGoodsData') {
      return {
        'records': [
          {'skillId': '11', 'text': '口诀'},
        ],
      };
    }
    if (failBenefits) throw StateError('benefits offline');
    return const [
      {
        'category': 'social-work',
        'benefitsCode': 'SW_MEMBER_L1_3M',
        'expireTime': '2026-12-31 23:59:59',
      },
    ];
  }

  @override
  Future<Object?> postBody(String path, Map<String, dynamic> body) {
    throw UnimplementedError();
  }
}
