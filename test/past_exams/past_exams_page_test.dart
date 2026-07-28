import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/exam/exam_models.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/past_exams/past_exams_models.dart';
import 'package:ultcpa_flutter/src/past_exams/past_exams_page.dart';
import 'package:ultcpa_flutter/src/past_exams/past_exams_repository.dart';

void main() {
  testWidgets('shows loading, retries a failure, and renders empty', (
    tester,
  ) async {
    final first = Completer<PastExamsCatalog>();
    final second = Completer<PastExamsCatalog>();
    var attempt = 0;
    final source = _Source(
      load: (_) => attempt++ == 0 ? first.future : second.future,
    );
    await tester.pumpWidget(_app(source: source));

    expect(find.byKey(const ValueKey('past-exams-loading')), findsOneWidget);
    first.completeError(StateError('offline'));
    await tester.pump();
    expect(find.byKey(const ValueKey('past-exams-error')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('past-exams-retry')));
    await tester.pump();
    expect(find.byKey(const ValueKey('past-exams-loading')), findsOneWidget);
    second.complete(_catalog(fullAccess: false, count: 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('past-exams-empty')), findsOneWidget);
    expect(find.text('暂无历年真题卷'), findsOneWidget);
    expect(source.modules, [_module, _module]);
  });

  testWidgets('preserves rows, launches free papers, and guards duplicates', (
    tester,
  ) async {
    final source = _Source(load: (_) async => _catalog(fullAccess: false));
    final pending = Completer<void>();
    final requests = <ExamRequest>[];
    await tester.pumpWidget(
      _app(
        source: source,
        examLauncher: (context, request) {
          requests.add(request);
          return pending.future;
        },
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('past-exams-list')), findsOneWidget);
    expect(find.text('真题一'), findsOneWidget);
    expect(find.text('真题二'), findsOneWidget);
    expect(find.text('真题三'), findsOneWidget);
    expect(find.byKey(const ValueKey('past-exams-start-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('past-exams-start-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('past-exams-unlock-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('past-exams-unlock-3')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('past-exams-start-1')));
    await tester.pump();
    expect(requests, hasLength(1));
    expect(requests.single.module, same(_module));
    expect(requests.single.shelfId, 12);
    expect(requests.single.title, '真题二');
    expect(requests.single.duration, const Duration(minutes: 135));
    final start = tester.widget<FilledButton>(
      find.byKey(const ValueKey('past-exams-start-1')),
    );
    expect(start.onPressed, isNull);
    pending.complete();
    await tester.pump();
  });

  testWidgets('default locked action keeps the payment boundary honest', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(source: _Source(load: (_) async => _catalog(fullAccess: false))),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('past-exams-unlock-2')));
    await tester.pump();

    expect(find.text('历年真题卷需解锁，会员与支付功能仍在迁移中'), findsOneWidget);
  });

  testWidgets('injected unlock reloads access and ignores duplicate taps', (
    tester,
  ) async {
    final pending = Completer<void>();
    var unlockCalls = 0;
    var loadCalls = 0;
    final source = _Source(
      load: (_) async => _catalog(fullAccess: loadCalls++ > 0),
    );
    await tester.pumpWidget(
      _app(
        source: source,
        onUnlock: () {
          unlockCalls += 1;
          return pending.future;
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('past-exams-unlock-2')));
    await tester.pump();
    expect(unlockCalls, 1);
    final unlock = tester.widget<TextButton>(
      find.byKey(const ValueKey('past-exams-unlock-2')),
    );
    expect(unlock.onPressed, isNull);

    pending.complete();
    await tester.pumpAndSettle();
    expect(source.modules, [_module, _module]);
    expect(find.byKey(const ValueKey('past-exams-unlock-2')), findsNothing);
    expect(find.byKey(const ValueKey('past-exams-start-2')), findsOneWidget);
  });

  testWidgets('back returns and ignores a stale catalog completion', (
    tester,
  ) async {
    final pending = Completer<PastExamsCatalog>();
    final source = _Source(load: (_) => pending.future);
    await tester.pumpWidget(MaterialApp(home: _Harness(source: source)));

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PastExamsPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('past-exams-back')));
    await tester.pumpAndSettle();
    expect(find.text('host'), findsOneWidget);

    pending.complete(_catalog(fullAccess: false));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits the Android list on a 320 by 568 viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(source: _Source(load: (_) async => _catalog(fullAccess: false))),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('past-exams-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('past-exams-start-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required PastExamsDataSource source,
  PastExamLauncher? examLauncher,
  PastExamsUnlockLauncher? onUnlock,
}) {
  return MaterialApp(
    home: PastExamsPage(
      module: _module,
      dataSource: source,
      examLauncher: examLauncher ?? (context, request) => Future<void>.value(),
      onUnlock: onUnlock,
    ),
  );
}

PastExamsCatalog _catalog({required bool fullAccess, int count = 4}) {
  return PastExamsCatalog(
    module: _module,
    hasFullAccess: fullAccess,
    papers: [
      for (var index = 0; index < count; index += 1)
        PastExamPaper(
          id: index + 11,
          name: '真题${['一', '二', '三', '四'][index]}',
          type: '扁平化',
          locked: !fullAccess && index >= 2,
        ),
    ],
  );
}

const _module = HomeModule(
  id: 51,
  name: '历年真题卷',
  page: '历年真题卷',
  tag: '',
  type: '嵌套化',
);

typedef _Loader = Future<PastExamsCatalog> Function(HomeModule module);

final class _Source implements PastExamsDataSource {
  _Source({required this.load});

  final _Loader load;
  final List<HomeModule> modules = [];

  @override
  Future<PastExamsCatalog> loadCatalog(HomeModule module) {
    modules.add(module);
    return load(module);
  }
}

final class _Harness extends StatelessWidget {
  const _Harness({required this.source});

  final PastExamsDataSource source;

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
                  builder: (_) => PastExamsPage(
                    module: _module,
                    dataSource: source,
                    examLauncher: (context, request) {},
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
