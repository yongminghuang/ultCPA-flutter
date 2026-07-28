import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/account_profile/account_profile_data_source.dart';
import 'package:ultcpa_flutter/src/account_profile/account_profile_models.dart';
import 'package:ultcpa_flutter/src/account_profile/account_sign_out_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(
    MethodChannelAccountProfileNativeStore.channelName,
  );

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('reads and clears the exact Android account channel', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'readAccountProfile'
              ? {
                  'isLoggedIn': true,
                  'userId': '2038529229062426626',
                  'nickname': '考友',
                  'avatar': 'https://example.com/avatar.png',
                }
              : null;
        });
    final store = MethodChannelAccountProfileNativeStore();

    final snapshot = await store.load();
    await store.clearSignedOutSession();

    expect(
      MethodChannelAccountProfileNativeStore.channelName,
      'com.xmzj.ult.agg/account_safety',
    );
    expect(snapshot.isLoggedIn, isTrue);
    expect(snapshot.userId, '2038529229062426626');
    expect(snapshot.nickname, '考友');
    expect(snapshot.avatar, 'https://example.com/avatar.png');
    expect(calls.map((call) => call.method), [
      'readAccountProfile',
      'clearSignedOutSession',
    ]);
    expect(calls.every((call) => call.arguments == null), isTrue);
  });

  test('rejects every malformed native profile field', () async {
    final malformed = <Map<String, Object?>>[
      {'isLoggedIn': 'yes', 'userId': '1', 'nickname': '考友', 'avatar': ''},
      {'isLoggedIn': true, 'userId': 1, 'nickname': '考友', 'avatar': ''},
      {'isLoggedIn': true, 'userId': '1', 'nickname': null, 'avatar': ''},
      {'isLoggedIn': true, 'userId': '1', 'nickname': '考友', 'avatar': 3},
    ];
    for (final values in malformed) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => values);

      await expectLater(
        MethodChannelAccountProfileNativeStore().load(),
        throwsFormatException,
      );
    }
  });

  test('loads a fresh snapshot through the native store', () async {
    final native = _NativeStore(_snapshot);
    final repository = AccountProfileRepository(
      remote: _RemoteGateway(),
      nativeStore: native,
      refreshDeviceSession: () async {},
    );

    final snapshot = await repository.load();

    expect(snapshot, same(_snapshot));
    expect(native.events, ['load']);
  });

  test('dispatches before clearing and refreshes in order', () async {
    final events = <String>[];
    final repository = AccountProfileRepository(
      remote: _RemoteGateway(onDispatch: () async => events.add('dispatch')),
      nativeStore: _NativeStore(_snapshot, onClear: () => events.add('clear')),
      refreshDeviceSession: () async => events.add('refresh'),
    );

    await repository.signOut();

    expect(events, ['dispatch', 'clear', 'refresh']);
  });

  test('request-context failure does not block local sign out', () async {
    final native = _NativeStore(_snapshot);
    var refreshCalls = 0;
    final repository = AccountProfileRepository(
      remote: _RemoteGateway(error: StateError('headers unavailable')),
      nativeStore: native,
      refreshDeviceSession: () async => refreshCalls += 1,
    );

    await repository.signOut();

    expect(native.events, ['clear']);
    expect(refreshCalls, 1);
  });

  test('cleanup failure stays visible and skips anonymous refresh', () async {
    var refreshCalls = 0;
    final repository = AccountProfileRepository(
      remote: _RemoteGateway(),
      nativeStore: _NativeStore(
        _snapshot,
        clearError: StateError('clear failed'),
      ),
      refreshDeviceSession: () async => refreshCalls += 1,
    );

    await expectLater(repository.signOut(), throwsStateError);

    expect(refreshCalls, 0);
  });

  test('anonymous refresh is best effort after local sign out', () async {
    final native = _NativeStore(_snapshot);
    final repository = AccountProfileRepository(
      remote: _RemoteGateway(),
      nativeStore: native,
      refreshDeviceSession: () async => throw StateError('offline'),
    );

    await repository.signOut();

    expect(native.events, ['clear']);
  });
}

const _snapshot = AccountProfileSnapshot(
  isLoggedIn: true,
  userId: '2038529229062426626',
  nickname: '考友',
  avatar: '',
);

final class _RemoteGateway implements AccountSignOutGateway {
  _RemoteGateway({this.onDispatch, this.error});

  final Future<void> Function()? onDispatch;
  final Object? error;

  @override
  Future<void> dispatch() async {
    await onDispatch?.call();
    if (error != null) throw error!;
  }
}

final class _NativeStore implements AccountProfileNativeStore {
  _NativeStore(this.snapshot, {this.onClear, this.clearError});

  final AccountProfileSnapshot snapshot;
  final void Function()? onClear;
  final Object? clearError;
  final List<String> events = [];

  @override
  Future<void> clearSignedOutSession() async {
    events.add('clear');
    onClear?.call();
    if (clearError != null) throw clearError!;
  }

  @override
  Future<AccountProfileSnapshot> load() async {
    events.add('load');
    return snapshot;
  }
}
