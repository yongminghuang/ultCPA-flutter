import '../network/app_api_client.dart';
import '../skill_mnemonics/skill_mnemonics_entitlement.dart';
import '../skill_mnemonics/skill_mnemonics_models.dart';
import '../storage/legacy_app_state_store.dart';
import 'smart_card_models.dart';

abstract interface class SmartCardDataSource {
  Future<SmartCardEntry> resolveEntry(SmartCardRequest request);

  Future<SkillMnemonicsCatalog> loadCatalog(
    SmartCardRequest request, {
    required bool isVip,
  });
}

final class SmartCardRepository implements SmartCardDataSource {
  SmartCardRepository({
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
  Future<SmartCardEntry> resolveEntry(SmartCardRequest request) async {
    if (!request.isValid) {
      return const SmartCardEntry(SmartCardEntryDestination.empty);
    }
    final snapshot = await _stateStore.readAppSnapshot();
    if (snapshot['isLoggedIn'] != true) {
      return const SmartCardEntry(SmartCardEntryDestination.page);
    }
    final benefits = await _api.getBody('/app/user/getUserBenefits');
    final isVip = _entitlementResolver.isVip(
      benefits,
      category: snapshot['category']?.toString() ?? '',
      level: snapshot['selectedLevel']?.toString() ?? '',
      subject: snapshot['selectedSubject']?.toString() ?? '',
    );
    if (!isVip || snapshot['category']?.toString().trim() != 'social-work') {
      return SmartCardEntry(SmartCardEntryDestination.page, isVip: isVip);
    }
    try {
      final catalog = await loadCatalog(request, isVip: true);
      if (catalog.records.isEmpty) {
        throw const FormatException('技巧卡片数据为空');
      }
      return SmartCardEntry(
        SmartCardEntryDestination.page,
        isVip: true,
        catalog: catalog,
      );
    } catch (_) {
      return const SmartCardEntry(
        SmartCardEntryDestination.unavailable,
        isVip: true,
      );
    }
  }

  @override
  Future<SkillMnemonicsCatalog> loadCatalog(
    SmartCardRequest request, {
    required bool isVip,
  }) async {
    final body = await _api.getBody(
      '/app/goods/pageGoodsData',
      queryParameters: request.queryParameters,
    );
    return SkillMnemonicsCatalog.fromBody(body, freeCount: 3, isVip: isVip);
  }
}
