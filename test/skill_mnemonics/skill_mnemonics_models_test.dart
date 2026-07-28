import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_models.dart';

void main() {
  test('parses Android page goods fields and normalizes nullable values', () {
    final catalog = SkillMnemonicsCatalog.fromBody({
      'total': '2',
      'pages': 1,
      'current': '1',
      'size': 200,
      'records': [
        {
          'skillId': 101,
          'text': '看到“必须”先排除',
          'keyword': '必须,排除',
          'note': '必须结合题干排除绝对表述',
          'questionCount': '7',
          'shelfId': 42,
          'goodsId': 'g-1',
          'type': '大招',
          'imgUrl': null,
          'extend': 'null',
          'sort': '3',
          'status': true,
        },
        {
          'id': '202',
          'text': '',
          'name': '名称备用口诀',
          'keyword': '罚款，拘留',
          'questionCount': 2,
        },
      ],
    }, freeCount: 1);

    expect(catalog.total, 2);
    expect(catalog.records, hasLength(2));
    expect(catalog.records.first.skillId, '101');
    expect(catalog.records.first.questionCount, 7);
    expect(catalog.records.first.shelfId, '42');
    expect(catalog.records.first.imgUrl, isNull);
    expect(catalog.records.first.extend, isNull);
    expect(catalog.records.first.keywordTerms, ['必须', '排除']);
    expect(catalog.records.last.skillId, '202');
    expect(catalog.records.last.displayText, '名称备用口诀');
    expect(catalog.records.last.keywordTerms, ['罚款', '拘留']);
    expect(
      () => catalog.records.add(catalog.records.first),
      throwsUnsupportedError,
    );
  });

  test('applies the Android free-row boundary with a VIP override', () {
    final catalog = SkillMnemonicsCatalog.fromBody({
      'records': [
        {'skillId': '1'},
        {'skillId': '2'},
        {'skillId': '3'},
      ],
    }, freeCount: 2);

    expect(catalog.isUnlocked(0), isTrue);
    expect(catalog.isUnlocked(1), isTrue);
    expect(catalog.isUnlocked(2), isFalse);
    expect(catalog.isUnlocked(2, isVip: true), isTrue);
  });

  test('rejects a malformed page body', () {
    expect(
      () => SkillMnemonicsCatalog.fromBody([], freeCount: 3),
      throwsFormatException,
    );
    expect(
      () => SkillMnemonicsCatalog.fromBody({
        'records': 'not-a-list',
      }, freeCount: 3),
      throwsFormatException,
    );
  });

  test('treats Android null or omitted records as an empty catalog', () {
    expect(
      SkillMnemonicsCatalog.fromBody({'records': null}, freeCount: 3).records,
      isEmpty,
    );
    expect(
      SkillMnemonicsCatalog.fromBody(const {}, freeCount: 3).records,
      isEmpty,
    );
  });
}
