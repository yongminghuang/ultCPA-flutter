import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

abstract interface class AppUpdateFileTransfer {
  Future<String> download({
    required String url,
    required void Function(int received, int total) onProgress,
  });

  Future<void> install(String path);

  Future<void> openExternal(String url);

  Future<void> openMarket();
}

abstract interface class AppUpdateNativeBridge {
  Future<String> createDownloadPath();

  Future<void> installApk(String path);

  Future<void> openExternalUrl(String url);

  Future<void> openApplicationMarket();
}

final class MethodChannelAppUpdateNativeBridge
    implements AppUpdateNativeBridge {
  MethodChannelAppUpdateNativeBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.xmzj.ult.agg/mine_actions';

  final MethodChannel _channel;

  @override
  Future<String> createDownloadPath() async {
    final path = await _channel.invokeMethod<String>(
      'createAppUpdateDownloadPath',
    );
    if (path == null || path.trim().isEmpty) {
      throw StateError('Android did not provide an update download path.');
    }
    return path;
  }

  @override
  Future<void> installApk(String path) {
    return _channel.invokeMethod<void>('installAppUpdateApk', {'path': path});
  }

  @override
  Future<void> openExternalUrl(String url) {
    return _channel.invokeMethod<void>('openAppUpdateUrl', {'url': url});
  }

  @override
  Future<void> openApplicationMarket() {
    return _channel.invokeMethod<void>('openApplicationMarket');
  }
}

final class DioAppUpdateFileTransfer implements AppUpdateFileTransfer {
  const DioAppUpdateFileTransfer({
    required Dio dio,
    required AppUpdateNativeBridge nativeBridge,
  }) : _dio = dio,
       _nativeBridge = nativeBridge;

  final Dio _dio;
  final AppUpdateNativeBridge _nativeBridge;

  @override
  Future<String> download({
    required String url,
    required void Function(int received, int total) onProgress,
  }) async {
    final path = await _nativeBridge.createDownloadPath();
    await _dio.download(url, path, onReceiveProgress: onProgress);
    return path;
  }

  @override
  Future<void> install(String path) => _nativeBridge.installApk(path);

  @override
  Future<void> openExternal(String url) => _nativeBridge.openExternalUrl(url);

  @override
  Future<void> openMarket() => _nativeBridge.openApplicationMarket();
}
