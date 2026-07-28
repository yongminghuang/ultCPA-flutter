import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_models.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_repository.dart';
import 'package:ultcpa_flutter/src/storage/legacy_app_state_store.dart';

void main() {
  test('invalid module resolves empty before state or network I/O', () async {
    final api = _Api((_, _) => throw StateError('unexpected GET'));
    final store = _Store(const {});
    final repository = _repository(api: api, store: store);

    final entry = await repository.resolveEntry(
      const HomeModule(id: 0, name: '考前6页纸', page: '考前6页纸', tag: ''),
    );

    expect(entry.destination, PreExamSixPaperEntryDestination.empty);
    expect(store.readCalls, 0);
    expect(api.getRequests, isEmpty);
  });

  test('logged-out users enter landing without benefits I/O', () async {
    final api = _Api((_, _) => throw StateError('unexpected GET'));
    final store = _Store(const {
      'isLoggedIn': false,
      'category': 'social-work',
    });
    final repository = _repository(api: api, store: store);

    final entry = await repository.resolveEntry(_module);

    expect(entry.destination, PreExamSixPaperEntryDestination.landing);
    expect(store.readCalls, 1);
    expect(api.getRequests, isEmpty);
  });

  test('logged-in users without global VIP enter landing', () async {
    final api = _Api((path, query) {
      expect(path, '/app/user/getUserBenefits');
      expect(query, isEmpty);
      return const [];
    });
    final repository = _repository(api: api, store: _Store(_socialSnapshot));

    final entry = await repository.resolveEntry(_module);

    expect(entry.destination, PreExamSixPaperEntryDestination.landing);
    expect(api.getRequests, hasLength(1));
  });

  test('non-social VIP opens preview without probing shelf content', () async {
    final api = _Api((path, query) {
      expect(path, '/app/user/getUserBenefits');
      return const [
        {
          'category': 'joy-ledger',
          'benefitsCode': 'KJ_MEMBER_L1_3M',
          'expireTime': '2026-12-31 23:59:59',
        },
      ];
    });
    final repository = _repository(
      api: api,
      store: _Store(const {
        'isLoggedIn': true,
        'category': 'joy-ledger',
        'selectedLevel': '初级会计',
        'selectedSubject': '经济法基础',
      }),
    );

    final entry = await repository.resolveEntry(_module);

    expect(entry.destination, PreExamSixPaperEntryDestination.preview);
    expect(entry.file, isNull);
    expect(api.getRequests, hasLength(1));
  });

  test('social-work VIP probes and prefills the exact first file', () async {
    final store = _Store({
      ..._socialSnapshot,
      'ossDomain': 'https://cdn.example.com/root/',
    });
    final api = _Api((path, query) {
      if (path == '/app/user/getUserBenefits') return _socialVipBenefits;
      expect(path, '/app/goods/pageGoodsData');
      expect(query, {'pageNum': 1, 'pageSize': 1, 'shelfId': 46});
      return _filePage;
    });
    final repository = _repository(api: api, store: store);

    final entry = await repository.resolveEntry(_module);

    expect(entry.destination, PreExamSixPaperEntryDestination.preview);
    expect(entry.file?.name, '考前重点');
    expect(entry.file?.textUrl, 'https://cdn.example.com/root/preview/a.html');
    expect(entry.file?.fileUrl, 'https://cdn.example.com/root/files/a.pdf');
    expect(entry.file?.htmlBaseUrl, 'https://cdn.example.com/root/');
    expect(store.readCalls, 1);
    expect(api.getRequests, hasLength(2));
  });

  test(
    'social-work VIP maps probe failure or empty content unavailable',
    () async {
      for (final response in <Object?>[
        StateError('offline'),
        const {'records': <Object?>[]},
        const {
          'records': [
            {'type': '题目'},
          ],
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

        final entry = await repository.resolveEntry(_module);

        expect(
          entry.destination,
          PreExamSixPaperEntryDestination.unavailable,
          reason: '$response',
        );
      }
    },
  );

  test('required benefit failure remains retryable', () async {
    final repository = _repository(
      api: _Api((_, _) => throw StateError('benefits offline')),
      store: _Store(_socialSnapshot),
    );

    await expectLater(repository.resolveEntry(_module), throwsStateError);
  });

  test('loads the exact file on demand with fallback OSS origin', () async {
    final api = _Api((path, query) {
      expect(path, '/app/goods/pageGoodsData');
      expect(query, {'pageNum': 1, 'pageSize': 1, 'shelfId': 46});
      return _filePage;
    });
    final repository = _repository(
      api: api,
      store: _Store(const {'ossDomain': 'invalid-domain'}),
    );

    final file = await repository.loadFile(_module);

    expect(file.fileUrl, 'https://file.xmzhujing.com/files/a.pdf');
    expect(file.textUrl, 'https://file.xmzhujing.com/preview/a.html');
    expect(file.htmlBaseUrl, 'https://file.xmzhujing.com/');
    expect(api.getRequests, hasLength(1));
  });

  test('rejects invalid and empty on-demand files', () async {
    final api = _Api((_, _) => const {'records': <Object?>[]});
    final store = _Store(const {});
    final repository = _repository(api: api, store: store);

    await expectLater(
      repository.loadFile(
        const HomeModule(id: 0, name: '考前6页纸', page: '考前6页纸', tag: ''),
      ),
      throwsArgumentError,
    );
    expect(store.readCalls, 0);
    expect(api.getRequests, isEmpty);

    await expectLater(repository.loadFile(_module), throwsFormatException);
  });
}

PreExamSixPaperRepository _repository({
  required AppApiClient api,
  required LegacyAppStateStore store,
}) {
  return PreExamSixPaperRepository(
    api: api,
    stateStore: store,
    now: () => DateTime(2026, 7, 17),
  );
}

const _module = HomeModule(id: 46, name: '考前6页纸', page: '考前6页纸', tag: '');

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

const _filePage = <String, Object?>{
  'records': [
    {
      'type': '文件',
      'name': '考前重点',
      'text': '<p>重点</p>',
      'textUrl': '/preview/a.html',
      'fileUrl': '/files/a.pdf',
    },
  ],
};

final class _Request {
  const _Request(this.path, this.query);

  final String path;
  final Map<String, dynamic> query;
}

final class _Api implements AppApiClient {
  _Api(this.responder);

  final Object? Function(String path, Map<String, dynamic> query) responder;
  final List<_Request> getRequests = [];

  @override
  Future<Object?> getBody(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final query = Map<String, dynamic>.from(queryParameters ?? const {});
    getRequests.add(_Request(path, query));
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
