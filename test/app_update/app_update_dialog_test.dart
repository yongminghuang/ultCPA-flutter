import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/app_update/app_update_dialog.dart';
import 'package:ultcpa_flutter/src/app_update/app_update_file_transfer.dart';
import 'package:ultcpa_flutter/src/app_update/app_update_models.dart';

void main() {
  testWidgets('shows exact update copy and lets an optional update close', (
    tester,
  ) async {
    await _showDialog(tester, info: _optional, transfer: _Transfer());

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('最新版本：'), findsOneWidget);
    expect(find.text('v2.0.0'), findsOneWidget);
    expect(find.text('当前版本：'), findsOneWidget);
    expect(find.text('v1.2.5'), findsOneWidget);
    expect(find.text('更新内容：'), findsOneWidget);
    expect(find.text('修复练题记录\n新增专项复习'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-update-close')));
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsNothing);
  });

  testWidgets('forced update blocks close barrier and system back', (
    tester,
  ) async {
    await _showDialog(
      tester,
      info: _optional.copyWith(isForceUpdate: true),
      transfer: _Transfer(),
    );

    expect(find.byKey(const ValueKey('app-update-close')), findsNothing);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsOneWidget);
  });

  testWidgets('external and market targets delegate once and dismiss', (
    tester,
  ) async {
    final external = _Transfer();
    await _showDialog(
      tester,
      info: _optional.copyWith(rawUrl: 'https://fir.im/example'),
      transfer: external,
    );
    await tester.tap(find.byKey(const ValueKey('app-update-action')));
    await tester.pumpAndSettle();
    expect(external.externalUrls, ['https://fir.im/example']);
    expect(find.byType(AppUpdateDialog), findsNothing);

    final market = _Transfer();
    await _showDialog(
      tester,
      info: _optional.copyWith(rawUrl: ''),
      transfer: market,
    );
    await tester.tap(find.byKey(const ValueKey('app-update-action')));
    await tester.pumpAndSettle();
    expect(market.marketCalls, 1);
    expect(find.byType(AppUpdateDialog), findsNothing);
  });

  testWidgets('routing failure stays open and restores the update action', (
    tester,
  ) async {
    final transfer = _Transfer()..externalError = StateError('no handler');
    await _showDialog(
      tester,
      info: _optional.copyWith(rawUrl: 'https://myapp.com/example'),
      transfer: transfer,
    );

    await tester.tap(find.byKey(const ValueKey('app-update-action')));
    await tester.pumpAndSettle();

    expect(transfer.externalUrls, ['https://myapp.com/example']);
    expect(find.byType(AppUpdateDialog), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('app-update-action')),
    );
    expect(button.onPressed, isNotNull);
    expect(find.text('立即更新'), findsOneWidget);
  });

  testWidgets('APK reports progress auto-installs and keeps install retry', (
    tester,
  ) async {
    final download = Completer<String>();
    final transfer = _Transfer()..pendingDownload = download;
    await _showDialog(tester, info: _optional, transfer: transfer);

    await tester.tap(find.byKey(const ValueKey('app-update-action')));
    await tester.pump();
    transfer.progress?.call(40, 100);
    await tester.pump();

    expect(transfer.downloadUrls, ['https://cdn.example.com/app.apk']);
    expect(find.text('40%'), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('app-update-progress')),
    );
    expect(progress.value, 0.4);

    download.complete('/external/update/app.apk');
    await tester.pumpAndSettle();
    expect(transfer.installs, ['/external/update/app.apk']);
    expect(find.text('立即安装'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-update-action')));
    await tester.pumpAndSettle();
    expect(transfer.installs, [
      '/external/update/app.apk',
      '/external/update/app.apk',
    ]);
  });

  testWidgets('download failure changes the action and then closes', (
    tester,
  ) async {
    final transfer = _Transfer()..downloadError = StateError('offline');
    await _showDialog(tester, info: _optional, transfer: transfer);

    await tester.tap(find.byKey(const ValueKey('app-update-action')));
    await tester.pumpAndSettle();
    expect(find.text('下载失败'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-update-action')));
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsNothing);
  });

  testWidgets('optional dismissal during download still hands off install', (
    tester,
  ) async {
    final download = Completer<String>();
    final transfer = _Transfer()..pendingDownload = download;
    await _showDialog(tester, info: _optional, transfer: transfer);

    await tester.tap(find.byKey(const ValueKey('app-update-action')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('app-update-close')));
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsNothing);

    download.complete('/external/update/app.apk');
    await tester.pump();
    await tester.pump();
    expect(transfer.installs, ['/external/update/app.apk']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long content fits a 320 by 568 viewport', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _showDialog(
      tester,
      info: _optional.copyWith(description: List.filled(20, '更新内容').join('\n')),
      transfer: _Transfer(),
    );

    expect(find.byType(AppUpdateDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _optional = AppUpdateInfo(
  latestVersion: '2.0.0',
  description: '修复练题记录\n新增专项复习',
  isForceUpdate: false,
  rawUrl: 'https://cdn.example.com/app.apk',
  ossDomain: '',
);

extension on AppUpdateInfo {
  AppUpdateInfo copyWith({
    String? description,
    bool? isForceUpdate,
    String? rawUrl,
  }) {
    return AppUpdateInfo(
      latestVersion: latestVersion,
      description: description ?? this.description,
      isForceUpdate: isForceUpdate ?? this.isForceUpdate,
      rawUrl: rawUrl ?? this.rawUrl,
      ossDomain: ossDomain,
    );
  }
}

Future<void> _showDialog(
  WidgetTester tester, {
  required AppUpdateInfo info,
  required AppUpdateFileTransfer transfer,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showAppUpdateDialog(
              context: context,
              info: info,
              fileTransfer: transfer,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

final class _Transfer implements AppUpdateFileTransfer {
  Completer<String>? pendingDownload;
  Object? downloadError;
  Object? externalError;
  void Function(int received, int total)? progress;
  int marketCalls = 0;
  final List<String> downloadUrls = [];
  final List<String> installs = [];
  final List<String> externalUrls = [];

  @override
  Future<String> download({
    required String url,
    required void Function(int received, int total) onProgress,
  }) async {
    downloadUrls.add(url);
    progress = onProgress;
    final error = downloadError;
    if (error != null) throw error;
    return pendingDownload?.future ?? '/external/update/app.apk';
  }

  @override
  Future<void> install(String path) async => installs.add(path);

  @override
  Future<void> openExternal(String url) async {
    externalUrls.add(url);
    final error = externalError;
    if (error != null) throw error;
  }

  @override
  Future<void> openMarket() async => marketCalls += 1;
}
