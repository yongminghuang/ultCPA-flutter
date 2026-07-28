import '../main_tabs/main_tabs_models.dart';
import '../practice/practice_models.dart';

final class ExamRequest {
  const ExamRequest({
    required this.module,
    required this.shelfId,
    required this.title,
    this.duration = const Duration(minutes: 135),
  });

  final HomeModule module;
  final int shelfId;
  final String title;
  final Duration duration;

  bool get isValid =>
      module.id > 0 &&
      shelfId > 0 &&
      title.trim().isNotEmpty &&
      duration.inMicroseconds > 0;

  Map<String, dynamic> get queryParameters {
    if (module.id <= 0) {
      throw ArgumentError.value(module.id, 'module.id', '必须大于 0');
    }
    if (shelfId <= 0) {
      throw ArgumentError.value(shelfId, 'shelfId', '必须大于 0');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', '不能为空');
    }
    if (duration.inMicroseconds <= 0) {
      throw ArgumentError.value(duration, 'duration', '必须大于 0');
    }
    return {
      'pageNum': 1,
      'pageSize': 120,
      'modelId': module.id,
      'shelfId': shelfId,
    };
  }
}

final class ExamCatalog {
  ExamCatalog({
    required this.request,
    required List<PracticeQuestion> questions,
    this.hasMemberTier = false,
  }) : questions = List<PracticeQuestion>.unmodifiable(questions);

  final ExamRequest request;
  final List<PracticeQuestion> questions;
  final bool hasMemberTier;
}

enum ExamQuestionStatus { unanswered, right, wrong }

final class ExamAnswerSection {
  ExamAnswerSection({
    required this.kind,
    required this.title,
    required List<int> indexes,
    required List<PracticeQuestion> questions,
    required this.rightCount,
    required this.wrongCount,
    required this.unansweredCount,
  }) : indexes = List<int>.unmodifiable(indexes),
       questions = List<PracticeQuestion>.unmodifiable(questions);

  final PracticeQuestionKind kind;
  final String title;
  final List<int> indexes;
  final List<PracticeQuestion> questions;
  final int rightCount;
  final int wrongCount;
  final int unansweredCount;
}

final class ExamResult {
  ExamResult({
    required this.request,
    required List<PracticeQuestion> questions,
    required Map<String, String> selections,
    required Duration elapsed,
    this.hasMemberTier = false,
  }) : questions = List<PracticeQuestion>.unmodifiable(questions),
       selections = _normalizedSelections(questions, selections),
       elapsed = elapsed.isNegative ? Duration.zero : elapsed {
    sections = _buildSections(this);
  }

  final ExamRequest request;
  final List<PracticeQuestion> questions;
  final Map<String, String> selections;
  final Duration elapsed;
  final bool hasMemberTier;
  late final List<ExamAnswerSection> sections;

  List<PracticeQuestion> get allQuestions => questions;

  List<PracticeQuestion> get wrongQuestions =>
      List<PracticeQuestion>.unmodifiable(
        questions.where(
          (question) => statusFor(question) == ExamQuestionStatus.wrong,
        ),
      );

  int get answeredCount => selections.length;

  int get rightCount => questions
      .where((question) => statusFor(question) == ExamQuestionStatus.right)
      .length;

  int get wrongCount => questions
      .where((question) => statusFor(question) == ExamQuestionStatus.wrong)
      .length;

  int get unansweredCount => questions.length - answeredCount;

  int get accuracyPercent =>
      questions.isEmpty ? 0 : rightCount * 100 ~/ questions.length;

  /// Android mock exams award one point for each of 100 questions, or two
  /// points for each of 50 questions. Other paper sizes are not scored.
  int get score {
    final pointsPerQuestion = switch (questions.length) {
      100 => 1,
      50 => 2,
      _ => 0,
    };
    final value = rightCount * pointsPerQuestion;
    return value > 100 ? 100 : value;
  }

  ExamPrediction get prediction => ExamPrediction.fromScore(score);

  String selectionFor(PracticeQuestion question) =>
      selections[question.id] ?? '';

  PracticeAnswer? answerFor(PracticeQuestion question) {
    final choose = selectionFor(question);
    if (choose.isEmpty) return null;
    return PracticeAnswer(
      choose: choose,
      isRight: question.isCorrect([choose]),
    );
  }

  ExamQuestionStatus statusFor(PracticeQuestion question) {
    final answer = answerFor(question);
    if (answer == null) return ExamQuestionStatus.unanswered;
    return answer.isRight ? ExamQuestionStatus.right : ExamQuestionStatus.wrong;
  }
}

enum ExamPredictionBand { steady, uncertain, low }

final class ExamPrediction {
  const ExamPrediction({
    required this.band,
    required this.levelText,
    required this.actionText,
  });

  factory ExamPrediction.fromScore(int score) {
    if (score >= 80) {
      return const ExamPrediction(
        band: ExamPredictionBand.steady,
        levelText: '稳过',
        actionText: '挑战高分',
      );
    }
    if (score >= 60) {
      return const ExamPrediction(
        band: ExamPredictionBand.uncertain,
        levelText: '悬',
        actionText: '巩固弱项',
      );
    }
    return const ExamPrediction(
      band: ExamPredictionBand.low,
      levelText: '很低',
      actionText: '去提升',
    );
  }

  final ExamPredictionBand band;
  final String levelText;
  final String actionText;
}

Map<String, String> _normalizedSelections(
  List<PracticeQuestion> questions,
  Map<String, String> selections,
) {
  final validIds = questions.map((question) => question.id).toSet();
  final normalized = <String, String>{};
  for (final entry in selections.entries) {
    if (!validIds.contains(entry.key)) continue;
    final choose = normalizePracticeChoices([entry.value]);
    if (choose.isNotEmpty) normalized[entry.key] = choose;
  }
  return Map<String, String>.unmodifiable(normalized);
}

List<ExamAnswerSection> _buildSections(ExamResult result) {
  final grouped = <PracticeQuestionKind, List<int>>{};
  for (var index = 0; index < result.questions.length; index += 1) {
    final question = result.questions[index];
    grouped.putIfAbsent(question.kind, () => <int>[]).add(index);
  }
  return List<ExamAnswerSection>.unmodifiable(
    grouped.entries.map((entry) {
      final questions = entry.value
          .map((index) => result.questions[index])
          .toList(growable: false);
      var rightCount = 0;
      var wrongCount = 0;
      var unansweredCount = 0;
      for (final question in questions) {
        switch (result.statusFor(question)) {
          case ExamQuestionStatus.right:
            rightCount += 1;
          case ExamQuestionStatus.wrong:
            wrongCount += 1;
          case ExamQuestionStatus.unanswered:
            unansweredCount += 1;
        }
      }
      return ExamAnswerSection(
        kind: entry.key,
        title: _sectionTitle(entry.key),
        indexes: entry.value,
        questions: questions,
        rightCount: rightCount,
        wrongCount: wrongCount,
        unansweredCount: unansweredCount,
      );
    }),
  );
}

String _sectionTitle(PracticeQuestionKind kind) {
  return switch (kind) {
    PracticeQuestionKind.single => '· 单项选择题',
    PracticeQuestionKind.multiple => '· 多项选择题',
    PracticeQuestionKind.judgment => '· 判断题',
  };
}
