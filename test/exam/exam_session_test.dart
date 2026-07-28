import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/exam/exam_models.dart';
import 'package:ultcpa_flutter/src/exam/exam_session.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/practice/practice_models.dart';

void main() {
  test('single and judgment selections replace the previous choice', () {
    final questions = [_single('1', 'B'), _judgment('2', 'A')];
    final session = _session(questions);

    expect(session.select('A'), isTrue);
    expect(session.selectedFor(questions[0]), 'A');
    expect(session.select('B'), isTrue);
    expect(session.selectedFor(questions[0]), 'B');
    expect(session.select('B'), isFalse);

    expect(session.moveNext(), isTrue);
    expect(session.select('B'), isTrue);
    expect(session.select('A'), isTrue);
    expect(session.selectedFor(questions[1]), 'A');
    expect(session.answeredCount, 2);
    expect(session.unansweredCount, 0);
  });

  test('multiple-choice selections toggle and normalize option order', () {
    final question = _multiple('1', 'AC');
    final session = _session([question]);

    expect(session.select('C'), isTrue);
    expect(session.select('A'), isTrue);
    expect(session.selectedFor(question), 'AC');
    expect(session.select('C'), isTrue);
    expect(session.selectedFor(question), 'A');
    expect(session.select('Z'), isFalse);
  });

  test('navigation is bounded and exposes only the current selection', () {
    final questions = [_single('1', 'A'), _single('2', 'B')];
    final session = _session(questions);

    expect(session.currentIndex, 0);
    expect(session.currentQuestion, same(questions[0]));
    expect(session.movePrevious(), isFalse);
    expect(session.jumpTo(2), isFalse);
    expect(session.jumpTo(1), isTrue);
    expect(session.currentQuestion, same(questions[1]));
    expect(session.moveNext(), isFalse);
    expect(session.selectedFor(questions[1]), isEmpty);
    expect(session.selections, isEmpty);
  });

  test('finish grades once, freezes edits, and returns the same result', () {
    final questions = [
      _single('1', 'B'),
      _multiple('2', 'AC'),
      _judgment('3', 'A'),
    ];
    final session = _session(questions, hasMemberTier: true);
    session.select('B');
    session.moveNext();
    session.select('A');
    session.select('B');

    final result = session.finish(elapsed: const Duration(minutes: 8));

    expect(session.isFinished, isTrue);
    expect(result.rightCount, 1);
    expect(result.wrongCount, 1);
    expect(result.unansweredCount, 1);
    expect(result.hasMemberTier, isTrue);
    expect(result.statusFor(questions[0]), ExamQuestionStatus.right);
    expect(result.statusFor(questions[1]), ExamQuestionStatus.wrong);
    expect(result.statusFor(questions[2]), ExamQuestionStatus.unanswered);
    expect(session.select('C'), isFalse);
    expect(session.jumpTo(2), isFalse);
    expect(session.finish(elapsed: const Duration(minutes: 99)), same(result));
  });

  test('empty catalog remains stable', () {
    final session = _session(const []);

    expect(session.currentQuestion, isNull);
    expect(session.answeredCount, 0);
    expect(session.unansweredCount, 0);
    expect(session.select('A'), isFalse);
    expect(session.moveNext(), isFalse);
    expect(session.finish(elapsed: Duration.zero).accuracyPercent, 0);
  });
}

ExamSession _session(
  List<PracticeQuestion> questions, {
  bool hasMemberTier = false,
}) {
  return ExamSession(
    ExamCatalog(
      request: _request,
      questions: questions,
      hasMemberTier: hasMemberTier,
    ),
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

PracticeQuestion _single(String id, String answer) =>
    _question(id, questionType: '单选题', answer: answer);

PracticeQuestion _multiple(String id, String answer) =>
    _question(id, questionType: '多选题', answer: answer);

PracticeQuestion _judgment(String id, String answer) =>
    _question(id, questionType: '判断题', answer: answer);

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
  });
}
