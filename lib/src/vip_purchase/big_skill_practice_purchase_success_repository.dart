import '../main_tabs/main_tabs_models.dart';
import '../network/app_api_client.dart';
import '../practice/practice_benefit_kind.dart';
import '../storage/legacy_app_state_store.dart';
import 'vip_purchase_models.dart';

abstract interface class BigSkillPracticePurchaseSuccessDataSource {
  Future<BigSkillPracticePurchaseSuccessSummary> loadSummary(
    PracticeBenefitKind kind,
  );

  Future<BigSkillPracticeDestination?> loadDestination({
    HomeModule? cachedPracticeModule,
    HomeModule? cachedCircleModule,
  });
}

final class BigSkillPracticeDestination {
  const BigSkillPracticeDestination({
    required this.practiceModule,
    required this.circleModule,
  });

  final HomeModule practiceModule;
  final HomeModule? circleModule;
}

final class BigSkillPracticePurchaseSuccessRepository
    implements BigSkillPracticePurchaseSuccessDataSource {
  BigSkillPracticePurchaseSuccessRepository({
    required AppApiClient api,
    required LegacyAppStateStore stateStore,
    DateTime Function()? now,
  }) : _api = api,
       _stateStore = stateStore,
       _now = now ?? DateTime.now;

  final AppApiClient _api;
  final LegacyAppStateStore _stateStore;
  final DateTime Function() _now;

  @override
  Future<BigSkillPracticePurchaseSuccessSummary> loadSummary(
    PracticeBenefitKind kind,
  ) async {
    AppSnapshot snapshot;
    try {
      snapshot = AppSnapshot.fromMap(await _stateStore.readAppSnapshot());
    } catch (_) {
      return BigSkillPracticePurchaseSuccessSummary.generic(kind);
    }

    Object? benefits = snapshot.userBenefitsJson;
    try {
      final live = await _api.getBody('/app/user/getUserBenefits');
      if (live is List) benefits = live;
    } catch (_) {
      // Android keeps the last benefit cache when its refresh fails.
    }
    return resolveBigSkillPracticePurchaseSuccessSummary(
      benefits,
      kind: kind,
      category: snapshot.category,
      level: snapshot.selectedLevel,
      now: _now,
    );
  }

  @override
  Future<BigSkillPracticeDestination?> loadDestination({
    HomeModule? cachedPracticeModule,
    HomeModule? cachedCircleModule,
  }) async {
    if (_isPracticeModule(cachedPracticeModule)) {
      return BigSkillPracticeDestination(
        practiceModule: cachedPracticeModule!,
        circleModule: _isCircleModule(cachedCircleModule)
            ? cachedCircleModule
            : null,
      );
    }

    try {
      final snapshot = AppSnapshot.fromMap(await _stateStore.readAppSnapshot());
      if (snapshot.selectedMarketId <= 0) return null;
      final body = await _api.getBody(
        '/knowledge/shelf/moduleLis',
        queryParameters: {'marketId': snapshot.selectedMarketId},
      );
      if (body is! List) return null;

      HomeModule? practice;
      HomeModule? circle;
      for (final raw in body) {
        final module = _module(raw);
        if (module == null) continue;
        if (practice == null && _isPracticeModule(module)) practice = module;
        if (circle == null && _isCircleModule(module)) circle = module;
        if (practice != null && circle != null) break;
      }
      if (practice == null) return null;
      return BigSkillPracticeDestination(
        practiceModule: practice,
        circleModule: circle,
      );
    } catch (_) {
      return null;
    }
  }
}

HomeModule? _module(Object? raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final id = _int(map['id']);
  if (id <= 0) return null;
  return HomeModule(
    id: id,
    name: _text(map['name']).trim(),
    page: _text(map['page']).trim(),
    tag: _text(map['tag']).trim(),
    type: _text(map['type']).trim(),
  );
}

bool _isPracticeModule(HomeModule? module) {
  if (module == null || module.id <= 0) return false;
  return module.page.trim() == '技巧练题' || module.name.trim() == '技巧练题';
}

bool _isCircleModule(HomeModule? module) {
  if (module == null || module.id <= 0) return false;
  final name = module.name.trim();
  return module.page.trim() == '技巧圈题卷' || name == '技巧圈题卷' || name == '大招圈题卷';
}

String _text(Object? value) => value?.toString() ?? '';

int _int(Object? value) {
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? 0;
}
