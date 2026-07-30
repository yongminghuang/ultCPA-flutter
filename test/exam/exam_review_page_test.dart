import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/exam/exam_models.dart';
import 'package:ultcpa_flutter/src/exam/exam_review_page.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/practice/practice_models.dart';
import 'package:ultcpa_flutter/src/practice/practice_repository.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_models.dart';

void main() {
  testWidgets('shows selected, correct, and explanation without editing', (
    tester,
  ) async {
    final result = _result();
    await tester.pumpWidget(_app(result, [result.questions.first]));

    expect(find.byKey(const ValueKey('exam-review-page')), findsOneWidget);
    expect(find.text('1. 题目 1'), findsOneWidget);
    expect(find.text('你的答案：A'), findsOneWidget);
    expect(find.text('正确答案：B'), findsOneWidget);
    expect(find.text('解析 1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('exam-review-selected-A')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('exam-review-correct-B')), findsOneWidget);
    expect(find.byKey(const ValueKey('exam-review-option-A')), findsOneWidget);
    expect(find.byKey(const ValueKey('exam-review-option-B')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('exam-review-option-A')),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });

  testWidgets('navigates within the provided immutable review subset', (
    tester,
  ) async {
    final result = _result();
    await tester.pumpWidget(_app(result, result.questions));

    var previous = tester.widget<IconButton>(
      find.byKey(const ValueKey('exam-review-previous')),
    );
    expect(previous.onPressed, isNull);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('exam-review-next')));
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('2. 题目 2'), findsOneWidget);
    final next = tester.widget<IconButton>(
      find.byKey(const ValueKey('exam-review-next')),
    );
    expect(next.onPressed, isNull);
    previous = tester.widget<IconButton>(
      find.byKey(const ValueKey('exam-review-previous')),
    );
    expect(previous.onPressed, isNotNull);
  });

  testWidgets('loads mnemonic labels and content for each reviewed question', (
    tester,
  ) async {
    final result = _result();
    final source = _SkillSource();
    await tester.pumpWidget(
      _app(result, result.questions, skillExplanationDataSource: source),
    );
    await tester.pump();
    await tester.pump();

    expect(source.questionIds, ['1']);
    expect(find.text('速记技巧'), findsOneWidget);
    expect(find.text('技巧 1', findRichText: true), findsOneWidget);
    expect(find.text('技巧解析 1', findRichText: true), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('exam-review-next')));
    await tester.pump();
    await tester.pump();

    expect(source.questionIds, ['1', '2']);
    expect(find.text('技巧 2', findRichText: true), findsOneWidget);
    expect(find.text('技巧解析 2', findRichText: true), findsOneWidget);
  });

  testWidgets('renders a stable empty review subset', (tester) async {
    final result = _result();
    await tester.pumpWidget(_app(result, const []));

    expect(find.byKey(const ValueKey('exam-review-empty')), findsOneWidget);
    expect(find.text('暂无题目'), findsOneWidget);
  });

  testWidgets('fits read-only review on a 320 by 568 viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final result = _result();

    await tester.pumpWidget(_app(result, result.questions));

    expect(find.byKey(const ValueKey('exam-review-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  ExamResult result,
  List<PracticeQuestion> questions, {
  PracticeSkillExplanationDataSource? skillExplanationDataSource,
}) {
  return MaterialApp(
    home: ExamReviewPage(
      title: '全部题目',
      result: result,
      questions: questions,
      skillExplanationDataSource: skillExplanationDataSource,
    ),
  );
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
        'keyword': '技巧',
        'note': '技巧解析 $questionId',
      }),
    ];
  }
}

ExamResult _result() {
  final questions = [_question('1', answer: 'B'), _question('2', answer: 'A')];
  return ExamResult(
    request: _request,
    questions: questions,
    selections: const {'1': 'A'},
    elapsed: const Duration(minutes: 1),
  );
}

const _request = ExamRequest(module: _module, shelfId: 901, title: '真题一');

const _module = HomeModule(
  id: 51,
  name: '历年真题卷',
  page: '历年真题卷',
  tag: '',
  type: '嵌套化',
);

PracticeQuestion _question(String id, {required String answer}) {
  return PracticeQuestion.fromMap({
    'questionId': id,
    'title': '题目 $id',
    'questionType': '单选题',
    'options': {'A': '选项 A', 'B': '选项 B'},
    'answer': answer,
    'analysis': '解析 $id',
  });
}
