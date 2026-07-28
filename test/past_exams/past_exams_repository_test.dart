import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';
import 'package:ultcpa_flutter/src/past_exams/past_exams_repository.dart';
import 'package:ultcpa_flutter/src/storage/legacy_app_state_store.dart';

void main() {
  test('invalid or unsupported modules return empty without any I/O', () async {
    final api = _Api((path, query) => throw StateError('unexpected API'));
    final store = _Store(const {}, failRead: true);
    final repository = PastExamsRepository(api: api, stateStore: store);
    const invalid = HomeModule(
      id: 0,
      name: '历年真题卷',
      page: '历年真题卷',
      tag: '',
      type: '嵌套化',
    );
    const unsupported = HomeModule(
      id: 52,
      name: '历年真题卷',
      page: '历年真题卷',
      tag: '',
      type: '扁平化',
    );

    for (final module in [invalid, unsupported]) {
      final catalog = await repository.loadCatalog(module);
      expect(catalog.module, same(module));
      expect(catalog.papers, isEmpty);
      expect(catalog.hasFullAccess, isFalse);
    }
    expect(store.readCount, 0);
    expect(api.getRequests, isEmpty);
  });

  test(
    'logged-out users load the exact tree and keep two free papers',
    () async {
      final api = _Api((path, query) {
        expect(path, '/app/shelf/getShelfTree');
        expect(query, {'shelfId': 51});
        return _tree;
      });
      final store = _Store(const {'isLoggedIn': false});
      final repository = PastExamsRepository(api: api, stateStore: store);

      final catalog = await repository.loadCatalog(_module);

      expect(catalog.hasFullAccess, isFalse);
      expect(catalog.papers.map((paper) => paper.id), [11, 12, 13]);
      expect(catalog.papers.map((paper) => paper.locked), [false, false, true]);
      expect(store.readCount, 1);
      expect(api.getRequests, hasLength(1));
    },
  );

  test('matching past-exams access unlocks every paper', () async {
    final api = _Api((path, query) {
      if (path == '/app/shelf/getShelfTree') {
        expect(query, {'shelfId': 51});
        return _tree;
      }
      expect(path, '/app/user/getUserBenefits');
      expect(query, isEmpty);
      return const [
        {
          'benefitsCode': 'social-work:初级社工:社工实务:past_exams',
          'expireTime': '2026-12-31',
        },
      ];
    });
    final repository = PastExamsRepository(
      api: api,
      stateStore: _Store(_loggedInSnapshot),
      now: () => DateTime(2026, 7, 17),
    );

    final catalog = await repository.loadCatalog(_module);

    expect(catalog.hasFullAccess, isTrue);
    expect(catalog.papers.every((paper) => !paper.locked), isTrue);
    expect(api.getRequests.map((request) => request.path), [
      '/app/shelf/getShelfTree',
      '/app/user/getUserBenefits',
    ]);
  });

  test(
    'benefit failure keeps the catalog and degrades to two free papers',
    () async {
      for (final benefits in <Object?>[
        StateError('benefits offline'),
        const {'bad': true},
      ]) {
        final api = _Api((path, query) {
          if (path == '/app/shelf/getShelfTree') return _tree;
          if (benefits is Error) throw benefits;
          return benefits;
        });
        final repository = PastExamsRepository(
          api: api,
          stateStore: _Store(_loggedInSnapshot),
        );

        final catalog = await repository.loadCatalog(_module);

        expect(catalog.hasFullAccess, isFalse, reason: '$benefits');
        expect(catalog.papers.map((paper) => paper.locked), [
          false,
          false,
          true,
        ], reason: '$benefits');
      }
    },
  );

  test(
    'tree transport and parse failures propagate before state reads',
    () async {
      final offlineStore = _Store(const {}, failRead: true);
      final offline = PastExamsRepository(
        api: _Api((path, query) => throw StateError('tree offline')),
        stateStore: offlineStore,
      );
      await expectLater(offline.loadCatalog(_module), throwsStateError);
      expect(offlineStore.readCount, 0);

      final malformedStore = _Store(const {}, failRead: true);
      final malformed = PastExamsRepository(
        api: _Api((path, query) => const {'bad': true}),
        stateStore: malformedStore,
      );
      await expectLater(malformed.loadCatalog(_module), throwsFormatException);
      expect(malformedStore.readCount, 0);
    },
  );

  test('valid empty tree returns a stable empty catalog', () async {
    final repository = PastExamsRepository(
      api: _Api((path, query) => const <Object?>[]),
      stateStore: _Store(const {'isLoggedIn': false}),
    );

    final catalog = await repository.loadCatalog(_module);

    expect(catalog.papers, isEmpty);
    expect(catalog.hasFullAccess, isFalse);
  });
}

const _module = HomeModule(
  id: 51,
  name: '历年真题卷',
  page: '历年真题卷',
  tag: '',
  type: '嵌套化',
);

const _tree = <Object?>[
  {'id': 11, 'name': '真题一', 'type': '扁平化'},
  {'id': 12, 'name': '真题二', 'type': '扁平化'},
  {'id': 13, 'name': '真题三', 'type': '扁平化'},
];

const _loggedInSnapshot = <String, dynamic>{
  'isLoggedIn': true,
  'category': 'social-work',
  'selectedLevel': '初级社工',
  'selectedSubject': '社工实务',
};

final class _Request {
  const _Request({required this.path, required this.query});

  final String path;
  final Map<String, dynamic> query;
}

typedef _Responder = Object? Function(String path, Map<String, dynamic> query);

final class _Api implements AppApiClient {
  _Api(this.responder);

  final _Responder responder;
  final List<_Request> getRequests = [];

  @override
  Future<Object?> getBody(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final query = queryParameters ?? const <String, dynamic>{};
    getRequests.add(_Request(path: path, query: query));
    return responder(path, query);
  }

  @override
  Future<Object?> postBody(String path, Map<String, dynamic> body) {
    throw StateError('unexpected POST $path');
  }
}

final class _Store implements LegacyAppStateStore {
  _Store(this.snapshot, {this.failRead = false});

  final Map<String, dynamic> snapshot;
  final bool failRead;
  int readCount = 0;

  @override
  Future<Map<String, dynamic>> readAppSnapshot() async {
    readCount += 1;
    if (failRead) throw StateError('unexpected state read');
    return snapshot;
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
