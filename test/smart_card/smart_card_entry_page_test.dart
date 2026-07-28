import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_models.dart';
import 'package:ultcpa_flutter/src/smart_card/smart_card_entry_page.dart';
import 'package:ultcpa_flutter/src/smart_card/smart_card_models.dart';
import 'package:ultcpa_flutter/src/smart_card/smart_card_page.dart';
import 'package:ultcpa_flutter/src/smart_card/smart_card_repository.dart';

void main() {
  testWidgets('shows loading and retries an entry resolution failure', (
    tester,
  ) async {
    final first = Completer<SmartCardEntry>();
    final second = Completer<SmartCardEntry>();
    var attempt = 0;
    final source = _Source(
      resolve: (_) => attempt++ == 0 ? first.future : second.future,
    );

    await tester.pumpWidget(_app(source));
    expect(
      find.byKey(const ValueKey('smart-card-entry-loading')),
      findsOneWidget,
    );

    first.completeError(StateError('offline'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('smart-card-entry-error')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('smart-card-entry-retry')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('smart-card-entry-loading')),
      findsOneWidget,
    );

    final catalog = _catalog(isVip: false);
    second.complete(
      SmartCardEntry(SmartCardEntryDestination.page, catalog: catalog),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SmartCardPage), findsOneWidget);
    expect(source.resolvedRequests, [_request, _request]);
    expect(source.loadedRequests, isEmpty);
  });

  testWidgets('renders the invalid request empty destination', (tester) async {
    final source = _Source(
      resolve: (_) async =>
          const SmartCardEntry(SmartCardEntryDestination.empty),
    );

    await tester.pumpWidget(_app(source));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('smart-card-entry-empty')),
      findsOneWidget,
    );
    expect(find.text('暂无技巧卡片'), findsOneWidget);
  });

  testWidgets('forwards prefetched page state and the unlock callback', (
    tester,
  ) async {
    final catalog = _catalog(isVip: false);
    final source = _Source(
      resolve: (_) async => SmartCardEntry(
        SmartCardEntryDestination.page,
        isVip: false,
        catalog: catalog,
      ),
    );
    var unlockCalls = 0;

    await tester.pumpWidget(_app(source, onUnlock: () => unlockCalls += 1));
    await tester.pumpAndSettle();

    final page = tester.widget<SmartCardPage>(find.byType(SmartCardPage));
    expect(page.request, same(_request));
    expect(page.dataSource, same(source));
    expect(page.initialCatalog, same(catalog));
    expect(page.isVip, isFalse);
    expect(source.loadedRequests, isEmpty);

    await tester.tap(find.byKey(const ValueKey('smart-card-unlock')));
    await tester.pump();
    expect(unlockCalls, 1);
  });

  testWidgets('unavailable entry reports a message and returns', (
    tester,
  ) async {
    final source = _Source(
      resolve: (_) async =>
          const SmartCardEntry(SmartCardEntryDestination.unavailable),
    );

    await tester.pumpWidget(MaterialApp(home: _EntryHarness(source: source)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('host'), findsOneWidget);
    expect(find.byType(SmartCardEntryPage), findsNothing);
    expect(find.text('入口数据加载中，请稍后重试'), findsOneWidget);
  });
}

Widget _app(SmartCardDataSource source, {SmartCardUnlockLauncher? onUnlock}) {
  return MaterialApp(
    home: SmartCardEntryPage(
      request: _request,
      dataSource: source,
      onUnlock: onUnlock,
    ),
  );
}

SkillMnemonicsCatalog _catalog({required bool isVip}) {
  return SkillMnemonicsCatalog.fromBody(
    const {
      'records': [
        {'skillId': '1', 'text': '看到题干先排除', 'keyword': '题干', 'note': '结合题干判断'},
      ],
      'total': 1,
      'pages': 1,
      'current': 1,
      'size': 200,
    },
    freeCount: 3,
    isVip: isVip,
  );
}

const _module = HomeModule(id: 51, name: '技巧卡片', page: '技巧卡片', tag: '');

const _request = SmartCardRequest(module: _module);

typedef _EntryResolver =
    Future<SmartCardEntry> Function(SmartCardRequest request);

final class _Source implements SmartCardDataSource {
  _Source({required this.resolve});

  final _EntryResolver resolve;
  final List<SmartCardRequest> resolvedRequests = [];
  final List<({SmartCardRequest request, bool isVip})> loadedRequests = [];

  @override
  Future<SmartCardEntry> resolveEntry(SmartCardRequest request) {
    resolvedRequests.add(request);
    return resolve(request);
  }

  @override
  Future<SkillMnemonicsCatalog> loadCatalog(
    SmartCardRequest request, {
    required bool isVip,
  }) {
    loadedRequests.add((request: request, isVip: isVip));
    throw StateError('unexpected catalog load');
  }
}

final class _EntryHarness extends StatelessWidget {
  const _EntryHarness({required this.source});

  final SmartCardDataSource source;

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
                  builder: (_) =>
                      SmartCardEntryPage(request: _request, dataSource: source),
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
