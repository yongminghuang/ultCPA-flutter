import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/daily_skill/daily_skill_repository.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';
import 'package:ultcpa_flutter/src/storage/legacy_app_state_store.dart';

void main() {
  test(
    'loads the exact detail endpoint and Android fallback image origin',
    () async {
      final api = _Api((path, query) {
        expect(path, '/knowledge/skill/dailySkill');
        expect(query, {'moduleId': 42});
        return const {
          'skillId': '11',
          'text': '看到必须先排除',
          'keyword': '必须',
          'questionCount': 3,
          'shelfId': '',
          'imgUrl': '/daily/a.gif',
        };
      });
      final repository = DailySkillRepository(
        api: api,
        stateStore: _Store(const {'ossDomain': ''}),
      );

      final detail = await repository.loadDetail(_module);

      expect(detail.module, _module);
      expect(detail.skill.skillId, '11');
      expect(detail.effectiveShelfId, 42);
      expect(detail.imageUrl, 'https://file.xmzhujing.com/daily/a.gif');
      expect(api.getRequests, hasLength(1));
    },
  );

  test('uses persisted OSS domain and preserves absolute image URLs', () async {
    Object? response = const {
      'records': [
        {'id': '21', 'name': '分页技巧', 'shelfId': '111', 'imgUrl': 'daily/b.png'},
      ],
    };
    final api = _Api((path, query) => response);
    final repository = DailySkillRepository(
      api: api,
      stateStore: _Store(const {'ossDomain': 'https://cdn.example.com/root/'}),
    );

    final relative = await repository.loadDetail(_module);
    expect(relative.effectiveShelfId, 111);
    expect(relative.imageUrl, 'https://cdn.example.com/root/daily/b.png');

    response = const {
      'skillId': '22',
      'name': '绝对地址',
      'imgUrl': 'https://images.example.com/c.png',
    };
    final absolute = await repository.loadDetail(_module);
    expect(absolute.imageUrl, 'https://images.example.com/c.png');
  });

  test('rejects invalid modules without state or network I/O', () async {
    final api = _Api((path, query) => throw StateError('unexpected GET'));
    final store = _Store(const {}, failRead: true);
    final repository = DailySkillRepository(api: api, stateStore: store);

    await expectLater(
      repository.loadDetail(
        const HomeModule(id: 0, name: '每日一招', page: '每日一招', tag: ''),
      ),
      throwsArgumentError,
    );

    expect(api.getRequests, isEmpty);
    expect(store.readCount, 0);
  });

  test('treats an empty daily payload as invalid data', () async {
    final repository = DailySkillRepository(
      api: _Api((path, query) => const {'records': []}),
      stateStore: _Store(const {}),
    );

    await expectLater(repository.loadDetail(_module), throwsFormatException);
  });

  test(
    'loads related questions by the exact skill id in server order',
    () async {
      final api = _Api((path, query) {
        expect(path, '/app/question/queryQuestionsBySkill');
        expect(query, {'skillId': '11'});
        return const [
          {
            'questionId': '101',
            'title': '题目一',
            'questionType': '单选题',
            'options': {'A': '对', 'B': '错'},
            'answer': 'A',
          },
          {'type': '文件', 'id': 'file-1'},
          {
            'questionId': '102',
            'title': '题目二',
            'questionType': '判断题',
            'options': {'A': '对', 'B': '错'},
            'answer': 'B',
          },
        ];
      });
      final repository = DailySkillRepository(
        api: api,
        stateStore: _Store(const {}),
      );

      final questions = await repository.loadQuestions(' 11 ');

      expect(questions.map((question) => question.id), ['101', '102']);
    },
  );

  test('rejects an empty skill id before network I/O', () async {
    final api = _Api((path, query) => throw StateError('unexpected GET'));
    final repository = DailySkillRepository(
      api: api,
      stateStore: _Store(const {}),
    );

    await expectLater(repository.loadQuestions('  '), throwsArgumentError);
    expect(api.getRequests, isEmpty);
  });
}

const _module = HomeModule(id: 42, name: '每日一招', page: '每日一招', tag: 'hot');

final class _Request {
  const _Request(this.path, this.query);

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
    getRequests.add(_Request(path, query));
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
