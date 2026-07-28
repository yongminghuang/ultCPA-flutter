import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/daily_skill/daily_skill_models.dart';
import 'package:ultcpa_flutter/src/practice/practice_models.dart';

void main() {
  test('parses a direct daily SkillVO and normalizes nullable fields', () {
    final skill = parseDailySkillBody(const {
      'skillId': 11,
      'text': '看到必须先排除',
      'name': '每日技巧',
      'keyword': '必须',
      'note': '先排除绝对表述',
      'imgUrl': 'null',
      'questionCount': '3',
      'shelfId': 111,
    });

    expect(skill?.skillId, '11');
    expect(skill?.displayText, '看到必须先排除');
    expect(skill?.imgUrl, isNull);
    expect(skill?.questionCount, 3);
    expect(skill?.shelfId, '111');
  });

  test('falls back to the first record in a page body', () {
    final skill = parseDailySkillBody(const {
      'total': 2,
      'records': [
        {'id': '21', 'name': '第一招', 'text': '', 'questionCount': 2},
        {'id': '22', 'name': '第二招'},
      ],
    });

    expect(skill?.skillId, '21');
    expect(skill?.displayText, '第一招');
  });

  test('returns null for empty payloads and rejects malformed pages', () {
    expect(parseDailySkillBody(null), isNull);
    expect(parseDailySkillBody(const {}), isNull);
    expect(parseDailySkillBody(const {'records': []}), isNull);
    expect(
      () => parseDailySkillBody(const {'records': 'bad'}),
      throwsFormatException,
    );
    expect(() => parseDailySkillBody(const []), throwsFormatException);
  });

  test('converts Android A-F bit-mask picks in canonical order', () {
    expect(dailySkillAnswerPick('a,c,f'), 37);
    expect(dailySkillAnswerPick('BA'), 3);
    expect(dailySkillAnswerPick(''), 0);
    expect(dailySkillChooseFromPick(37), 'ACF');
    expect(dailySkillChooseFromPick(3), 'AB');
    expect(dailySkillChooseFromPick(0), '');
    expect(dailySkillChooseFromPick(64), '');
  });

  test('builds all and wrong-only read-only analysis catalogs', () {
    final questions = [_question('101'), _question('102'), _question('103')];
    final answers = {
      101: const DailySkillAnswer(
        questionId: 101,
        pick: 1,
        isRight: true,
        timestamp: 10,
      ),
      102: const DailySkillAnswer(
        questionId: 102,
        pick: 2,
        isRight: false,
        timestamp: 20,
      ),
    };

    final all = buildDailySkillAnalysisCatalog(
      questions: questions,
      answers: answers,
      wrongQuestionIds: const [102],
      onlyWrong: false,
    );
    final wrong = buildDailySkillAnalysisCatalog(
      questions: questions,
      answers: answers,
      wrongQuestionIds: const [102],
      onlyWrong: true,
    );

    expect(
      all.items.whereType<PracticeQuestionItem>().map(
        (item) => item.question.id,
      ),
      ['101', '102', '103'],
    );
    expect(
      (all.items[0] as PracticeQuestionItem).question.serverAnswer,
      const PracticeAnswer(choose: 'A', isRight: true),
    );
    expect(
      (all.items[1] as PracticeQuestionItem).question.serverAnswer,
      const PracticeAnswer(choose: 'B', isRight: false),
    );
    expect(
      wrong.items.whereType<PracticeQuestionItem>().map(
        (item) => item.question.id,
      ),
      ['102'],
    );
    expect(all.access.fullAccess, isTrue);
    expect(all.behavior.restoreServerAnswers, isTrue);
    expect(all.behavior.persistAnswers, isFalse);
    expect(all.behavior.showResults, isFalse);
    expect(all.behavior.lastItemMessage, '当前已是最后一题');
  });
}

PracticeQuestion _question(String id) {
  return PracticeQuestion.fromMap({
    'questionId': id,
    'title': '题目 $id',
    'questionType': '单选题',
    'options': {'A': '正确', 'B': '错误'},
    'answer': 'A',
  });
}
