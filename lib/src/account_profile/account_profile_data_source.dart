import 'package:flutter/services.dart';

import 'account_profile_models.dart';
import 'account_sign_out_gateway.dart';

abstract interface class AccountProfileDataSource {
  Future<AccountProfileSnapshot> load();

  Future<void> signOut();
}

abstract interface class AccountProfileNativeStore {
  Future<AccountProfileSnapshot> load();

  Future<void> clearSignedOutSession();
}

final class MethodChannelAccountProfileNativeStore
    implements AccountProfileNativeStore {
  MethodChannelAccountProfileNativeStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.xmzj.ult.agg/account_safety';

  final MethodChannel _channel;

  @override
  Future<AccountProfileSnapshot> load() async {
    final values = await _channel.invokeMapMethod<String, dynamic>(
      'readAccountProfile',
    );
    final isLoggedIn = values?['isLoggedIn'];
    final userId = values?['userId'];
    final nickname = values?['nickname'];
    final avatar = values?['avatar'];
    if (isLoggedIn is! bool ||
        userId is! String ||
        nickname is! String ||
        avatar is! String) {
      throw const FormatException('原生账号资料快照字段无效');
    }
    return AccountProfileSnapshot(
      isLoggedIn: isLoggedIn,
      userId: userId,
      nickname: nickname,
      avatar: avatar,
    );
  }

  @override
  Future<void> clearSignedOutSession() {
    return _channel.invokeMethod<void>('clearSignedOutSession');
  }
}

typedef ProfileDeviceSessionRefresh = Future<void> Function();

final class AccountProfileRepository implements AccountProfileDataSource {
  AccountProfileRepository({
    required AccountSignOutGateway remote,
    required AccountProfileNativeStore nativeStore,
    required ProfileDeviceSessionRefresh refreshDeviceSession,
  }) : _remote = remote,
       _nativeStore = nativeStore,
       _refreshDeviceSession = refreshDeviceSession;

  final AccountSignOutGateway _remote;
  final AccountProfileNativeStore _nativeStore;
  final ProfileDeviceSessionRefresh _refreshDeviceSession;

  @override
  Future<AccountProfileSnapshot> load() => _nativeStore.load();

  @override
  Future<void> signOut() async {
    try {
      await _remote.dispatch();
    } catch (_) {
      // Android proceeds with local sign out even if logout cannot be sent.
    }
    await _nativeStore.clearSignedOutSession();
    try {
      await _refreshDeviceSession();
    } catch (_) {
      // Anonymous device-session recovery remains best effort after cleanup.
    }
  }
}
