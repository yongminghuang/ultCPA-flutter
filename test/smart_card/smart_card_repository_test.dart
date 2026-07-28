import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';
import 'package:ultcpa_flutter/src/smart_card/smart_card_models.dart';
import 'package:ultcpa_flutter/src/smart_card/smart_card_repository.dart';
import 'package:ultcpa_flutter/src/storage/legacy_app_state_store.dart';

void main() {
  test('invalid request resolves empty before state or network I/O', () async {
    final api = _Api((_, _) => throw StateError('unexpected GET'));
    final store = _Store(const {});
    final repository = _repository(api: api, store: store);

    final entry = await repository.resolveEntry(
      const SmartCardRequest(
        module: HomeModule(id: 0, name: '技巧卡片', page: '技巧卡片', tag: ''),
      ),
    );

    expect(entry.destination, SmartCardEntryDestination.empty);
    expect(store.readCalls, 0);
    expect(api.requests, isEmpty);
  });

  test('logged-out users open non-VIP cards without network I/O', () async {
    final api = _Api((_, _) => throw StateError('unexpected GET'));
    final repository = _repository(
      api: api,
      store: _Store(const {'isLoggedIn': false, 'category': 'social-work'}),
    );

    final entry = await repository.resolveEntry(_request);

    expect(entry.destination, SmartCardEntryDestination.page);
    expect(entry.isVip, isFalse);
    expect(entry.catalog, isNull);
    expect(api.requests, isEmpty);
  });

  test('logged-in non-VIP resolves benefits without probing goods', () async {
    final api = _Api((path, query) {
      expect(path, '/app/user/getUserBenefits');
      expect(query, isEmpty);
      return const <Object?>[];
    });
    final repository = _repository(api: api, store: _Store(_socialSnapshot));

    final entry = await repository.resolveEntry(_request);

    expect(entry.destination, SmartCardEntryDestination.page);
    expect(entry.isVip, isFalse);
    expect(entry.catalog, isNull);
    expect(api.requests, hasLength(1));
  });

  test('non-social VIP opens directly without probing goods', () async {
    final api = _Api(
      (path, query) => const [
        {
          'category': 'joy-ledger',
          'benefitsCode': 'KJ_MEMBER_L1_3M',
          'expireTime': '2026-12-31 23:59:59',
        },
      ],
    );
    final repository = _repository(
      api: api,
      store: _Store(const {
        'isLoggedIn': true,
        'category': 'joy-ledger',
        'selectedLevel': '初级会计',
        'selectedSubject': '经济法基础',
      }),
    );

    final entry = await repository.resolveEntry(_request);

    expect(entry.destination, SmartCardEntryDestination.page);
    expect(entry.isVip, isTrue);
    expect(entry.catalog, isNull);
    expect(api.requests, hasLength(1));
  });

  test('social-work VIP probes and prefills the exact first page', () async {
    final api = _Api((path, query) {
      if (path == '/app/user/getUserBenefits') return _socialVipBenefits;
      expect(path, '/app/goods/pageGoodsData');
      expect(query, {'pageNum': 1, 'pageSize': 200, 'shelfId': 51});
      return _skillsPage;
    });
    final repository = _repository(api: api, store: _Store(_socialSnapshot));

    final entry = await repository.resolveEntry(_request);

    expect(entry.destination, SmartCardEntryDestination.page);
    expect(entry.isVip, isTrue);
    expect(entry.catalog?.isVip, isTrue);
    expect(entry.catalog?.freeCount, 3);
    expect(entry.catalog?.records.map((item) => item.skillId), ['11', '12']);
    expect(api.requests, hasLength(2));
  });

  test(
    'social-work VIP maps probe failure or invalid content unavailable',
    () async {
      for (final response in <Object?>[
        StateError('offline'),
        const {'records': <Object?>[]},
        const {
          'records': ['invalid'],
        },
      ]) {
        final api = _Api((path, query) {
          if (path == '/app/user/getUserBenefits') return _socialVipBenefits;
          if (response is Error) throw response;
          return response;
        });
        final repository = _repository(
          api: api,
          store: _Store(_socialSnapshot),
        );

        final entry = await repository.resolveEntry(_request);

        expect(
          entry.destination,
          SmartCardEntryDestination.unavailable,
          reason: '$response',
        );
      }
    },
  );

  test('benefit failure remains retryable', () async {
    final repository = _repository(
      api: _Api((_, _) => throw StateError('benefits offline')),
      store: _Store(_socialSnapshot),
    );

    await expectLater(repository.resolveEntry(_request), throwsStateError);
  });

  test('loads exact flat and nested catalogs on demand', () async {
    final api = _Api((path, query) {
      expect(path, '/app/goods/pageGoodsData');
      return _skillsPage;
    });
    final repository = _repository(api: api, store: _Store(const {}));

    final flat = await repository.loadCatalog(_request, isVip: false);
    final nested = await repository.loadCatalog(
      const SmartCardRequest(module: _module, shelfId: 901),
      isVip: true,
    );

    expect(flat.freeCount, 3);
    expect(flat.isVip, isFalse);
    expect(nested.isVip, isTrue);
    expect(api.requests[0].query, {
      'pageNum': 1,
      'pageSize': 200,
      'shelfId': 51,
    });
    expect(api.requests[1].query, {
      'pageNum': 1,
      'pageSize': 200,
      'modelId': 51,
      'shelfId': 901,
    });
  });

  test('rejects invalid on-demand requests before network I/O', () async {
    final api = _Api((_, _) => throw StateError('unexpected GET'));
    final repository = _repository(api: api, store: _Store(const {}));

    await expectLater(
      repository.loadCatalog(
        const SmartCardRequest(module: _module, shelfId: -1),
        isVip: false,
      ),
      throwsArgumentError,
    );
    expect(api.requests, isEmpty);
  });
}

SmartCardRepository _repository({
  required AppApiClient api,
  required LegacyAppStateStore store,
}) {
  return SmartCardRepository(
    api: api,
    stateStore: store,
    now: () => DateTime(2026, 7, 17),
  );
}

const _module = HomeModule(id: 51, name: '技巧卡片', page: '技巧卡片', tag: '');

const _request = SmartCardRequest(module: _module);

const _socialSnapshot = <String, dynamic>{
  'isLoggedIn': true,
  'category': 'social-work',
  'selectedLevel': '初级社工',
  'selectedSubject': '社工实务',
};

const _socialVipBenefits = <Object?>[
  {
    'category': 'social-work',
    'benefitsCode': 'SW_MEMBER_L1_3M',
    'expireTime': '2026-12-31 23:59:59',
  },
];

const _skillsPage = <String, Object?>{
  'records': [
    {'skillId': '11', 'text': '先读题干', 'keyword': '题干', 'note': '找到题干中的关键词'},
    {'skillId': '12', 'name': '再看选项', 'keyword': '选项', 'note': '逐项排除'},
  ],
  'total': 2,
  'pages': 1,
  'current': 1,
  'size': 200,
};

final class _RequestRecord {
  const _RequestRecord(this.path, this.query);

  final String path;
  final Map<String, dynamic> query;
}

final class _Api implements AppApiClient {
  _Api(this.responder);

  final Object? Function(String path, Map<String, dynamic> query) responder;
  final List<_RequestRecord> requests = [];

  @override
  Future<Object?> getBody(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final query = Map<String, dynamic>.from(queryParameters ?? const {});
    requests.add(_RequestRecord(path, query));
    return responder(path, query);
  }

  @override
  Future<Object?> postBody(String path, Map<String, dynamic> body) {
    throw StateError('unexpected POST');
  }
}

final class _Store implements LegacyAppStateStore {
  _Store(this.snapshot);

  final Map<String, dynamic> snapshot;
  int readCalls = 0;

  @override
  Future<Map<String, dynamic>> readAppSnapshot() async {
    readCalls += 1;
    return Map<String, dynamic>.from(snapshot);
  }

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
