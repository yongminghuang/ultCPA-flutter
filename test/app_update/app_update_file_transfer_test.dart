import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/app_update/app_update_file_transfer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(MethodChannelAppUpdateNativeBridge.channelName);

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'uses the exact native path install external and market contracts',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'createAppUpdateDownloadPath') {
              return '/external/update/app.apk';
            }
            return null;
          });
      final bridge = MethodChannelAppUpdateNativeBridge();

      final path = await bridge.createDownloadPath();
      await bridge.installApk(path);
      await bridge.openExternalUrl('https://app.qq.com/example');
      await bridge.openApplicationMarket();

      expect(path, '/external/update/app.apk');
      expect(calls.map((call) => call.method), [
        'createAppUpdateDownloadPath',
        'installAppUpdateApk',
        'openAppUpdateUrl',
        'openApplicationMarket',
      ]);
      expect(calls[0].arguments, isNull);
      expect(calls[1].arguments, {'path': '/external/update/app.apk'});
      expect(calls[2].arguments, {'url': 'https://app.qq.com/example'});
      expect(calls[3].arguments, isNull);
    },
  );

  test(
    'downloads bytes to the native update path and reports progress',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'app-update-download-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final path = '${temp.path}${Platform.pathSeparator}app.apk';
      final adapter = _BytesAdapter([
        Uint8List.fromList([1, 2]),
        Uint8List.fromList([3, 4]),
      ]);
      final dio = Dio()..httpClientAdapter = adapter;
      final bridge = _FakeBridge(path);
      final transfer = DioAppUpdateFileTransfer(dio: dio, nativeBridge: bridge);
      final progress = <(int, int)>[];

      final result = await transfer.download(
        url: 'https://cdn.example.com/app.apk',
        onProgress: (received, total) => progress.add((received, total)),
      );

      expect(result, path);
      expect(await File(path).readAsBytes(), [1, 2, 3, 4]);
      expect(adapter.requestedUrls, ['https://cdn.example.com/app.apk']);
      expect(bridge.createPathCalls, 1);
      expect(progress, isNotEmpty);
      expect(progress.last, (4, 4));
    },
  );

  test('delegates install and both non-APK targets to Android', () async {
    final bridge = _FakeBridge('/external/update/app.apk');
    final transfer = DioAppUpdateFileTransfer(dio: Dio(), nativeBridge: bridge);

    await transfer.install('/external/update/app.apk');
    await transfer.openExternal('https://fir.im/example');
    await transfer.openMarket();

    expect(bridge.installs, ['/external/update/app.apk']);
    expect(bridge.externalUrls, ['https://fir.im/example']);
    expect(bridge.marketCalls, 1);
  });
}

final class _FakeBridge implements AppUpdateNativeBridge {
  _FakeBridge(this.path);

  final String path;
  int createPathCalls = 0;
  int marketCalls = 0;
  final List<String> installs = [];
  final List<String> externalUrls = [];

  @override
  Future<String> createDownloadPath() async {
    createPathCalls += 1;
    return path;
  }

  @override
  Future<void> installApk(String path) async => installs.add(path);

  @override
  Future<void> openApplicationMarket() async => marketCalls += 1;

  @override
  Future<void> openExternalUrl(String url) async => externalUrls.add(url);
}

final class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.chunks);

  final List<Uint8List> chunks;
  final List<String> requestedUrls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedUrls.add(options.uri.toString());
    final length = chunks.fold<int>(0, (total, chunk) => total + chunk.length);
    return ResponseBody(
      Stream<Uint8List>.fromIterable(chunks),
      200,
      headers: {
        Headers.contentLengthHeader: ['$length'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
