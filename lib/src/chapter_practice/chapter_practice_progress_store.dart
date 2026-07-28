abstract interface class ChapterPracticeProgressStore {
  Future<int> loadExpandedCatalog({required int moduleId});

  Future<void> saveExpandedCatalog({
    required int moduleId,
    required int catalogIndex,
  });

  Future<int> loadQuestionPosition({
    required int moduleId,
    required int catalogIndex,
    required int chapterIndex,
  });

  Future<void> saveQuestionPosition({
    required int moduleId,
    required int catalogIndex,
    required int chapterIndex,
    required int position,
  });
}

final class DisabledChapterPracticeProgressStore
    implements ChapterPracticeProgressStore {
  const DisabledChapterPracticeProgressStore();

  @override
  Future<int> loadExpandedCatalog({required int moduleId}) async => -1;

  @override
  Future<void> saveExpandedCatalog({
    required int moduleId,
    required int catalogIndex,
  }) async {}

  @override
  Future<int> loadQuestionPosition({
    required int moduleId,
    required int catalogIndex,
    required int chapterIndex,
  }) async => 0;

  @override
  Future<void> saveQuestionPosition({
    required int moduleId,
    required int catalogIndex,
    required int chapterIndex,
    required int position,
  }) async {}
}
