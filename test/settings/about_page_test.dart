import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/settings/about_page.dart';
import 'package:ultcpa_flutter/src/settings/settings_data_source.dart';
import 'package:ultcpa_flutter/src/settings/settings_models.dart';
import 'package:ultcpa_flutter/src/settings/settings_navigation.dart';
import 'package:ultcpa_flutter/src/startup/privacy_consent_dialog.dart';

void main() {
  testWidgets('renders Android app identity, rows, and footer', (tester) async {
    await tester.pumpWidget(_app(source: _Source()));

    expect(find.text('关于'), findsOneWidget);
    expect(find.text('考有招'), findsWidgets);
    expect(find.text('v1.2.5\n(build:26071018)'), findsOneWidget);
    expect(find.text('用户协议'), findsOneWidget);
    expect(find.text('隐私政策'), findsOneWidget);
    expect(find.text('给我好评'), findsOneWidget);
    expect(find.text('上报软件错误'), findsOneWidget);
    expect(find.text('闽ICP备2026009152号 >'), findsOneWidget);
    expect(find.text('厦门铸径信息科技有限公司'), findsOneWidget);
    expect(find.text('Copyright© 2026 All Rights Reserved'), findsOneWidget);
    final icon = tester.widget<Image>(
      find.byKey(const ValueKey('about-app-icon')),
    );
    expect(
      (icon.image as AssetImage).assetName,
      'assets/images/settings/app_icon.png',
    );
  });

  testWidgets('opens exact agreement documents and store rating', (
    tester,
  ) async {
    final source = _Source();
    final documents = <AgreementDocument>[];
    await tester.pumpWidget(
      _app(
        source: source,
        agreementLauncher: (context, document) => documents.add(document),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('about-user-agreement')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('about-privacy-policy')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('about-rate-app')));
    await tester.pump();

    expect(documents, [
      AgreementDocument.userAgreement,
      AgreementDocument.privacyPolicy,
    ]);
    expect(source.storeCalls, 1);
  });

  testWidgets('reports the Android-equivalent software-error feedback', (
    tester,
  ) async {
    await tester.pumpWidget(_app(source: _Source()));

    await tester.tap(find.byKey(const ValueKey('about-report-error')));
    await tester.pump();

    expect(find.text('错误信息已上报成功，感谢反馈。'), findsOneWidget);
  });

  testWidgets('confirms ICP before opening the official site', (tester) async {
    final source = _Source();
    await tester.pumpWidget(_app(source: source));

    await tester.tap(find.byKey(const ValueKey('about-icp')));
    await tester.pumpAndSettle();
    expect(find.text('是否跳转到手机浏览器打开 ICP 备案号查询官网'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('about-icp-cancel')));
    await tester.pumpAndSettle();
    expect(source.externalUrls, isEmpty);

    await tester.tap(find.byKey(const ValueKey('about-icp')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('about-icp-confirm')));
    await tester.pumpAndSettle();
    expect(source.externalUrls, [Uri.parse('https://beian.miit.gov.cn')]);
  });

  testWidgets('reports platform failures and restores actions', (tester) async {
    final source = _Source(
      onStore: () => throw StateError('no market'),
      onExternal: (url) => throw StateError('no browser'),
    );
    await tester.pumpWidget(_app(source: source));

    await tester.tap(find.byKey(const ValueKey('about-rate-app')));
    await tester.pump();
    expect(find.text('应用商店打开失败，请重试'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('about-icp')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('about-icp-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('备案网站打开失败，请重试'), findsOneWidget);
  });

  testWidgets('supports back and fits a 320 by 568 viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: _AboutHarness(source: _Source())),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('about-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('about-back')));
    await tester.pumpAndSettle();
    expect(find.text('host'), findsOneWidget);
  });
}

Widget _app({
  required _Source source,
  SettingsAgreementLauncher? agreementLauncher,
}) {
  return MaterialApp(
    home: AboutPage(
      dataSource: source,
      agreementLauncher:
          agreementLauncher ?? (context, document) => Future<void>.value(),
    ),
  );
}

typedef _Action = Future<void> Function();
typedef _ExternalAction = Future<void> Function(Uri url);

final class _Source implements SettingsDataSource {
  _Source({this.onStore, this.onExternal});

  final _Action? onStore;
  final _ExternalAction? onExternal;
  int storeCalls = 0;
  final List<Uri> externalUrls = [];

  @override
  Future<void> openStoreRating() async {
    storeCalls += 1;
    await onStore?.call();
  }

  @override
  Future<void> openExternalUrl(Uri url) async {
    externalUrls.add(url);
    await onExternal?.call(url);
  }

  @override
  Future<void> clearCaches() async {}

  @override
  Future<SettingsSnapshot> load() async {
    return const SettingsSnapshot(
      notificationEnabled: true,
      personalizedRecommendations: true,
    );
  }

  @override
  Future<void> setNotificationEnabled(bool enabled) async {}

  @override
  Future<void> setPersonalizedRecommendations(bool enabled) async {}
}

final class _AboutHarness extends StatelessWidget {
  const _AboutHarness({required this.source});

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
                  builder: (_) => AboutPage(
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
