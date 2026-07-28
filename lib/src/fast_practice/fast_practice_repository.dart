import '../main_tabs/main_tabs_models.dart';
import '../network/app_api_client.dart';
import '../skill_mnemonics/skill_mnemonics_entitlement.dart';
import '../storage/legacy_app_state_store.dart';
import 'fast_practice_models.dart';

abstract interface class FastPracticeDataSource {
  Future<FastPracticeEntryDestination> resolveEntry(HomeModule module);

  Future<FastPracticeCatalog> loadCatalog(HomeModule module);
}

final class FastPracticeRepository implements FastPracticeDataSource {
  FastPracticeRepository({
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
  Future<FastPracticeEntryDestination> resolveEntry(HomeModule module) async {
    if (!_isValidModule(module)) return FastPracticeEntryDestination.empty;
    final snapshot = await _stateStore.readAppSnapshot();
    if (snapshot['isLoggedIn'] != true) {
      return FastPracticeEntryDestination.landing;
    }
    try {
      final benefits = await _api.getBody('/app/user/getUserBenefits');
      final hasAccess = _entitlementResolver.hasFastPracticeAccess(
        benefits,
        category: snapshot['category']?.toString() ?? '',
        level: snapshot['selectedLevel']?.toString() ?? '',
        subject: snapshot['selectedSubject']?.toString() ?? '',
      );
      return hasAccess
          ? FastPracticeEntryDestination.catalog
          : FastPracticeEntryDestination.landing;
    } catch (_) {
      return FastPracticeEntryDestination.landing;
    }
  }

  @override
  Future<FastPracticeCatalog> loadCatalog(HomeModule module) async {
    if (!_isValidModule(module)) {
      return FastPracticeCatalog(module: module, leaves: const []);
    }
    final body = await _api.getBody(
      '/app/shelf/getShelfTree',
      queryParameters: {'shelfId': module.id},
    );
    return FastPracticeCatalog(
      module: module,
      leaves: parseFastPracticeLeaves(body),
    );
  }
}

bool _isValidModule(HomeModule module) => module.id > 0;
