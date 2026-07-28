import '../main_tabs/main_tabs_models.dart';
import '../network/app_api_client.dart';
import '../practice/practice_models.dart';
import '../storage/legacy_app_state_store.dart';
import 'daily_skill_models.dart';

abstract interface class DailySkillDataSource {
  Future<DailySkillDetail> loadDetail(HomeModule module);

  Future<List<PracticeQuestion>> loadQuestions(String skillId);
}

final class DailySkillRepository implements DailySkillDataSource {
  DailySkillRepository({
    required AppApiClient api,
    required LegacyAppStateStore stateStore,
  }) : _api = api,
       _stateStore = stateStore;

  static const _fallbackOssOrigin = 'https://file.xmzhujing.com/';

  final AppApiClient _api;
  final LegacyAppStateStore _stateStore;

  @override
  Future<DailySkillDetail> loadDetail(HomeModule module) async {
    if (module.id <= 0) {
      throw ArgumentError.value(module.id, 'module.id', '必须大于 0');
    }
    final body = await _api.getBody(
      '/knowledge/skill/dailySkill',
      queryParameters: {'moduleId': module.id},
    );
    final skill = parseDailySkillBody(body);
    if (skill == null) throw const FormatException('每日一招数据为空');

    Map<String, dynamic> snapshot;
    try {
      snapshot = await _stateStore.readAppSnapshot();
    } catch (_) {
      snapshot = const {};
    }
    final parsedShelfId = int.tryParse(skill.shelfId.trim()) ?? 0;
    return DailySkillDetail(
      module: module,
      skill: skill,
      effectiveShelfId: parsedShelfId > 0 ? parsedShelfId : module.id,
      imageUrl: _resolveImageUrl(
        skill.imgUrl ?? '',
        snapshot['ossDomain']?.toString() ?? '',
      ),
    );
  }

  @override
  Future<List<PracticeQuestion>> loadQuestions(String skillId) async {
    final normalizedId = skillId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(skillId, 'skillId', '不能为空');
    }
    final body = await _api.getBody(
      '/app/question/queryQuestionsBySkill',
      queryParameters: {'skillId': normalizedId},
    );
    return List<PracticeQuestion>.unmodifiable(
      PracticePageBatch.fromListBody(
        body,
      ).items.whereType<PracticeQuestionItem>().map((item) => item.question),
    );
  }

  String _resolveImageUrl(String value, String rawDomain) {
    final path = value.trim();
    if (path.isEmpty) return '';
    final uri = Uri.tryParse(path);
    if (uri?.hasScheme == true) return path;
    final domain = rawDomain.trim().isEmpty
        ? _fallbackOssOrigin
        : rawDomain.trim();
    return '${domain.replaceFirst(RegExp(r'/$'), '')}/'
        '${path.replaceFirst(RegExp(r'^/'), '')}';
  }
}
