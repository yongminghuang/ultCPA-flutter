import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/fast_practice/fast_practice_catalog_page.dart';
import 'package:ultcpa_flutter/src/fast_practice/fast_practice_entry_page.dart';
import 'package:ultcpa_flutter/src/fast_practice/fast_practice_landing_page.dart';
import 'package:ultcpa_flutter/src/fast_practice/fast_practice_models.dart';
import 'package:ultcpa_flutter/src/fast_practice/fast_practice_repository.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';

void main() {
  testWidgets('renders loading before resolving the catalog destination', (
    tester,
  ) async {
    final pending = Completer<FastPracticeEntryDestination>();
    final source = _Source(resolve: (_) => pending.future);

    await tester.pumpWidget(_app(source));
    expect(
      find.byKey(const ValueKey('fast-practice-entry-loading')),
      findsOneWidget,
    );

    pending.complete(FastPracticeEntryDestination.catalog);
    await tester.pumpAndSettle();

    expect(find.byType(FastPracticeCatalogPage), findsOneWidget);
    expect(source.resolveCount, 1);
    expect(source.catalogCount, 1);
  });

  testWidgets('renders the Android landing destination without loading tree', (
    tester,
  ) async {
    final source = _Source(
      resolve: (_) async => FastPracticeEntryDestination.landing,
    );

    await tester.pumpWidget(_app(source));
    await tester.pumpAndSettle();

    expect(find.byType(FastPracticeLandingPage), findsOneWidget);
    expect(find.text('立即领取速成300题'), findsOneWidget);
    expect(source.catalogCount, 0);
  });

  testWidgets('renders an invalid empty destination', (tester) async {
    final source = _Source(
      resolve: (_) async => FastPracticeEntryDestination.empty,
    );

    await tester.pumpWidget(_app(source));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('fast-practice-entry-empty')),
      findsOneWidget,
    );
    expect(find.text('暂无速成练习内容'), findsOneWidget);
    expect(source.catalogCount, 0);
  });

  testWidgets('awaits unlock then resolves the unlocked catalog once', (
    tester,
  ) async {
    final unlock = Completer<void>();
    var resolveAttempt = 0;
    var unlockCalls = 0;
    final source = _Source(
      resolve: (_) async => resolveAttempt++ == 0
          ? FastPracticeEntryDestination.landing
          : FastPracticeEntryDestination.catalog,
    );

    await tester.pumpWidget(
      _app(
        source,
        onUnlock: () {
          unlockCalls += 1;
          return unlock.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('fast-practice-unlock')));
    await tester.tap(find.byKey(const ValueKey('fast-practice-unlock')));
    await tester.pump();

    expect(unlockCalls, 1);
    expect(source.resolveCount, 1);
    expect(find.byType(FastPracticeLandingPage), findsOneWidget);

    unlock.complete();
    await tester.pumpAndSettle();

    expect(source.resolveCount, 2);
    expect(find.byType(FastPracticeCatalogPage), findsOneWidget);
  });

  testWidgets('ignores a resolved destination after disposal', (tester) async {
    final pending = Completer<FastPracticeEntryDestination>();
    final source = _Source(resolve: (_) => pending.future);

    await tester.pumpWidget(_app(source));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete(FastPracticeEntryDestination.catalog);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(source.catalogCount, 0);
  });
}

Widget _app(
  FastPracticeDataSource source, {
  FutureOr<void> Function()? onUnlock,
}) {
  return MaterialApp(
    home: FastPracticeEntryPage(
      module: _module,
      dataSource: source,
      practiceLauncher: (_, _) async {},
      onUnlock: onUnlock,
    ),
  );
}

const _module = HomeModule(id: 42, name: '速成300题', page: '速成300题', tag: '');

typedef _Resolver =
    Future<FastPracticeEntryDestination> Function(HomeModule module);

final class _Source implements FastPracticeDataSource {
  _Source({required this.resolve});

  final _Resolver resolve;
  int resolveCount = 0;
  int catalogCount = 0;

  @override
  Future<FastPracticeEntryDestination> resolveEntry(HomeModule module) {
    resolveCount += 1;
    return resolve(module);
  }

  @override
  Future<FastPracticeCatalog> loadCatalog(HomeModule module) async {
    catalogCount += 1;
    return FastPracticeCatalog(module: module, leaves: const []);
  }
}
