import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_models.dart';
import 'package:ultcpa_flutter/src/smart_card/smart_card_models.dart';
import 'package:ultcpa_flutter/src/smart_card/smart_card_page.dart';
import 'package:ultcpa_flutter/src/smart_card/smart_card_repository.dart';

void main() {
  test('registers both authoritative Android smart-card bitmaps', () {
    for (final name in ['bg_smard_card_top.png', 'ic_lock.png']) {
      expect(
        File('assets/images/smart_card/$name').existsSync(),
        isTrue,
        reason: name,
      );
    }
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/images/smart_card/'),
    );
  });

  testWidgets(
    'prefetched cards preserve order, trial badges, and keyword style',
    (tester) async {
      final source = _Source(
        load: (_, {required isVip}) => throw StateError('unexpected load'),
      );
      await tester.pumpWidget(
        _app(source: source, catalog: _catalog(isVip: false)),
      );
      await tester.pumpAndSettle();

      expect(source.loadCalls, isEmpty);
      expect(find.byKey(const ValueKey('smart-card-pager')), findsOneWidget);
      expect(find.byKey(const ValueKey('smart-card-item-0')), findsOneWidget);
      expect(find.text('第1条题干技巧', findRichText: true), findsOneWidget);
      expect(find.text('第1条题干说明', findRichText: true), findsOneWidget);
      expect(find.text('体验卡片'), findsWidgets);
      expect(find.byKey(const ValueKey('smart-card-unlock')), findsOneWidget);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.bottomNavigationBar, isNotNull);

      final highlighted = tester
          .widgetList<RichText>(
            find.descendant(
              of: find.byKey(const ValueKey('smart-card-item-0')),
              matching: find.byType(RichText),
            ),
          )
          .expand((widget) => _flatten(widget.text))
          .where((span) => span.text == '题干')
          .toList();
      expect(highlighted, isNotEmpty);
      expect(highlighted.first.style?.color, const Color(0xFFFF2200));
      expect(highlighted.first.style?.fontWeight, FontWeight.bold);
    },
  );

  testWidgets('fourth non-VIP card is locked and reports the Android message', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(source: _unusedSource(), catalog: _catalog(isVip: false)),
    );
    await tester.pumpAndSettle();

    final pager = find.byKey(const ValueKey('smart-card-pager'));
    for (var index = 0; index < 3; index += 1) {
      await tester.drag(pager, const Offset(-360, 0));
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const ValueKey('smart-card-item-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('smart-card-lock-3')), findsOneWidget);
    expect(find.text('技巧卡片'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('smart-card-item-3')));
    await tester.pump();
    expect(find.text('开通会员以解锁所有技巧卡片'), findsOneWidget);
  });

  testWidgets('VIP hides badges, locks, and the bottom unlock action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        source: _unusedSource(),
        catalog: _catalog(isVip: true),
        isVip: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('体验卡片'), findsNothing);
    expect(find.text('技巧卡片'), findsNothing);
    expect(find.byKey(const ValueKey('smart-card-lock-0')), findsNothing);
    expect(find.byKey(const ValueKey('smart-card-unlock')), findsNothing);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.bottomNavigationBar, isNull);
  });

  testWidgets('loads, retries a failure, and renders an empty catalog', (
    tester,
  ) async {
    final first = Completer<SkillMnemonicsCatalog>();
    final second = Completer<SkillMnemonicsCatalog>();
    var attempt = 0;
    final source = _Source(
      load: (_, {required isVip}) =>
          attempt++ == 0 ? first.future : second.future,
    );
    await tester.pumpWidget(_app(source: source));
    await tester.pump();

    expect(find.byKey(const ValueKey('smart-card-loading')), findsOneWidget);
    first.completeError(StateError('offline'));
    await tester.pump();
    expect(find.byKey(const ValueKey('smart-card-error')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('smart-card-retry')));
    await tester.pump();
    expect(find.byKey(const ValueKey('smart-card-loading')), findsOneWidget);
    second.complete(_catalog(isVip: false, count: 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('smart-card-empty')), findsOneWidget);
    expect(find.text('暂无技巧卡片'), findsOneWidget);
    expect(source.loadCalls, hasLength(2));
  });

  testWidgets('default and injected unlock actions keep payment honest', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(source: _unusedSource(), catalog: _catalog(isVip: false)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('smart-card-unlock')));
    await tester.pump();
    expect(find.text('技巧卡片需解锁，会员与支付功能仍在迁移中'), findsOneWidget);

    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      _app(
        source: _unusedSource(),
        catalog: _catalog(isVip: false),
        onUnlock: () {
          calls += 1;
          return pending.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('smart-card-unlock')),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(calls, 1);
    pending.complete();
    await tester.pump();
  });

  testWidgets('successful unlock reloads cards and applies paid access', (
    tester,
  ) async {
    final source = _Source(
      load: (_, {required isVip}) async => _catalog(isVip: true),
      entry: const SmartCardEntry(SmartCardEntryDestination.page, isVip: true),
    );
    await tester.pumpWidget(
      _app(
        source: source,
        catalog: _catalog(isVip: false),
        onUnlock: () async {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('smart-card-unlock')));
    await tester.pumpAndSettle();

    expect(source.loadCalls, hasLength(1));
    expect(find.byKey(const ValueKey('smart-card-unlock')), findsNothing);
    expect(find.text('体验卡片'), findsNothing);
  });

  testWidgets('back returns and stale load completion is ignored', (
    tester,
  ) async {
    final pending = Completer<SkillMnemonicsCatalog>();
    final source = _Source(load: (_, {required isVip}) => pending.future);
    await tester.pumpWidget(MaterialApp(home: _Harness(source: source)));

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SmartCardPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('smart-card-back')));
    await tester.pumpAndSettle();
    expect(find.text('host'), findsOneWidget);

    pending.complete(_catalog(isVip: false));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits the Android card surface on a 320 by 568 viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(source: _unusedSource(), catalog: _catalog(isVip: false)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('smart-card-pager')), findsOneWidget);
    expect(find.byKey(const ValueKey('smart-card-unlock')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Iterable<TextSpan> _flatten(InlineSpan span) sync* {
  if (span is! TextSpan) return;
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    yield* _flatten(child);
  }
}

Widget _app({
  required SmartCardDataSource source,
  SkillMnemonicsCatalog? catalog,
  bool isVip = false,
  SmartCardUnlockLauncher? onUnlock,
}) {
  return MaterialApp(
    home: SmartCardPage(
      request: _request,
      dataSource: source,
      initialCatalog: catalog,
      isVip: isVip,
      onUnlock: onUnlock,
    ),
  );
}

SkillMnemonicsCatalog _catalog({required bool isVip, int count = 5}) {
  return SkillMnemonicsCatalog.fromBody(
    {
      'records': [
        for (var index = 0; index < count; index += 1)
          {
            'skillId': '${index + 1}',
            if (index != 1) 'text': '第${index + 1}条题干技巧',
            if (index == 1) 'name': '第2条题干技巧',
            'keyword': '题干',
            'note': '第${index + 1}条题干说明',
          },
      ],
      'total': count,
      'pages': 1,
      'current': 1,
      'size': 200,
    },
    freeCount: 3,
    isVip: isVip,
  );
}

_Source _unusedSource() {
  return _Source(
    load: (_, {required isVip}) => throw StateError('unexpected load'),
  );
}

const _module = HomeModule(id: 51, name: '技巧卡片', page: '技巧卡片', tag: '');

const _request = SmartCardRequest(module: _module);

typedef _Loader =
    Future<SkillMnemonicsCatalog> Function(
      SmartCardRequest request, {
      required bool isVip,
    });

final class _Source implements SmartCardDataSource {
  _Source({
    required this.load,
    this.entry = const SmartCardEntry(SmartCardEntryDestination.page),
  });

  final _Loader load;
  final SmartCardEntry entry;
  final List<({SmartCardRequest request, bool isVip})> loadCalls = [];

  @override
  Future<SkillMnemonicsCatalog> loadCatalog(
    SmartCardRequest request, {
    required bool isVip,
  }) {
    loadCalls.add((request: request, isVip: isVip));
    return load(request, isVip: isVip);
  }

  @override
  Future<SmartCardEntry> resolveEntry(SmartCardRequest request) async => entry;
}

final class _Harness extends StatelessWidget {
  const _Harness({required this.source});

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
                  builder: (_) => SmartCardPage(
                    request: _request,
                    dataSource: source,
                    isVip: false,
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
