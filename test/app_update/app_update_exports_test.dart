import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/ultcpa_flutter.dart';

void main() {
  test('exports the complete manual app-update public surface', () {
    const info = AppUpdateInfo(
      latestVersion: '2.0.0',
      description: 'changes',
      isForceUpdate: false,
      rawUrl: '',
      ossDomain: '',
    );
    const result = AppUpdateAvailable(info);

    expect(result, isA<AppUpdateCheckResult>());
    expect(const AppUpdateLatest(), isA<AppUpdateCheckResult>());
    expect(info.target, AppUpdateTarget.applicationMarket);
    expect(AppApiAppUpdateDataSource.new, isA<Function>());
    expect(DioAppUpdateFileTransfer.new, isA<Function>());
    expect(MethodChannelAppUpdateNativeBridge.channelName, isNotEmpty);
    expect(AppUpdateDialog.new, isA<Function>());
    expect(showAppUpdateDialog, isA<Function>());
  });
}
