import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_file_transfer.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_models.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_preview_page.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_repository.dart';

void main() {
  testWidgets('prefetched file skips I/O, limits title, and prefers textUrl', (
    tester,
  ) async {
    final dataSource = _DataSource((_) => throw StateError('unexpected load'));
    final transfer = _Transfer();
    final contentCalls = <_ContentCall>[];

    await tester.pumpWidget(
      MaterialApp(
        home: PreExamSixPaperPreviewPage(
          module: _module,
          initialFile: _file(
            name: 'ABCDEFGHIJK',
            text: '<p>inline must not win</p>',
            textUrl: 'https://cdn.example.com/six.html',
          ),
          dataSource: dataSource,
          fileTransfer: transfer,
          contentBuilder: _contentBuilder(contentCalls),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('ABCDEFGHIJ..'), findsOneWidget);
    expect(dataSource.loadCalls, isEmpty);
    expect(
      find.byKey(const ValueKey('pre-exam-six-preview-content')),
      findsOneWidget,
    );
    expect(contentCalls.last.url, 'https://cdn.example.com/six.html');
    expect(contentCalls.last.html, isNull);
    expect(contentCalls.last.baseUrl, 'https://cdn.example.com/root/');
  });

  testWidgets('loads on demand and wraps inline HTML with its base URL', (
    tester,
  ) async {
    final pending = Completer<PreExamSixPaperFile>();
    final dataSource = _DataSource((_) => pending.future);
    final contentCalls = <_ContentCall>[];

    await tester.pumpWidget(
      MaterialApp(
        home: PreExamSixPaperPreviewPage(
          module: _module,
          dataSource: dataSource,
          fileTransfer: _Transfer(),
          contentBuilder: _contentBuilder(contentCalls),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('pre-exam-six-preview-loading')),
      findsOneWidget,
    );
    expect(dataSource.loadCalls, [_module]);

    pending.complete(
      _file(text: '<p>重点<img src="images/a.png"></p>', textUrl: ''),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('pre-exam-six-preview-content')),
      findsOneWidget,
    );
    expect(contentCalls.last.url, isNull);
    expect(contentCalls.last.baseUrl, 'https://cdn.example.com/root/');
    expect(contentCalls.last.html, contains('<p>重点'));
    expect(
      contentCalls.last.html,
      contains('https://cdn.example.com/root/images/a.png'),
    );
  });

  testWidgets('load failure reports the network error and shows empty state', (
    tester,
  ) async {
    final pending = Completer<PreExamSixPaperFile>();
    await tester.pumpWidget(
      MaterialApp(
        home: PreExamSixPaperPreviewPage(
          module: _module,
          dataSource: _DataSource((_) => pending.future),
          fileTransfer: _Transfer(),
          contentBuilder: _contentBuilder([]),
        ),
      ),
    );
    await tester.pump();

    pending.completeError(StateError('offline'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('pre-exam-six-preview-empty')),
      findsOneWidget,
    );
    expect(find.text('题库更新中'), findsOneWidget);
    expect(find.text('网络开小差了，请稍后重试'), findsOneWidget);
  });

  testWidgets('empty or invalid content renders the stable empty state', (
    tester,
  ) async {
    for (final file in <PreExamSixPaperFile>[
      _file(text: '', textUrl: ''),
      _file(text: '<p>ignored</p>', textUrl: 'not a valid URL'),
    ]) {
      final contentCalls = <_ContentCall>[];
      await tester.pumpWidget(
        MaterialApp(
          home: PreExamSixPaperPreviewPage(
            module: _module,
            initialFile: file,
            dataSource: _DataSource((_) => throw StateError('unexpected load')),
            fileTransfer: _Transfer(),
            contentBuilder: _contentBuilder(contentCalls),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('pre-exam-six-preview-empty')),
        findsOneWidget,
      );
      expect(find.text('题库更新中'), findsOneWidget);
      expect(contentCalls, isEmpty);
    }
  });

  testWidgets('missing file URL reports that no download is available', (
    tester,
  ) async {
    final transfer = _Transfer();
    await tester.pumpWidget(
      MaterialApp(
        home: PreExamSixPaperPreviewPage(
          module: _module,
          initialFile: _file(fileUrl: ''),
          dataSource: _DataSource((_) => throw StateError('unexpected load')),
          fileTransfer: transfer,
          contentBuilder: _contentBuilder([]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('pre-exam-six-preview-download')),
    );
    await tester.pump();

    expect(find.text('暂无可用文件下载'), findsOneWidget);
    expect(transfer.downloads, isEmpty);
  });

  testWidgets(
    'downloads once, reports progress, and shares the completed PDF',
    (tester) async {
      final transfer = _Transfer();
      await tester.pumpWidget(
        MaterialApp(
          home: PreExamSixPaperPreviewPage(
            module: _module,
            initialFile: _file(name: '冲刺资料', fileUrl: 'https://cdn/a.pdf'),
            dataSource: _DataSource((_) => throw StateError('unexpected load')),
            fileTransfer: transfer,
            contentBuilder: _contentBuilder([]),
            fileExists: (_) => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final download = find.byKey(
        const ValueKey('pre-exam-six-preview-download'),
      );
      final downloadButton = tester.widget<TextButton>(download);
      downloadButton.onPressed!();
      downloadButton.onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(transfer.downloads, hasLength(1));
      expect(transfer.downloads.single.url, 'https://cdn/a.pdf');
      expect(transfer.downloads.single.fileName, '冲刺资料.pdf');
      expect(
        find.byKey(const ValueKey('pre-exam-six-download-progress')),
        findsOneWidget,
      );

      transfer.downloads.single.onProgress(50, 100);
      await tester.pump();
      expect(find.text('50%'), findsOneWidget);

      transfer.downloads.single.completer.complete('/cache/冲刺资料.pdf');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('pre-exam-six-download-complete')),
        findsOneWidget,
      );
      expect(find.text('/cache/冲刺资料.pdf'), findsOneWidget);

      final share = find.byKey(const ValueKey('pre-exam-six-download-share'));
      await tester.tap(share);
      await tester.tap(share);
      await tester.pump();
      expect(transfer.shares, hasLength(1));
      expect(transfer.shares.single.path, '/cache/冲刺资料.pdf');
      expect(transfer.shares.single.mimeType, 'application/pdf');

      transfer.shares.single.completer.complete();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pre-exam-six-download-complete')),
        findsNothing,
      );
    },
  );

  testWidgets('reuses an existing file and redownloads it after deletion', (
    tester,
  ) async {
    var exists = true;
    final transfer = _Transfer();
    await tester.pumpWidget(
      MaterialApp(
        home: PreExamSixPaperPreviewPage(
          module: _module,
          initialFile: _file(),
          dataSource: _DataSource((_) => throw StateError('unexpected load')),
          fileTransfer: transfer,
          contentBuilder: _contentBuilder([]),
          fileExists: (_) => exists,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final download = find.byKey(
      const ValueKey('pre-exam-six-preview-download'),
    );
    await tester.tap(download);
    await tester.pump();
    transfer.downloads.single.completer.complete('/cache/guide.pdf');
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(download);
    await tester.pumpAndSettle();
    expect(transfer.downloads, hasLength(1));
    expect(find.text('/cache/guide.pdf'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    exists = false;
    await tester.tap(download);
    await tester.pump();
    expect(transfer.downloads, hasLength(2));
    expect(
      find.byKey(const ValueKey('pre-exam-six-download-progress')),
      findsOneWidget,
    );
    transfer.downloads.last.completer.complete('/cache/guide-new.pdf');
    await tester.pumpAndSettle();
    expect(find.text('/cache/guide-new.pdf'), findsOneWidget);
  });

  testWidgets('default existence check reuses a real downloaded file', (
    tester,
  ) async {
    final downloaded = File(
      'test/pre_exam_six_paper/pre_exam_six_paper_preview_page_test.dart',
    ).absolute;
    expect(downloaded.existsSync(), isTrue);
    final transfer = _Transfer();
    await tester.pumpWidget(
      MaterialApp(
        home: PreExamSixPaperPreviewPage(
          module: _module,
          initialFile: _file(),
          dataSource: _DataSource((_) => throw StateError('unexpected load')),
          fileTransfer: transfer,
          contentBuilder: _contentBuilder([]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final download = find.byKey(
      const ValueKey('pre-exam-six-preview-download'),
    );
    await tester.tap(download);
    await tester.pump();
    transfer.downloads.single.completer.complete(downloaded.path);
    await _pumpDialogTransitions(tester);
    await tester.tap(find.text('关闭'));
    await _pumpDialogTransitions(tester);

    await tester.tap(download);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    if (transfer.downloads.length > 1) {
      transfer.downloads.last.completer.complete('/cache/unexpected.pdf');
      await tester.pumpAndSettle();
    }

    expect(transfer.downloads, hasLength(1));
    expect(find.text(downloaded.path), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await _pumpDialogTransitions(tester);
  });

  testWidgets(
    'download failure dismisses progress and reports a retryable error',
    (tester) async {
      final transfer = _Transfer();
      await tester.pumpWidget(
        MaterialApp(
          home: PreExamSixPaperPreviewPage(
            module: _module,
            initialFile: _file(),
            dataSource: _DataSource((_) => throw StateError('unexpected load')),
            fileTransfer: transfer,
            contentBuilder: _contentBuilder([]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('pre-exam-six-preview-download')),
      );
      await tester.pump();
      transfer.downloads.single.completer.completeError(StateError('offline'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey('pre-exam-six-download-progress')),
        findsNothing,
      );
      expect(find.text('下载失败，请稍后重试'), findsOneWidget);
    },
  );

  testWidgets('share failure preserves the file and permits a guarded retry', (
    tester,
  ) async {
    final transfer = _Transfer();
    await tester.pumpWidget(
      MaterialApp(
        home: PreExamSixPaperPreviewPage(
          module: _module,
          initialFile: _file(fileUrl: 'https://cdn/a.bin'),
          dataSource: _DataSource((_) => throw StateError('unexpected load')),
          fileTransfer: transfer,
          contentBuilder: _contentBuilder([]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('pre-exam-six-preview-download')),
    );
    await tester.pump();
    transfer.downloads.single.completer.complete('/cache/a.bin');
    await tester.pumpAndSettle();

    final share = find.byKey(const ValueKey('pre-exam-six-download-share'));
    await tester.tap(share);
    await tester.tap(share);
    await tester.pump();
    expect(transfer.shares, hasLength(1));
    expect(transfer.shares.single.mimeType, '*/*');
    transfer.shares.single.completer.completeError(StateError('share failed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('分享失败'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pre-exam-six-download-complete')),
      findsOneWidget,
    );

    await tester.tap(share);
    await tester.pump();
    expect(transfer.shares, hasLength(2));
    transfer.shares.last.completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('dispose cancels transfer and ignores stale completions', (
    tester,
  ) async {
    final transfer = _Transfer();
    await tester.pumpWidget(
      MaterialApp(
        home: PreExamSixPaperPreviewPage(
          module: _module,
          initialFile: _file(),
          dataSource: _DataSource((_) => throw StateError('unexpected load')),
          fileTransfer: transfer,
          contentBuilder: _contentBuilder([]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('pre-exam-six-preview-download')),
    );
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(transfer.cancelCalls, 1);

    transfer.downloads.single.completer.complete('/cache/stale.pdf');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDialogTransitions(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

PreExamSixPaperContentBuilder _contentBuilder(List<_ContentCall> calls) {
  return (context, {required url, required html, required baseUrl}) {
    calls.add(_ContentCall(url: url, html: html, baseUrl: baseUrl));
    return Text(url ?? html ?? 'empty');
  };
}

PreExamSixPaperFile _file({
  String name = '考前重点',
  String text = '<p>重点</p>',
  String textUrl = '',
  String fileUrl = 'https://cdn.example.com/guide.pdf',
}) {
  return PreExamSixPaperFile(
    name: name,
    text: text,
    textUrl: textUrl,
    fileUrl: fileUrl,
    htmlBaseUrl: 'https://cdn.example.com/root/',
  );
}

const _module = HomeModule(id: 46, name: '考前6页纸', page: '考前6页纸', tag: '');

final class _ContentCall {
  const _ContentCall({
    required this.url,
    required this.html,
    required this.baseUrl,
  });

  final String? url;
  final String? html;
  final String baseUrl;
}

final class _DataSource implements PreExamSixPaperDataSource {
  _DataSource(this.loader);

  final Future<PreExamSixPaperFile> Function(HomeModule module) loader;
  final List<HomeModule> loadCalls = [];

  @override
  Future<PreExamSixPaperFile> loadFile(HomeModule module) {
    loadCalls.add(module);
    return loader(module);
  }

  @override
  Future<PreExamSixPaperEntry> resolveEntry(HomeModule module) {
    throw StateError('unexpected entry resolution');
  }
}

final class _Transfer implements PreExamSixPaperFileTransfer {
  final List<_DownloadCall> downloads = [];
  final List<_ShareCall> shares = [];
  int cancelCalls = 0;

  @override
  Future<String> download({
    required String url,
    required String fileName,
    required void Function(int received, int total) onProgress,
  }) {
    final call = _DownloadCall(
      url: url,
      fileName: fileName,
      onProgress: onProgress,
    );
    downloads.add(call);
    return call.completer.future;
  }

  @override
  Future<void> share({required String path, required String mimeType}) {
    final call = _ShareCall(path: path, mimeType: mimeType);
    shares.add(call);
    return call.completer.future;
  }

  @override
  void cancel() {
    cancelCalls += 1;
  }
}

final class _DownloadCall {
  _DownloadCall({
    required this.url,
    required this.fileName,
    required this.onProgress,
  });

  final String url;
  final String fileName;
  final void Function(int received, int total) onProgress;
  final Completer<String> completer = Completer<String>();
}

final class _ShareCall {
  _ShareCall({required this.path, required this.mimeType});

  final String path;
  final String mimeType;
  final Completer<void> completer = Completer<void>();
}
