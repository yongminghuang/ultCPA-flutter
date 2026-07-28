import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_entry_page.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_file_transfer.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_landing_page.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_models.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_preview_page.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_repository.dart';

void main() {
  testWidgets('shows loading and retries an entry resolution failure', (
    tester,
  ) async {
    final first = Completer<PreExamSixPaperEntry>();
    final second = Completer<PreExamSixPaperEntry>();
    var attempt = 0;
    final source = _Source(
      resolve: (_) => attempt++ == 0 ? first.future : second.future,
    );

    await tester.pumpWidget(_app(source));
    expect(
      find.byKey(const ValueKey('pre-exam-six-entry-loading')),
      findsOneWidget,
    );

    first.completeError(StateError('offline'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('pre-exam-six-entry-error')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('pre-exam-six-entry-retry')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('pre-exam-six-entry-loading')),
      findsOneWidget,
    );

    second.complete(
      const PreExamSixPaperEntry(PreExamSixPaperEntryDestination.landing),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PreExamSixPaperLandingPage), findsOneWidget);
    expect(source.resolvedModules, [_module, _module]);
  });

  testWidgets('renders the invalid module empty destination', (tester) async {
    final source = _Source(
      resolve: (_) async =>
          const PreExamSixPaperEntry(PreExamSixPaperEntryDestination.empty),
    );

    await tester.pumpWidget(_app(source));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('pre-exam-six-entry-empty')),
      findsOneWidget,
    );
    expect(find.text('暂无考前6页纸内容'), findsOneWidget);
  });

  testWidgets('renders landing and forwards the injected unlock callback', (
    tester,
  ) async {
    var unlockCalls = 0;
    final source = _Source(
      resolve: (_) async =>
          const PreExamSixPaperEntry(PreExamSixPaperEntryDestination.landing),
    );

    await tester.pumpWidget(_app(source, onUnlock: () => unlockCalls += 1));
    await tester.pumpAndSettle();

    expect(find.byType(PreExamSixPaperLandingPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pre-exam-six-landing-unlock')));
    await tester.pump();
    expect(unlockCalls, 1);
  });

  testWidgets('awaits unlock then resolves the unlocked preview once', (
    tester,
  ) async {
    const file = PreExamSixPaperFile(
      name: '考前重点',
      text: '<p>已解锁</p>',
      textUrl: '',
      fileUrl: '',
      htmlBaseUrl: '',
    );
    final unlock = Completer<void>();
    var resolveAttempt = 0;
    var unlockCalls = 0;
    final source = _Source(
      resolve: (_) async => resolveAttempt++ == 0
          ? const PreExamSixPaperEntry(PreExamSixPaperEntryDestination.landing)
          : const PreExamSixPaperEntry(
              PreExamSixPaperEntryDestination.preview,
              file: file,
            ),
    );

    await tester.pumpWidget(
      _app(
        source,
        onUnlock: () {
          unlockCalls += 1;
          return unlock.future;
        },
        contentBuilder:
            (context, {required url, required html, required baseUrl}) =>
                const Text('UNLOCKED-PREVIEW'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pre-exam-six-landing-unlock')));
    await tester.tap(find.byKey(const ValueKey('pre-exam-six-landing-unlock')));
    await tester.pump();

    expect(unlockCalls, 1);
    expect(source.resolvedModules, [_module]);
    expect(find.byType(PreExamSixPaperLandingPage), findsOneWidget);

    unlock.complete();
    await tester.pumpAndSettle();

    expect(source.resolvedModules, [_module, _module]);
    expect(find.byType(PreExamSixPaperPreviewPage), findsOneWidget);
    expect(find.text('UNLOCKED-PREVIEW'), findsOneWidget);
  });

  testWidgets(
    'opens preview with the prefetched file and shared dependencies',
    (tester) async {
      const file = PreExamSixPaperFile(
        name: '考前重点',
        text: '<p>预取内容</p>',
        textUrl: '',
        fileUrl: 'https://cdn.example.com/a.pdf',
        htmlBaseUrl: 'https://cdn.example.com/',
      );
      final source = _Source(
        resolve: (_) async => const PreExamSixPaperEntry(
          PreExamSixPaperEntryDestination.preview,
          file: file,
        ),
      );
      final transfer = _Transfer();

      await tester.pumpWidget(
        _app(
          source,
          transfer: transfer,
          contentBuilder:
              (context, {required url, required html, required baseUrl}) {
                return Text('CONTENT:$baseUrl:${html != null}');
              },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PreExamSixPaperPreviewPage), findsOneWidget);
      expect(
        find.text('CONTENT:https://cdn.example.com/:true'),
        findsOneWidget,
      );
      expect(source.resolvedModules, [_module]);
      expect(source.loadedModules, isEmpty);
      final preview = tester.widget<PreExamSixPaperPreviewPage>(
        find.byType(PreExamSixPaperPreviewPage),
      );
      expect(preview.initialFile, same(file));
      expect(preview.dataSource, same(source));
      expect(preview.fileTransfer, same(transfer));
    },
  );

  testWidgets('unavailable entry reports a message and returns', (
    tester,
  ) async {
    final source = _Source(
      resolve: (_) async => const PreExamSixPaperEntry(
        PreExamSixPaperEntryDestination.unavailable,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: _EntryHarness(source: source, transfer: _Transfer()),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('host'), findsOneWidget);
    expect(find.byType(PreExamSixPaperEntryPage), findsNothing);
    expect(find.text('入口数据加载中，请稍后重试'), findsOneWidget);
  });
}

Widget _app(
  PreExamSixPaperDataSource source, {
  _Transfer? transfer,
  FutureOr<void> Function()? onUnlock,
  PreExamSixPaperContentBuilder? contentBuilder,
}) {
  return MaterialApp(
    home: PreExamSixPaperEntryPage(
      module: _module,
      dataSource: source,
      fileTransfer: transfer ?? _Transfer(),
      onUnlock: onUnlock,
      contentBuilder: contentBuilder,
    ),
  );
}

const _module = HomeModule(id: 46, name: '考前6页纸', page: '考前6页纸', tag: '');

typedef _EntryResolver =
    Future<PreExamSixPaperEntry> Function(HomeModule module);

final class _Source implements PreExamSixPaperDataSource {
  _Source({required this.resolve});

  final _EntryResolver resolve;
  final List<HomeModule> resolvedModules = [];
  final List<HomeModule> loadedModules = [];

  @override
  Future<PreExamSixPaperEntry> resolveEntry(HomeModule module) {
    resolvedModules.add(module);
    return resolve(module);
  }

  @override
  Future<PreExamSixPaperFile> loadFile(HomeModule module) {
    loadedModules.add(module);
    throw StateError('unexpected preview load');
  }
}

final class _Transfer implements PreExamSixPaperFileTransfer {
  @override
  Future<String> download({
    required String url,
    required String fileName,
    required void Function(int received, int total) onProgress,
  }) {
    throw StateError('unexpected download');
  }

  @override
  Future<void> share({required String path, required String mimeType}) {
    throw StateError('unexpected share');
  }

  @override
  void cancel() {}
}

final class _EntryHarness extends StatelessWidget {
  const _EntryHarness({required this.source, required this.transfer});

  final PreExamSixPaperDataSource source;
  final PreExamSixPaperFileTransfer transfer;

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
                  builder: (_) => PreExamSixPaperEntryPage(
                    module: _module,
                    dataSource: source,
                    fileTransfer: transfer,
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
