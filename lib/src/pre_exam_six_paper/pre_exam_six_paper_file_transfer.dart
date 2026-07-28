import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

abstract interface class PreExamSixPaperFileTransfer {
  Future<String> download({
    required String url,
    required String fileName,
    required void Function(int received, int total) onProgress,
  });

  Future<void> share({required String path, required String mimeType});

  void cancel();
}

abstract interface class PreExamSixPaperNativeBridge {
  Future<String> createDownloadPath({required String fileName});

  Future<void> shareFile({required String path, required String mimeType});
}

final class MethodChannelPreExamSixPaperNativeBridge
    implements PreExamSixPaperNativeBridge {
  MethodChannelPreExamSixPaperNativeBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.xmzj.ult.agg/request_context';

  final MethodChannel _channel;

  @override
  Future<String> createDownloadPath({required String fileName}) async {
    final path = await _channel.invokeMethod<String>(
      'createPreExamSixPaperDownloadPath',
      {'fileName': fileName},
    );
    if (path == null || path.trim().isEmpty) {
      throw StateError('Android did not provide a download path.');
    }
    return path;
  }

  @override
  Future<void> shareFile({required String path, required String mimeType}) {
    return _channel.invokeMethod<void>('sharePreExamSixPaperFile', {
      'path': path,
      'mimeType': mimeType,
    });
  }
}

final class DioPreExamSixPaperFileTransfer
    implements PreExamSixPaperFileTransfer {
  DioPreExamSixPaperFileTransfer({
    required Dio dio,
    required PreExamSixPaperNativeBridge nativeBridge,
  }) : _dio = dio,
       _nativeBridge = nativeBridge;

  final Dio _dio;
  final PreExamSixPaperNativeBridge _nativeBridge;
  CancelToken? _activeCancelToken;

  @override
  Future<String> download({
    required String url,
    required String fileName,
    required void Function(int received, int total) onProgress,
  }) async {
    final path = await _nativeBridge.createDownloadPath(fileName: fileName);
    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;
    try {
      await _dio.download(
        url,
        path,
        cancelToken: cancelToken,
        onReceiveProgress: onProgress,
      );
      return path;
    } finally {
      if (identical(_activeCancelToken, cancelToken)) {
        _activeCancelToken = null;
      }
    }
  }

  @override
  Future<void> share({required String path, required String mimeType}) {
    return _nativeBridge.shareFile(path: path, mimeType: mimeType);
  }

  @override
  void cancel() {
    final cancelToken = _activeCancelToken;
    _activeCancelToken = null;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel();
    }
  }
}
