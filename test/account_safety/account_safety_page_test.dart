import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/account_safety/account_safety_data_source.dart';
import 'package:ultcpa_flutter/src/account_safety/account_safety_models.dart';
import 'package:ultcpa_flutter/src/account_safety/account_safety_page.dart';

void main() {
  testWidgets('loads native account state and retries a failure', (
    tester,
  ) async {
    final first = Completer<AccountSafetySnapshot>();
    final second = Completer<AccountSafetySnapshot>();
    var attempt = 0;
    final source = _Source(
      loader: () => attempt++ == 0 ? first.future : second.future,
    );
    await tester.pumpWidget(_app(source));

    expect(
      find.byKey(const ValueKey('account-safety-loading')),
      findsOneWidget,
    );
    first.completeError(StateError('offline'));
    await tester.pump();
    expect(find.byKey(const ValueKey('account-safety-error')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account-safety-retry')));
    await tester.pump();
    second.complete(_snapshot());
    await tester.pumpAndSettle();

    expect(find.text('账号与安全'), findsOneWidget);
    expect(find.text('138****8000'), findsOneWidget);
    expect(source.loadCalls, 2);
  });

  testWidgets('shows only Android visible rows and keeps phone read only', (
    tester,
  ) async {
    var launchCalls = 0;
    await tester.pumpWidget(
      _app(
        _Source(loader: () async => _snapshot()),
        launcher: (_) async {
          launchCalls += 1;
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('手机号'), findsOneWidget);
    expect(find.text('138****8000'), findsOneWidget);
    expect(find.text('注销账号'), findsOneWidget);
    expect(find.text('请注意！注销后将无法恢复'), findsOneWidget);
    expect(find.text('微信'), findsNothing);
    expect(find.textContaining('更换'), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account-safety-phone')));
    await tester.pump();
    expect(launchCalls, 0);

    await tester.tap(find.byKey(const ValueKey('account-safety-deactivate')));
    await tester.pump();
    expect(launchCalls, 1);
  });

  testWidgets('uses the Android empty-phone fallback', (tester) async {
    await tester.pumpWidget(
      _app(
        _Source(
          loader: () async =>
              const AccountSafetySnapshot(isLoggedIn: true, phone: ''),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('点击绑定'), findsOneWidget);
  });

  testWidgets('forwards deactivation result to the settings route', (
    tester,
  ) async {
    final results = <AccountSafetyResult?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _Harness(
          source: _Source(loader: () async => _snapshot()),
          launcher: (_) async => AccountSafetyResult.deactivated,
          results: results,
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-safety-deactivate')));
    await tester.pumpAndSettle();

    expect(find.text('host'), findsOneWidget);
    expect(results, [AccountSafetyResult.deactivated]);
  });

  testWidgets('supports back without reporting deactivation', (tester) async {
    final results = <AccountSafetyResult?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _Harness(
          source: _Source(loader: () async => _snapshot()),
          launcher: (_) async => null,
          results: results,
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('account-safety-back')));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });

  testWidgets('ignores a stale load after disposal', (tester) async {
    final load = Completer<AccountSafetySnapshot>();
    await tester.pumpWidget(_app(_Source(loader: () => load.future)));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    load.complete(_snapshot());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('fits the Android surface on a 320 by 568 viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_Source(loader: () async => _snapshot())));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('account-safety-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

AccountSafetySnapshot _snapshot() {
  return const AccountSafetySnapshot(isLoggedIn: true, phone: '13800138000');
}

Widget _app(_Source source, {AccountDeactivationLauncher? launcher}) {
  return MaterialApp(
    home: AccountSafetyPage(
      dataSource: source,
      deactivationLauncher: launcher ?? (_) async => null,
    ),
  );
}

final class _Source implements AccountSafetyDataSource {
  _Source({required this.loader});

  final Future<AccountSafetySnapshot> Function() loader;
  int loadCalls = 0;

  @override
  Future<AccountSafetySnapshot> load() {
    loadCalls += 1;
    return loader();
  }

  @override
  Future<void> deactivateAccount() async {}
}

final class _Harness extends StatelessWidget {
  const _Harness({
    required this.source,
    required this.launcher,
    required this.results,
  });

  final AccountSafetyDataSource source;
  final AccountDeactivationLauncher launcher;
  final List<AccountSafetyResult?> results;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('host'),
          TextButton(
            onPressed: () async {
              final result = await Navigator.of(context)
                  .push<AccountSafetyResult>(
                    MaterialPageRoute<AccountSafetyResult>(
                      builder: (_) => AccountSafetyPage(
                        dataSource: source,
                        deactivationLauncher: launcher,
                      ),
                    ),
                  );
              results.add(result);
            },
            child: const Text('open'),
          ),
        ],
      ),
    );
  }
}
