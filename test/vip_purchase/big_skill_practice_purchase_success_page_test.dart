import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/practice/practice_benefit_kind.dart';
import 'package:ultcpa_flutter/src/vip_purchase/big_skill_practice_purchase_success_page.dart';
import 'package:ultcpa_flutter/src/vip_purchase/big_skill_practice_purchase_success_repository.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_models.dart';

void main() {
  testWidgets('renders Android default then applies refreshed success copy', (
    tester,
  ) async {
    final summary = Completer<BigSkillPracticePurchaseSuccessSummary>();
    final source = _Source(summaryHandler: (_) => summary.future);

    await tester.pumpWidget(
      _app(
        source: source,
        request: const BigSkillPracticePurchaseSuccessRequest(
          benefitKind: PracticeBenefitKind.chapterPractice,
        ),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final icon = tester.widget<Image>(
      find.byKey(const ValueKey('big-skill-success-icon')),
    );
    final actionMaterial = tester.widget<Material>(
      find.byKey(const ValueKey('big-skill-success-action-material')),
    );
    expect(scaffold.backgroundColor, const Color(0xFFFFFDF5));
    expect(appBar.backgroundColor, const Color(0xFFFFFDF5));
    expect(
      find.byKey(const ValueKey('big-skill-success-back')),
      findsOneWidget,
    );
    expect(icon.width, 72);
    expect(icon.height, 72);
    expect(
      icon.image,
      const AssetImage('assets/images/vip_purchase/icon_open_vip_success.png'),
    );
    expect(find.text('恭喜！【章节练习权益】开通成功'), findsOneWidget);
    expect(find.textContaining('有效期至'), findsNothing);
    expect(find.text('去技巧练题'), findsOneWidget);
    expect(actionMaterial.color, const Color(0xFF0094FF));
    expect(source.summaryCalls, [PracticeBenefitKind.chapterPractice]);

    summary.complete(
      const BigSkillPracticePurchaseSuccessSummary(
        kind: PracticeBenefitKind.chapterPractice,
        benefitName: '章节专项包',
        expiresOn: '2026-08-01',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('恭喜！【章节专项包】开通成功'), findsOneWidget);
    expect(find.text('有效期至 2026-08-01'), findsOneWidget);
  });

  testWidgets('summary failure keeps the kind-specific generic copy', (
    tester,
  ) async {
    final source = _Source(
      summaryHandler: (_) async => throw StateError('benefits offline'),
    );
    await tester.pumpWidget(
      _app(
        source: source,
        request: const BigSkillPracticePurchaseSuccessRequest(
          benefitKind: PracticeBenefitKind.fastPractice,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('恭喜！【速成300题功能】开通成功'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('app and system back finish once with the Home intent', (
    tester,
  ) async {
    final finishes = <bool>[];
    await tester.pumpWidget(_app(source: _Source(), onFinished: finishes.add));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('big-skill-success-back')));
    await tester.tap(find.byKey(const ValueKey('big-skill-success-back')));
    await tester.pump();
    expect(finishes, [true]);

    final systemFinishes = <bool>[];
    await tester.pumpWidget(
      _app(
        key: const ValueKey('no-home-system-back'),
        source: _Source(),
        request: const BigSkillPracticePurchaseSuccessRequest(
          navigateHomeOnBack: false,
        ),
        onFinished: systemFinishes.add,
      ),
    );
    await tester.binding.handlePopRoute();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(systemFinishes, [false]);
  });

  testWidgets('CTA forwards cached modules once and finishes without Home', (
    tester,
  ) async {
    const practice = HomeModule(id: 41, name: '技巧练题', page: '技巧练题', tag: '');
    const circle = HomeModule(id: 42, name: '技巧圈题卷', page: '技巧圈题卷', tag: '');
    const destination = BigSkillPracticeDestination(
      practiceModule: practice,
      circleModule: circle,
    );
    final launch = Completer<void>();
    final launches = <(BigSkillPracticeDestination, PracticeBenefitKind)>[];
    final finishes = <bool>[];
    final source = _Source(destinationHandler: (_, _) async => destination);
    await tester.pumpWidget(
      _app(
        source: source,
        request: const BigSkillPracticePurchaseSuccessRequest(
          benefitKind: PracticeBenefitKind.pastExams,
          cachedPracticeModule: practice,
          cachedCircleModule: circle,
        ),
        practiceLauncher: (_, value, kind) {
          launches.add((value, kind));
          return launch.future;
        },
        onFinished: finishes.add,
      ),
    );
    await tester.pump();

    final action = find.byKey(const ValueKey('big-skill-success-action'));
    await tester.tap(action);
    await tester.tap(action);
    await tester.pump();

    expect(source.destinationCalls, [(practice, circle)]);
    expect(launches, [(destination, PracticeBenefitKind.pastExams)]);
    expect(
      find.byKey(const ValueKey('big-skill-success-action-progress')),
      findsOneWidget,
    );
    expect(finishes, isEmpty);

    launch.complete();
    await tester.pumpAndSettle();
    expect(finishes, [false]);
  });

  testWidgets('missing destination notifies and allows a retry', (
    tester,
  ) async {
    final source = _Source(destinationHandler: (_, _) async => null);
    await tester.pumpWidget(_app(source: source));
    await tester.pump();
    final action = find.byKey(const ValueKey('big-skill-success-action'));

    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(source.destinationCalls, hasLength(1));
    expect(find.text('入口数据加载中，请返回首页后再试'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('big-skill-success-action-progress')),
      findsNothing,
    );

    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(source.destinationCalls, hasLength(2));
  });

  testWidgets('destination and launcher errors restore the CTA', (
    tester,
  ) async {
    var destinationCall = 0;
    var launchCalls = 0;
    const destination = BigSkillPracticeDestination(
      practiceModule: HomeModule(id: 41, name: '技巧练题', page: '技巧练题', tag: ''),
      circleModule: null,
    );
    final source = _Source(
      destinationHandler: (_, _) async {
        destinationCall += 1;
        if (destinationCall == 1) throw StateError('modules offline');
        return destination;
      },
    );
    await tester.pumpWidget(
      _app(
        source: source,
        practiceLauncher: (_, _, _) async {
          launchCalls += 1;
          throw StateError('route failed');
        },
      ),
    );
    await tester.pump();
    final action = find.byKey(const ValueKey('big-skill-success-action'));

    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('入口数据加载中，请返回首页后再试'), findsOneWidget);
    expect(launchCalls, 0);

    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(launchCalls, 1);
    expect(find.text('入口数据加载中，请返回首页后再试'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('big-skill-success-action-progress')),
      findsNothing,
    );
  });

  testWidgets('late summary and destination completions are ignored', (
    tester,
  ) async {
    final summary = Completer<BigSkillPracticePurchaseSuccessSummary>();
    final destination = Completer<BigSkillPracticeDestination?>();
    final source = _Source(
      summaryHandler: (_) => summary.future,
      destinationHandler: (_, _) => destination.future,
    );
    await tester.pumpWidget(_app(source: source));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('big-skill-success-action')));
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    summary.complete(
      const BigSkillPracticePurchaseSuccessSummary.generic(
        PracticeBenefitKind.regularPractice,
      ),
    );
    destination.complete(null);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('fits both compact Android viewports without overflow', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in const [Size(320, 568), Size(360, 640)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        _app(
          key: ValueKey('${size.width}x${size.height}'),
          source: _Source(
            summaryHandler: (_) async =>
                const BigSkillPracticePurchaseSuccessSummary(
                  kind: PracticeBenefitKind.regularPractice,
                  benefitName: '初级社工全科技巧练题长期权益包',
                  expiresOn: '2026-08-01',
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '$size');
      expect(
        find.byKey(const ValueKey('big-skill-success-action')),
        findsOneWidget,
      );
    }
  });
}

Widget _app({
  Key? key,
  required BigSkillPracticePurchaseSuccessDataSource source,
  BigSkillPracticePurchaseSuccessRequest request =
      const BigSkillPracticePurchaseSuccessRequest(),
  Future<void> Function(
    BuildContext,
    BigSkillPracticeDestination,
    PracticeBenefitKind,
  )?
  practiceLauncher,
  ValueChanged<bool>? onFinished,
}) {
  return MaterialApp(
    key: key,
    home: BigSkillPracticePurchaseSuccessPage(
      request: request,
      dataSource: source,
      practiceLauncher: practiceLauncher ?? (_, _, _) async {},
      onFinished: onFinished ?? (_) {},
    ),
  );
}

final class _Source implements BigSkillPracticePurchaseSuccessDataSource {
  _Source({this.summaryHandler, this.destinationHandler});

  final Future<BigSkillPracticePurchaseSuccessSummary> Function(
    PracticeBenefitKind,
  )?
  summaryHandler;
  final Future<BigSkillPracticeDestination?> Function(HomeModule?, HomeModule?)?
  destinationHandler;
  final summaryCalls = <PracticeBenefitKind>[];
  final destinationCalls = <(HomeModule?, HomeModule?)>[];

  @override
  Future<BigSkillPracticePurchaseSuccessSummary> loadSummary(
    PracticeBenefitKind kind,
  ) {
    summaryCalls.add(kind);
    return summaryHandler?.call(kind) ??
        Future.value(BigSkillPracticePurchaseSuccessSummary.generic(kind));
  }

  @override
  Future<BigSkillPracticeDestination?> loadDestination({
    HomeModule? cachedPracticeModule,
    HomeModule? cachedCircleModule,
  }) {
    destinationCalls.add((cachedPracticeModule, cachedCircleModule));
    return destinationHandler?.call(cachedPracticeModule, cachedCircleModule) ??
        Future.value(null);
  }
}
