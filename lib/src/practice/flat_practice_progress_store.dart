abstract interface class FlatPracticeProgressStore {
  Future<int> loadFlatQuestionPosition({required int shelfId});

  Future<void> saveFlatQuestionPosition({
    required int shelfId,
    required int position,
  });
}

final class DisabledFlatPracticeProgressStore
    implements FlatPracticeProgressStore {
  const DisabledFlatPracticeProgressStore();

  @override
  Future<int> loadFlatQuestionPosition({required int shelfId}) async => 0;

  @override
  Future<void> saveFlatQuestionPosition({
    required int shelfId,
    required int position,
  }) async {}
}
