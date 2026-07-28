import '../main_tabs/main_tabs_models.dart';
import '../network/app_api_client.dart';
import '../storage/legacy_app_state_store.dart';
import 'skill_mnemonics_entitlement.dart';
import 'skill_mnemonics_models.dart';

abstract interface class SkillMnemonicsDataSource {
  Future<SkillMnemonicsCatalog> load(HomeModule module);
}

final class SkillMnemonicsRepository implements SkillMnemonicsDataSource {
  SkillMnemonicsRepository({
    required AppApiClient api,
    required LegacyAppStateStore stateStore,
    DateTime Function()? now,
  }) : _api = api,
       _stateStore = stateStore,
       _entitlementResolver = SkillMnemonicsEntitlementResolver(now: now);

  final AppApiClient _api;
  final LegacyAppStateStore _stateStore;
  final SkillMnemonicsEntitlementResolver _entitlementResolver;

  @override
  Future<SkillMnemonicsCatalog> load(HomeModule module) async {
    if (module.id <= 0) {
      throw ArgumentError.value(module.id, 'module.id', '必须大于 0');
    }
    final results = await Future.wait<Object?>([
      _api.getBody(
        '/app/goods/pageGoodsData',
        queryParameters: {'pageNum': 1, 'pageSize': 200, 'shelfId': module.id},
      ),
      _stateStore.readAppSnapshot(),
    ]);
    final snapshot = results[1] is Map
        ? Map<String, dynamic>.from(results[1] as Map)
        : <String, dynamic>{};
    final rawFreeCount = snapshot['skillFormulaFreeCount'];
    final freeCount = _integer(rawFreeCount, 3).clamp(0, 0x7fffffff);
    var isVip = false;
    if (snapshot['isLoggedIn'] == true) {
      try {
        final benefits = await _api.getBody('/app/user/getUserBenefits');
        isVip = _entitlementResolver.isVip(
          benefits,
          category: snapshot['category']?.toString() ?? '',
          level: snapshot['selectedLevel']?.toString() ?? '',
          subject: snapshot['selectedSubject']?.toString() ?? '',
        );
      } catch (_) {
        isVip = false;
      }
    }
    return SkillMnemonicsCatalog.fromBody(
      results[0],
      freeCount: freeCount,
      isVip: isVip,
    );
  }
}

int _integer(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
