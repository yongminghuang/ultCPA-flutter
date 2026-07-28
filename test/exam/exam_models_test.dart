import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/exam/exam_models.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/practice/practice_models.dart';

void main() {
  test(
    'normal exam request preserves the exact Android query and duration',
    () {
      expect(_request.isValid, isTrue);
      expect(_request.queryParameters, {
        'pageNum': 1,
        'pageSize': 120,
        'modelId': 51,
        'shelfId': 901,
      });
      expect(_request.duration, const Duration(minutes: 135));
    },
  );

  test('invalid requests reject query creation', () {
    for (final request in [
      ExamRequest(module: _module(id: 0), shelfId: 1, title: '真题'),
      ExamRequest(module: _module(), shelfId: 0, title: '真题'),
      ExamRequest(module: _module(), shelfId: 1, title: '  '),
      ExamRequest(
        module: _module(),
        shelfId: 1,
        title: '真题',
        duration: Duration.zero,
      ),
    ]) {
      expect(request.isValid, isFalse, reason: request.title);
      expect(() => request.queryParameters, throwsArgumentError);
    }
  });

  test('catalog owns an immutable question snapshot', () {
    final source = <PracticeQuestion>[_single('1', answer: 'A')];
    final catalog = ExamCatalog(
      request: _request,
      questions: source,
      hasMemberTier: true,
    );
    source.clear();

    expect(catalog.request, same(_request));
    expect(catalog.questions, hasLength(1));
    expect(catalog.hasMemberTier, isTrue);
    expect(
      () => catalog.questions.add(_single('2', answer: 'B')),
      throwsUnsupportedError,
    );
  });

  test('result grades over all questions and groups first-seen kinds', () {
    final questions = [
      _single('1', answer: 'A'),
      _multiple('2', answer: 'AB'),
      _judgment('3', answer: 'B'),
    ];
    final result = ExamResult(
      request: _request,
      questions: questions,
      selections: const {'1': 'A', '2': 'CA'},
      elapsed: const Duration(minutes: 7, seconds: 9),
    );

    expect(result.elapsed, const Duration(minutes: 7, seconds: 9));
    expect(result.answeredCount, 2);
    expect(result.rightCount, 1);
    expect(result.wrongCount, 1);
    expect(result.unansweredCount, 1);
    expect(result.accuracyPercent, 33);
    expect(result.selectionFor(questions[1]), 'AC');
    expect(result.statusFor(questions[0]), ExamQuestionStatus.right);
    expect(result.statusFor(questions[1]), ExamQuestionStatus.wrong);
    expect(result.statusFor(questions[2]), ExamQuestionStatus.unanswered);
    expect(result.allQuestions, questions);
    expect(result.wrongQuestions, [questions[1]]);

    expect(result.sections.map((section) => section.kind), [
      PracticeQuestionKind.single,
      PracticeQuestionKind.multiple,
      PracticeQuestionKind.judgment,
    ]);
    expect(result.sections.map((section) => section.title), [
      '· 单项选择题',
      '· 多项选择题',
      '· 判断题',
    ]);
    expect(result.sections.map((section) => section.indexes), [
      [0],
      [1],
      [2],
    ]);
    expect(result.sections.map((section) => section.rightCount), [1, 0, 0]);
    expect(result.sections.map((section) => section.wrongCount), [0, 1, 0]);
    expect(result.sections.map((section) => section.unansweredCount), [
      0,
      0,
      1,
    ]);
  });

  test('result ignores unknown or empty selections and is immutable', () {
    final question = _single('1', answer: 'A');
    final sourceQuestions = <PracticeQuestion>[question];
    final sourceSelections = <String, String>{'1': '', '404': 'A'};
    final result = ExamResult(
      request: _request,
      questions: sourceQuestions,
      selections: sourceSelections,
      elapsed: const Duration(seconds: -1),
    );
    sourceQuestions.clear();
    sourceSelections['1'] = 'A';

    expect(result.questions, hasLength(1));
    expect(result.selections, isEmpty);
    expect(result.elapsed, Duration.zero);
    expect(() => result.selections['1'] = 'A', throwsUnsupportedError);
  });

  test('score follows the Android 50 and 100 question rules', () {
    expect(_scoredResult(questionCount: 50, rightCount: 40).score, 80);
    expect(_scoredResult(questionCount: 100, rightCount: 87).score, 87);
    expect(_scoredResult(questionCount: 3, rightCount: 3).score, 0);
  });

  test('prediction bands preserve the Android thresholds and copy', () {
    expect(
      ExamPrediction.fromScore(80),
      isA<ExamPrediction>()
          .having((value) => value.band, 'band', ExamPredictionBand.steady)
          .having((value) => value.levelText, 'levelText', '稳过')
          .having((value) => value.actionText, 'actionText', '挑战高分'),
    );
    expect(
      ExamPrediction.fromScore(60),
      isA<ExamPrediction>()
          .having((value) => value.band, 'band', ExamPredictionBand.uncertain)
          .having((value) => value.levelText, 'levelText', '悬')
          .having((value) => value.actionText, 'actionText', '巩固弱项'),
    );
    expect(
      ExamPrediction.fromScore(59),
      isA<ExamPrediction>()
          .having((value) => value.band, 'band', ExamPredictionBand.low)
          .having((value) => value.levelText, 'levelText', '很低')
          .having((value) => value.actionText, 'actionText', '去提升'),
    );
  });
}

const _request = ExamRequest(module: _validModule, shelfId: 901, title: '真题一');

const _validModule = HomeModule(
  id: 51,
  name: '历年真题卷',
  page: '历年真题卷',
  tag: '',
  type: '嵌套化',
);

HomeModule _module({int id = 51}) =>
    HomeModule(id: id, name: '历年真题卷', page: '历年真题卷', tag: '', type: '嵌套化');

PracticeQuestion _single(String id, {required String answer}) =>
    _question(id, questionType: '单选题', answer: answer);

PracticeQuestion _multiple(String id, {required String answer}) =>
    _question(id, questionType: '多选题', answer: answer);

PracticeQuestion _judgment(String id, {required String answer}) =>
    _question(id, questionType: '判断题', answer: answer);

ExamResult _scoredResult({
  required int questionCount,
  required int rightCount,
}) {
  final questions = List<PracticeQuestion>.generate(
    questionCount,
    (index) => _single('${index + 1}', answer: 'A'),
  );
  return ExamResult(
    request: _request,
    questions: questions,
    selections: {
      for (var index = 0; index < rightCount; index += 1) '${index + 1}': 'A',
    },
    elapsed: Duration.zero,
  );
}

PracticeQuestion _question(
  String id, {
  required String questionType,
  required String answer,
}) {
  return PracticeQuestion.fromMap({
    'questionId': id,
    'title': '题目 $id',
    'questionType': questionType,
    'options': {'A': '选项 A', 'B': '选项 B', 'C': '选项 C'},
    'answer': answer,
    'analysis': '解析 $id',
  });
}
