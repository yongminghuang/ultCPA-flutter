import '../main_tabs/main_tabs_models.dart';
import '../practice/practice_models.dart';
import '../skill_mnemonics/skill_mnemonics_models.dart';

final class DailySkillDetail {
  const DailySkillDetail({
    required this.module,
    required this.skill,
    required this.effectiveShelfId,
    required this.imageUrl,
  });

  final HomeModule module;
  final SkillMnemonic skill;
  final int effectiveShelfId;
  final String imageUrl;
}

final class DailySkillAnswer {
  const DailySkillAnswer({
    required this.questionId,
    required this.pick,
    required this.isRight,
    required this.timestamp,
  });

  factory DailySkillAnswer.fromChoose({
    required int questionId,
    required String choose,
    required bool isRight,
    required int timestamp,
  }) {
    return DailySkillAnswer(
      questionId: questionId,
      pick: dailySkillAnswerPick(choose),
      isRight: isRight,
      timestamp: timestamp,
    );
  }

  final int questionId;
  final int pick;
  final bool isRight;
  final int timestamp;

  String get choose => dailySkillChooseFromPick(pick);
}

SkillMnemonic? parseDailySkillBody(Object? body) {
  if (body == null) return null;
  if (body is! Map) {
    throw const FormatException('每日一招响应 body 不是对象');
  }
  final map = Map<String, dynamic>.from(body);
  final direct = SkillMnemonic.fromMap(map);
  if (_hasSkillPayload(direct)) return direct;

  final rawRecords = map['records'];
  if (rawRecords != null && rawRecords is! List) {
    throw const FormatException('每日一招响应 records 不是数组');
  }
  final records = rawRecords as List? ?? const <Object?>[];
  if (records.isEmpty) return null;
  final first = records.first;
  if (first is! Map) {
    throw const FormatException('每日一招条目不是对象');
  }
  final skill = SkillMnemonic.fromMap(Map<String, dynamic>.from(first));
  return _hasSkillPayload(skill) ? skill : null;
}

int dailySkillAnswerPick(String choose) {
  final normalized = normalizePracticeChoices([choose]);
  var pick = 0;
  for (var index = 0; index < _answerKeys.length; index += 1) {
    if (normalized.contains(_answerKeys[index])) pick |= 1 << index;
  }
  return pick;
}

String dailySkillChooseFromPick(int pick) {
  final result = StringBuffer();
  for (var index = 0; index < _answerKeys.length; index += 1) {
    if ((pick & (1 << index)) != 0) result.write(_answerKeys[index]);
  }
  return result.toString();
}

PracticeCatalog buildDailySkillAnalysisCatalog({
  required List<PracticeQuestion> questions,
  required Map<int, DailySkillAnswer> answers,
  required Iterable<int> wrongQuestionIds,
  required bool onlyWrong,
}) {
  final wrongIds = wrongQuestionIds.toSet();
  final items = <PracticeItem>[];
  for (final question in questions) {
    final questionId = int.tryParse(question.id.trim()) ?? 0;
    if (onlyWrong && !wrongIds.contains(questionId)) continue;
    final saved = answers[questionId];
    final answer = saved == null
        ? null
        : PracticeAnswer(choose: saved.choose, isRight: saved.isRight);
    items.add(PracticeQuestionItem(question.withServerAnswer(answer)));
  }
  return PracticeCatalog(
    items: List<PracticeItem>.unmodifiable(items),
    access: const PracticeAccess(fullAccess: true, freeQuestionCount: 0),
    title: onlyWrong ? '错题解析' : '查看全部解析',
    behavior: const PracticeBehavior.dailyReview(),
  );
}

bool _hasSkillPayload(SkillMnemonic skill) {
  return skill.skillId.trim().isNotEmpty ||
      skill.text.trim().isNotEmpty ||
      skill.name.trim().isNotEmpty;
}

const _answerKeys = ['A', 'B', 'C', 'D', 'E', 'F'];
