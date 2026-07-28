import '../network/app_api_client.dart';
import '../storage/legacy_app_state_store.dart';
import 'learning_materials_models.dart';

abstract interface class LearningMaterialsDataSource {
  Future<LearningMaterialsAppSnapshot> readSnapshot();

  Future<List<LearningMaterialsShelf>> loadShelfTabs({
    required int moduleId,
  });

  Future<LearningMaterialsPage> loadPage({
    required int moduleId,
    required int shelfId,
    int pageNumber = 1,
    int pageSize = 20,
  });
}

final class LearningMaterialsRepository implements LearningMaterialsDataSource {
  const LearningMaterialsRepository({
    required AppApiClient api,
    required LegacyAppStateStore stateStore,
  }) : _api = api,
       _stateStore = stateStore;

  final AppApiClient _api;
  final LegacyAppStateStore _stateStore;

  @override
  Future<LearningMaterialsAppSnapshot> readSnapshot() async {
    return LearningMaterialsAppSnapshot.fromMap(
      await _stateStore.readAppSnapshot(),
    );
  }

  @override
  Future<List<LearningMaterialsShelf>> loadShelfTabs({
    required int moduleId,
  }) async {
    if (moduleId <= 0) throw ArgumentError.value(moduleId, 'moduleId');
    final body = await _api.getBody(
      '/app/shelf/getShelfTree',
      queryParameters: {'shelfId': moduleId},
    );
    return learningMaterialsTabsFromBody(body);
  }

  @override
  Future<LearningMaterialsPage> loadPage({
    required int moduleId,
    required int shelfId,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    if (moduleId <= 0) throw ArgumentError.value(moduleId, 'moduleId');
    if (shelfId <= 0) throw ArgumentError.value(shelfId, 'shelfId');
    if (pageNumber <= 0) throw ArgumentError.value(pageNumber, 'pageNumber');
    if (pageSize <= 0) throw ArgumentError.value(pageSize, 'pageSize');
    final body = await _api.getBody(
      '/app/goods/pageGoodsData',
      queryParameters: {
        'pageNum': pageNumber,
        'pageSize': pageSize,
        'modelId': moduleId,
        'shelfId': shelfId,
      },
    );
    return LearningMaterialsPage.fromBody(body);
  }
}
