import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/exam/exam_models.dart';
import 'package:ultcpa_flutter/src/exam/exam_repository.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';
import 'package:ultcpa_flutter/src/practice/practice_models.dart';
import 'package:ultcpa_flutter/src/storage/legacy_app_state_store.dart';

void main() {
  test('loads the exact first page and keeps only question records', () async {
    final api = _Api(
      getResponder: (path, query) {
        expect(path, '/app/goods/pageGoodsData');
        expect(query, {
          'pageNum': 1,
          'pageSize': 120,
          'modelId': 51,
          'shelfId': 901,
        });
        return const {
          'records': [
            {
              'type': '题目',
              'questionId': '101',
              'title': '真题一',
              'questionType': '单选题',
              'options': {'A': '对', 'B': '错'},
              'answer': 'A',
            },
            {'type': '大招', 'skillId': 's1', 'text': '技巧'},
            {'type': '文件', 'name': '附件'},
          ],
          'total': 3,
          'pages': 1,
          'current': 1,
          'size': 120,
        };
      },
    );
    final repository = ExamRepository(
      api: api,
      stateStore: _Store(const {}, failRead: true),
    );

    final catalog = await repository.load(_request);

    expect(catalog.request, same(_request));
    expect(catalog.questions, hasLength(1));
    expect(catalog.questions.single.id, '101');
    expect(api.getRequests, hasLength(1));
    expect(api.postRequests, isEmpty);
  });

  test('loads the cached current member tier into the exam catalog', () async {
    final api = _Api(getResponder: (path, query) => _examPageBody);
    final store = _Store({
      'category': 'social-work',
      'selectedLevel': '初级社工',
      'userBenefitsJson': jsonEncode(const [
        {
          'category': 'social-work',
          'benefitsCode': 'SW_MEMBER_L1_3M',
          'expireTime': '4102444800000',
        },
      ]),
    });
    final repository = ExamRepository(api: api, stateStore: store);

    final catalog = await repository.load(_request);

    expect(catalog.hasMemberTier, isTrue);
    expect(store.readCount, 1);
    expect(api.getRequests, hasLength(1));
  });

  test('does not hide prediction for a scoped past-exams benefit', () async {
    final repository = ExamRepository(
      api: _Api(getResponder: (path, query) => _examPageBody),
      stateStore: _Store({
        'category': 'social-work',
        'selectedLevel': '初级社工',
        'userBenefitsJson': jsonEncode(const [
          {
            'category': 'social-work',
            'benefitsCode': 'SW_PRACTICE_PAST_EXAMS_L1_3M',
            'expireTime': '4102444800000',
          },
        ]),
      }),
    );

    expect((await repository.load(_request)).hasMemberTier, isFalse);
  });

  test('invalid request is rejected before API or state I/O', () async {
    final api = _Api(
      getResponder: (path, query) => throw StateError('unexpected GET'),
    );
    final store = _Store(const {}, failRead: true);
    final repository = ExamRepository(api: api, stateStore: store);
    final invalid = ExamRequest(module: _module, shelfId: 0, title: '真题一');

    await expectLater(repository.load(invalid), throwsArgumentError);
    expect(api.getRequests, isEmpty);
    expect(store.readCount, 0);
  });

  test('empty and malformed page bodies remain distinct', () async {
    final empty = ExamRepository(
      api: _Api(
        getResponder: (path, query) => const {
          'records': <Object?>[],
          'total': 0,
          'pages': 1,
          'current': 1,
          'size': 120,
        },
      ),
      stateStore: _Store(const {}, failRead: true),
    );
    expect((await empty.load(_request)).questions, isEmpty);

    final malformed = ExamRepository(
      api: _Api(getResponder: (path, query) => const {'records': 'bad'}),
      stateStore: _Store(const {}, failRead: true),
    );
    await expectLater(malformed.load(_request), throwsFormatException);
  });

  test(
    'submits answered valid IDs with the exact Android batch payload',
    () async {
      final api = _Api(
        getResponder: (path, query) => throw StateError('unexpected GET'),
        postResponder: (path, body) {
          expect(path, '/app/question/saveQuestionRecordBatch');
          expect(body, {
            'subject': '社工实务',
            'level': '初级社工',
            'questionList': [
              {'questionId': 101, 'choose': 'AC', 'isRight': 1},
              {'questionId': 102, 'choose': 'B', 'isRight': 0},
            ],
          });
          return const {'saved': true};
        },
      );
      final store = _Store(const {
        'selectedSubject': '社工实务',
        'selectedLevel': '初级社工',
      });
      final repository = ExamRepository(api: api, stateStore: store);
      final questions = [
        _question('101', answer: 'AC'),
        _question('102', answer: 'A'),
        _question('bad-id', answer: 'A'),
        _question('103', answer: 'A'),
      ];
      final result = ExamResult(
        request: _request,
        questions: questions,
        selections: const {'101': 'CA', '102': 'B', 'bad-id': 'A'},
        elapsed: const Duration(minutes: 4),
      );

      await repository.submit(result);

      expect(store.readCount, 1);
      expect(api.postRequests, hasLength(1));
    },
  );

  test('zero valid answered IDs skip state and POST I/O', () async {
    final api = _Api(
      getResponder: (path, query) => throw StateError('unexpected GET'),
      postResponder: (path, body) => throw StateError('unexpected POST'),
    );
    final store = _Store(const {}, failRead: true);
    final repository = ExamRepository(api: api, stateStore: store);
    final result = ExamResult(
      request: _request,
      questions: [_question('bad-id', answer: 'A')],
      selections: const {'bad-id': 'A'},
      elapsed: Duration.zero,
    );

    await repository.submit(result);

    expect(store.readCount, 0);
    expect(api.postRequests, isEmpty);
  });

  test(
    'batch transport failure propagates to the exam page boundary',
    () async {
      final repository = ExamRepository(
        api: _Api(
          getResponder: (path, query) => throw StateError('unexpected GET'),
          postResponder: (path, body) => throw StateError('submit offline'),
        ),
        stateStore: _Store(const {
          'selectedSubject': '社工实务',
          'selectedLevel': '初级社工',
        }),
      );
      final result = ExamResult(
        request: _request,
        questions: [_question('101', answer: 'A')],
        selections: const {'101': 'A'},
        elapsed: Duration.zero,
      );

      await expectLater(repository.submit(result), throwsStateError);
    },
  );
}

const _examPageBody = {
  'records': [
    {
      'type': '题目',
      'questionId': '101',
      'title': '真题一',
      'questionType': '单选题',
      'options': {'A': '对', 'B': '错'},
      'answer': 'A',
    },
  ],
  'total': 1,
  'pages': 1,
  'current': 1,
  'size': 120,
};

const _request = ExamRequest(module: _module, shelfId: 901, title: '真题一');

const _module = HomeModule(
  id: 51,
  name: '历年真题卷',
  page: '历年真题卷',
  tag: '',
  type: '嵌套化',
);

PracticeQuestion _question(String id, {required String answer}) {
  return PracticeQuestion.fromMap({
    'type': '题目',
    'questionId': id,
    'title': '题目 $id',
    'questionType': answer.length > 1 ? '多选题' : '单选题',
    'options': {'A': '选项 A', 'B': '选项 B', 'C': '选项 C'},
    'answer': answer,
  });
}

final class _GetRequest {
  const _GetRequest({required this.path, required this.query});

  final String path;
  final Map<String, dynamic> query;
}

final class _PostRequest {
  const _PostRequest({required this.path, required this.body});

  final String path;
  final Map<String, dynamic> body;
}

typedef _GetResponder =
    Object? Function(String path, Map<String, dynamic> query);
typedef _PostResponder =
    Object? Function(String path, Map<String, dynamic> body);

final class _Api implements AppApiClient {
  _Api({required this.getResponder, this.postResponder});

  final _GetResponder getResponder;
  final _PostResponder? postResponder;
  final List<_GetRequest> getRequests = [];
  final List<_PostRequest> postRequests = [];

  @override
  Future<Object?> getBody(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final query = queryParameters ?? const <String, dynamic>{};
    getRequests.add(_GetRequest(path: path, query: query));
    return getResponder(path, query);
  }

  @override
  Future<Object?> postBody(String path, Map<String, dynamic> body) async {
    postRequests.add(_PostRequest(path: path, body: body));
    final responder = postResponder;
    if (responder == null) throw StateError('unexpected POST $path');
    return responder(path, body);
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
