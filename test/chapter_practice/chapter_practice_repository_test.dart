import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/chapter_practice/chapter_practice_repository.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';
import 'package:ultcpa_flutter/src/storage/legacy_app_state_store.dart';

void main() {
  group('chapter catalog requests', () {
    test(
      'loads tree, records, benefits, progress, and snapshot preview',
      () async {
        final api = _Api(
          getResponder: (path, query) {
            if (path == '/app/shelf/getShelfTree') return _threeGroupTree;
            if (path == '/app/user/getUserBenefits') {
              return const <Object?>[];
            }
            throw StateError('unexpected GET $path');
          },
          postResponder: (path, body) {
            expect(path, '/app/question/getQuestionRecordList');
            return const [
              {
                'shelfId': 11,
                'questionRecordResponseList': [
                  {'questionId': 101, 'choose': 'A', 'isRight': 1},
                  {'questionId': 102, 'choose': ''},
                ],
              },
            ];
          },
        );
        final repository = ChapterPracticeRepository(
          api: api,
          stateStore: _Store({..._snapshot, 'chapterQuestionFreeCount': '1'}),
          now: () => DateTime(2026, 7, 16),
        );

        final catalog = await repository.load(_module);

        expect(api.getRequests.first.path, '/app/shelf/getShelfTree');
        expect(api.getRequests.first.query, {'shelfId': 42});
        expect(
          api.postRequests.single.path,
          '/app/question/getQuestionRecordList',
        );
        expect(api.postRequests.single.body, {
          'modelId': 42,
          'shelfIdList': [11, 21, 31],
        });
        expect(api.getRequests.last.path, '/app/user/getUserBenefits');
        expect(catalog.previewGroupCount, 1);
        expect(catalog.fullAccess, isFalse);
        expect(catalog.groups.map((group) => group.unlocked), [
          true,
          false,
          false,
        ]);
        expect(catalog.groups.first.chapters.single.doneCount, 1);
        expect(catalog.groups.first.chapters.single.totalCount, 2);
      },
    );

    test('chunks 2000 shelf ids and continues after a failed chunk', () async {
      final leaves = List.generate(
        2001,
        (index) => <String, Object?>{
          'id': index + 1,
          'name': '章节 ${index + 1}',
        },
      );
      var postCount = 0;
      final api = _Api(
        getResponder: (path, query) {
          if (path == '/app/shelf/getShelfTree') {
            return [
              {'id': 9000, 'name': '目录', 'children': leaves},
            ];
          }
          throw StateError('unexpected GET $path');
        },
        postResponder: (path, body) {
          postCount += 1;
          if (postCount == 1) throw StateError('first chunk offline');
          return const [
            {
              'shelfId': 2001,
              'questionRecordResponseList': [
                {'questionId': 88, 'choose': 'B', 'isRight': 0},
              ],
            },
          ];
        },
      );
      final repository = ChapterPracticeRepository(
        api: api,
        stateStore: _Store(const {'isLoggedIn': false}),
      );

      final catalog = await repository.load(_module);

      expect(api.postRequests, hasLength(2));
      expect(
        api.postRequests.first.body!['shelfIdList'] as List<dynamic>,
        hasLength(2000),
      );
      expect(api.postRequests.last.body, {
        'modelId': 42,
        'shelfIdList': [2001],
      });
      expect(catalog.groups.single.chapters.last.doneCount, 1);
    });

    test('ignores malformed record chunks and benefit failures', () async {
      final api = _Api(
        getResponder: (path, query) {
          if (path == '/app/shelf/getShelfTree') return _threeGroupTree;
          throw StateError('benefits offline');
        },
        postResponder: (path, body) => const {'malformed': true},
      );
      final repository = ChapterPracticeRepository(
        api: api,
        stateStore: _Store(_snapshot),
      );

      final catalog = await repository.load(_module);

      expect(catalog.groups, hasLength(3));
      expect(catalog.previewGroupCount, 2);
      expect(catalog.fullAccess, isFalse);
      expect(catalog.groups.map((group) => group.unlocked), [
        true,
        true,
        false,
      ]);
      expect(catalog.groups.first.chapters.single.doneCount, 0);
    });

    test('unlocks every group with a matching chapter benefit', () async {
      final api = _Api(
        getResponder: (path, query) {
          if (path == '/app/shelf/getShelfTree') return _threeGroupTree;
          return const [
            {
              'benefitsCode': 'social-work:初级社工:社工实务:practice_chapter',
              'expireTime': '2026-12-31',
            },
          ];
        },
        postResponder: (path, body) => const <Object?>[],
      );
      final repository = ChapterPracticeRepository(
        api: api,
        stateStore: _Store({..._snapshot, 'chapterQuestionFreeCount': 0}),
        now: () => DateTime(2026, 7, 16),
      );

      final catalog = await repository.load(_module);

      expect(catalog.fullAccess, isTrue);
      expect(catalog.groups.every((group) => group.unlocked), isTrue);
    });
  });

  group('chapter catalog failures and empty state', () {
    test('returns empty without I/O for invalid module contracts', () async {
      final api = _Api(
        getResponder: (path, query) => throw StateError('unexpected I/O'),
        postResponder: (path, body) => throw StateError('unexpected I/O'),
      );
      final repository = ChapterPracticeRepository(
        api: api,
        stateStore: _Store(const {}),
      );

      for (final module in [
        const HomeModule(
          id: 0,
          name: '章节练习',
          page: '章节练习',
          tag: '',
          type: '结构化',
        ),
        const HomeModule(
          id: 42,
          name: '章节练习',
          page: '章节练习',
          tag: '',
          type: '扁平化',
        ),
      ]) {
        expect((await repository.load(module)).groups, isEmpty);
      }
      expect(api.getRequests, isEmpty);
      expect(api.postRequests, isEmpty);
    });

    test('keeps an empty tree as an empty catalog', () async {
      final api = _Api(
        getResponder: (path, query) => const <Object?>[],
        postResponder: (path, body) => throw StateError('unexpected POST'),
      );
      final repository = ChapterPracticeRepository(
        api: api,
        stateStore: _Store(const {}),
      );

      final catalog = await repository.load(_module);

      expect(catalog.groups, isEmpty);
      expect(api.getRequests, hasLength(1));
      expect(api.postRequests, isEmpty);
    });

    test('propagates tree transport and parse failures', () async {
      final offline = ChapterPracticeRepository(
        api: _Api(
          getResponder: (path, query) => throw StateError('tree offline'),
          postResponder: (path, body) => null,
        ),
        stateStore: _Store(const {}),
      );
      await expectLater(offline.load(_module), throwsStateError);

      final malformed = ChapterPracticeRepository(
        api: _Api(
          getResponder: (path, query) => const {'not': 'a list'},
          postResponder: (path, body) => null,
        ),
        stateStore: _Store(const {}),
      );
      await expectLater(malformed.load(_module), throwsFormatException);
    });
  });
}

const _module = HomeModule(
  id: 42,
  name: '章节练习',
  page: '章节练习',
  tag: '',
  type: '结构化',
);

const _threeGroupTree = <Object?>[
  {'id': 11, 'name': '第一组', 'goodsCount': 2},
  {'id': 21, 'name': '第二组', 'goodsCount': 1},
  {'id': 31, 'name': '第三组', 'goodsCount': 1},
];

const _snapshot = <String, dynamic>{
  'isLoggedIn': true,
  'category': 'social-work',
  'selectedLevel': '初级社工',
  'selectedSubject': '社工实务',
};

final class _Request {
  const _Request({required this.path, this.query, this.body});

  final String path;
  final Map<String, dynamic>? query;
  final Map<String, dynamic>? body;
}

typedef _GetResponder =
    Object? Function(String path, Map<String, dynamic> query);
typedef _PostResponder =
    Object? Function(String path, Map<String, dynamic> body);

final class _Api implements AppApiClient {
  _Api({required this.getResponder, required this.postResponder});

  final _GetResponder getResponder;
  final _PostResponder postResponder;
  final List<_Request> getRequests = [];
  final List<_Request> postRequests = [];

  @override
  Future<Object?> getBody(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final query = queryParameters ?? const <String, dynamic>{};
    getRequests.add(_Request(path: path, query: query));
    return getResponder(path, query);
  }

  @override
  Future<Object?> postBody(String path, Map<String, dynamic> body) async {
    postRequests.add(_Request(path: path, body: body));
    return postResponder(path, body);
  }
}

final class _Store implements LegacyAppStateStore {
  const _Store(this.snapshot);

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
