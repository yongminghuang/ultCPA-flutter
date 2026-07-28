abstract interface class LegacyAppStateStore {
  Future<Map<String, dynamic>> readAppSnapshot();

  Future<void> persistCategorySelection({
    required String categoryBodyJson,
    required String category,
    required Map<String, dynamic> selectedCategory,
    required String selectedCategoryKey,
    required int marketId,
    required String subject,
  });
}
