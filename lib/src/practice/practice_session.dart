import 'practice_models.dart';

sealed class PracticeTransition {
  const PracticeTransition();
}

final class PracticeDraftChanged extends PracticeTransition {
  const PracticeDraftChanged({required this.question, required this.choose});

  final PracticeQuestion question;
  final String choose;
}

final class PracticeSubmitted extends PracticeTransition {
  const PracticeSubmitted({required this.question, required this.answer});

  final PracticeQuestion question;
  final PracticeAnswer answer;
}

final class PracticeLocked extends PracticeTransition {
  const PracticeLocked({
    required this.question,
    required this.freeQuestionCount,
  });

  final PracticeQuestion question;
  final int freeQuestionCount;
}

final class PracticeNoChange extends PracticeTransition {
  const PracticeNoChange();
}

final class PracticeSession {
  PracticeSession(PracticeCatalog catalog)
    : _items = List.of(catalog.items),
      access = catalog.access {
    for (final item in _items.whereType<PracticeQuestionItem>()) {
      _collected[item.question.id] =
          catalog.behavior.reviewKind == PracticeReviewKind.collections ||
          item.question.isCollected;
      if (!catalog.behavior.restoreServerAnswers) continue;
      final answer = item.question.serverAnswer;
      if (answer != null) _answers[item.question.id] = answer;
    }
  }

  final List<PracticeItem> _items;
  final PracticeAccess access;
  final Map<String, PracticeAnswer> _answers = {};
  final Map<String, Set<String>> _drafts = {};
  final Map<String, bool> _collected = {};
  final Set<String> _newlySubmittedIds = {};
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;
  List<PracticeItem> get items => List.unmodifiable(_items);

  PracticeItem? get currentItem {
    if (_currentIndex < 0 || _currentIndex >= _items.length) return null;
    return _items[_currentIndex];
  }

  PracticeQuestion? get currentQuestion {
    return switch (currentItem) {
      PracticeQuestionItem(:final question) => question,
      _ => null,
    };
  }

  Map<String, PracticeAnswer> get answers => Map.unmodifiable(_answers);

  int get newlySubmittedCount => _newlySubmittedIds.length;
  int get answeredCount => _answers.length;
  int get rightCount =>
      _answers.values.where((answer) => answer.isRight).length;
  int get wrongCount => answeredCount - rightCount;

  int get unansweredCount {
    final total = _items.whereType<PracticeQuestionItem>().length;
    final value = total - answeredCount;
    return value < 0 ? 0 : value;
  }

  double get accuracy => answeredCount == 0 ? 0 : rightCount / answeredCount;

  PracticeAnswer? answerFor(PracticeQuestion question) {
    return _answers[question.id];
  }

  void restoreAnswer(PracticeQuestion question, PracticeAnswer answer) {
    final exists = _items.any(
      (item) => item is PracticeQuestionItem && item.question.id == question.id,
    );
    if (!exists) return;
    _answers[question.id] = answer;
    _drafts.remove(question.id);
    _newlySubmittedIds.remove(question.id);
  }

  bool isCollected(PracticeQuestion question) {
    return _collected[question.id] ?? question.isCollected;
  }

  void setCollected(PracticeQuestion question, bool collected) {
    _collected[question.id] = collected;
  }

  bool removeQuestion(String questionId) {
    final removedIndex = _items.indexWhere(
      (item) => item is PracticeQuestionItem && item.question.id == questionId,
    );
    if (removedIndex < 0) return false;

    _items.removeAt(removedIndex);
    _answers.remove(questionId);
    _drafts.remove(questionId);
    _collected.remove(questionId);
    _newlySubmittedIds.remove(questionId);

    if (_items.isEmpty) {
      _currentIndex = 0;
    } else if (removedIndex == _currentIndex) {
      _currentIndex = removedIndex > 0 ? removedIndex - 1 : 0;
    } else if (removedIndex < _currentIndex) {
      _currentIndex -= 1;
    }
    return true;
  }

  String draftFor(PracticeQuestion question) {
    return normalizePracticeChoices(_drafts[question.id] ?? const []);
  }

  bool canVisit(int index) {
    if (index < 0 || index >= _items.length) return false;
    final item = _items[index];
    if (item is! PracticeQuestionItem) return true;
    return !_isLocked(item.question);
  }

  bool moveNext() => jumpTo(_currentIndex + 1);

  bool movePrevious() => jumpTo(_currentIndex - 1);

  bool jumpTo(int index) {
    if (!canVisit(index)) return false;
    _currentIndex = index;
    return true;
  }

  PracticeTransition select(String rawChoice) {
    final question = currentQuestion;
    if (question == null || question.kind == PracticeQuestionKind.multiple) {
      return const PracticeNoChange();
    }
    if (_answers.containsKey(question.id)) return const PracticeNoChange();
    if (_isLocked(question)) return _locked(question);
    final choice = _validSingleChoice(question, rawChoice);
    if (choice == null) return const PracticeNoChange();
    return _submit(question, choice);
  }

  PracticeTransition toggleMultiple(String rawChoice) {
    final question = currentQuestion;
    if (question == null || question.kind != PracticeQuestionKind.multiple) {
      return const PracticeNoChange();
    }
    if (_answers.containsKey(question.id)) return const PracticeNoChange();
    if (_isLocked(question)) return _locked(question);
    final choice = _validSingleChoice(question, rawChoice);
    if (choice == null) return const PracticeNoChange();

    final draft = _drafts.putIfAbsent(question.id, () => <String>{});
    if (!draft.add(choice)) draft.remove(choice);
    return PracticeDraftChanged(
      question: question,
      choose: normalizePracticeChoices(draft),
    );
  }

  PracticeTransition confirmMultiple() {
    final question = currentQuestion;
    if (question == null || question.kind != PracticeQuestionKind.multiple) {
      return const PracticeNoChange();
    }
    if (_answers.containsKey(question.id)) return const PracticeNoChange();
    if (_isLocked(question)) return _locked(question);
    final choose = draftFor(question);
    if (choose.isEmpty) return const PracticeNoChange();
    return _submit(question, choose);
  }

  void reset() {
    _answers.clear();
    _drafts.clear();
    _newlySubmittedIds.clear();
    _currentIndex = 0;
  }

  PracticeTransition _submit(PracticeQuestion question, String choose) {
    final answer = PracticeAnswer(
      choose: choose,
      isRight: question.isCorrect([choose]),
    );
    _answers[question.id] = answer;
    _newlySubmittedIds.add(question.id);
    _drafts.remove(question.id);
    return PracticeSubmitted(question: question, answer: answer);
  }

  bool _isLocked(PracticeQuestion question) {
    if (_answers.containsKey(question.id) || access.fullAccess) return false;
    final freeQuestionCount = access.freeQuestionCount < 0
        ? 0
        : access.freeQuestionCount;
    return newlySubmittedCount >= freeQuestionCount;
  }

  PracticeLocked _locked(PracticeQuestion question) {
    return PracticeLocked(
      question: question,
      freeQuestionCount: access.freeQuestionCount < 0
          ? 0
          : access.freeQuestionCount,
    );
  }
}

String? _validSingleChoice(PracticeQuestion question, String rawChoice) {
  final normalized = normalizePracticeChoices([rawChoice]);
  if (normalized.length != 1) return null;
  final exists = question.options.any((option) => option.key == normalized);
  return exists ? normalized : null;
}
