abstract interface class PracticeReviewStore {
  Future<int> loadWrongRemovalThreshold();

  Future<void> saveWrongRemovalThreshold(int threshold);

  Future<bool> recordWrongQuestionCorrect(String questionId);
}

final class DisabledPracticeReviewStore implements PracticeReviewStore {
  const DisabledPracticeReviewStore();

  @override
  Future<int> loadWrongRemovalThreshold() async => -1;

  @override
  Future<void> saveWrongRemovalThreshold(int threshold) async {}

  @override
  Future<bool> recordWrongQuestionCorrect(String questionId) async => false;
}
