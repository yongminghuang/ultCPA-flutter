import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/fast_practice/fast_practice_catalog_page.dart';
import 'package:ultcpa_flutter/src/fast_practice/fast_practice_models.dart';
import 'package:ultcpa_flutter/src/fast_practice/fast_practice_repository.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/practice/practice_models.dart';
import 'package:ultcpa_flutter/src/practice/practice_page.dart';
import 'package:ultcpa_flutter/src/practice/practice_repository.dart';

void main() {
  testWidgets('renders loading, retry, fallback title, and server leaf order', (
    tester,
  ) async {
    final pending = Completer<FastPracticeCatalog>();
    var calls = 0;
    final source = _Source((module) {
      calls += 1;
      return calls == 1 ? pending.future : Future.value(_catalog(module));
    });

    await tester.pumpWidget(_app(source: source, module: _unnamedModule));
    expect(
      find.byKey(const ValueKey('fast-practice-catalog-loading')),
      findsOneWidget,
    );

    pending.completeError(StateError('offline'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('fast-practice-catalog-error')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('fast-practice-catalog-retry')));
    await tester.pumpAndSettle();

    expect(find.text('速成200题'), findsOneWidget);
    expect(find.text('精选一'), findsOneWidget);
    expect(find.text('精选二'), findsOneWidget);
    final first = tester.getTopLeft(
      find.byKey(const ValueKey('fast-practice-leaf-111')),
    );
    final second = tester.getTopLeft(
      find.byKey(const ValueKey('fast-practice-leaf-222')),
    );
    expect(first.dy, lessThan(second.dy));
    expect(calls, 2);
  });

  testWidgets('renders the Android empty state', (tester) async {
    final source = _Source(
      (module) async => FastPracticeCatalog(module: module, leaves: const []),
    );

    await tester.pumpWidget(_app(source: source));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('fast-practice-catalog-empty')),
      findsOneWidget,
    );
    expect(find.text('暂无速成练习内容'), findsOneWidget);
  });

  testWidgets('launches the exact selected leaf request without reloading', (
    tester,
  ) async {
    final source = _Source((module) async => _catalog(module));
    final launched = <FastPracticeRequest>[];

    await tester.pumpWidget(
      _app(
        source: source,
        launcher: (_, request) async => launched.add(request),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fast-practice-leaf-222')));
    await tester.pumpAndSettle();

    expect(launched, hasLength(1));
    expect(launched.single.module, _module);
    expect(launched.single.shelfId, 222);
    expect(launched.single.shelfName, '精选二');
    expect(launched.single.shelfType, '信息化');
    expect(source.loadCount, 1);
  });

  testWidgets('default selection pushes the shared practice page', (
    tester,
  ) async {
    final source = _Source((module) async => _catalog(module));

    await tester.pumpWidget(
      MaterialApp(
        home: FastPracticeCatalogPage(
          module: _module,
          dataSource: source,
          practiceDataSource: _PracticeSource(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fast-practice-leaf-111')));
    await tester.pumpAndSettle();

    expect(find.byType(PracticePage), findsOneWidget);
  });

  testWidgets('ignores a catalog result after disposal', (tester) async {
    final pending = Completer<FastPracticeCatalog>();
    final source = _Source((_) => pending.future);

    await tester.pumpWidget(_app(source: source));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete(_catalog(_module));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required FastPracticeDataSource source,
  HomeModule module = _module,
  FastPracticeLauncher? launcher,
}) {
  return MaterialApp(
    home: FastPracticeCatalogPage(
      module: module,
      dataSource: source,
      practiceLauncher: launcher ?? (_, _) async {},
    ),
  );
}

FastPracticeCatalog _catalog(HomeModule module) {
  return FastPracticeCatalog(
    module: module,
    leaves: const [
      FastPracticeLeaf(id: 111, name: '精选一', type: '扁平化'),
      FastPracticeLeaf(id: 222, name: '精选二', type: '信息化'),
    ],
  );
}

const _module = HomeModule(id: 42, name: '速成300题', page: '速成300题', tag: '');

const _unnamedModule = HomeModule(id: 42, name: '  ', page: '', tag: '');

typedef _Loader = Future<FastPracticeCatalog> Function(HomeModule module);

final class _Source implements FastPracticeDataSource {
  _Source(this.loader);

  final _Loader loader;
  int loadCount = 0;

  @override
  Future<FastPracticeCatalog> loadCatalog(HomeModule module) {
    loadCount += 1;
    return loader(module);
  }

  @override
  Future<FastPracticeEntryDestination> resolveEntry(HomeModule module) async {
    return FastPracticeEntryDestination.catalog;
  }
}

final class _PracticeSource implements PracticeDataSource {
  @override
  Future<PracticeCatalog> load(PracticeRequest request) async {
    return PracticeCatalog(
      items: const [],
      access: const PracticeAccess(fullAccess: true, freeQuestionCount: 0),
      title: request.title,
    );
  }

  @override
  Future<void> saveAnswer(
    PracticeQuestion question,
    PracticeAnswer answer,
  ) async {}

  @override
  Future<void> setCollected(PracticeQuestion question, bool collected) async {}

  @override
  Future<void> removeWrongQuestion(PracticeQuestion question) async {}

  @override
  Future<ErrorPracticeAvailability> probeErrorPractice() async {
    return const ErrorPracticeAvailability(requiresLogin: false);
  }

  @override
  Future<int> loadWrongRemovalThreshold() async => -1;

  @override
  Future<void> saveWrongRemovalThreshold(int threshold) async {}

  @override
  Future<bool> recordWrongQuestionCorrect(PracticeQuestion question) async {
    return false;
  }
}
