import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_landing_page.dart';

void main() {
  test('registers every authoritative Android landing bitmap', () {
    const names = <String>[
      'ic_pre_exam_six_pager_80.png',
      'ic_pre_exam_six_pager_hero_banner.png',
      'ic_pre_exam_six_paper_col_repeat.png',
      'ic_pre_exam_six_paper_col_speed.png',
      'ic_pre_exam_six_paper_col_years.png',
      'ic_pre_exam_six_paper_row_calm.png',
      'ic_pre_exam_six_paper_row_score.png',
      'ic_pre_exam_six_paper_row_time.png',
      'vip_open_accounting_layer_25.png',
      'vip_open_accounting_rect_12.png',
    ];
    for (final name in names) {
      expect(
        File('assets/images/pre_exam_six_paper/$name').existsSync(),
        isTrue,
        reason: name,
      );
    }
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/images/pre_exam_six_paper/'),
    );
  });

  testWidgets('renders Android hero comparisons benefits and fixed CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PreExamSixPaperLandingPage(module: _module)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('pre-exam-six-landing-hero')),
      findsOneWidget,
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('书太厚背不完？别背了！'), findsOneWidget);
    expect(find.text('重复率91%'), findsOneWidget);
    expect(find.text('5小时速成'), findsOneWidget);
    expect(find.text('5年考11次'), findsOneWidget);
    expect(find.text('省时间'), findsOneWidget);
    expect(find.text('好拿分'), findsOneWidget);
    expect(find.text('心态稳'), findsOneWidget);
    expect(find.text('立即领取考前6页纸'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pre-exam-six-landing-unlock')),
      findsOneWidget,
    );
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.bottomNavigationBar, isNotNull);

    final assetNames = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<AssetImage>()
        .map((image) => image.assetName)
        .toSet();
    expect(
      assetNames,
      containsAll(<String>{
        for (final name in const <String>[
          'ic_pre_exam_six_pager_80.png',
          'ic_pre_exam_six_pager_hero_banner.png',
          'ic_pre_exam_six_paper_col_repeat.png',
          'ic_pre_exam_six_paper_col_speed.png',
          'ic_pre_exam_six_paper_col_years.png',
          'ic_pre_exam_six_paper_row_calm.png',
          'ic_pre_exam_six_paper_row_score.png',
          'ic_pre_exam_six_paper_row_time.png',
          'vip_open_accounting_layer_25.png',
          'vip_open_accounting_rect_12.png',
        ])
          'assets/images/pre_exam_six_paper/$name',
      }),
    );
  });

  testWidgets('default CTA reports the pending membership payment boundary', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PreExamSixPaperLandingPage(module: _module)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pre-exam-six-landing-unlock')));
    await tester.pump();

    expect(find.text('考前6页纸需解锁，会员与支付功能仍在迁移中'), findsOneWidget);
  });

  testWidgets('injected unlock callback replaces the pending CTA action', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PreExamSixPaperLandingPage(
          module: _module,
          onUnlock: () => calls += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pre-exam-six-landing-unlock')));
    await tester.pump();

    expect(calls, 1);
    expect(find.text('考前6页纸需解锁，会员与支付功能仍在迁移中'), findsNothing);
  });

  testWidgets('transparent back control returns to the previous route', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _LandingHarness()));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(PreExamSixPaperLandingPage), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pre-exam-six-landing-back')));
    await tester.pumpAndSettle();

    expect(find.text('host'), findsOneWidget);
    expect(find.byType(PreExamSixPaperLandingPage), findsNothing);
  });
}

const _module = HomeModule(id: 46, name: '考前6页纸', page: '考前6页纸', tag: '');

final class _LandingHarness extends StatelessWidget {
  const _LandingHarness();

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
                      const PreExamSixPaperLandingPage(module: _module),
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
