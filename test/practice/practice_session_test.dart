import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/practice/practice_models.dart';
import 'package:ultcpa_flutter/src/practice/practice_session.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_models.dart';

void main() {
  test('single and judgment choices submit immediately', () {
    final single = _question('single', answer: 'A');
    final judgment = _question('judgment', questionType: '判断题', answer: 'B');
    final session = PracticeSession(
      _catalog([single, judgment], fullAccess: true),
    );

    final first = session.select('a');

    expect(first, isA<PracticeSubmitted>());
    expect((first as PracticeSubmitted).answer.choose, 'A');
    expect(first.answer.isRight, isTrue);
    expect(session.rightCount, 1);
    expect(session.moveNext(), isTrue);

    final second = session.select('A') as PracticeSubmitted;
    expect(second.answer.isRight, isFalse);
    expect(session.answeredCount, 2);
    expect(session.rightCount, 1);
    expect(session.wrongCount, 1);
    expect(session.unansweredCount, 0);
    expect(session.accuracy, 0.5);
  });

  test('multiple choices toggle until confirmation and normalize order', () {
    final question = _question(
      'multiple',
      questionType: '多选题',
      answer: 'AC',
      options: const {'A': '甲', 'B': '乙', 'C': '丙'},
    );
    final session = PracticeSession(_catalog([question], fullAccess: true));

    final first = session.toggleMultiple('C') as PracticeDraftChanged;
    expect(first.choose, 'C');
    final second = session.toggleMultiple('A') as PracticeDraftChanged;
    expect(second.choose, 'AC');
    expect(session.draftFor(question), 'AC');

    final submitted = session.confirmMultiple() as PracticeSubmitted;
    expect(submitted.answer.choose, 'AC');
    expect(submitted.answer.isRight, isTrue);
    expect(session.draftFor(question), isEmpty);

    expect(session.toggleMultiple('B'), isA<PracticeNoChange>());
    expect(session.confirmMultiple(), isA<PracticeNoChange>());
    expect(session.answerFor(question)?.choose, 'AC');
  });

  test('restores immutable server answers without spending free usage', () {
    final restored = _question(
      'restored',
      answer: 'A',
      choose: 'B',
      isRight: false,
    );
    final fresh = _question('fresh');
    final locked = _question('locked');
    final session = PracticeSession(
      _catalog([restored, fresh, locked], freeQuestionCount: 1),
    );

    expect(session.answerFor(restored)?.choose, 'B');
    expect(session.answeredCount, 1);
    expect(session.wrongCount, 1);
    expect(session.newlySubmittedCount, 0);
    expect(session.select('A'), isA<PracticeNoChange>());
    expect(
      () => session.answers['fresh'] = const PracticeAnswer(
        choose: 'A',
        isRight: true,
      ),
      throwsUnsupportedError,
    );

    expect(session.moveNext(), isTrue);
    expect(session.select('A'), isA<PracticeSubmitted>());
    expect(session.newlySubmittedCount, 1);
    expect(session.moveNext(), isFalse);
    expect(session.jumpTo(0), isTrue);
    expect(session.jumpTo(2), isFalse);
  });

  test('Mine review ignores server answer snapshots', () {
    final restored = _question(
      'restored-review',
      answer: 'A',
      choose: 'B',
      isRight: false,
    );
    final session = PracticeSession(
      PracticeCatalog(
        items: [PracticeQuestionItem(restored)],
        access: const PracticeAccess(fullAccess: true, freeQuestionCount: 0),
        title: '我的错题',
        behavior: const PracticeBehavior.errorReview(emptyMessage: '还没有错题哟'),
      ),
    );

    expect(session.answerFor(restored), isNull);
    expect(session.answeredCount, 0);
    expect(session.select('A'), isA<PracticeSubmitted>());
    expect(session.answerFor(restored)?.isRight, isTrue);
  });

  test('collection review owns optimistic collection state', () {
    final question = _question('collected');
    final session = PracticeSession(
      PracticeCatalog(
        items: [PracticeQuestionItem(question)],
        access: const PracticeAccess(fullAccess: true, freeQuestionCount: 0),
        title: '我的收藏',
        behavior: const PracticeBehavior.collectionReview(
          emptyMessage: '暂无收藏题目',
        ),
      ),
    );

    expect(question.isCollected, isFalse);
    expect(session.isCollected(question), isTrue);

    session.setCollected(question, false);

    expect(session.isCollected(question), isFalse);
  });

  test('removes a question by stable id and selects the previous survivor', () {
    final first = _question('q-1');
    final middle = _question('q-2');
    final last = _question('q-3');
    final session = PracticeSession(
      _catalog([first, middle, last], fullAccess: true),
    );
    session.jumpTo(1);
    session.select('A');

    expect(session.removeQuestion('q-2'), isTrue);

    expect(
      session.items.whereType<PracticeQuestionItem>().map(
        (item) => item.question.id,
      ),
      ['q-1', 'q-3'],
    );
    expect(session.currentQuestion?.id, 'q-1');
    expect(session.answerFor(middle), isNull);
    expect(session.removeQuestion('missing'), isFalse);

    expect(session.removeQuestion('q-1'), isTrue);
    expect(session.currentQuestion?.id, 'q-3');
    expect(session.removeQuestion('q-3'), isTrue);
    expect(session.items, isEmpty);
    expect(session.currentItem, isNull);
    expect(session.currentIndex, 0);
  });

  test('navigates mixed items and answer-card positions deterministically', () {
    final firstQuestion = _question('q-1');
    final secondQuestion = _question('q-2');
    final session = PracticeSession(
      PracticeCatalog(
        items: [
          _skill('s-1'),
          PracticeQuestionItem(firstQuestion),
          _skill('s-2'),
          PracticeQuestionItem(secondQuestion),
        ],
        access: const PracticeAccess(fullAccess: true, freeQuestionCount: 0),
        title: '混合练题',
      ),
    );

    expect(session.currentIndex, 0);
    expect(session.currentItem, isA<PracticeSkillItem>());
    expect(session.currentQuestion, isNull);
    expect(session.select('A'), isA<PracticeNoChange>());
    expect(session.moveNext(), isTrue);
    expect(session.currentQuestion?.id, 'q-1');
    expect(session.movePrevious(), isTrue);
    expect(session.jumpTo(3), isTrue);
    expect(session.currentQuestion?.id, 'q-2');
    expect(session.jumpTo(-1), isFalse);
    expect(session.jumpTo(4), isFalse);
    expect(session.moveNext(), isFalse);
  });

  test('locks unanswered content at the free boundary', () {
    final session = PracticeSession(
      _catalog([_question('q-1'), _question('q-2')], freeQuestionCount: 1),
    );

    expect(session.canVisit(0), isTrue);
    expect(session.select('A'), isA<PracticeSubmitted>());
    expect(session.canVisit(0), isTrue);
    expect(session.canVisit(1), isFalse);
    expect(session.moveNext(), isFalse);

    final locked = session.select('B');
    expect(locked, isA<PracticeNoChange>());
    expect(session.answeredCount, 1);
  });

  test('returns locked before drafting when the free count is zero', () {
    final question = _question('multiple', questionType: '多选题', answer: 'AB');
    final session = PracticeSession(_catalog([question], freeQuestionCount: 0));

    final result = session.toggleMultiple('A');

    expect(result, isA<PracticeLocked>());
    expect((result as PracticeLocked).freeQuestionCount, 0);
    expect(session.draftFor(question), isEmpty);
    expect(session.confirmMultiple(), isA<PracticeLocked>());
    expect(session.answeredCount, 0);
  });

  test('full access ignores the configured free boundary', () {
    final session = PracticeSession(
      _catalog(
        [_question('q-1'), _question('q-2')],
        fullAccess: true,
        freeQuestionCount: 0,
      ),
    );

    expect(session.select('A'), isA<PracticeSubmitted>());
    expect(session.moveNext(), isTrue);
    expect(session.select('A'), isA<PracticeSubmitted>());
    expect(session.answeredCount, 2);
  });

  test('restores a local answer without marking it newly submitted', () {
    final question = _question('101');
    final session = PracticeSession(_catalog([question], fullAccess: true));

    session.restoreAnswer(
      question,
      const PracticeAnswer(choose: 'B', isRight: false),
    );

    expect(session.answerFor(question)?.choose, 'B');
    expect(session.answerFor(question)?.isRight, isFalse);
    expect(session.answeredCount, 1);
    expect(session.wrongCount, 1);
    expect(session.newlySubmittedCount, 0);
    expect(session.select('A'), isA<PracticeNoChange>());
  });

  test('reset clears answers drafts and position for another attempt', () {
    final multiple = _question('multiple', questionType: '多选题', answer: 'AB');
    final single = _question('single');
    final session = PracticeSession(
      _catalog([multiple, single], fullAccess: true),
    );
    session.toggleMultiple('A');
    session.confirmMultiple();
    session.moveNext();
    session.select('A');

    session.reset();

    expect(session.currentIndex, 0);
    expect(session.answers, isEmpty);
    expect(session.draftFor(multiple), isEmpty);
    expect(session.answeredCount, 0);
    expect(session.rightCount, 0);
    expect(session.wrongCount, 0);
    expect(session.unansweredCount, 2);
    expect(session.newlySubmittedCount, 0);
  });
}

PracticeCatalog _catalog(
  List<PracticeQuestion> questions, {
  bool fullAccess = false,
  int freeQuestionCount = 5,
}) {
  return PracticeCatalog(
    items: questions.map(PracticeQuestionItem.new).toList(growable: false),
    access: PracticeAccess(
      fullAccess: fullAccess,
      freeQuestionCount: freeQuestionCount,
    ),
    title: '练题',
  );
}

PracticeQuestion _question(
  String id, {
  String questionType = '单选题',
  String answer = 'A',
  Map<String, String> options = const {'A': '正确', 'B': '错误'},
  String? choose,
  bool? isRight,
}) {
  return PracticeQuestion.fromMap({
    'questionId': id,
    'title': '题目 $id',
    'questionType': questionType,
    'options': options,
    'answer': answer,
    'choose': ?choose,
    'isRight': ?isRight,
  });
}

PracticeSkillItem _skill(String id) {
  return PracticeSkillItem(
    SkillMnemonic.fromMap({'skillId': id, 'text': '技巧 $id', 'type': '大招'}),
  );
}
