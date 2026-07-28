import '../practice/practice_models.dart';
import 'exam_models.dart';

final class ExamSession {
  ExamSession(this.catalog);

  final ExamCatalog catalog;
  final Map<String, Set<String>> _selections = {};
  int _currentIndex = 0;
  ExamResult? _finishedResult;

  int get currentIndex => _currentIndex;
  bool get isFinished => _finishedResult != null;

  PracticeQuestion? get currentQuestion {
    if (_currentIndex < 0 || _currentIndex >= catalog.questions.length) {
      return null;
    }
    return catalog.questions[_currentIndex];
  }

  Map<String, String> get selections => Map<String, String>.unmodifiable({
    for (final entry in _selections.entries)
      if (entry.value.isNotEmpty)
        entry.key: normalizePracticeChoices(entry.value),
  });

  int get answeredCount => selections.length;
  int get unansweredCount => catalog.questions.length - answeredCount;

  String selectedFor(PracticeQuestion question) {
    return normalizePracticeChoices(
      _selections[question.id] ?? const <String>{},
    );
  }

  bool select(String rawChoice) {
    if (isFinished) return false;
    final question = currentQuestion;
    if (question == null) return false;
    final choice = _validChoice(question, rawChoice);
    if (choice == null) return false;
    if (question.kind == PracticeQuestionKind.multiple) {
      final selected = _selections.putIfAbsent(question.id, () => <String>{});
      final changed = selected.add(choice);
      if (!changed) selected.remove(choice);
      if (selected.isEmpty) _selections.remove(question.id);
      return true;
    }
    final previous = selectedFor(question);
    if (previous == choice) return false;
    _selections[question.id] = <String>{choice};
    return true;
  }

  bool moveNext() => jumpTo(_currentIndex + 1);

  bool movePrevious() => jumpTo(_currentIndex - 1);

  bool jumpTo(int index) {
    if (isFinished || index < 0 || index >= catalog.questions.length) {
      return false;
    }
    _currentIndex = index;
    return true;
  }

  ExamResult finish({required Duration elapsed}) {
    final finished = _finishedResult;
    if (finished != null) return finished;
    final result = ExamResult(
      request: catalog.request,
      questions: catalog.questions,
      selections: selections,
      elapsed: elapsed,
      hasMemberTier: catalog.hasMemberTier,
    );
    _finishedResult = result;
    return result;
  }
}

String? _validChoice(PracticeQuestion question, String rawChoice) {
  final choice = normalizePracticeChoices([rawChoice]);
  if (choice.length != 1) return null;
  return question.options.any((option) => option.key == choice) ? choice : null;
}
