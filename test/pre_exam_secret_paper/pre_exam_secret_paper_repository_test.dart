import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';
import 'package:ultcpa_flutter/src/pre_exam_secret_paper/pre_exam_secret_paper_repository.dart';
import 'package:ultcpa_flutter/src/storage/legacy_app_state_store.dart';

void main() {
  test('invalid module returns empty without network or state I/O', () async {
    final api = _Api((path, query) => throw StateError('unexpected API'));
    final store = _Store(const {}, failRead: true);
    final repository = PreExamSecretPaperRepository(
      api: api,
      stateStore: store,
    );
    const module = HomeModule(id: 0, name: '最后密押卷', page: '最后密押卷', tag: '');

    final catalog = await repository.loadCatalog(module);

    expect(catalog.module, same(module));
    expect(catalog.papers, isEmpty);
    expect(catalog.isVip, isFalse);
    expect(api.getRequests, isEmpty);
    expect(store.readCount, 0);
  });

  test('logged-out users load the exact recursive shelf tree', () async {
    final api = _Api((path, query) {
      expect(path, '/app/shelf/getShelfTree');
      expect(query, {'shelfId': 81});
      return _tree;
    });
    final store = _Store(const {'isLoggedIn': false});
    final repository = PreExamSecretPaperRepository(
      api: api,
      stateStore: store,
    );

    final catalog = await repository.loadCatalog(_module);

    expect(catalog.papers.map((paper) => paper.id), [101, 102, 103, 104]);
    expect(catalog.isVip, isFalse);
    expect(store.readCount, 1);
    expect(api.getRequests, hasLength(1));
  });

  test('member prefix grants VIP access', () async {
    final api = _Api((path, query) {
      if (path == '/app/shelf/getShelfTree') return _tree;
      expect(path, '/app/user/getUserBenefits');
      expect(query, isEmpty);
      return const [
        {
          'category': 'social-work',
          'benefitsCode': 'SW_MEMBER_L1_3M',
          'expireTime': '2026-12-31',
        },
      ];
    });
    final repository = PreExamSecretPaperRepository(
      api: api,
      stateStore: _Store(_loggedInSnapshot),
      now: () => DateTime(2026, 7, 17),
    );

    final catalog = await repository.loadCatalog(_module);

    expect(catalog.isVip, isTrue);
    expect(api.getRequests.map((request) => request.path), [
      '/app/shelf/getShelfTree',
      '/app/user/getUserBenefits',
    ]);
  });

  test('the complete answering benefit set grants VIP access', () async {
    final api = _Api((path, query) {
      if (path == '/app/shelf/getShelfTree') return _tree;
      return const [
        {
          'benefitsCode': 'social-work:初级社工:社工实务:practice_skill',
          'expireTime': '2026-12-31',
        },
        {
          'benefitsCode': 'social-work:初级社工:社工实务:practice_speed',
          'expireTime': '2026-12-31',
        },
        {
          'benefitsCode': 'social-work:初级社工:社工实务:past_exams',
          'expireTime': '2026-12-31',
        },
      ];
    });
    final repository = PreExamSecretPaperRepository(
      api: api,
      stateStore: _Store(_loggedInSnapshot),
      now: () => DateTime(2026, 7, 17),
    );

    final catalog = await repository.loadCatalog(_module);

    expect(catalog.isVip, isTrue);
  });

  test('benefit failure keeps papers and degrades to non-member', () async {
    for (final benefits in <Object?>[
      StateError('benefits offline'),
      const {'malformed': true},
      const [
        {
          'benefitsCode': 'social-work:初级社工:社工实务:practice_skill',
          'expireTime': '2026-12-31',
        },
      ],
    ]) {
      final api = _Api((path, query) {
        if (path == '/app/shelf/getShelfTree') return _tree;
        if (benefits is Error) throw benefits;
        return benefits;
      });
      final repository = PreExamSecretPaperRepository(
        api: api,
        stateStore: _Store(_loggedInSnapshot),
        now: () => DateTime(2026, 7, 17),
      );

      final catalog = await repository.loadCatalog(_module);

      expect(catalog.papers, hasLength(4), reason: '$benefits');
      expect(catalog.isVip, isFalse, reason: '$benefits');
    }
  });

  test(
    'tree transport and parse failures propagate before state reads',
    () async {
      final offlineStore = _Store(const {}, failRead: true);
      final offline = PreExamSecretPaperRepository(
        api: _Api((path, query) => throw StateError('tree offline')),
        stateStore: offlineStore,
      );
      await expectLater(offline.loadCatalog(_module), throwsStateError);
      expect(offlineStore.readCount, 0);

      final malformedStore = _Store(const {}, failRead: true);
      final malformed = PreExamSecretPaperRepository(
        api: _Api((path, query) => const {'bad': true}),
        stateStore: malformedStore,
      );
      await expectLater(malformed.loadCatalog(_module), throwsFormatException);
      expect(malformedStore.readCount, 0);
    },
  );
}

const _module = HomeModule(id: 81, name: '最后密押卷', page: '最后密押卷', tag: '');

const _tree = <Object?>[
  {
    'id': 1,
    'name': '目录一',
    'children': [
      {'id': 101, 'name': '密卷一'},
      {'id': 102, 'name': '密卷二'},
    ],
  },
  {
    'id': 2,
    'name': '目录二',
    'children': [
      {
        'id': 3,
        'name': '二级目录',
        'children': [
          {'id': 103, 'name': '密卷三'},
        ],
      },
    ],
  },
  {'id': 104, 'name': '密卷四'},
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
