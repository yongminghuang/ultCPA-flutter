import '../main_tabs/main_tabs_models.dart';
import '../network/app_api_client.dart';
import '../skill_mnemonics/skill_mnemonics_entitlement.dart';
import '../storage/legacy_app_state_store.dart';
import 'pre_exam_secret_paper_models.dart';

abstract interface class PreExamSecretPaperDataSource {
  Future<PreExamSecretPaperCatalog> loadCatalog(HomeModule module);
}

final class PreExamSecretPaperRepository
    implements PreExamSecretPaperDataSource {
  PreExamSecretPaperRepository({
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
  Future<PreExamSecretPaperCatalog> loadCatalog(HomeModule module) async {
    if (module.id <= 0) {
      return PreExamSecretPaperCatalog(
        module: module,
        papers: const [],
        isVip: false,
      );
    }
    final body = await _api.getBody(
      '/app/shelf/getShelfTree',
      queryParameters: {'shelfId': module.id},
    );
    final papers = parsePreExamSecretPapers(body);
    final snapshot = await _stateStore.readAppSnapshot();
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
    return PreExamSecretPaperCatalog(
      module: module,
      papers: papers,
      isVip: isVip,
    );
  }
}
