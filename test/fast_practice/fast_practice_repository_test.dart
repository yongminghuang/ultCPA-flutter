import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/fast_practice/fast_practice_models.dart';
import 'package:ultcpa_flutter/src/fast_practice/fast_practice_repository.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';
import 'package:ultcpa_flutter/src/storage/legacy_app_state_store.dart';

void main() {
  group('fast practice entry access', () {
    test(
      'invalid module resolves empty without state or network I/O',
      () async {
        final api = _Api((path, query) => throw StateError('unexpected I/O'));
        final store = _Store(const {}, failRead: true);
        final repository = FastPracticeRepository(api: api, stateStore: store);
        const invalid = HomeModule(
          id: 0,
          name: '速成300题',
          page: '速成300题',
          tag: '',
        );

        expect(
          await repository.resolveEntry(invalid),
          FastPracticeEntryDestination.empty,
        );
        expect((await repository.loadCatalog(invalid)).leaves, isEmpty);
        expect(store.readCount, 0);
        expect(api.getRequests, isEmpty);
      },
    );

    test(
      'logged-out selection enters landing without requesting benefits',
      () async {
        final api = _Api((path, query) => throw StateError('unexpected I/O'));
        final repository = FastPracticeRepository(
          api: api,
          stateStore: _Store(const {'isLoggedIn': false}),
        );

        expect(
          await repository.resolveEntry(_module),
          FastPracticeEntryDestination.landing,
        );
        expect(api.getRequests, isEmpty);
      },
    );

    test('matching speed benefit enters catalog with exact request', () async {
      final api = _Api((path, query) {
        expect(path, '/app/user/getUserBenefits');
        expect(query, isEmpty);
        return const [
          {
            'benefitsCode': 'social-work:初级社工:社工实务:practice_speed',
            'expireTime': '2026-12-31',
          },
        ];
      });
      final repository = FastPracticeRepository(
        api: api,
        stateStore: _Store(_loggedInSnapshot),
        now: () => DateTime(2026, 7, 16),
      );

      expect(
        await repository.resolveEntry(_module),
        FastPracticeEntryDestination.catalog,
      );
      expect(api.getRequests.single.path, '/app/user/getUserBenefits');
    });

    test('benefit failure and mismatched benefit both enter landing', () async {
      final offline = FastPracticeRepository(
        api: _Api((path, query) => throw StateError('benefits offline')),
        stateStore: _Store(_loggedInSnapshot),
      );
      expect(
        await offline.resolveEntry(_module),
        FastPracticeEntryDestination.landing,
      );

      final mismatched = FastPracticeRepository(
        api: _Api(
          (path, query) => const [
            {
              'benefitsCode': 'social-work:中级社工:社工实务:practice_speed',
              'expireTime': '2026-12-31',
            },
          ],
        ),
        stateStore: _Store(_loggedInSnapshot),
        now: () => DateTime(2026, 7, 16),
      );
      expect(
        await mismatched.resolveEntry(_module),
        FastPracticeEntryDestination.landing,
      );
    });
  });

  group('fast practice leaf catalog', () {
    test('loads the exact tree request and recursive server order', () async {
      final api = _Api((path, query) {
        expect(path, '/app/shelf/getShelfTree');
        expect(query, {'shelfId': 42});
        return const [
          {
            'id': 100,
            'name': '目录',
            'children': [
              {'id': 111, 'name': '精选一', 'type': '扁平化'},
              {
                'id': 120,
                'name': '二级',
                'children': [
                  {'id': 121, 'name': '精选二', 'type': '信息化'},
                ],
              },
            ],
          },
        ];
      });
      final repository = FastPracticeRepository(
        api: api,
        stateStore: _Store(const {}),
      );

      final catalog = await repository.loadCatalog(_module);

      expect(catalog.module.id, 42);
      expect(catalog.leaves.map((leaf) => leaf.id), [111, 121]);
      expect(catalog.leaves.map((leaf) => leaf.name), ['精选一', '精选二']);
      expect(api.getRequests, hasLength(1));
    });

    test('keeps a valid empty tree as an empty catalog', () async {
      final repository = FastPracticeRepository(
        api: _Api((path, query) => const <Object?>[]),
        stateStore: _Store(const {}),
      );

      expect((await repository.loadCatalog(_module)).leaves, isEmpty);
    });

    test(
      'propagates tree transport and parse failures for page retry',
      () async {
        final offline = FastPracticeRepository(
          api: _Api((path, query) => throw StateError('tree offline')),
          stateStore: _Store(const {}),
        );
        await expectLater(offline.loadCatalog(_module), throwsStateError);

        final malformed = FastPracticeRepository(
          api: _Api((path, query) => const {'bad': true}),
          stateStore: _Store(const {}),
        );
        await expectLater(
          malformed.loadCatalog(_module),
          throwsFormatException,
        );
      },
    );
  });
}

const _module = HomeModule(id: 42, name: '速成300题', page: '速成300题', tag: 'hot');

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
  Future<Object?> postBody(String path, Map<String, dynamic> body) async {
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
