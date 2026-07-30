import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/daily_skill/daily_skill_models.dart';
import 'package:ultcpa_flutter/src/daily_skill/daily_skill_progress_store.dart';
import 'package:ultcpa_flutter/src/daily_skill/daily_skill_report_page.dart';
import 'package:ultcpa_flutter/src/daily_skill/daily_skill_repository.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/practice/practice_models.dart';
import 'package:ultcpa_flutter/src/practice/practice_page.dart';
import 'package:ultcpa_flutter/src/practice/practice_repository.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_models.dart';

void main() {
  testWidgets('shows loading then returns when today progress is missing', (
    tester,
  ) async {
    final pending = Completer<DailySkillProgress?>();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('report host')),
      ),
    );
    unawaited(
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => DailySkillReportPage(
            request: _request,
            dataSource: _Source((_) async => const []),
            progressStore: _ProgressStore(() => pending.future),
            improveLauncher: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('daily-skill-report-loading')),
      findsOneWidget,
    );

    pending.complete(null);
    await tester.pumpAndSettle();

    expect(find.text('report host'), findsOneWidget);
    expect(find.text('暂无练习记录'), findsOneWidget);
    expect(find.byType(DailySkillReportPage), findsNothing);
  });

  testWidgets('floors accuracy and renders ordered six-column answer states', (
    tester,
  ) async {
    final progress = _progress(
      questionOrder: const [101, 102, 103, 104],
      answers: const {
        101: DailySkillAnswer(
          questionId: 101,
          pick: 1,
          isRight: true,
          timestamp: 10,
        ),
        102: DailySkillAnswer(
          questionId: 102,
          pick: 2,
          isRight: false,
          timestamp: 20,
        ),
        103: DailySkillAnswer(
          questionId: 103,
          pick: 1,
          isRight: true,
          timestamp: 30,
        ),
      },
    );

    await tester.pumpWidget(
      _app(
        progressStore: _ProgressStore(() async => progress, completedDays: 2),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本次练习报告'), findsOneWidget);
    expect(find.text('已打卡2天'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('daily-skill-report-accuracy')),
        matching: find.text('66%'),
      ),
      findsOneWidget,
    );
    expect(find.text('正确 2'), findsOneWidget);
    expect(find.text('错误 1'), findsOneWidget);
    expect(find.text('未答题 1'), findsOneWidget);

    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 6);
    expect(_cellColor(tester, 0), const Color(0xFF00CB94));
    expect(_cellColor(tester, 1), const Color(0xFFE0321A));
    expect(_cellColor(tester, 2), const Color(0xFF00CB94));
    expect(_cellColor(tester, 3), const Color(0xFFEEEEEE));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('daily-skill-report-cell-3')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('hides zero check-in days and reports an empty wrong set', (
    tester,
  ) async {
    final source = _Source((_) async => [_question('101')]);
    final launches = <PracticeCatalog>[];
    await tester.pumpWidget(
      _app(
        source: source,
        progressStore: _ProgressStore(
          () async => _progress(
            questionOrder: const [101],
            answers: const {
              101: DailySkillAnswer(
                questionId: 101,
                pick: 1,
                isRight: true,
                timestamp: 10,
              ),
            },
          ),
        ),
        analysisLauncher: (_, catalog) async => launches.add(catalog),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('已打卡'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('daily-skill-report-wrong')));
    await tester.pumpAndSettle();

    expect(find.text('暂无错题'), findsOneWidget);
    expect(source.loadedSkillIds, isEmpty);
    expect(launches, isEmpty);
  });

  testWidgets('reloads and filters wrong and all read-only analysis', (
    tester,
  ) async {
    final source = _Source(
      (_) async => [_question('103'), _question('102'), _question('101')],
    );
    final launches = <PracticeCatalog>[];
    final progress = _progress(
      questionOrder: const [101, 102, 103],
      answers: const {
        101: DailySkillAnswer(
          questionId: 101,
          pick: 1,
          isRight: true,
          timestamp: 10,
        ),
        102: DailySkillAnswer(
          questionId: 102,
          pick: 2,
          isRight: false,
          timestamp: 20,
        ),
      },
    );
    await tester.pumpWidget(
      _app(
        source: source,
        progressStore: _ProgressStore(() async => progress),
        analysisLauncher: (_, catalog) async => launches.add(catalog),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('daily-skill-report-wrong')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('daily-skill-report-all')));
    await tester.pumpAndSettle();

    expect(source.loadedSkillIds, ['11', '11']);
    expect(_catalogQuestionIds(launches[0]), ['102']);
    expect(launches[0].title, '错题解析');
    expect(_catalogQuestionIds(launches[1]), ['103', '102', '101']);
    expect(launches[1].title, '查看全部解析');
    expect(launches[0].access.fullAccess, isTrue);
    expect(launches[0].behavior.restoreServerAnswers, isTrue);
    expect(launches[0].behavior.persistAnswers, isFalse);
    expect(launches[0].behavior.showResults, isFalse);
    final wrongQuestion = launches[0].items
        .whereType<PracticeQuestionItem>()
        .single
        .question;
    expect(wrongQuestion.serverAnswer?.choose, 'B');
    expect(wrongQuestion.serverAnswer?.isRight, isFalse);
  });

  testWidgets('reports transport and empty analysis results', (tester) async {
    var mode = 0;
    final source = _Source((_) async {
      if (mode == 0) throw StateError('offline');
      if (mode == 1) return const [];
      return [_question('999')];
    });
    await tester.pumpWidget(
      _app(
        source: source,
        progressStore: _ProgressStore(
          () async => _progress(
            questionOrder: const [101],
            answers: const {
              101: DailySkillAnswer(
                questionId: 101,
                pick: 2,
                isRight: false,
                timestamp: 10,
              ),
            },
          ),
        ),
        analysisLauncher: (_, _) async {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('daily-skill-report-all')));
    await tester.pumpAndSettle();
    expect(find.text('解析加载失败，请稍后重试'), findsOneWidget);

    mode = 1;
    await tester.tap(find.byKey(const ValueKey('daily-skill-report-all')));
    await tester.pumpAndSettle();
    expect(find.text('暂无解析数据'), findsOneWidget);

    mode = 2;
    await tester.tap(find.byKey(const ValueKey('daily-skill-report-wrong')));
    await tester.pumpAndSettle();
    expect(find.text('暂无错题'), findsOneWidget);
  });

  testWidgets('default analysis launcher opens the shared read-only practice', (
    tester,
  ) async {
    final source = _Source((_) async => [_question('101')]);
    final skillSource = _SkillSource();
    await tester.pumpWidget(
      _app(
        source: source,
        skillExplanationDataSource: skillSource,
        progressStore: _ProgressStore(
          () async => _progress(
            questionOrder: const [101],
            answers: const {
              101: DailySkillAnswer(
                questionId: 101,
                pick: 2,
                isRight: false,
                timestamp: 10,
              ),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('daily-skill-report-all')));
    await tester.pumpAndSettle();

    expect(find.byType(PracticePage), findsOneWidget);
    expect(find.text('查看全部解析'), findsOneWidget);
    expect(find.text('正确答案：A'), findsOneWidget);
    expect(skillSource.questionIds, ['101']);
    expect(find.text('速记技巧'), findsOneWidget);
    expect(find.text('技巧 101', findRichText: true), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('practice-next')));
    await tester.pumpAndSettle();
    expect(find.text('当前已是最后一题'), findsOneWidget);
  });

  testWidgets('opens improvement and reports launcher failure', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _app(
        improveLauncher: (_) async {
          calls += 1;
          if (calls == 2) throw StateError('missing module');
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('daily-skill-report-improve')));
    await tester.pumpAndSettle();
    expect(calls, 1);

    await tester.tap(find.byKey(const ValueKey('daily-skill-report-improve')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('入口数据加载中，请稍后重试'), findsOneWidget);
  });
}

Widget _app({
  DailySkillDataSource? source,
  DailySkillProgressDataSource? progressStore,
  DailySkillAnalysisLauncher? analysisLauncher,
  PracticeSkillExplanationDataSource? skillExplanationDataSource,
  Future<void> Function(BuildContext context)? improveLauncher,
}) {
  return MaterialApp(
    home: DailySkillReportPage(
      request: _request,
      dataSource: source ?? _Source((_) async => [_question('101')]),
      progressStore:
          progressStore ??
          _ProgressStore(() async => _progress(questionOrder: const [101])),
      analysisLauncher: analysisLauncher,
      skillExplanationDataSource: skillExplanationDataSource,
      improveLauncher: improveLauncher ?? (_) async {},
    ),
  );
}

const _module = HomeModule(id: 42, name: '每日一招', page: '每日一招', tag: '');

const _request = DailySkillPracticeRequest(
  module: _module,
  skillId: '11',
  shelfId: 111,
);

DailySkillProgress _progress({
  List<int> questionOrder = const [],
  Map<int, DailySkillAnswer> answers = const {},
}) {
  return DailySkillProgress(
    date: '2026-07-16',
    skillId: '11',
    moduleId: 42,
    shelfId: 111,
    currentIndex: 0,
    isFinished: false,
    questionOrder: questionOrder,
    rightQuestionIds: [
      for (final entry in answers.entries)
        if (entry.value.isRight) entry.key,
    ],
    wrongQuestionIds: [
      for (final entry in answers.entries)
        if (!entry.value.isRight) entry.key,
    ],
    answers: answers,
  );
}

PracticeQuestion _question(String id) {
  return PracticeQuestion.fromMap({
    'questionId': id,
    'title': '题目 $id',
    'questionType': '单选题',
    'options': const {'A': '正确', 'B': '错误'},
    'answer': 'A',
    'subject': '社工实务',
    'level': '初级社工',
  });
}

List<String> _catalogQuestionIds(PracticeCatalog catalog) {
  return catalog.items
      .whereType<PracticeQuestionItem>()
      .map((item) => item.question.id)
      .toList(growable: false);
}

Color? _cellColor(WidgetTester tester, int index) {
  final cell = tester.widget<Container>(
    find.byKey(ValueKey('daily-skill-report-cell-$index')),
  );
  return (cell.decoration as BoxDecoration?)?.color;
}

final class _Source implements DailySkillDataSource {
  _Source(this.questionLoader);

  final Future<List<PracticeQuestion>> Function(String skillId) questionLoader;
  final List<String> loadedSkillIds = [];

  @override
  Future<DailySkillDetail> loadDetail(HomeModule module) {
    throw UnimplementedError();
  }

  @override
  Future<List<PracticeQuestion>> loadQuestions(String skillId) {
    loadedSkillIds.add(skillId);
    return questionLoader(skillId);
  }
}

final class _SkillSource implements PracticeSkillExplanationDataSource {
  final List<String> questionIds = [];

  @override
  Future<List<SkillMnemonic>> loadSkillsForQuestion(String questionId) async {
    questionIds.add(questionId);
    return [
      SkillMnemonic.fromMap({
        'skillId': 'skill-$questionId',
        'text': '技巧 $questionId',
      }),
    ];
  }
}

final class _ProgressStore implements DailySkillProgressDataSource {
  _ProgressStore(this.loader, {this.completedDays = 0});

  final Future<DailySkillProgress?> Function() loader;
  final int completedDays;

  @override
  Future<DailySkillProgress?> loadToday() => loader();

  @override
  Future<DailySkillProgress> ensureToday({
    required String skillId,
    required int moduleId,
    required int shelfId,
  }) {
    throw UnimplementedError();
  }

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

  @override
  Future<void> markFinished(bool finished) async {}

  @override
  Future<int> completedDaysCount() async => completedDays;

  @override
  Future<void> clear() async {}
}
