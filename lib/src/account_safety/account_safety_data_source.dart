import 'package:flutter/services.dart';

import 'account_deactivation_gateway.dart';
import 'account_safety_models.dart';

abstract interface class AccountSafetyDataSource {
  Future<AccountSafetySnapshot> load();

  Future<void> deactivateAccount();
}

abstract interface class AccountSafetyNativeStore {
  Future<AccountSafetySnapshot> load();

  Future<void> clearDeactivatedSession();
}

final class MethodChannelAccountSafetyNativeStore
    implements AccountSafetyNativeStore {
  MethodChannelAccountSafetyNativeStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.xmzj.ult.agg/account_safety';

  final MethodChannel _channel;

  @override
  Future<AccountSafetySnapshot> load() async {
    final values = await _channel.invokeMapMethod<String, dynamic>(
      'readAccountSafety',
    );
    final isLoggedIn = values?['isLoggedIn'];
    final phone = values?['phone'];
    if (isLoggedIn is! bool || phone is! String) {
      throw const FormatException('原生账号安全快照字段无效');
    }
    return AccountSafetySnapshot(isLoggedIn: isLoggedIn, phone: phone);
  }

  @override
  Future<void> clearDeactivatedSession() {
    return _channel.invokeMethod<void>('clearDeactivatedSession');
  }
}

typedef DeviceSessionRefresh = Future<void> Function();

final class AccountSafetyRepository implements AccountSafetyDataSource {
  AccountSafetyRepository({
    required AccountDeactivationGateway remote,
    required AccountSafetyNativeStore nativeStore,
    required DeviceSessionRefresh refreshDeviceSession,
  }) : _remote = remote,
       _nativeStore = nativeStore,
       _refreshDeviceSession = refreshDeviceSession;

  final AccountDeactivationGateway _remote;
  final AccountSafetyNativeStore _nativeStore;
  final DeviceSessionRefresh _refreshDeviceSession;

  @override
  Future<AccountSafetySnapshot> load() => _nativeStore.load();

  @override
  Future<void> deactivateAccount() async {
    await _remote.deactivate();
    await _nativeStore.clearDeactivatedSession();
    try {
      await _refreshDeviceSession();
    } catch (_) {
      // Android also treats anonymous device-session recovery as best effort.
    }
  }
}
