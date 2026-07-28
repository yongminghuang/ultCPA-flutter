import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/account_safety/account_deactivation_gateway.dart';
import 'package:ultcpa_flutter/src/account_safety/account_safety_data_source.dart';
import 'package:ultcpa_flutter/src/account_safety/account_safety_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(
    MethodChannelAccountSafetyNativeStore.channelName,
  );

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('reads and clears the exact Android account-safety channel', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'readAccountSafety'
              ? {'isLoggedIn': true, 'phone': '13800138000'}
              : null;
        });
    final store = MethodChannelAccountSafetyNativeStore();

    final snapshot = await store.load();
    await store.clearDeactivatedSession();

    expect(
      MethodChannelAccountSafetyNativeStore.channelName,
      'com.xmzj.ult.agg/account_safety',
    );
    expect(snapshot.isLoggedIn, isTrue);
    expect(snapshot.phone, '13800138000');
    expect(calls.map((call) => call.method), [
      'readAccountSafety',
      'clearDeactivatedSession',
    ]);
    expect(calls.every((call) => call.arguments == null), isTrue);
  });

  test('rejects malformed native account snapshots', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          return {'isLoggedIn': 'yes', 'phone': 13800138000};
        });

    await expectLater(
      MethodChannelAccountSafetyNativeStore().load(),
      throwsFormatException,
    );
  });

  test('loads through the native store', () async {
    final native = _NativeStore(
      const AccountSafetySnapshot(isLoggedIn: true, phone: '13800138000'),
    );
    final repository = AccountSafetyRepository(
      remote: _RemoteGateway(),
      nativeStore: native,
      refreshDeviceSession: () async {},
    );

    final snapshot = await repository.load();

    expect(snapshot.isLoggedIn, isTrue);
    expect(snapshot.phone, '13800138000');
    expect(native.events, ['load']);
  });

  test('deactivates remotely then clears and refreshes in order', () async {
    final events = <String>[];
    final repository = AccountSafetyRepository(
      remote: _RemoteGateway(onDeactivate: () => events.add('remote')),
      nativeStore: _NativeStore(
        const AccountSafetySnapshot(isLoggedIn: true, phone: ''),
        onClear: () => events.add('clear'),
      ),
      refreshDeviceSession: () async => events.add('refresh'),
    );

    await repository.deactivateAccount();

    expect(events, ['remote', 'clear', 'refresh']);
  });

  test('remote failure preserves native state and skips refresh', () async {
    final native = _NativeStore(
      const AccountSafetySnapshot(isLoggedIn: true, phone: ''),
    );
    var refreshCalls = 0;
    final repository = AccountSafetyRepository(
      remote: _RemoteGateway(error: StateError('remote failed')),
      nativeStore: native,
      refreshDeviceSession: () async => refreshCalls += 1,
    );

    await expectLater(repository.deactivateAccount(), throwsStateError);

    expect(native.events, isEmpty);
    expect(refreshCalls, 0);
  });

  test('cleanup failure skips refresh and remains visible', () async {
    var refreshCalls = 0;
    final repository = AccountSafetyRepository(
      remote: _RemoteGateway(),
      nativeStore: _NativeStore(
        const AccountSafetySnapshot(isLoggedIn: true, phone: ''),
        clearError: StateError('clear failed'),
      ),
      refreshDeviceSession: () async => refreshCalls += 1,
    );

    await expectLater(repository.deactivateAccount(), throwsStateError);

    expect(refreshCalls, 0);
  });

  test('anonymous refresh is best effort after local cleanup', () async {
    final native = _NativeStore(
      const AccountSafetySnapshot(isLoggedIn: true, phone: ''),
    );
    final repository = AccountSafetyRepository(
      remote: _RemoteGateway(),
      nativeStore: native,
      refreshDeviceSession: () async => throw StateError('offline'),
    );

    await repository.deactivateAccount();

    expect(native.events, ['clear']);
  });
}

final class _RemoteGateway implements AccountDeactivationGateway {
  _RemoteGateway({this.onDeactivate, this.error});

  final void Function()? onDeactivate;
  final Object? error;

  @override
  Future<void> deactivate() async {
    onDeactivate?.call();
    if (error != null) throw error!;
  }
}

final class _NativeStore implements AccountSafetyNativeStore {
  _NativeStore(this.snapshot, {this.onClear, this.clearError});

  final AccountSafetySnapshot snapshot;
  final void Function()? onClear;
  final Object? clearError;
  final List<String> events = [];

  @override
  Future<void> clearDeactivatedSession() async {
    events.add('clear');
    onClear?.call();
    if (clearError != null) throw clearError!;
  }

  @override
  Future<AccountSafetySnapshot> load() async {
    events.add('load');
    return snapshot;
  }
}
