import '../main_tabs/main_tabs_models.dart';
import '../network/app_api_client.dart';
import '../skill_mnemonics/skill_mnemonics_entitlement.dart';
import '../storage/legacy_app_state_store.dart';
import 'pre_exam_six_paper_models.dart';

abstract interface class PreExamSixPaperDataSource {
  Future<PreExamSixPaperEntry> resolveEntry(HomeModule module);

  Future<PreExamSixPaperFile> loadFile(HomeModule module);
}

final class PreExamSixPaperRepository implements PreExamSixPaperDataSource {
  PreExamSixPaperRepository({
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
  Future<PreExamSixPaperEntry> resolveEntry(HomeModule module) async {
    if (module.id <= 0) {
      return const PreExamSixPaperEntry(PreExamSixPaperEntryDestination.empty);
    }
    final snapshot = await _stateStore.readAppSnapshot();
    if (snapshot['isLoggedIn'] != true) {
      return const PreExamSixPaperEntry(
        PreExamSixPaperEntryDestination.landing,
      );
    }
    final benefits = await _api.getBody('/app/user/getUserBenefits');
    final isVip = _entitlementResolver.isVip(
      benefits,
      category: snapshot['category']?.toString() ?? '',
      level: snapshot['selectedLevel']?.toString() ?? '',
      subject: snapshot['selectedSubject']?.toString() ?? '',
    );
    if (!isVip) {
      return const PreExamSixPaperEntry(
        PreExamSixPaperEntryDestination.landing,
      );
    }
    if (snapshot['category']?.toString().trim() != 'social-work') {
      return const PreExamSixPaperEntry(
        PreExamSixPaperEntryDestination.preview,
      );
    }
    try {
      final file = await _loadFile(module, snapshot);
      return PreExamSixPaperEntry(
        PreExamSixPaperEntryDestination.preview,
        file: file,
      );
    } catch (_) {
      return const PreExamSixPaperEntry(
        PreExamSixPaperEntryDestination.unavailable,
      );
    }
  }

  @override
  Future<PreExamSixPaperFile> loadFile(HomeModule module) async {
    if (module.id <= 0) {
      throw ArgumentError.value(module.id, 'module.id', '必须大于 0');
    }
    final snapshot = await _stateStore.readAppSnapshot();
    return _loadFile(module, snapshot);
  }

  Future<PreExamSixPaperFile> _loadFile(
    HomeModule module,
    Map<String, dynamic> snapshot,
  ) async {
    final body = await _api.getBody(
      '/app/goods/pageGoodsData',
      queryParameters: {'pageNum': 1, 'pageSize': 1, 'shelfId': module.id},
    );
    final parsed = parsePreExamSixPaperFileBody(body);
    if (parsed == null) throw const FormatException('考前6页纸数据为空');
    final ossDomain = snapshot['ossDomain']?.toString() ?? '';
    return PreExamSixPaperFile(
      name: parsed.name,
      text: parsed.text,
      textUrl: resolvePreExamSixPaperUrl(parsed.textUrl, ossDomain: ossDomain),
      fileUrl: resolvePreExamSixPaperUrl(parsed.fileUrl, ossDomain: ossDomain),
      htmlBaseUrl: preExamSixPaperOssOrigin(ossDomain),
    );
  }
}
