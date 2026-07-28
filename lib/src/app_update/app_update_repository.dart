import '../config/app_identity.dart';
import '../network/app_api_client.dart';
import '../storage/legacy_app_state_store.dart';
import 'app_update_models.dart';

abstract interface class AppUpdateDataSource {
  Future<AppUpdateCheckResult> checkManual();

  Future<AppUpdateCheckResult?> checkProactive();
}

final class AppApiAppUpdateDataSource implements AppUpdateDataSource {
  AppApiAppUpdateDataSource({
    required AppApiClient api,
    required LegacyAppStateStore stateStore,
    required Future<void> Function(int millis) persistCheckTimestamp,
    int Function()? nowMillis,
  }) : _api = api,
       _stateStore = stateStore,
       _persistCheckTimestamp = persistCheckTimestamp,
       _nowMillis = nowMillis ?? _systemNowMillis;

  static const proactiveCheckIntervalMillis = 30 * 60 * 1000;

  final AppApiClient _api;
  final LegacyAppStateStore _stateStore;
  final Future<void> Function(int millis) _persistCheckTimestamp;
  final int Function() _nowMillis;

  @override
  Future<AppUpdateCheckResult> checkManual() async {
    await _persistCheckTimestamp(_nowMillis());
    final snapshot = await _stateStore.readAppSnapshot();
    return _request(snapshot, isActive: true);
  }

  @override
  Future<AppUpdateCheckResult?> checkProactive() async {
    final snapshot = await _stateStore.readAppSnapshot();
    final now = _nowMillis();
    final last = _integer(snapshot['lastProactiveVersionCheckAt']);
    if (last > 0 && now - last < proactiveCheckIntervalMillis) return null;
    await _persistCheckTimestamp(now);
    return _request(snapshot, isActive: false);
  }

  Future<AppUpdateCheckResult> _request(
    Map<String, dynamic> snapshot, {
    required bool isActive,
  }) async {
    final body = await _api.getBody(
      '/currency/version',
      queryParameters: <String, dynamic>{
        'appType': _text(snapshot['category'], 'social-work'),
        'systemType': 'Android',
        'appVersion': AppIdentity.versionName,
        'isActive': isActive,
        'appChannel': _text(snapshot['appChannel']),
      },
    );
    return parseAppUpdateCheckBody(
      body,
      ossDomain: _text(snapshot['ossDomain']),
    );
  }
}

int _systemNowMillis() => DateTime.now().millisecondsSinceEpoch;

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _text(Object? value, [String fallback = '']) {
  final text = value?.toString() ?? '';
  return text.isEmpty ? fallback : text;
}
