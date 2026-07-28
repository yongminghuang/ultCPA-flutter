import 'dart:convert';

import 'daily_skill_models.dart';

abstract interface class DailySkillProgressPersistence {
  Future<String> readDailySkillProgressJson();

  Future<void> writeDailySkillProgressJson(String json);

  Future<String> readDailySkillCheckInJson();

  Future<void> writeDailySkillCheckInJson(String json);
}

abstract interface class DailySkillProgressDataSource {
  Future<DailySkillProgress?> loadToday();

  Future<DailySkillProgress> ensureToday({
    required String skillId,
    required int moduleId,
    required int shelfId,
  });

  Future<void> persistQuestionOrder(List<int> questionOrder);

  Future<void> recordAnswer({
    required int questionId,
    required String choose,
    required bool isRight,
    required int currentIndex,
    required List<int> questionOrder,
  });

  Future<void> markFinished(bool finished);

  Future<int> completedDaysCount();

  Future<void> clear();
}

final class DailySkillProgress {
  DailySkillProgress({
    required this.date,
    required this.skillId,
    required this.moduleId,
    required this.shelfId,
    required this.currentIndex,
    required this.isFinished,
    required List<int> questionOrder,
    required List<int> rightQuestionIds,
    required List<int> wrongQuestionIds,
    required Map<int, DailySkillAnswer> answers,
  }) : questionOrder = List<int>.unmodifiable(questionOrder),
       rightQuestionIds = List<int>.unmodifiable(rightQuestionIds),
       wrongQuestionIds = List<int>.unmodifiable(wrongQuestionIds),
       answers = Map<int, DailySkillAnswer>.unmodifiable(answers);

  factory DailySkillProgress.empty({
    required String date,
    required String skillId,
    required int moduleId,
    required int shelfId,
  }) {
    return DailySkillProgress(
      date: date,
      skillId: skillId,
      moduleId: moduleId,
      shelfId: shelfId,
      currentIndex: 0,
      isFinished: false,
      questionOrder: const [],
      rightQuestionIds: const [],
      wrongQuestionIds: const [],
      answers: const {},
    );
  }

  final String date;
  final String skillId;
  final int moduleId;
  final int shelfId;
  final int currentIndex;
  final bool isFinished;
  final List<int> questionOrder;
  final List<int> rightQuestionIds;
  final List<int> wrongQuestionIds;
  final Map<int, DailySkillAnswer> answers;

  int get doneCount => answers.length;
  int get rightCount => rightQuestionIds.length;
  int get wrongCount => wrongQuestionIds.length;

  int resolveResumeIndex(List<int> order) {
    if (order.isEmpty) return currentIndex < 0 ? 0 : currentIndex;
    if (answers.isEmpty) return 0;
    for (var index = 0; index < order.length; index += 1) {
      if (!answers.containsKey(order[index])) return index;
    }
    return order.length - 1;
  }

  DailySkillProgress copyWith({
    String? skillId,
    int? moduleId,
    int? shelfId,
    int? currentIndex,
    bool? isFinished,
    List<int>? questionOrder,
    List<int>? rightQuestionIds,
    List<int>? wrongQuestionIds,
    Map<int, DailySkillAnswer>? answers,
  }) {
    return DailySkillProgress(
      date: date,
      skillId: skillId ?? this.skillId,
      moduleId: moduleId ?? this.moduleId,
      shelfId: shelfId ?? this.shelfId,
      currentIndex: currentIndex ?? this.currentIndex,
      isFinished: isFinished ?? this.isFinished,
      questionOrder: questionOrder ?? this.questionOrder,
      rightQuestionIds: rightQuestionIds ?? this.rightQuestionIds,
      wrongQuestionIds: wrongQuestionIds ?? this.wrongQuestionIds,
      answers: answers ?? this.answers,
    );
  }

  Map<String, Object?> toAndroidMap() {
    return {
      'date': date,
      'skillId': skillId,
      'moduleId': moduleId,
      'shelfId': shelfId,
      'currentIndex': currentIndex,
      'isFinished': isFinished,
      'doneCount': doneCount,
      'rightCount': rightCount,
      'wrongCount': wrongCount,
      'questionOrder': questionOrder,
      'rightQuestionIds': rightQuestionIds,
      'wrongQuestionIds': wrongQuestionIds,
      'answers': {
        for (final entry in answers.entries)
          '${entry.key}': {
            'pick': entry.value.pick,
            'isRight': entry.value.isRight,
            'timestamp': entry.value.timestamp,
          },
      },
    };
  }
}

final class DailySkillProgressStore implements DailySkillProgressDataSource {
  DailySkillProgressStore({
    required DailySkillProgressPersistence persistence,
    DateTime Function()? now,
  }) : _persistence = persistence,
       _now = now ?? DateTime.now;

  final DailySkillProgressPersistence _persistence;
  final DateTime Function() _now;

  @override
  Future<DailySkillProgress?> loadToday() async {
    final progress = await _loadProgress();
    return progress?.date == _todayKey() ? progress : null;
  }

  @override
  Future<DailySkillProgress> ensureToday({
    required String skillId,
    required int moduleId,
    required int shelfId,
  }) async {
    final today = _todayKey();
    var progress = await _loadProgress();
    if (progress == null || progress.date != today) {
      progress = DailySkillProgress.empty(
        date: today,
        skillId: skillId,
        moduleId: moduleId,
        shelfId: shelfId,
      );
    } else {
      progress = progress.copyWith(
        skillId: skillId.trim().isEmpty ? progress.skillId : skillId,
        moduleId: moduleId > 0 ? moduleId : progress.moduleId,
        shelfId: shelfId > 0 ? shelfId : progress.shelfId,
      );
    }
    await _saveProgress(progress);
    return progress;
  }

  @override
  Future<void> persistQuestionOrder(List<int> questionOrder) async {
    final order = _positiveIds(questionOrder);
    if (order.isEmpty) return;
    final progress = await loadToday();
    if (progress == null) return;
    await _saveProgress(progress.copyWith(questionOrder: order));
  }

  @override
  Future<void> recordAnswer({
    required int questionId,
    required String choose,
    required bool isRight,
    required int currentIndex,
    required List<int> questionOrder,
  }) async {
    if (questionId <= 0) {
      throw ArgumentError.value(questionId, 'questionId', '必须大于 0');
    }
    final pick = dailySkillAnswerPick(choose);
    if (pick <= 0) {
      throw ArgumentError.value(choose, 'choose', '必须包含 A-F 选项');
    }
    final progress = await _loadProgress();
    if (progress == null || progress.date != _todayKey()) {
      await clear();
      return;
    }
    final answers = Map<int, DailySkillAnswer>.from(progress.answers);
    answers[questionId] = DailySkillAnswer(
      questionId: questionId,
      pick: pick,
      isRight: isRight,
      timestamp: _now().millisecondsSinceEpoch,
    );
    final right = <int>[
      ...progress.rightQuestionIds.where((id) => id != questionId),
    ];
    final wrong = <int>[
      ...progress.wrongQuestionIds.where((id) => id != questionId),
    ];
    (isRight ? right : wrong).add(questionId);
    final order = _positiveIds(questionOrder);
    await _saveProgress(
      progress.copyWith(
        currentIndex: currentIndex < 0 ? 0 : currentIndex,
        questionOrder: order.isEmpty ? progress.questionOrder : order,
        rightQuestionIds: right,
        wrongQuestionIds: wrong,
        answers: answers,
      ),
    );
  }

  @override
  Future<void> markFinished(bool finished) async {
    final progress = await _loadProgress();
    if (progress == null) return;
    await _saveProgress(progress.copyWith(isFinished: finished));
    if (!finished) return;

    final dates = await _loadCompletedDates();
    final today = _todayKey();
    if (!dates.contains(today)) {
      dates.add(today);
      await _persistence.writeDailySkillCheckInJson(
        jsonEncode({'completedDates': dates}),
      );
    }
  }

  @override
  Future<int> completedDaysCount() async {
    return (await _loadCompletedDates()).length;
  }

  @override
  Future<void> clear() {
    return _persistence.writeDailySkillProgressJson('');
  }

  Future<DailySkillProgress?> _loadProgress() async {
    final raw = await _persistence.readDailySkillProgressJson();
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('进度不是对象');
      return _progressFromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> _saveProgress(DailySkillProgress progress) {
    return _persistence.writeDailySkillProgressJson(
      jsonEncode(progress.toAndroidMap()),
    );
  }

  Future<List<String>> _loadCompletedDates() async {
    final raw = await _persistence.readDailySkillCheckInJson();
    if (raw.trim().isEmpty) return <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String>[];
      final values = decoded['completedDates'];
      if (values is! List) return <String>[];
      final result = <String>[];
      for (final value in values) {
        final date = value?.toString().trim() ?? '';
        if (date.isNotEmpty && !result.contains(date)) result.add(date);
      }
      return result;
    } catch (_) {
      return <String>[];
    }
  }

  String _todayKey() {
    final date = _now();
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

final class DisabledDailySkillProgressStore
    implements DailySkillProgressDataSource {
  const DisabledDailySkillProgressStore();

  @override
  Future<DailySkillProgress?> loadToday() async => null;

  @override
  Future<DailySkillProgress> ensureToday({
    required String skillId,
    required int moduleId,
    required int shelfId,
  }) async {
    return DailySkillProgress.empty(
      date: '',
      skillId: skillId,
      moduleId: moduleId,
      shelfId: shelfId,
    );
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
  Future<int> completedDaysCount() async => 0;

  @override
  Future<void> clear() async {}
}

DailySkillProgress _progressFromMap(Map<String, dynamic> map) {
  final answers = <int, DailySkillAnswer>{};
  final rawAnswers = map['answers'];
  if (rawAnswers != null && rawAnswers is! Map) {
    throw const FormatException('每日一招 answers 不是对象');
  }
  for (final entry in (rawAnswers as Map? ?? const {}).entries) {
    final questionId = _integer(entry.key);
    if (questionId <= 0 || entry.value is! Map) continue;
    final answer = Map<String, dynamic>.from(entry.value as Map);
    final pick = _integer(answer['pick']);
    if (pick <= 0) continue;
    answers[questionId] = DailySkillAnswer(
      questionId: questionId,
      pick: pick,
      isRight: _boolean(answer['isRight']),
      timestamp: _integer(answer['timestamp']),
    );
  }

  final right = _ids(
    map['rightQuestionIds'],
  ).where((id) => answers[id]?.isRight == true).toList();
  final wrong = _ids(
    map['wrongQuestionIds'],
  ).where((id) => answers[id]?.isRight == false).toList();
  for (final answer in answers.values) {
    final target = answer.isRight ? right : wrong;
    if (!target.contains(answer.questionId)) target.add(answer.questionId);
  }
  return DailySkillProgress(
    date: map['date']?.toString() ?? '',
    skillId: map['skillId']?.toString() ?? '',
    moduleId: _integer(map['moduleId']),
    shelfId: _integer(map['shelfId']),
    currentIndex: _integer(map['currentIndex']).clamp(0, 1 << 30),
    isFinished: _boolean(map['isFinished']),
    questionOrder: _ids(map['questionOrder']),
    rightQuestionIds: right,
    wrongQuestionIds: wrong,
    answers: answers,
  );
}

List<int> _ids(Object? value) {
  if (value is! List) return const [];
  return _positiveIds(value.map(_integer));
}

List<int> _positiveIds(Iterable<int> values) {
  return List<int>.unmodifiable(values.where((value) => value > 0));
}

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _boolean(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return value?.toString().trim().toLowerCase() == 'true';
}
