import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/learning_materials/learning_materials_repository.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';
import 'package:ultcpa_flutter/src/storage/legacy_app_state_store.dart';

void main() {
  test('loads state snapshot, one-level shelf tabs, and exact goods query', () async {
    final api = _Api({
      '/app/shelf/getShelfTree': [
        {
          'id': 100,
          'name': 'root',
          'children': [
            {'id': 101, 'name': '精选'},
            {'id': 102, 'name': '冲刺'},
          ],
        },
      ],
      '/app/goods/pageGoodsData': {
        'total': 2,
        'pages': 2,
        'size': 20,
        'current': 1,
        'records': [
          {'id': 1, 'type': '文档', 'title': '资料'},
          {'id': 2, 'type': '支付卡片', 'isShow': false},
        ],
      },
    });
    final repository = LearningMaterialsRepository(
      api: api,
      stateStore: _Store({
        'selectedCategory': {'level': '中级社工'},
        'ossDomain': 'https://oss.example.com',
        'isLoggedIn': true,
        'isTestEnvironment': false,
      }),
    );

    final snapshot = await repository.readSnapshot();
    final tabs = await repository.loadShelfTabs(moduleId: 88);
    final page = await repository.loadPage(
      moduleId: 88,
      shelfId: 101,
      pageNumber: 1,
    );

    expect(snapshot.libraryTitle, '中级社工资料库');
    expect(tabs.map((tab) => tab.id), [101, 102]);
    expect(page.records.map((item) => item.id), [1, 2]);
    expect(page.hasMore, isTrue);
    expect(api.calls, [
      const _Call('/app/shelf/getShelfTree', {'shelfId': 88}),
      const _Call('/app/goods/pageGoodsData', {
        'pageNum': 1,
        'pageSize': 20,
        'modelId': 88,
        'shelfId': 101,
      }),
    ]);
  });

  test('keeps multiple shelf roots and accepts a custom page size', () async {
    final api = _Api({
      '/app/shelf/getShelfTree': [
        {'id': 1, 'name': 'A'},
        {'id': 2, 'name': 'B'},
      ],
      '/app/goods/pageGoodsData': {
        'records': <Object>[],
        'current': 1,
        'pages': 1,
      },
    });
    final repository = LearningMaterialsRepository(
      api: api,
      stateStore: _Store(const {}),
    );

    expect(
      (await repository.loadShelfTabs(moduleId: 9)).map((tab) => tab.id),
      [1, 2],
    );
    await repository.loadPage(
      moduleId: 9,
      shelfId: 2,
      pageNumber: 3,
      pageSize: 7,
    );

    expect(api.calls.last.query, {
      'pageNum': 3,
      'pageSize': 7,
      'modelId': 9,
      'shelfId': 2,
    });
  });

  test('rejects invalid request identifiers before touching the API', () async {
    final api = _Api(const {});
    final repository = LearningMaterialsRepository(
      api: api,
      stateStore: _Store(const {}),
    );

    await expectLater(
      repository.loadShelfTabs(moduleId: 0),
      throwsArgumentError,
    );
    await expectLater(
      repository.loadPage(moduleId: 1, shelfId: 0),
      throwsArgumentError,
    );
    await expectLater(
      repository.loadPage(moduleId: 1, shelfId: 1, pageNumber: 0),
      throwsArgumentError,
    );
    expect(api.calls, isEmpty);
  });
}

final class _Api implements AppApiClient {
  _Api(this.responses);

  final Map<String, Object?> responses;
  final List<_Call> calls = [];

  @override
  Future<Object?> getBody(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    calls.add(_Call(path, Map.unmodifiable(queryParameters ?? const {})));
    if (!responses.containsKey(path)) throw StateError('unexpected $path');
    return responses[path];
  }

  @override
  Future<Object?> postBody(String path, Map<String, dynamic> body) {
    throw StateError('unexpected POST $path');
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
  }) {
    throw StateError('unexpected persist');
  }
}

final class _Call {
  const _Call(this.path, this.query);

  final String path;
  final Map<String, dynamic> query;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _Call && other.path == path && _mapEquals(other.query, query);
  }

  @override
  int get hashCode => Object.hash(path, Object.hashAllUnordered(query.entries));
}

bool _mapEquals(Map<Object?, Object?> left, Map<Object?, Object?> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
