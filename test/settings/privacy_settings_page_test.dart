import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/settings/privacy_settings_page.dart';
import 'package:ultcpa_flutter/src/settings/settings_data_source.dart';
import 'package:ultcpa_flutter/src/settings/settings_models.dart';
import 'package:ultcpa_flutter/src/settings/settings_navigation.dart';
import 'package:ultcpa_flutter/src/startup/privacy_consent_dialog.dart';

void main() {
  testWidgets('loads fresh state and retries a read failure', (tester) async {
    final first = Completer<SettingsSnapshot>();
    final second = Completer<SettingsSnapshot>();
    var attempt = 0;
    final source = _Source(
      loader: () => attempt++ == 0 ? first.future : second.future,
    );
    await tester.pumpWidget(_app(source: source));

    expect(find.byKey(const ValueKey('privacy-loading')), findsOneWidget);
    first.completeError(StateError('offline'));
    await tester.pump();
    expect(find.byKey(const ValueKey('privacy-error')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('privacy-retry')));
    await tester.pump();
    second.complete(_snapshot(personalized: false));
    await tester.pumpAndSettle();

    expect(find.text('隐私设置'), findsOneWidget);
    expect(_personalizedSwitch(tester).value, isFalse);
    expect(source.loadCalls, 2);
  });

  testWidgets('persists personalization and rolls back a failed write', (
    tester,
  ) async {
    var fail = false;
    final source = _Source(
      loader: () async => _snapshot(personalized: true),
      writer: (enabled) async {
        if (fail) throw StateError('write failed');
      },
    );
    await tester.pumpWidget(_app(source: source));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('privacy-personalized-switch')));
    await tester.pumpAndSettle();
    expect(source.writes, [false]);
    expect(_personalizedSwitch(tester).value, isFalse);

    fail = true;
    await tester.tap(find.byKey(const ValueKey('privacy-personalized-switch')));
    await tester.pumpAndSettle();
    expect(source.writes, [false, true]);
    expect(_personalizedSwitch(tester).value, isFalse);
    expect(find.text('设置保存失败，请重试'), findsOneWidget);
  });

  testWidgets('opens the exact privacy document and supports back', (
    tester,
  ) async {
    final documents = <AgreementDocument>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _PrivacyHarness(
          source: _Source(loader: () async => _snapshot(personalized: true)),
          agreementLauncher: (context, document) => documents.add(document),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('privacy-policy')));
    await tester.pump();
    expect(documents, [AgreementDocument.privacyPolicy]);

    await tester.tap(find.byKey(const ValueKey('privacy-back')));
    await tester.pumpAndSettle();
    expect(find.text('host'), findsOneWidget);
  });

  testWidgets('fits privacy settings on a 320 by 568 viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(source: _Source(loader: () async => _snapshot(personalized: true))),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('privacy-content')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Switch _personalizedSwitch(WidgetTester tester) {
  return tester.widget<Switch>(
    find.byKey(const ValueKey('privacy-personalized-switch')),
  );
}

Widget _app({required _Source source}) {
  return MaterialApp(
    home: PrivacySettingsPage(
      dataSource: source,
      agreementLauncher: (context, document) {},
    ),
  );
}

SettingsSnapshot _snapshot({required bool personalized}) {
  return SettingsSnapshot(
    notificationEnabled: true,
    personalizedRecommendations: personalized,
  );
}

typedef _Loader = Future<SettingsSnapshot> Function();
typedef _Writer = Future<void> Function(bool enabled);

final class _Source implements SettingsDataSource {
  _Source({required this.loader, this.writer});

  final _Loader loader;
  final _Writer? writer;
  int loadCalls = 0;
  final List<bool> writes = [];

  @override
  Future<SettingsSnapshot> load() {
    loadCalls += 1;
    return loader();
  }

  @override
  Future<void> setPersonalizedRecommendations(bool enabled) async {
    writes.add(enabled);
    await writer?.call(enabled);
  }

  @override
  Future<void> clearCaches() async {}

  @override
  Future<void> openExternalUrl(Uri url) async {}

  @override
  Future<void> openStoreRating() async {}

  @override
  Future<void> setNotificationEnabled(bool enabled) async {}
}

final class _PrivacyHarness extends StatelessWidget {
  const _PrivacyHarness({
    required this.source,
    required this.agreementLauncher,
  });

  final SettingsDataSource source;
  final SettingsAgreementLauncher agreementLauncher;

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
                  builder: (_) => PrivacySettingsPage(
                    dataSource: source,
                    agreementLauncher: agreementLauncher,
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
