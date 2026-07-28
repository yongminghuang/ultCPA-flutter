import 'dart:convert';

import '../main_tabs/main_tabs_models.dart';
import '../skill_mnemonics/skill_mnemonics_models.dart';

enum PracticeQuestionKind { judgment, single, multiple }

final class PracticeOption {
  const PracticeOption({required this.key, required this.text});

  final String key;
  final String text;
}

final class PracticeAnswer {
  const PracticeAnswer({required this.choose, required this.isRight});

  final String choose;
  final bool isRight;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PracticeAnswer &&
            other.choose == choose &&
            other.isRight == isRight;
  }

  @override
  int get hashCode => Object.hash(choose, isRight);
}

sealed class PracticeItem {
  const PracticeItem();

  String get stableId;
}

final class PracticeSkillItem extends PracticeItem {
  const PracticeSkillItem(this.skill);

  final SkillMnemonic skill;

  @override
  String get stableId => 'skill:${skill.skillId}';
}

final class PracticeQuestionItem extends PracticeItem {
  const PracticeQuestionItem(this.question);

  final PracticeQuestion question;

  @override
  String get stableId => 'question:${question.id}';
}

final class PracticeQuestion {
  const PracticeQuestion({
    required this.id,
    required this.wrongCountId,
    required this.shelfId,
    required this.goodsId,
    required this.level,
    required this.subject,
    required this.title,
    required this.content,
    required this.type,
    required this.questionType,
    required this.kind,
    required this.options,
    required this.answer,
    required this.analysis,
    required this.keyword,
    required this.titleKeyword,
    required this.answerKeyword,
    required this.tags,
    required this.serverAnswer,
    required this.isCollected,
  });

  factory PracticeQuestion.fromMap(Map<String, dynamic> map) {
    final id = _text(map['questionId']).isNotEmpty
        ? _text(map['questionId'])
        : _text(map['id']);
    final title = _text(map['title']);
    final content = _text(map['content']);
    final questionType = _text(map['questionType']);
    final answer = normalizePracticeChoices([_text(map['answer'])]);
    final choose = normalizePracticeChoices([_text(map['choose'])]);
    final rawRight = _nullableBoolean(map['isRight']);
    final legacyId = _text(map['id']);
    return PracticeQuestion(
      id: id,
      wrongCountId: legacyId.isNotEmpty ? legacyId : id,
      shelfId: _text(map['shelfId']),
      goodsId: _text(map['goodsId']),
      level: _text(map['level']),
      subject: _text(map['subject']),
      title: title,
      content: content,
      type: _text(map['type']),
      questionType: questionType,
      kind: _questionKind(questionType),
      options: _options(map['options']),
      answer: answer,
      analysis: _text(map['analysis']),
      keyword: _text(map['keyword']),
      titleKeyword: _text(map['titleKeyword']),
      answerKeyword: _text(map['answerKeyword']),
      tags: _text(map['tags']),
      serverAnswer: choose.isEmpty
          ? null
          : PracticeAnswer(
              choose: choose,
              isRight: rawRight ?? choose == answer,
            ),
      isCollected: _boolean(map['isCollect']),
    );
  }

  final String id;
  final String wrongCountId;
  final String shelfId;
  final String goodsId;
  final String level;
  final String subject;
  final String title;
  final String content;
  final String type;
  final String questionType;
  final PracticeQuestionKind kind;
  final List<PracticeOption> options;
  final String answer;
  final String analysis;
  final String keyword;
  final String titleKeyword;
  final String answerKeyword;
  final String tags;
  final PracticeAnswer? serverAnswer;
  final bool isCollected;

  PracticeQuestion withServerAnswer(PracticeAnswer? value) {
    return PracticeQuestion(
      id: id,
      wrongCountId: wrongCountId,
      shelfId: shelfId,
      goodsId: goodsId,
      level: level,
      subject: subject,
      title: title,
      content: content,
      type: type,
      questionType: questionType,
      kind: kind,
      options: options,
      answer: answer,
      analysis: analysis,
      keyword: keyword,
      titleKeyword: titleKeyword,
      answerKeyword: answerKeyword,
      tags: tags,
      serverAnswer: value,
      isCollected: isCollected,
    );
  }

  String get displayTitle => title.trim().isNotEmpty ? title : content;
  String get normalizedAnswer => answer;

  bool isCorrect(Iterable<String> choices) {
    return normalizePracticeChoices(choices) == normalizedAnswer;
  }
}

final class PracticeAccess {
  const PracticeAccess({
    required this.fullAccess,
    required this.freeQuestionCount,
  });

  final bool fullAccess;
  final int freeQuestionCount;
}

enum PracticeReviewKind { errors, collections }

final class PracticeBehavior {
  const PracticeBehavior.standard()
    : restoreServerAnswers = true,
      persistAnswers = true,
      showResults = true,
      emptyMessage = '暂无练习内容',
      lastItemMessage = '',
      reviewKind = null;

  const PracticeBehavior.review({required this.emptyMessage})
    : restoreServerAnswers = false,
      persistAnswers = false,
      showResults = false,
      lastItemMessage = '当前已是最后一题',
      reviewKind = null;

  const PracticeBehavior.errorReview({required this.emptyMessage})
    : restoreServerAnswers = false,
      persistAnswers = false,
      showResults = false,
      lastItemMessage = '当前已是最后一题',
      reviewKind = PracticeReviewKind.errors;

  const PracticeBehavior.collectionReview({required this.emptyMessage})
    : restoreServerAnswers = false,
      persistAnswers = false,
      showResults = false,
      lastItemMessage = '当前已是最后一题',
      reviewKind = PracticeReviewKind.collections;

  const PracticeBehavior.dailyReview()
    : restoreServerAnswers = true,
      persistAnswers = false,
      showResults = false,
      emptyMessage = '暂无解析数据',
      lastItemMessage = '当前已是最后一题',
      reviewKind = null;

  final bool restoreServerAnswers;
  final bool persistAnswers;
  final bool showResults;
  final String emptyMessage;
  final String lastItemMessage;
  final PracticeReviewKind? reviewKind;
}

final class PracticeCatalog {
  const PracticeCatalog({
    required this.items,
    required this.access,
    required this.title,
    this.behavior = const PracticeBehavior.standard(),
    this.chapterContext,
  });

  final List<PracticeItem> items;
  final PracticeAccess access;
  final String title;
  final PracticeBehavior behavior;
  final PracticeChapterContext? chapterContext;
}

final class PracticeChapterTarget {
  const PracticeChapterTarget({
    required this.catalogIndex,
    required this.chapterIndex,
    required this.title,
    required this.unlocked,
  });

  final int catalogIndex;
  final int chapterIndex;
  final String title;
  final bool unlocked;
}

final class PracticeChapterContext {
  const PracticeChapterContext({
    required this.module,
    required this.catalogIndex,
    required this.chapterIndex,
    required this.title,
    required this.questionIds,
    required this.nextChapter,
  });

  final HomeModule module;
  final int catalogIndex;
  final int chapterIndex;
  final String title;
  final List<String> questionIds;
  final PracticeChapterTarget? nextChapter;
}

final class PracticePageBatch {
  const PracticePageBatch({
    required this.items,
    required this.total,
    required this.pages,
    required this.current,
    required this.size,
  });

  factory PracticePageBatch.fromBody(Object? body) {
    if (body is! Map) {
      throw const FormatException('练题响应 body 不是对象');
    }
    final map = Map<String, dynamic>.from(body);
    final records = map['records'];
    if (records != null && records is! List) {
      throw const FormatException('练题响应 records 不是数组');
    }
    final items = parsePracticeRecords(records ?? const <Object?>[]);
    return PracticePageBatch(
      items: items,
      total: _integer(map['total'], items.length),
      pages: _integer(map['pages'], 1),
      current: _integer(map['current'], 1),
      size: _integer(map['size'], 30),
    );
  }

  factory PracticePageBatch.fromListBody(Object? body) {
    final items = parsePracticeRecords(body);
    return PracticePageBatch(
      items: items,
      total: items.length,
      pages: 1,
      current: 1,
      size: items.length,
    );
  }

  final List<PracticeItem> items;
  final int total;
  final int pages;
  final int current;
  final int size;
}

List<PracticeItem> parsePracticeRecords(Object? rawRecords) {
  if (rawRecords is! List) {
    throw const FormatException('练题 records 不是数组');
  }
  final items = <PracticeItem>[];
  for (final value in rawRecords) {
    if (value is! Map) continue;
    final map = Map<String, dynamic>.from(value);
    final type = _text(map['type']).trim();
    if (type == '文件') continue;
    if (type == '大招') {
      final skill = SkillMnemonic.fromMap(map);
      if (skill.skillId.isNotEmpty || skill.displayText.trim().isNotEmpty) {
        items.add(PracticeSkillItem(skill));
      }
      continue;
    }
    final question = PracticeQuestion.fromMap(map);
    if (question.id.isNotEmpty || question.displayTitle.trim().isNotEmpty) {
      items.add(PracticeQuestionItem(question));
    }
  }
  return List.unmodifiable(items);
}

String normalizePracticeChoices(Iterable<String> values) {
  final found = <String>{};
  for (final value in values) {
    for (final match in RegExp('[A-F]').allMatches(value.toUpperCase())) {
      found.add(match.group(0)!);
    }
  }
  const order = ['A', 'B', 'C', 'D', 'E', 'F'];
  return order.where(found.contains).join();
}

PracticeQuestionKind _questionKind(String value) {
  return switch (value.trim()) {
    '判断题' || '判断' => PracticeQuestionKind.judgment,
    '多选题' || '多选' => PracticeQuestionKind.multiple,
    _ => PracticeQuestionKind.single,
  };
}

List<PracticeOption> _options(Object? raw) {
  Object? decoded = raw;
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      decoded = null;
    }
  }
  if (decoded is! Map) return const [];
  const keys = ['A', 'B', 'C', 'D', 'E', 'F'];
  final options = <PracticeOption>[];
  for (final key in keys) {
    final text = _text(decoded[key]);
    if (text.trim().isNotEmpty) {
      options.add(PracticeOption(key: key, text: text));
    }
  }
  return List.unmodifiable(options);
}

String _text(Object? value) {
  if (value == null) return '';
  final text = value.toString();
  return text.trim().toLowerCase() == 'null' ? '' : text;
}

int _integer(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _boolean(Object? value) => _nullableBoolean(value) ?? false;

bool? _nullableBoolean(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  return switch (value.toString().trim().toLowerCase()) {
    '1' || 'true' => true,
    '0' || 'false' => false,
    _ => null,
  };
}
