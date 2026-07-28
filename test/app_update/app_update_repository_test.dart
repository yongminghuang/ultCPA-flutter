import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/app_update/app_update_models.dart';
import 'package:ultcpa_flutter/src/app_update/app_update_repository.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';
import 'package:ultcpa_flutter/src/storage/legacy_app_state_store.dart';

void main() {
  test(
    'manual check refreshes the throttle then requests exact Android context',
    () async {
      final events = <String>[];
      final api = _Api(const {
        'isUpdatePrompt': true,
        'version': '2.0.0',
        'updateDescription': 'New review mode',
        'isForceUpdates': false,
        'url': 'updates/app.apk',
      }, events: events);
      final repository = AppApiAppUpdateDataSource(
        api: api,
        stateStore: _Store(const {
          'category': 'accounting',
          'appChannel': 'qnm',
          'ossDomain': 'https://cdn.example.com/files',
          'lastProactiveVersionCheckAt': 1999999,
        }),
        nowMillis: () => 2000000,
        persistCheckTimestamp: (millis) async {
          events.add('persist:$millis');
        },
      );

      final result = await repository.checkManual();

      expect(result, isA<AppUpdateAvailable>());
      expect(events, ['persist:2000000', 'request']);
      expect(api.paths, ['/currency/version']);
      final entries = api.queries.single.entries.toList();
      expect(entries.map((entry) => entry.key), [
        'appType',
        'systemType',
        'appVersion',
        'isActive',
        'appChannel',
      ]);
      expect(entries.map((entry) => entry.value), [
        'accounting',
        'Android',
        '1.2.5',
        true,
        'qnm',
      ]);
      final info = (result as AppUpdateAvailable).info;
      expect(info.downloadUrl, 'https://cdn.example.com/files/updates/app.apk');
    },
  );

  test('uses Android category defaults and returns latest', () async {
    final api = _Api(const {'isUpdatePrompt': 0});
    final repository = AppApiAppUpdateDataSource(
      api: api,
      stateStore: _Store(const {}),
      nowMillis: () => 2000000,
      persistCheckTimestamp: (_) async {},
    );

    final result = await repository.checkManual();

    expect(result, isA<AppUpdateLatest>());
    expect(api.queries.single, {
      'appType': 'social-work',
      'systemType': 'Android',
      'appVersion': '1.2.5',
      'isActive': true,
      'appChannel': '',
    });
  });

  test('propagates malformed update responses to the Mine guard', () async {
    final repository = AppApiAppUpdateDataSource(
      api: _Api(const {'version': '2.0.0'}),
      stateStore: _Store(const {}),
      nowMillis: () => 2000000,
      persistCheckTimestamp: (_) async {},
    );

    await expectLater(repository.checkManual(), throwsFormatException);
  });

  test('proactive check skips inside the thirty minute window', () async {
    final api = _Api(const {'isUpdatePrompt': false});
    final persisted = <int>[];
    final repository = AppApiAppUpdateDataSource(
      api: api,
      stateStore: _Store(const {'lastProactiveVersionCheckAt': 200001}),
      nowMillis: () => 2000000,
      persistCheckTimestamp: (millis) async => persisted.add(millis),
    );

    final result = await repository.checkProactive();

    expect(result, isNull);
    expect(persisted, isEmpty);
    expect(api.paths, isEmpty);
  });

  test('proactive check treats a future timestamp as throttled', () async {
    final api = _Api(const {'isUpdatePrompt': false});
    final repository = AppApiAppUpdateDataSource(
      api: api,
      stateStore: _Store(const {'lastProactiveVersionCheckAt': 2000001}),
      nowMillis: () => 2000000,
      persistCheckTimestamp: (_) async {},
    );

    expect(await repository.checkProactive(), isNull);
    expect(api.paths, isEmpty);
  });

  test(
    'proactive check runs on the inclusive boundary with isActive false',
    () async {
      final events = <String>[];
      final api = _Api(const {'isUpdatePrompt': false}, events: events);
      final repository = AppApiAppUpdateDataSource(
        api: api,
        stateStore: _Store(const {
          'category': 'accounting',
          'appChannel': 'qnm',
          'lastProactiveVersionCheckAt': 200000,
        }),
        nowMillis: () => 2000000,
        persistCheckTimestamp: (millis) async {
          events.add('persist:$millis');
        },
      );

      final result = await repository.checkProactive();

      expect(result, isA<AppUpdateLatest>());
      expect(events, ['persist:2000000', 'request']);
      expect(api.queries.single.entries.map((entry) => entry.key), [
        'appType',
        'systemType',
        'appVersion',
        'isActive',
        'appChannel',
      ]);
      expect(api.queries.single, {
        'appType': 'accounting',
        'systemType': 'Android',
        'appVersion': '1.2.5',
        'isActive': false,
        'appChannel': 'qnm',
      });
    },
  );

  for (final last in <Object>[0, -1, '0']) {
    test('proactive check runs for non-positive timestamp $last', () async {
      final persisted = <int>[];
      final api = _Api(const {'isUpdatePrompt': false});
      final repository = AppApiAppUpdateDataSource(
        api: api,
        stateStore: _Store({'lastProactiveVersionCheckAt': last}),
        nowMillis: () => 2000000,
        persistCheckTimestamp: (millis) async => persisted.add(millis),
      );

      expect(await repository.checkProactive(), isA<AppUpdateLatest>());
      expect(persisted, [2000000]);
      expect(api.queries.single['isActive'], isFalse);
    });
  }
}

final class _Api implements AppApiClient {
  _Api(this.response, {this.events});

  final Object? response;
  final List<String>? events;
  final List<String> paths = [];
  final List<Map<String, dynamic>> queries = [];

  @override
  Future<Object?> getBody(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    events?.add('request');
    paths.add(path);
    queries.add(Map<String, dynamic>.from(queryParameters ?? const {}));
    return response;
  }

  @override
  Future<Object?> postBody(String path, Map<String, dynamic> body) {
    throw UnimplementedError();
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
