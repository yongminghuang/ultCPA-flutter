import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/daily_skill/daily_skill_detail_page.dart';
import 'package:ultcpa_flutter/src/daily_skill/daily_skill_models.dart';
import 'package:ultcpa_flutter/src/daily_skill/daily_skill_progress_store.dart';
import 'package:ultcpa_flutter/src/daily_skill/daily_skill_repository.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/practice/practice_models.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_models.dart';

void main() {
  testWidgets('renders loading, retryable failure, and loaded detail', (
    tester,
  ) async {
    final pending = Completer<DailySkillDetail>();
    var calls = 0;
    final source = _Source((_) {
      calls += 1;
      return calls == 1 ? pending.future : Future.value(_detail());
    });

    await tester.pumpWidget(_app(source: source));
    expect(find.byKey(const ValueKey('daily-skill-loading')), findsOneWidget);

    pending.completeError(StateError('offline'));
    await tester.pump();
    expect(find.byKey(const ValueKey('daily-skill-error')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('daily-skill-retry-load')));
    await tester.pumpAndSettle();

    expect(find.text('每日一招'), findsOneWidget);
    expect(find.text('看到必须先排除', findRichText: true), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('invalid module renders empty without data or progress I/O', (
    tester,
  ) async {
    final source = _Source((_) => throw StateError('unexpected load'));
    final progress = _ProgressStore();

    await tester.pumpWidget(
      _app(
        source: source,
        progress: progress,
        module: const HomeModule(id: 0, name: '每日一招', page: '每日一招', tag: ''),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('daily-skill-empty')), findsOneWidget);
    expect(find.text('暂无每日一招内容'), findsOneWidget);
    expect(source.loadCount, 0);
    expect(progress.ensureCalls, isEmpty);
  });

  testWidgets('renders optional image, explanation, and exact practice CTA', (
    tester,
  ) async {
    final launched = <DailySkillDetail>[];
    final detail = _detail(imageUrl: 'https://cdn.example.com/daily.gif');

    await tester.pumpWidget(
      _app(
        source: _Source((_) async => detail),
        practiceLauncher: (_, value) async => launched.add(value),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('daily-skill-image')), findsOneWidget);
    final image = tester.widget<Image>(
      find.byKey(const ValueKey('daily-skill-image')),
    );
    expect(
      (image.image as NetworkImage).url,
      'https://cdn.example.com/daily.gif',
    );
    expect(find.text('技巧解析'), findsOneWidget);
    expect(find.text('先排除绝对表述', findRichText: true), findsOneWidget);
    expect(find.text('掌握该技巧能做 3 题', findRichText: true), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('daily-skill-practice')));
    await tester.pumpAndSettle();
    expect(launched, [detail]);
  });

  testWidgets('hides absent image and explanation', (tester) async {
    final detail = _detail(
      imageUrl: '',
      skill: _skill(note: '', imgUrl: null),
    );

    await tester.pumpWidget(_app(source: _Source((_) async => detail)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('daily-skill-image')), findsNothing);
    expect(find.text('技巧解析'), findsNothing);
  });

  testWidgets('finished state retries practice and opens improvement', (
    tester,
  ) async {
    final progress = _ProgressStore(finished: true);
    final practiceLaunches = <DailySkillDetail>[];
    var improveCalls = 0;

    await tester.pumpWidget(
      _app(
        progress: progress,
        practiceLauncher: (_, detail) async => practiceLaunches.add(detail),
        improveLauncher: (_) async => improveCalls += 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('daily-skill-finished')), findsOneWidget);
    expect(find.text('太棒了！今天目标已达成，明天记得来！'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-skill-practice')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('daily-skill-retry-practice')));
    await tester.pumpAndSettle();
    expect(progress.clearCalls, 1);
    expect(progress.ensureCalls, hasLength(2));
    expect(practiceLaunches, hasLength(1));

    await tester.tap(find.byKey(const ValueKey('daily-skill-improve')));
    await tester.pumpAndSettle();
    expect(improveCalls, 1);
  });

  testWidgets('ignores a detail result after disposal', (tester) async {
    final pending = Completer<DailySkillDetail>();
    final source = _Source((_) => pending.future);

    await tester.pumpWidget(_app(source: source));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete(_detail());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  DailySkillDataSource? source,
  DailySkillProgressDataSource? progress,
  HomeModule module = _module,
  DailySkillPracticeLauncher? practiceLauncher,
  DailySkillImproveLauncher? improveLauncher,
}) {
  return MaterialApp(
    home: DailySkillDetailPage(
      module: module,
      dataSource: source ?? _Source((_) async => _detail()),
      progressStore: progress ?? _ProgressStore(),
      practiceLauncher: practiceLauncher ?? (_, _) async {},
      improveLauncher: improveLauncher ?? (_) async {},
    ),
  );
}

DailySkillDetail _detail({String imageUrl = '', SkillMnemonic? skill}) {
  return DailySkillDetail(
    module: _module,
    skill: skill ?? _skill(),
    effectiveShelfId: 111,
    imageUrl: imageUrl,
  );
}

SkillMnemonic _skill({String note = '先排除绝对表述', String? imgUrl}) {
  return SkillMnemonic.fromMap({
    'skillId': '11',
    'text': '看到必须先排除',
    'keyword': '必须',
    'note': note,
    'imgUrl': imgUrl,
    'questionCount': 3,
    'shelfId': '111',
  });
}

const _module = HomeModule(id: 42, name: '每日一招', page: '每日一招', tag: 'hot');

typedef _Loader = Future<DailySkillDetail> Function(HomeModule module);

final class _Source implements DailySkillDataSource {
  _Source(this.loader);

  final _Loader loader;
  int loadCount = 0;

  @override
  Future<DailySkillDetail> loadDetail(HomeModule module) {
    loadCount += 1;
    return loader(module);
  }

  @override
  Future<List<PracticeQuestion>> loadQuestions(String skillId) async =>
      const [];
}

final class _ProgressStore implements DailySkillProgressDataSource {
  _ProgressStore({this.finished = false});

  final bool finished;
  final List<({String skillId, int moduleId, int shelfId})> ensureCalls = [];
  int clearCalls = 0;

  @override
  Future<DailySkillProgress?> loadToday() async => null;

  @override
  Future<DailySkillProgress> ensureToday({
    required String skillId,
    required int moduleId,
    required int shelfId,
  }) async {
    ensureCalls.add((skillId: skillId, moduleId: moduleId, shelfId: shelfId));
    return DailySkillProgress.empty(
      date: '2026-07-16',
      skillId: skillId,
      moduleId: moduleId,
      shelfId: shelfId,
    ).copyWith(isFinished: finished);
  }

  @override
  Future<void> clear() async => clearCalls += 1;

  @override
  Future<int> completedDaysCount() async => 0;

  @override
  Future<void> markFinished(bool finished) async {}

  @override
  Future<void> persistQuestionOrder(List<int> questionOrder) async {}

  @override
  Future<void> recordAnswer({
    required int questionId,
    required String choose,
    required bool isRight,
    required int currentIndex,
    required List<int> questionOrder,
  }) async {}
}
