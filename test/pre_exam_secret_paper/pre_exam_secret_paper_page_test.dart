import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/exam/exam_models.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/pre_exam_secret_paper/pre_exam_secret_paper_models.dart';
import 'package:ultcpa_flutter/src/pre_exam_secret_paper/pre_exam_secret_paper_page.dart';
import 'package:ultcpa_flutter/src/pre_exam_secret_paper/pre_exam_secret_paper_repository.dart';

void main() {
  testWidgets(
    'keeps the hero while loading, retries failure, and renders empty',
    (tester) async {
      final first = Completer<PreExamSecretPaperCatalog>();
      final second = Completer<PreExamSecretPaperCatalog>();
      var attempt = 0;
      final source = _Source(
        load: (_) => attempt++ == 0 ? first.future : second.future,
      );
      await tester.pumpWidget(_app(source: source));

      expect(find.text('最后密押卷'), findsOneWidget);
      expect(find.byKey(const ValueKey('secret-paper-hero')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('secret-paper-loading')),
        findsOneWidget,
      );
      final hero = tester.widget<Image>(
        find.byKey(const ValueKey('secret-paper-hero')),
      );
      expect(
        (hero.image as AssetImage).assetName,
        'assets/images/pre_exam_secret_paper/pre_exam_before_exam_bg.png',
      );

      first.completeError(StateError('offline'));
      await tester.pump();
      expect(find.byKey(const ValueKey('secret-paper-error')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('secret-paper-retry')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('secret-paper-loading')),
        findsOneWidget,
      );
      second.complete(_catalog(isVip: false, count: 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('secret-paper-empty')), findsOneWidget);
      expect(find.text('暂无密押卷数据'), findsOneWidget);
      expect(source.modules, [_module, _module]);
    },
  );

  testWidgets('renders only three Android cards and launches member papers', (
    tester,
  ) async {
    final pending = Completer<void>();
    final requests = <ExamRequest>[];
    await tester.pumpWidget(
      _app(
        source: _Source(load: (_) async => _catalog(isVip: true)),
        examLauncher: (context, request) {
          requests.add(request);
          return pending.future;
        },
      ),
    );
    await tester.pump();

    expect(find.text('密卷A: 新规智能预测卷'), findsOneWidget);
    expect(find.text('密卷B: 单元强化提分卷'), findsOneWidget);
    expect(find.text('密卷C: 高频易错冲刺卷'), findsOneWidget);
    expect(find.byKey(const ValueKey('secret-paper-card-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('secret-paper-card-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('secret-paper-card-3')), findsNothing);
    expect(
      find.byKey(const ValueKey('secret-paper-bottom-unlock')),
      findsNothing,
    );
    final icon = tester.widget<Image>(
      find.byKey(const ValueKey('secret-paper-icon-0')),
    );
    expect(
      (icon.image as AssetImage).assetName,
      'assets/images/pre_exam_secret_paper/pre_exam_before_exam_ic.png',
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('secret-paper-card-1')),
    );
    await tester.pump();
    expect(requests, hasLength(1));
    expect(requests.single.module, same(_module));
    expect(requests.single.shelfId, 102);
    expect(requests.single.title, '服务端密卷二');
    expect(requests.single.duration, const Duration(minutes: 135));
    final card = tester.widget<InkWell>(
      find.byKey(const ValueKey('secret-paper-card-1')),
    );
    expect(card.onTap, isNull);

    pending.complete();
    await tester.pump();
  });

  testWidgets('default card and bottom actions keep payment pending honest', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(source: _Source(load: (_) async => _catalog(isVip: false))),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('secret-paper-bottom-unlock')),
      findsOneWidget,
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('secret-paper-card-0')),
    );
    await tester.pump();
    expect(find.text('最后密押卷需解锁，会员与支付功能仍在迁移中'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('secret-paper-bottom-unlock')));
    await tester.pump();
    expect(find.text('最后密押卷需解锁，会员与支付功能仍在迁移中'), findsOneWidget);
  });

  testWidgets('injected unlock reloads membership and guards duplicate taps', (
    tester,
  ) async {
    final pending = Completer<void>();
    var unlockCalls = 0;
    final unlockSources = <PreExamSecretPaperUnlockSource>[];
    var loadCalls = 0;
    final requests = <ExamRequest>[];
    final source = _Source(load: (_) async => _catalog(isVip: loadCalls++ > 0));
    await tester.pumpWidget(
      _app(
        source: source,
        examLauncher: (context, request) => requests.add(request),
        onUnlock: (source) {
          unlockCalls += 1;
          unlockSources.add(source);
          return pending.future;
        },
      ),
    );
    await tester.pump();

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('secret-paper-card-1')),
    );
    await tester.pump();
    expect(unlockCalls, 1);
    expect(unlockSources, [PreExamSecretPaperUnlockSource.lockedCard]);
    expect(requests, isEmpty);
    final card = tester.widget<InkWell>(
      find.byKey(const ValueKey('secret-paper-card-1')),
    );
    expect(card.onTap, isNull);
    final bottom = tester.widget<FilledButton>(
      find.byKey(const ValueKey('secret-paper-bottom-unlock')),
    );
    expect(bottom.onPressed, isNull);

    pending.complete();
    await tester.pumpAndSettle();
    expect(source.modules, [_module, _module]);
    expect(
      find.byKey(const ValueKey('secret-paper-bottom-unlock')),
      findsNothing,
    );

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('secret-paper-card-1')),
    );
    await tester.pump();
    expect(requests.single.shelfId, 102);
  });

  testWidgets('distinguishes locked-card and bottom payment entries', (
    tester,
  ) async {
    final entries = <PreExamSecretPaperUnlockSource>[];
    await tester.pumpWidget(
      _app(
        source: _Source(load: (_) async => _catalog(isVip: false)),
        onUnlock: (entry) => entries.add(entry),
      ),
    );
    await tester.pump();

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('secret-paper-card-0')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('secret-paper-bottom-unlock')));
    await tester.pumpAndSettle();

    expect(entries, [
      PreExamSecretPaperUnlockSource.lockedCard,
      PreExamSecretPaperUnlockSource.bottomAction,
    ]);
  });

  testWidgets('launcher and unlock failures restore their actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        source: _Source(load: (_) async => _catalog(isVip: true)),
        examLauncher: (context, request) => throw StateError('launch failed'),
      ),
    );
    await tester.pump();
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('secret-paper-card-0')),
    );
    await tester.pump();
    expect(find.text('考试入口打开失败，请重试'), findsOneWidget);
    expect(
      tester
          .widget<InkWell>(find.byKey(const ValueKey('secret-paper-card-0')))
          .onTap,
      isNotNull,
    );

    await tester.pumpWidget(
      _app(
        source: _Source(load: (_) async => _catalog(isVip: false)),
        onUnlock: (_) => throw StateError('unlock failed'),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('secret-paper-bottom-unlock')));
    await tester.pump();
    expect(find.text('解锁入口打开失败，请重试'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('secret-paper-bottom-unlock')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('back returns and ignores a stale catalog completion', (
    tester,
  ) async {
    final pending = Completer<PreExamSecretPaperCatalog>();
    final source = _Source(load: (_) => pending.future);
    await tester.pumpWidget(MaterialApp(home: _Harness(source: source)));

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PreExamSecretPaperPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('secret-paper-back')));
    await tester.pumpAndSettle();
    expect(find.text('host'), findsOneWidget);

    pending.complete(_catalog(isVip: false));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits the Android landing surface on a 320 by 568 viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(source: _Source(load: (_) async => _catalog(isVip: false))),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('secret-paper-card-0')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('secret-paper-bottom-unlock')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Widget _app({
  required PreExamSecretPaperDataSource source,
  PreExamSecretPaperExamLauncher? examLauncher,
  PreExamSecretPaperUnlockLauncher? onUnlock,
}) {
  return MaterialApp(
    home: PreExamSecretPaperPage(
      key: ValueKey(source),
      module: _module,
      dataSource: source,
      examLauncher: examLauncher ?? (context, request) {},
      onUnlock: onUnlock,
    ),
  );
}

PreExamSecretPaperCatalog _catalog({required bool isVip, int count = 4}) {
  return PreExamSecretPaperCatalog(
    module: _module,
    isVip: isVip,
    papers: [
      for (var index = 0; index < count; index += 1)
        PreExamSecretPaper(
          id: 101 + index,
          name: '服务端密卷${['一', '二', '三', '四'][index]}',
        ),
    ],
  );
}

const _module = HomeModule(id: 81, name: '最后密押卷', page: '最后密押卷', tag: '');

typedef _Loader = Future<PreExamSecretPaperCatalog> Function(HomeModule module);

final class _Source implements PreExamSecretPaperDataSource {
  _Source({required this.load});

  final _Loader load;
  final List<HomeModule> modules = [];

  @override
  Future<PreExamSecretPaperCatalog> loadCatalog(HomeModule module) {
    modules.add(module);
    return load(module);
  }
}

final class _Harness extends StatelessWidget {
  const _Harness({required this.source});

  final PreExamSecretPaperDataSource source;

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
                  builder: (_) => PreExamSecretPaperPage(
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
