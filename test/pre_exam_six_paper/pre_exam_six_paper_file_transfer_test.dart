import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_file_transfer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    MethodChannelPreExamSixPaperNativeBridge.channelName,
  );

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'uses the exact native cache path and share channel contracts',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'createPreExamSixPaperDownloadPath') {
              return '/cache/pre_exam_six_paper/review.pdf';
            }
            return null;
          });
      final bridge = MethodChannelPreExamSixPaperNativeBridge();

      final path = await bridge.createDownloadPath(fileName: 'review.pdf');
      await bridge.shareFile(path: path, mimeType: 'application/pdf');

      expect(path, '/cache/pre_exam_six_paper/review.pdf');
      expect(calls, hasLength(2));
      expect(calls[0].method, 'createPreExamSixPaperDownloadPath');
      expect(calls[0].arguments, {'fileName': 'review.pdf'});
      expect(calls[1].method, 'sharePreExamSixPaperFile');
      expect(calls[1].arguments, {
        'path': '/cache/pre_exam_six_paper/review.pdf',
        'mimeType': 'application/pdf',
      });
    },
  );

  test('downloads bytes to the native path and reports progress', () async {
    final temp = await Directory.systemTemp.createTemp('six-paper-download-');
    addTearDown(() => temp.delete(recursive: true));
    final path = '${temp.path}${Platform.pathSeparator}review.pdf';
    final adapter = _BytesAdapter([
      Uint8List.fromList([1, 2]),
      Uint8List.fromList([3, 4]),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final bridge = _FakeBridge(path);
    final transfer = DioPreExamSixPaperFileTransfer(
      dio: dio,
      nativeBridge: bridge,
    );
    final progress = <(int, int)>[];

    final result = await transfer.download(
      url: 'https://cdn.example.com/review.pdf',
      fileName: 'review.pdf',
      onProgress: (received, total) => progress.add((received, total)),
    );

    expect(result, path);
    expect(await File(path).readAsBytes(), [1, 2, 3, 4]);
    expect(adapter.requestedUrls, ['https://cdn.example.com/review.pdf']);
    expect(bridge.fileNames, ['review.pdf']);
    expect(progress, isNotEmpty);
    expect(progress.last, (4, 4));
  });

  test('delegates an existing download to the native share bridge', () async {
    final bridge = _FakeBridge('/cache/review.pdf');
    final transfer = DioPreExamSixPaperFileTransfer(
      dio: Dio(),
      nativeBridge: bridge,
    );

    await transfer.share(
      path: '/cache/review.pdf',
      mimeType: 'application/pdf',
    );

    expect(bridge.shares, [('/cache/review.pdf', 'application/pdf')]);
  });

  test(
    'cancel is idempotent and the next download gets a fresh token',
    () async {
      final temp = await Directory.systemTemp.createTemp('six-paper-cancel-');
      addTearDown(() => temp.delete(recursive: true));
      final path = '${temp.path}${Platform.pathSeparator}review.pdf';
      final adapter = _CancelThenSuccessAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final transfer = DioPreExamSixPaperFileTransfer(
        dio: dio,
        nativeBridge: _FakeBridge(path),
      );

      final cancelled = transfer.download(
        url: 'https://cdn.example.com/slow.pdf',
        fileName: 'review.pdf',
        onProgress: (_, _) {},
      );
      await adapter.firstRequestStarted.future;
      transfer.cancel();
      transfer.cancel();

      await expectLater(
        cancelled,
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );

      final completed = await transfer.download(
        url: 'https://cdn.example.com/retry.pdf',
        fileName: 'review.pdf',
        onProgress: (_, _) {},
      );

      expect(completed, path);
      expect(await File(path).readAsBytes(), [7, 8, 9]);
      expect(adapter.fetchCalls, 2);
    },
  );
}

final class _FakeBridge implements PreExamSixPaperNativeBridge {
  _FakeBridge(this.path);

  final String path;
  final List<String> fileNames = [];
  final List<(String, String)> shares = [];

  @override
  Future<String> createDownloadPath({required String fileName}) async {
    fileNames.add(fileName);
    return path;
  }

  @override
  Future<void> shareFile({
    required String path,
    required String mimeType,
  }) async {
    shares.add((path, mimeType));
  }
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

final class _CancelThenSuccessAdapter implements HttpClientAdapter {
  final Completer<void> firstRequestStarted = Completer<void>();
  int fetchCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCalls += 1;
    if (fetchCalls == 1) {
      firstRequestStarted.complete();
      await cancelFuture;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      );
    }
    return ResponseBody.fromBytes(
      [7, 8, 9],
      200,
      headers: {
        Headers.contentLengthHeader: ['3'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
