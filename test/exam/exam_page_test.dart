import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/exam/exam_models.dart';
import 'package:ultcpa_flutter/src/exam/exam_page.dart';
import 'package:ultcpa_flutter/src/exam/exam_repository.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/practice/practice_models.dart';

void main() {
  testWidgets('shows loading, retries a failure, and renders empty', (
    tester,
  ) async {
    final first = Completer<ExamCatalog>();
    final second = Completer<ExamCatalog>();
    var attempt = 0;
    final source = _Source(
      load: (_) => attempt++ == 0 ? first.future : second.future,
    );

    await tester.pumpWidget(_app(source: source));
    expect(find.byKey(const ValueKey('exam-loading')), findsOneWidget);

    first.completeError(StateError('offline'));
    await tester.pump();
    expect(find.byKey(const ValueKey('exam-error')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('exam-retry')));
    await tester.pump();
    expect(find.byKey(const ValueKey('exam-loading')), findsOneWidget);

    second.complete(ExamCatalog(request: _request, questions: const []));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('exam-empty')), findsOneWidget);
    expect(find.text('暂无考试题目'), findsOneWidget);
    expect(source.loadRequests, [_request, _request]);
  });

  testWidgets('edits selections without revealing correctness before hand-in', (
    tester,
  ) async {
    final source = _loadedSource();
    await tester.pumpWidget(_app(source: source));
    await tester.pump();

    expect(find.byKey(const ValueKey('exam-question')), findsOneWidget);
    expect(find.text('1. 题目 1'), findsOneWidget);
    expect(find.text('解析 1'), findsNothing);
    expect(find.text('正确答案：B'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('exam-option-A')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('exam-option-selected-A')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('exam-option-B')));
    await tester.pump();
    expect(find.byKey(const ValueKey('exam-option-selected-A')), findsNothing);
    expect(
      find.byKey(const ValueKey('exam-option-selected-B')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('exam-next')));
    await tester.pump();
    expect(find.text('2. 题目 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('exam-option-C')));
    await tester.tap(find.byKey(const ValueKey('exam-option-A')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('exam-option-selected-A')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('exam-option-selected-C')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('exam-option-C')));
    await tester.pump();
    expect(find.byKey(const ValueKey('exam-option-selected-C')), findsNothing);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('exam-countdown')), findsOneWidget);
  });

  testWidgets('answer card uses six columns and jumps to a question', (
    tester,
  ) async {
    await tester.pumpWidget(_app(source: _loadedSource()));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('exam-option-B')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('exam-answer-card')));
    await tester.pumpAndSettle();

    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 6);
    expect(find.byKey(const ValueKey('exam-answer-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('exam-answer-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('exam-answer-2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('exam-answer-1')));
    await tester.pumpAndSettle();
    expect(find.text('2. 题目 2'), findsOneWidget);
  });

  testWidgets('confirms hand-in once and launches a successful result', (
    tester,
  ) async {
    final pending = Completer<void>();
    final source = _Source(
      load: (_) async => _catalog(_request),
      submit: (_) => pending.future,
    );
    ExamResult? captured;
    bool? capturedUploadFailed;
    var launchCalls = 0;
    await tester.pumpWidget(
      _app(
        source: source,
        resultLauncher: (context, {required result, required uploadFailed}) {
          launchCalls += 1;
          captured = result;
          capturedUploadFailed = uploadFailed;
        },
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('exam-option-B')));
    await tester.tap(find.byKey(const ValueKey('exam-submit')));
    await tester.pumpAndSettle();

    expect(find.text('仍有 2 道题未作答，确认交卷吗？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('exam-confirm-submit')));
    await tester.pump();
    expect(source.submitResults, hasLength(1));
    expect(launchCalls, 0);
    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey('exam-submit')),
    );
    expect(submit.onPressed, isNull);

    pending.complete();
    await tester.pump();
    expect(launchCalls, 1);
    expect(capturedUploadFailed, isFalse);
    expect(captured?.answeredCount, 1);
    expect(captured?.rightCount, 1);
  });

  testWidgets('upload failure remains a non-blocking result flag', (
    tester,
  ) async {
    final source = _Source(
      load: (_) async => _catalog(_request),
      submit: (_) => throw StateError('submit offline'),
    );
    bool? capturedUploadFailed;
    await tester.pumpWidget(
      _app(
        source: source,
        resultLauncher: (context, {required result, required uploadFailed}) {
          capturedUploadFailed = uploadFailed;
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('exam-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('exam-confirm-submit')));
    await tester.pump();

    expect(capturedUploadFailed, isTrue);
  });

  testWidgets('countdown expiry automatically hands in through one path', (
    tester,
  ) async {
    final source = _Source(load: (_) async => _catalog(_shortRequest));
    var launchCalls = 0;
    ExamResult? capturedResult;
    await tester.pumpWidget(
      _app(
        source: source,
        request: _shortRequest,
        resultLauncher: (context, {required result, required uploadFailed}) {
          launchCalls += 1;
          capturedResult = result;
        },
      ),
    );
    await tester.pump();

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(source.submitResults, hasLength(1));
    expect(launchCalls, 1);
    expect(capturedResult?.elapsed, const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('exam-confirm-submit')), findsNothing);
  });

  testWidgets('back confirms abandonment and ignores a stale load completion', (
    tester,
  ) async {
    final pending = Completer<ExamCatalog>();
    final source = _Source(load: (_) => pending.future);
    await tester.pumpWidget(MaterialApp(home: _Harness(source: source)));

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ExamPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('exam-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('考试进行中，确认退出吗？'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('exam-confirm-abandon')));
    await tester.pumpAndSettle();
    expect(find.text('host'), findsOneWidget);
    expect(find.byType(ExamPage), findsNothing);

    pending.complete(_catalog(_request));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposed submit completion never launches a result', (
    tester,
  ) async {
    final pending = Completer<void>();
    final source = _Source(
      load: (_) async => _catalog(_request),
      submit: (_) => pending.future,
    );
    var launchCalls = 0;
    await tester.pumpWidget(
      _app(
        source: source,
        resultLauncher: (context, {required result, required uploadFailed}) {
          launchCalls += 1;
        },
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('exam-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('exam-confirm-submit')));
    await tester.pump();
    expect(source.submitResults, hasLength(1));

    await tester.pumpWidget(const SizedBox());
    pending.complete();
    await tester.pump();
    expect(launchCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits the exam controls on a 320 by 568 viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(source: _loadedSource()));
    await tester.pump();

    expect(find.byKey(const ValueKey('exam-question')), findsOneWidget);
    expect(find.byKey(const ValueKey('exam-submit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required ExamDataSource source,
  ExamRequest request = _request,
  ExamResultLauncher? resultLauncher,
}) {
  return MaterialApp(
    home: ExamPage(
      request: request,
      dataSource: source,
      resultLauncher:
          resultLauncher ??
          (context, {required result, required uploadFailed}) {},
    ),
  );
}

_Source _loadedSource() => _Source(load: (_) async => _catalog(_request));

ExamCatalog _catalog(ExamRequest request) {
  return ExamCatalog(
    request: request,
    questions: [
      _question('1', questionType: '单选题', answer: 'B'),
      _question('2', questionType: '多选题', answer: 'AB'),
      _question('3', questionType: '判断题', answer: 'A'),
    ],
  );
}

PracticeQuestion _question(
  String id, {
  required String questionType,
  required String answer,
}) {
  return PracticeQuestion.fromMap({
    'questionId': id,
    'title': '题目 $id',
    'questionType': questionType,
    'options': {'A': '选项 A', 'B': '选项 B', 'C': '选项 C'},
    'answer': answer,
    'analysis': '解析 $id',
  });
}

const _request = ExamRequest(module: _module, shelfId: 901, title: '真题一');

const _shortRequest = ExamRequest(
  module: _module,
  shelfId: 901,
  title: '真题一',
  duration: Duration(seconds: 3),
);

const _module = HomeModule(
  id: 51,
  name: '历年真题卷',
  page: '历年真题卷',
  tag: '',
  type: '嵌套化',
);

typedef _Loader = Future<ExamCatalog> Function(ExamRequest request);
typedef _Submitter = Future<void> Function(ExamResult result);

final class _Source implements ExamDataSource {
  _Source({required _Loader load, _Submitter? submit})
    : loader = load,
      submitter = submit;

  final _Loader loader;
  final _Submitter? submitter;
  final List<ExamRequest> loadRequests = [];
  final List<ExamResult> submitResults = [];

  @override
  Future<ExamCatalog> load(ExamRequest request) {
    loadRequests.add(request);
    return loader(request);
  }

  @override
  Future<void> submit(ExamResult result) {
    submitResults.add(result);
    return submitter?.call(result) ?? Future<void>.value();
  }
}

final class _Harness extends StatelessWidget {
  const _Harness({required this.source});

  final ExamDataSource source;

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
                  builder: (_) => ExamPage(
                    request: _request,
                    dataSource: source,
                    resultLauncher:
                        (context, {required result, required uploadFailed}) {},
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
