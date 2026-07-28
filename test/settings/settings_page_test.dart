import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/account_safety/account_safety_models.dart';
import 'package:ultcpa_flutter/src/settings/about_page.dart';
import 'package:ultcpa_flutter/src/settings/privacy_settings_page.dart';
import 'package:ultcpa_flutter/src/settings/settings_data_source.dart';
import 'package:ultcpa_flutter/src/settings/settings_models.dart';
import 'package:ultcpa_flutter/src/settings/settings_navigation.dart';
import 'package:ultcpa_flutter/src/settings/settings_page.dart';
import 'package:ultcpa_flutter/src/startup/privacy_consent_dialog.dart';

void main() {
  testWidgets('shows loading, retries a failure, and renders Android rows', (
    tester,
  ) async {
    final first = Completer<SettingsSnapshot>();
    final second = Completer<SettingsSnapshot>();
    var attempt = 0;
    final source = _Source(
      load: () => attempt++ == 0 ? first.future : second.future,
    );
    await tester.pumpWidget(_app(source: source));

    expect(find.byKey(const ValueKey('settings-loading')), findsOneWidget);
    first.completeError(StateError('offline'));
    await tester.pump();
    expect(find.byKey(const ValueKey('settings-error')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-retry')));
    await tester.pump();
    second.complete(_snapshot);
    await tester.pumpAndSettle();

    expect(find.text('我的设置'), findsOneWidget);
    expect(find.text('通知开关'), findsOneWidget);
    expect(find.text('清理缓存'), findsOneWidget);
    expect(find.text('关于我们'), findsOneWidget);
    expect(find.text('隐私设置'), findsOneWidget);
    expect(find.text('账号与安全'), findsOneWidget);
    expect(source.loadCalls, 2);
  });

  testWidgets('persists notification changes and rolls back failures', (
    tester,
  ) async {
    var fail = false;
    final source = _Source(
      load: () async => _snapshot,
      setNotification: (enabled) async {
        if (fail) throw StateError('write failed');
      },
    );
    await tester.pumpWidget(_app(source: source));
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('settings-notification-switch')),
    );
    await tester.pumpAndSettle();
    expect(source.notificationWrites, [false]);
    expect(_notificationSwitch(tester).value, isFalse);

    fail = true;
    await tester.tap(
      find.byKey(const ValueKey('settings-notification-switch')),
    );
    await tester.pumpAndSettle();
    expect(source.notificationWrites, [false, true]);
    expect(_notificationSwitch(tester).value, isFalse);
    expect(find.text('设置保存失败，请重试'), findsOneWidget);
  });

  testWidgets('guards cache clearing and reports success or failure', (
    tester,
  ) async {
    final pending = Completer<void>();
    final source = _Source(
      load: () async => _snapshot,
      clear: () => pending.future,
    );
    await tester.pumpWidget(_app(source: source));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('settings-clear-cache')));
    await tester.pump();
    expect(source.clearCalls, 1);
    expect(
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey('settings-clear-cache-action')),
          )
          .onTap,
      isNull,
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('清理成功'), findsOneWidget);

    final failing = _Source(
      load: () async => _snapshot,
      clear: () => throw StateError('clear failed'),
    );
    await tester.pumpWidget(_app(source: failing));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings-clear-cache')));
    await tester.pumpAndSettle();
    expect(find.text('清理失败，请重试'), findsOneWidget);
  });

  testWidgets('keeps account safety honest for every login boundary', (
    tester,
  ) async {
    final loggedOut = _Source(load: () async => _snapshot);
    await tester.pumpWidget(_app(source: loggedOut, isLoggedIn: false));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings-account-safety')));
    await tester.pump();
    expect(find.text('请先登录'), findsOneWidget);

    final pending = _Source(load: () async => _snapshot);
    await tester.pumpWidget(_app(source: pending, isLoggedIn: true));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings-account-safety')));
    await tester.pump();
    expect(find.text('账号与安全功能仍在迁移中'), findsOneWidget);

    var launchCalls = 0;
    final injected = _Source(load: () async => _snapshot);
    await tester.pumpWidget(
      _app(
        source: injected,
        isLoggedIn: true,
        accountSafetyLauncher: (context) {
          launchCalls += 1;
          return null;
        },
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings-account-safety')));
    await tester.pump();
    expect(launchCalls, 1);
  });

  testWidgets('returns account deactivation through the settings route', (
    tester,
  ) async {
    final results = <AccountSafetyResult?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _SettingsResultHarness(
          source: _Source(load: () async => _snapshot),
          results: results,
        ),
      ),
    );

    await tester.tap(find.text('open-result'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-account-safety')));
    await tester.pumpAndSettle();

    expect(find.text('result-host'), findsOneWidget);
    expect(results, [AccountSafetyResult.deactivated]);
  });

  testWidgets('opens about and privacy with shared dependencies', (
    tester,
  ) async {
    final source = _Source(load: () async => _snapshot);
    final documents = <AgreementDocument>[];
    await tester.pumpWidget(
      _app(
        source: source,
        agreementLauncher: (context, document) => documents.add(document),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('settings-about')));
    await tester.pumpAndSettle();
    expect(find.byType(AboutPage), findsOneWidget);
    expect(
      tester.widget<AboutPage>(find.byType(AboutPage)).dataSource,
      same(source),
    );
    await tester.tap(find.byKey(const ValueKey('about-back')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-privacy')));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacySettingsPage), findsOneWidget);
    final privacy = tester.widget<PrivacySettingsPage>(
      find.byType(PrivacySettingsPage),
    );
    expect(privacy.dataSource, same(source));
    await tester.tap(find.byKey(const ValueKey('privacy-policy')));
    await tester.pump();
    expect(documents, [AgreementDocument.privacyPolicy]);
  });

  testWidgets('back ignores a stale settings completion', (tester) async {
    final pending = Completer<SettingsSnapshot>();
    final source = _Source(load: () => pending.future);
    await tester.pumpWidget(MaterialApp(home: _Harness(source: source)));

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pumpAndSettle();
    expect(find.text('host'), findsOneWidget);

    pending.complete(_snapshot);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits settings on a 320 by 568 viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(source: _Source(load: () async => _snapshot)));
    await tester.pump();

    expect(find.byKey(const ValueKey('settings-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Switch _notificationSwitch(WidgetTester tester) {
  return tester.widget<Switch>(
    find.byKey(const ValueKey('settings-notification-switch')),
  );
}

Widget _app({
  required _Source source,
  bool isLoggedIn = true,
  SettingsAgreementLauncher? agreementLauncher,
  SettingsAccountSafetyLauncher? accountSafetyLauncher,
}) {
  return MaterialApp(
    home: SettingsPage(
      key: ValueKey(source),
      isLoggedIn: isLoggedIn,
      dataSource: source,
      agreementLauncher:
          agreementLauncher ?? (context, document) => Future<void>.value(),
      accountSafetyLauncher: accountSafetyLauncher,
    ),
  );
}

const _snapshot = SettingsSnapshot(
  notificationEnabled: true,
  personalizedRecommendations: true,
);

typedef _Load = Future<SettingsSnapshot> Function();
typedef _SetBool = Future<void> Function(bool enabled);
typedef _Action = Future<void> Function();

final class _Source implements SettingsDataSource {
  _Source({required _Load load, this.setNotification, this.clear})
    : loader = load;

  final _Load loader;
  final _SetBool? setNotification;
  final _Action? clear;
  int loadCalls = 0;
  int clearCalls = 0;
  final List<bool> notificationWrites = [];
  final List<bool> personalizedWrites = [];

  @override
  Future<SettingsSnapshot> load() {
    loadCalls += 1;
    return loader();
  }

  @override
  Future<void> setNotificationEnabled(bool enabled) async {
    notificationWrites.add(enabled);
    await setNotification?.call(enabled);
  }

  @override
  Future<void> setPersonalizedRecommendations(bool enabled) async {
    personalizedWrites.add(enabled);
  }

  @override
  Future<void> clearCaches() async {
    clearCalls += 1;
    await clear?.call();
  }

  @override
  Future<void> openExternalUrl(Uri url) async {}

  @override
  Future<void> openStoreRating() async {}
}

final class _Harness extends StatelessWidget {
  const _Harness({required this.source});

  final SettingsDataSource source;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('host'),
          TextButton(
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsPage(
                    isLoggedIn: true,
                    dataSource: source,
                    agreementLauncher: (context, document) {},
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ],
      ),
    );
  }
}

final class _SettingsResultHarness extends StatelessWidget {
  const _SettingsResultHarness({required this.source, required this.results});

  final SettingsDataSource source;
  final List<AccountSafetyResult?> results;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('result-host'),
          TextButton(
            onPressed: () async {
              final result = await Navigator.of(context)
                  .push<AccountSafetyResult>(
                    MaterialPageRoute<AccountSafetyResult>(
                      builder: (_) => SettingsPage(
                        isLoggedIn: true,
                        dataSource: source,
                        agreementLauncher: (context, document) {},
                        accountSafetyLauncher: (_) async =>
                            AccountSafetyResult.deactivated,
                      ),
                    ),
                  );
              results.add(result);
            },
            child: const Text('open-result'),
          ),
        ],
      ),
    );
  }
}
