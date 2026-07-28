import '../main_tabs/main_tabs_models.dart';
import '../network/app_api_client.dart';
import '../skill_mnemonics/skill_mnemonics_entitlement.dart';
import '../storage/legacy_app_state_store.dart';
import 'chapter_practice_models.dart';

abstract interface class ChapterPracticeDataSource {
  Future<ChapterPracticeCatalog> load(HomeModule module);
}

final class ChapterPracticeRepository implements ChapterPracticeDataSource {
  ChapterPracticeRepository({
    required AppApiClient api,
    required LegacyAppStateStore stateStore,
    DateTime Function()? now,
  }) : _api = api,
       _stateStore = stateStore,
       _entitlementResolver = SkillMnemonicsEntitlementResolver(now: now);

  static const _recordChunkSize = 2000;

  final AppApiClient _api;
  final LegacyAppStateStore _stateStore;
  final SkillMnemonicsEntitlementResolver _entitlementResolver;

  @override
  Future<ChapterPracticeCatalog> load(HomeModule module) async {
    if (!_isValidModule(module)) return ChapterPracticeCatalog.empty(module);

    final treeBody = await _api.getBody(
      '/app/shelf/getShelfTree',
      queryParameters: {'shelfId': module.id},
    );
    final roots = parseChapterShelfTree(treeBody);
    if (roots.isEmpty) return ChapterPracticeCatalog.empty(module);

    final snapshot = await _stateStore.readAppSnapshot();
    final recordsByShelf = await _loadRecords(
      module.id,
      roots.expand((root) => root.leafIds).toList(growable: false),
    );
    final fullAccess = await _loadFullAccess(snapshot);
    return ChapterPracticeCatalog.build(
      module: module,
      roots: roots,
      recordsByShelf: recordsByShelf,
      fullAccess: fullAccess,
      previewGroupCount: _nonNegativeInteger(
        snapshot['chapterQuestionFreeCount'],
        2,
      ),
    );
  }

  Future<Map<int, List<ChapterQuestionRecord>>> _loadRecords(
    int moduleId,
    List<int> shelfIds,
  ) async {
    final merged = <int, List<ChapterQuestionRecord>>{};
    for (var offset = 0; offset < shelfIds.length; offset += _recordChunkSize) {
      final end = (offset + _recordChunkSize).clamp(0, shelfIds.length);
      final chunk = shelfIds.sublist(offset, end);
      try {
        final body = await _api.postBody(
          '/app/question/getQuestionRecordList',
          {'modelId': moduleId, 'shelfIdList': chunk},
        );
        final parsed = parseChapterQuestionRecordBody(body);
        for (final entry in parsed.entries) {
          merged
              .putIfAbsent(entry.key, () => <ChapterQuestionRecord>[])
              .addAll(entry.value);
        }
      } catch (_) {
        // Android keeps loading later record chunks after an individual failure.
      }
    }
    return Map<int, List<ChapterQuestionRecord>>.unmodifiable({
      for (final entry in merged.entries)
        entry.key: List<ChapterQuestionRecord>.unmodifiable(entry.value),
    });
  }

  Future<bool> _loadFullAccess(Map<String, dynamic> snapshot) async {
    if (snapshot['isLoggedIn'] != true) return false;
    try {
      final benefits = await _api.getBody('/app/user/getUserBenefits');
      return _entitlementResolver.hasChapterPracticeAccess(
        benefits,
        category: snapshot['category']?.toString() ?? '',
        level: snapshot['selectedLevel']?.toString() ?? '',
        subject: snapshot['selectedSubject']?.toString() ?? '',
      );
    } catch (_) {
      return false;
    }
  }
}

bool _isValidModule(HomeModule module) {
  if (module.id <= 0) return false;
  final type = module.type.trim();
  return type == '结构化' || type == '嵌套化';
}

int _integer(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int _nonNegativeInteger(Object? value, int fallback) {
  final parsed = _integer(value, fallback);
  return parsed < 0 ? 0 : parsed;
}
