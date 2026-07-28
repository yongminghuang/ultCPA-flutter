import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/practice/practice_models.dart';

void main() {
  test('parses an Android mixed page and excludes file records', () {
    final batch = PracticePageBatch.fromBody({
      'total': '3',
      'pages': 2,
      'current': '1',
      'size': 30,
      'records': [
        {
          'type': '大招',
          'skillId': 's-1',
          'text': '技巧口诀',
          'keyword': '技巧',
          'note': '技巧解析',
          'questionCount': 2,
        },
        {'type': '文件', 'name': '讲义.pdf'},
        {
          'type': '多选题',
          'id': 314,
          'questionId': 9007199254740993,
          'title': '请选择正确选项',
          'questionType': '多选题',
          'options': '{"A":"甲","B":"乙","C":"丙"}',
          'answer': 'C,A',
          'analysis': 'A 与 C 正确',
          'subject': '社工实务',
          'level': '初级社工',
        },
      ],
    });

    expect(batch.total, 3);
    expect(batch.pages, 2);
    expect(batch.current, 1);
    expect(batch.items, hasLength(2));
    expect(batch.items.first, isA<PracticeSkillItem>());
    final skill = (batch.items.first as PracticeSkillItem).skill;
    expect(skill.skillId, 's-1');

    final question = (batch.items.last as PracticeQuestionItem).question;
    expect(question.id, '9007199254740993');
    expect(question.wrongCountId, '314');
    expect(question.kind, PracticeQuestionKind.multiple);
    expect(question.options.map((item) => item.key), ['A', 'B', 'C']);
    expect(question.options.map((item) => item.text), ['甲', '乙', '丙']);
    expect(question.normalizedAnswer, 'AC');
    expect(question.isCorrect({'C', 'A'}), isTrue);
  });

  test('accepts decoded options and maps judgment and single types', () {
    final items = parsePracticeRecords([
      {
        'questionId': 'q-1',
        'content': '说法是否正确',
        'questionType': '判断',
        'options': {'A': '正确', 'B': '错误'},
        'answer': 'A',
      },
      {
        'id': '2',
        'title': '单项选择',
        'questionType': 'unknown',
        'options': {'A': '一', 'B': '二'},
        'answer': 'b',
      },
    ]);

    final judgment = (items.first as PracticeQuestionItem).question;
    final single = (items.last as PracticeQuestionItem).question;
    expect(judgment.kind, PracticeQuestionKind.judgment);
    expect(judgment.displayTitle, '说法是否正确');
    expect(single.kind, PracticeQuestionKind.single);
    expect(single.normalizedAnswer, 'B');
  });

  test('restores a server answer snapshot and normalizes choices', () {
    final item =
        parsePracticeRecords([
              {
                'id': '3',
                'title': '快照题',
                'questionType': '多选题',
                'options': '{"A":"一","B":"二","C":"三"}',
                'answer': 'AB',
                'choose': 'B,A,A',
                'isRight': '1',
                'isCollect': 1,
              },
            ]).single
            as PracticeQuestionItem;

    expect(item.question.serverAnswer?.choose, 'AB');
    expect(item.question.serverAnswer?.isRight, isTrue);
    expect(item.question.isCollected, isTrue);
    expect(normalizePracticeChoices(['f', 'A', 'F', 'x']), 'AF');
  });

  test('parses listGoods and direct-skill list bodies', () {
    final items = PracticePageBatch.fromListBody([
      {
        'id': '4',
        'title': '列表题',
        'options': {'A': '是', 'B': '否'},
        'answer': 'A',
      },
    ]).items;

    expect(items.single, isA<PracticeQuestionItem>());
  });

  test('rejects malformed containers and skips empty records', () {
    expect(() => PracticePageBatch.fromBody([]), throwsFormatException);
    expect(
      () => PracticePageBatch.fromBody({'records': 'bad'}),
      throwsFormatException,
    );
    expect(
      parsePracticeRecords([
        {'type': '单选题'},
        null,
      ]),
      isEmpty,
    );
  });

  test('defines standard, error-review, and collection-review behavior', () {
    const standard = PracticeCatalog(
      items: [],
      access: PracticeAccess(fullAccess: true, freeQuestionCount: 5),
      title: '练题',
    );
    const errorReview = PracticeCatalog(
      items: [],
      access: PracticeAccess(fullAccess: true, freeQuestionCount: 0),
      title: '我的错题',
      behavior: PracticeBehavior.errorReview(emptyMessage: '还没有错题哟'),
    );
    const collectionReview = PracticeCatalog(
      items: [],
      access: PracticeAccess(fullAccess: true, freeQuestionCount: 0),
      title: '我的收藏',
      behavior: PracticeBehavior.collectionReview(emptyMessage: '暂无收藏题目'),
    );

    expect(standard.behavior.restoreServerAnswers, isTrue);
    expect(standard.behavior.persistAnswers, isTrue);
    expect(standard.behavior.showResults, isTrue);
    expect(standard.behavior.emptyMessage, '暂无练习内容');
    expect(standard.behavior.reviewKind, isNull);
    expect(errorReview.behavior.restoreServerAnswers, isFalse);
    expect(errorReview.behavior.persistAnswers, isFalse);
    expect(errorReview.behavior.showResults, isFalse);
    expect(errorReview.behavior.emptyMessage, '还没有错题哟');
    expect(errorReview.behavior.lastItemMessage, '当前已是最后一题');
    expect(errorReview.behavior.reviewKind, PracticeReviewKind.errors);
    expect(
      collectionReview.behavior.reviewKind,
      PracticeReviewKind.collections,
    );
    const daily = PracticeBehavior.dailyReview();
    expect(daily.restoreServerAnswers, isTrue);
    expect(daily.persistAnswers, isFalse);
    expect(daily.showResults, isFalse);
    expect(daily.lastItemMessage, '当前已是最后一题');
    expect(daily.emptyMessage, '暂无解析数据');
    expect(daily.reviewKind, isNull);
  });
}
