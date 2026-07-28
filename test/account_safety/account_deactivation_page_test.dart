import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/account_safety/account_deactivation_page.dart';
import 'package:ultcpa_flutter/src/account_safety/account_safety_data_source.dart';
import 'package:ultcpa_flutter/src/account_safety/account_safety_models.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';

void main() {
  testWidgets('renders the Android deactivation notice and supports back', (
    tester,
  ) async {
    final results = <AccountSafetyResult?>[];
    await tester.pumpWidget(_harness(_Source(), results));
    await _open(tester);

    expect(find.text('注销账号'), findsWidgets);
    expect(find.text('注销须知'), findsOneWidget);
    expect(find.textContaining('使用此手机和微信号将无法登录考有招系统'), findsOneWidget);
    expect(find.textContaining('虚拟资产（VIP会员）'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account-deactivation-back')));
    await tester.pumpAndSettle();
    expect(results, [null]);
  });

  testWidgets('first cancellation never opens typed confirmation', (
    tester,
  ) async {
    final source = _Source();
    await tester.pumpWidget(_app(source));

    await tester.tap(find.byKey(const ValueKey('account-deactivation-start')));
    await tester.pumpAndSettle();
    expect(find.text('确认要注销账号吗？'), findsOneWidget);
    expect(find.text('注销账户后,使用此手机号或微信号将无法登录考有招'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('account-deactivation-first-cancel')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('account-deactivation-input')),
      findsNothing,
    );
    expect(source.deactivateCalls, 0);
  });

  testWidgets('requires the exact trimmed confirmation phrase', (tester) async {
    final source = _Source();
    await tester.pumpWidget(_app(source));
    await _openTypedConfirmation(tester);

    final confirmFinder = find.byKey(
      const ValueKey('account-deactivation-typed-confirm'),
    );
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('account-deactivation-input')),
      '确认',
    );
    await tester.pump();
    expect(find.text('输入错误'), findsOneWidget);
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('account-deactivation-input')),
      '  确认注销  ',
    );
    await tester.pump();
    expect(find.text('输入错误'), findsNothing);
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNotNull);
  });

  testWidgets('submits once, shows progress, and returns deactivated', (
    tester,
  ) async {
    final pending = Completer<void>();
    final source = _Source(onDeactivate: () => pending.future);
    final results = <AccountSafetyResult?>[];
    await tester.pumpWidget(_harness(source, results));
    await _open(tester);
    await _openTypedConfirmation(tester);
    await _enterExactPhraseAndConfirm(tester);

    expect(source.deactivateCalls, 1);
    expect(
      find.byKey(const ValueKey('account-deactivation-progress')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('account-deactivation-start')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(
      find.byKey(const ValueKey('account-deactivation-start')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(source.deactivateCalls, 1);

    pending.complete();
    await tester.pumpAndSettle();
    expect(results, [AccountSafetyResult.deactivated]);
  });

  testWidgets('keeps the page and exposes the server failure message', (
    tester,
  ) async {
    final source = _Source(
      onDeactivate: () async =>
          throw const AppApiException('账号注销失败，请稍后重试', code: 409),
    );
    await tester.pumpWidget(_app(source));
    await _openTypedConfirmation(tester);
    await _enterExactPhraseAndConfirm(tester);
    await tester.pumpAndSettle();

    expect(find.text('账号注销失败，请稍后重试'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('account-deactivation-content')),
      findsOneWidget,
    );
    expect(source.deactivateCalls, 1);
  });

  testWidgets('does not expose native cleanup implementation errors', (
    tester,
  ) async {
    final source = _Source(
      onDeactivate: () async => throw PlatformException(
        code: 'account_safety_error',
        message: 'Could not clear legacy account preferences',
      ),
    );
    await tester.pumpWidget(_app(source));
    await _openTypedConfirmation(tester);
    await _enterExactPhraseAndConfirm(tester);
    await tester.pumpAndSettle();

    expect(find.text('账号注销失败，请重试'), findsOneWidget);
    expect(find.textContaining('legacy account'), findsNothing);
  });

  testWidgets('second cancellation and close never submit', (tester) async {
    final source = _Source();
    await tester.pumpWidget(_app(source));
    await _openTypedConfirmation(tester);

    await tester.tap(
      find.byKey(const ValueKey('account-deactivation-typed-cancel')),
    );
    await tester.pumpAndSettle();
    expect(source.deactivateCalls, 0);

    await _openTypedConfirmation(tester);
    await tester.tap(
      find.byKey(const ValueKey('account-deactivation-typed-close')),
    );
    await tester.pumpAndSettle();
    expect(source.deactivateCalls, 0);
  });

  testWidgets('fits both page and keyboard dialog at 320 by 568', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_Source()));
    await _openTypedConfirmation(tester);
    await tester.tap(find.byKey(const ValueKey('account-deactivation-input')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('account-deactivation-typed-dialog')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _openTypedConfirmation(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('account-deactivation-start')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('account-deactivation-first-confirm')),
  );
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('account-deactivation-typed-dialog')),
    findsOneWidget,
  );
}

Future<void> _enterExactPhraseAndConfirm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('account-deactivation-input')),
    '确认注销',
  );
  await tester.pump();
  await tester.tap(
    find.byKey(const ValueKey('account-deactivation-typed-confirm')),
  );
  await tester.pump();
}

Widget _app(AccountSafetyDataSource source) {
  return MaterialApp(home: AccountDeactivationPage(dataSource: source));
}

Widget _harness(
  AccountSafetyDataSource source,
  List<AccountSafetyResult?> results,
) {
  return MaterialApp(
    home: _Harness(source: source, results: results),
  );
}

final class _Source implements AccountSafetyDataSource {
  _Source({this.onDeactivate});

  final Future<void> Function()? onDeactivate;
  int deactivateCalls = 0;

  @override
  Future<void> deactivateAccount() async {
    deactivateCalls += 1;
    await onDeactivate?.call();
  }

  @override
  Future<AccountSafetySnapshot> load() async {
    return const AccountSafetySnapshot(isLoggedIn: true, phone: '13800138000');
  }
}

final class _Harness extends StatelessWidget {
  const _Harness({required this.source, required this.results});

  final AccountSafetyDataSource source;
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
                      builder: (_) =>
                          AccountDeactivationPage(dataSource: source),
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
