import '../main_tabs/main_tabs_models.dart';
import '../network/app_api_client.dart';
import '../skill_mnemonics/skill_mnemonics_entitlement.dart';
import '../storage/legacy_app_state_store.dart';
import 'past_exams_models.dart';

abstract interface class PastExamsDataSource {
  Future<PastExamsCatalog> loadCatalog(HomeModule module);
}

final class PastExamsRepository implements PastExamsDataSource {
  PastExamsRepository({
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
  Future<PastExamsCatalog> loadCatalog(HomeModule module) async {
    if (module.id <= 0 || module.type.trim() != '嵌套化') {
      return PastExamsCatalog(
        module: module,
        papers: const [],
        hasFullAccess: false,
      );
    }
    final body = await _api.getBody(
      '/app/shelf/getShelfTree',
      queryParameters: {'shelfId': module.id},
    );
    final previewPapers = parsePastExamPapers(body, hasFullAccess: false);
    final snapshot = await _stateStore.readAppSnapshot();
    var hasFullAccess = false;
    if (snapshot['isLoggedIn'] == true) {
      try {
        final benefits = await _api.getBody('/app/user/getUserBenefits');
        hasFullAccess = _entitlementResolver.hasPastExamsAccess(
          benefits,
          category: snapshot['category']?.toString() ?? '',
          level: snapshot['selectedLevel']?.toString() ?? '',
          subject: snapshot['selectedSubject']?.toString() ?? '',
        );
      } catch (_) {
        hasFullAccess = false;
      }
    }
    return PastExamsCatalog(
      module: module,
      papers: hasFullAccess
          ? parsePastExamPapers(body, hasFullAccess: true)
          : previewPapers,
      hasFullAccess: hasFullAccess,
    );
  }
}
