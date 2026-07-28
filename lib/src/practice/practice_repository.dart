import '../chapter_practice/chapter_practice_models.dart';
import '../chapter_practice/chapter_practice_repository.dart';
import '../main_tabs/main_tabs_models.dart';
import '../network/app_api_client.dart';
import '../skill_mnemonics/skill_mnemonics_entitlement.dart';
import '../storage/legacy_app_state_store.dart';
import 'practice_benefit_kind.dart';
import 'practice_models.dart';
import 'practice_review_store.dart';

sealed class PracticeRequest {
  const PracticeRequest();

  String get title;
}

final class ModulePracticeRequest extends PracticeRequest {
  const ModulePracticeRequest({
    required this.module,
    this.benefitKind = PracticeBenefitKind.regularPractice,
    this.bigSkillCircleModule,
  });

  final HomeModule module;
  final PracticeBenefitKind benefitKind;
  final HomeModule? bigSkillCircleModule;

  @override
  String get title {
    if (module.name.trim().isNotEmpty) return module.name;
    if (module.page.trim().isNotEmpty) return module.page;
    return '练题';
  }
}

final class SkillPracticeRequest extends PracticeRequest {
  const SkillPracticeRequest({
    required this.skillId,
    this.title = '关联练题',
    this.position,
    this.module,
  });

  final String skillId;

  @override
  final String title;

  final int? position;
  final HomeModule? module;
}

final class ErrorPracticeRequest extends PracticeRequest {
  const ErrorPracticeRequest();

  @override
  String get title => '我的错题';
}

final class CollectionPracticeRequest extends PracticeRequest {
  const CollectionPracticeRequest();

  @override
  String get title => '我的收藏';
}

enum ChapterPracticeEntryMode { resume, view, redo, automatic }

final class ChapterPracticeRequest extends PracticeRequest {
  const ChapterPracticeRequest({
    required this.module,
    required this.catalogIndex,
    required this.chapterIndex,
    this.entryMode = ChapterPracticeEntryMode.resume,
  });

  final HomeModule module;
  final int catalogIndex;
  final int chapterIndex;
  final ChapterPracticeEntryMode entryMode;

  @override
  String get title => module.name.trim().isEmpty ? '章节练习' : module.name;
}

final class FastPracticeRequest extends PracticeRequest {
  const FastPracticeRequest({
    required this.module,
    required this.shelfId,
    required this.shelfName,
    required this.shelfType,
  });

  final HomeModule module;
  final int shelfId;
  final String shelfName;
  final String shelfType;

  @override
  String get title => shelfName.trim().isEmpty ? '速成200题' : shelfName;
}

final class DailySkillPracticeRequest extends PracticeRequest {
  const DailySkillPracticeRequest({
    required this.module,
    required this.skillId,
    required this.shelfId,
  });

  final HomeModule module;
  final String skillId;
  final int shelfId;

  @override
  String get title => '每日一招';
}

abstract interface class PracticeDataSource {
  Future<PracticeCatalog> load(PracticeRequest request);

  Future<void> saveAnswer(PracticeQuestion question, PracticeAnswer answer);

  Future<void> setCollected(PracticeQuestion question, bool collected);

  Future<void> removeWrongQuestion(PracticeQuestion question);

  Future<ErrorPracticeAvailability> probeErrorPractice();

  Future<int> loadWrongRemovalThreshold();

  Future<void> saveWrongRemovalThreshold(int threshold);

  Future<bool> recordWrongQuestionCorrect(PracticeQuestion question);
}

final class ErrorPracticeAvailability {
  const ErrorPracticeAvailability({
    required this.requiresLogin,
    this.total = 0,
  });

  final bool requiresLogin;
  final int total;

  bool get hasQuestions => !requiresLogin && total > 0;
}

final class PracticeRepository implements PracticeDataSource {
  PracticeRepository({
    required AppApiClient api,
    required LegacyAppStateStore stateStore,
    PracticeReviewStore? reviewStore,
    ChapterPracticeDataSource? chapterDataSource,
    DateTime Function()? now,
  }) : _api = api,
       _stateStore = stateStore,
       _reviewStore = reviewStore ?? const DisabledPracticeReviewStore(),
       _chapterDataSource =
           chapterDataSource ??
           ChapterPracticeRepository(
             api: api,
             stateStore: stateStore,
             now: now,
           ),
       _entitlementResolver = SkillMnemonicsEntitlementResolver(now: now);

  static const _pageSize = 30;

  final AppApiClient _api;
  final LegacyAppStateStore _stateStore;
  final PracticeReviewStore _reviewStore;
  final ChapterPracticeDataSource _chapterDataSource;
  final SkillMnemonicsEntitlementResolver _entitlementResolver;

  @override
  Future<PracticeCatalog> load(PracticeRequest request) async {
    _validate(request);

    if (request is DailySkillPracticeRequest) {
      return _loadDailySkillPractice(request);
    }

    final snapshot = await _stateStore.readAppSnapshot();
    if (request is ChapterPracticeRequest) {
      return _loadChapterPractice(request, snapshot);
    }
    if (request is FastPracticeRequest) {
      return _loadFastPractice(request);
    }
    final items = await _loadItems(request, snapshot);
    final freeQuestionCount = _nonNegativeInteger(
      snapshot['skillQuestionFreeCount'],
      5,
    );

    final isReview =
        request is ErrorPracticeRequest || request is CollectionPracticeRequest;
    var fullAccess = isReview;
    if (!isReview && snapshot['isLoggedIn'] == true) {
      try {
        final benefits = await _api.getBody('/app/user/getUserBenefits');
        final category = snapshot['category']?.toString() ?? '';
        final level = snapshot['selectedLevel']?.toString() ?? '';
        final subject = snapshot['selectedSubject']?.toString() ?? '';
        fullAccess = switch (request) {
          ModulePracticeRequest(:final benefitKind) =>
            _entitlementResolver.hasPracticeAccess(
              benefits,
              kind: benefitKind,
              category: category,
              level: level,
              subject: subject,
            ),
          SkillPracticeRequest() => _entitlementResolver.isVip(
            benefits,
            category: category,
            level: level,
            subject: subject,
          ),
          ErrorPracticeRequest() || CollectionPracticeRequest() => true,
          ChapterPracticeRequest() => true,
          FastPracticeRequest() => true,
          DailySkillPracticeRequest() => true,
        };
      } catch (_) {
        fullAccess = false;
      }
    }

    return PracticeCatalog(
      items: List.unmodifiable(items),
      access: PracticeAccess(
        fullAccess: fullAccess,
        freeQuestionCount: freeQuestionCount,
      ),
      title: request.title,
      behavior: switch (request) {
        ErrorPracticeRequest() => const PracticeBehavior.errorReview(
          emptyMessage: '还没有错题哟',
        ),
        CollectionPracticeRequest() => const PracticeBehavior.collectionReview(
          emptyMessage: '暂无收藏题目',
        ),
        _ => const PracticeBehavior.standard(),
      },
    );
  }

  @override
  Future<void> saveAnswer(
    PracticeQuestion question,
    PracticeAnswer answer,
  ) async {
    final questionId = int.tryParse(question.id.trim());
    if (questionId == null || questionId <= 0) {
      throw ArgumentError.value(question.id, 'question.id', '必须是正整数');
    }
    await _api.postBody('/app/question/saveQuestionRecord', {
      'questionId': questionId,
      'subject': question.subject,
      'level': question.level,
      'choose': answer.choose,
      'isRight': answer.isRight ? 1 : 0,
    });
  }

  @override
  Future<void> setCollected(PracticeQuestion question, bool collected) async {
    final questionId = _positiveQuestionId(question.id);
    final selection = await _selectedReviewContext();
    if (collected) {
      await _api.postBody('/app/question/saveCollectQuestion', {
        'questionId': questionId,
        'subject': selection.subject,
        'level': selection.level,
      });
      return;
    }
    await _api.postBody('/app/question/deleteCollectQuestion', {
      'questionIds': [questionId],
      'subject': selection.subject,
      'level': selection.level,
    });
  }

  @override
  Future<void> removeWrongQuestion(PracticeQuestion question) async {
    final questionId = _positiveQuestionId(question.id);
    final selection = await _selectedReviewContext();
    await _api.postBody('/app/question/deleteQuestionRecord', {
      'questionIds': [questionId],
      'subject': selection.subject,
      'level': selection.level,
      'type': 2,
    });
  }

  @override
  Future<ErrorPracticeAvailability> probeErrorPractice() async {
    final snapshot = await _stateStore.readAppSnapshot();
    if (snapshot['isLoggedIn'] != true) {
      return const ErrorPracticeAvailability(requiresLogin: true);
    }
    final body = await _api.getBody(
      '/app/question/pageErrorQuestion',
      queryParameters: {
        'pageNum': 1,
        'pageSize': 1,
        'subject': snapshot['selectedSubject']?.toString() ?? '',
        'level': snapshot['selectedLevel']?.toString() ?? '',
      },
    );
    if (body is! Map) {
      throw const FormatException('错题数量响应不是对象');
    }
    return ErrorPracticeAvailability(
      requiresLogin: false,
      total: _integer(body['total']),
    );
  }

  @override
  Future<int> loadWrongRemovalThreshold() {
    return _reviewStore.loadWrongRemovalThreshold();
  }

  @override
  Future<void> saveWrongRemovalThreshold(int threshold) async {
    if (!_validWrongRemovalThreshold(threshold)) {
      throw ArgumentError.value(threshold, 'threshold', '必须为 -1 或 1 到 7');
    }
    await _reviewStore.saveWrongRemovalThreshold(threshold);
  }

  @override
  Future<bool> recordWrongQuestionCorrect(PracticeQuestion question) {
    final countId = _positiveQuestionId(
      question.wrongCountId,
      name: 'question.wrongCountId',
    );
    return _reviewStore.recordWrongQuestionCorrect(countId.toString());
  }

  Future<({String subject, String level})> _selectedReviewContext() async {
    final snapshot = await _stateStore.readAppSnapshot();
    return (
      subject: snapshot['selectedSubject']?.toString() ?? '',
      level: snapshot['selectedLevel']?.toString() ?? '',
    );
  }

  void _validate(PracticeRequest request) {
    switch (request) {
      case ModulePracticeRequest(:final module):
        if (module.id <= 0) {
          throw ArgumentError.value(module.id, 'module.id', '必须大于 0');
        }
      case SkillPracticeRequest(:final skillId):
        if (skillId.trim().isEmpty) {
          throw ArgumentError.value(skillId, 'skillId', '不能为空');
        }
      case ErrorPracticeRequest() || CollectionPracticeRequest():
        return;
      case ChapterPracticeRequest(
        :final module,
        :final catalogIndex,
        :final chapterIndex,
      ):
        if (module.id <= 0) {
          throw ArgumentError.value(module.id, 'module.id', '必须大于 0');
        }
        if (catalogIndex < 0) {
          throw ArgumentError.value(catalogIndex, 'catalogIndex', '不能小于 0');
        }
        if (chapterIndex < 0) {
          throw ArgumentError.value(chapterIndex, 'chapterIndex', '不能小于 0');
        }
      case FastPracticeRequest(:final module, :final shelfId, :final shelfName):
        if (module.id <= 0) {
          throw ArgumentError.value(module.id, 'module.id', '必须大于 0');
        }
        if (shelfId <= 0) {
          throw ArgumentError.value(shelfId, 'shelfId', '必须大于 0');
        }
        if (shelfName.trim().isEmpty) {
          throw ArgumentError.value(shelfName, 'shelfName', '不能为空');
        }
      case DailySkillPracticeRequest(
        :final module,
        :final skillId,
        :final shelfId,
      ):
        if (module.id <= 0) {
          throw ArgumentError.value(module.id, 'module.id', '必须大于 0');
        }
        if (skillId.trim().isEmpty) {
          throw ArgumentError.value(skillId, 'skillId', '不能为空');
        }
        if (shelfId <= 0) {
          throw ArgumentError.value(shelfId, 'shelfId', '必须大于 0');
        }
    }
  }

  Future<List<PracticeItem>> _loadItems(
    PracticeRequest request,
    Map<String, dynamic> snapshot,
  ) {
    return switch (request) {
      ModulePracticeRequest(:final module) =>
        module.type.trim() == '结构化' || module.type.trim() == '嵌套化'
            ? _loadStructured(module)
            : _loadFlat(module),
      SkillPracticeRequest(:final skillId) => _loadSkill(skillId.trim()),
      ErrorPracticeRequest() => _loadMineReview(
        path: '/app/question/pageErrorQuestion',
        snapshot: snapshot,
      ),
      CollectionPracticeRequest() => _loadMineReview(
        path: '/app/question/pageCollectQuestion',
        snapshot: snapshot,
      ),
      ChapterPracticeRequest() => throw StateError('章节练习请求必须通过选章加载分支'),
      FastPracticeRequest() => throw StateError('速成练习请求加载分支尚未接入'),
      DailySkillPracticeRequest() => throw StateError('每日一招请求必须通过专用加载分支'),
    };
  }

  Future<PracticeCatalog> _loadDailySkillPractice(
    DailySkillPracticeRequest request,
  ) async {
    final loadedItems = await _loadSkill(request.skillId.trim());
    final items = loadedItems
        .map((item) {
          if (item is! PracticeQuestionItem) return item;
          return PracticeQuestionItem(item.question.withServerAnswer(null));
        })
        .toList(growable: false);
    return PracticeCatalog(
      items: List.unmodifiable(items),
      access: const PracticeAccess(fullAccess: true, freeQuestionCount: 0),
      title: request.title,
    );
  }

  Future<PracticeCatalog> _loadChapterPractice(
    ChapterPracticeRequest request,
    Map<String, dynamic> snapshot,
  ) async {
    final chapterCatalog = await _chapterDataSource.load(request.module);
    final chapter = chapterCatalog.chapterAt(
      catalogIndex: request.catalogIndex,
      chapterIndex: request.chapterIndex,
    );
    if (chapter == null) {
      throw ArgumentError('章节目录坐标无效');
    }
    if (!chapter.unlocked) {
      throw StateError('章节尚未解锁');
    }
    final loadedItems = await _loadSelectedChapterItems(
      request.module,
      chapter,
    );
    var items = _overlayChapterRecords(loadedItems, chapter);
    if (request.entryMode == ChapterPracticeEntryMode.redo) {
      await _clearSelectedChapterRecords(items, snapshot);
      items = List.unmodifiable(
        items.map((item) {
          if (item is! PracticeQuestionItem) return item;
          return PracticeQuestionItem(item.question.withServerAnswer(null));
        }),
      );
    }
    final questionIds = items
        .whereType<PracticeQuestionItem>()
        .map((item) => item.question.id)
        .toList(growable: false);
    final next = chapterCatalog.nextChapterAfter(
      catalogIndex: request.catalogIndex,
      chapterIndex: request.chapterIndex,
    );
    return PracticeCatalog(
      items: items,
      access: const PracticeAccess(fullAccess: true, freeQuestionCount: 0),
      title: chapter.title,
      chapterContext: PracticeChapterContext(
        module: request.module,
        catalogIndex: request.catalogIndex,
        chapterIndex: request.chapterIndex,
        title: chapter.title,
        questionIds: List.unmodifiable(questionIds),
        nextChapter: next == null
            ? null
            : PracticeChapterTarget(
                catalogIndex: next.catalogIndex,
                chapterIndex: next.chapterIndex,
                title: next.title,
                unlocked: next.unlocked,
              ),
      ),
    );
  }

  Future<List<PracticeItem>> _loadSelectedChapterItems(
    HomeModule module,
    ChapterPracticeChapter chapter,
  ) async {
    final leafIds = chapter.leafShelfIds;
    if (leafIds.isEmpty) {
      throw const FormatException('章节没有有效叶子');
    }
    if (leafIds.length > 1) {
      final body = await _api.getBody(
        '/app/goods/listGoods',
        queryParameters: {'shelfIds': leafIds},
      );
      return PracticePageBatch.fromListBody(body).items;
    }
    return _loadPages(
      (page) => {
        'pageNum': page,
        'pageSize': _pageSize,
        'modelId': module.id,
        'shelfId': leafIds.single,
      },
    );
  }

  Future<PracticeCatalog> _loadFastPractice(FastPracticeRequest request) async {
    final loadedItems = await _loadPages(
      (page) => {
        'pageNum': page,
        'pageSize': _pageSize,
        'shelfId': request.shelfId,
      },
    );
    final records = await _loadFastPracticeRecords(request);
    final items = List<PracticeItem>.unmodifiable(
      loadedItems.map((item) {
        if (item is! PracticeQuestionItem) return item;
        final record = records[item.question.id];
        final answer = record != null && record.isAnswered
            ? PracticeAnswer(
                choose: normalizePracticeChoices([record.choose]),
                isRight: record.isRight,
              )
            : null;
        return PracticeQuestionItem(item.question.withServerAnswer(answer));
      }),
    );
    return PracticeCatalog(
      items: items,
      access: const PracticeAccess(fullAccess: true, freeQuestionCount: 0),
      title: request.title,
    );
  }

  Future<Map<String, ChapterQuestionRecord>> _loadFastPracticeRecords(
    FastPracticeRequest request,
  ) async {
    try {
      final body = await _api.postBody('/app/question/getQuestionRecordList', {
        'modelId': request.module.id,
        'shelfIdList': [request.shelfId],
      });
      final records = parseChapterQuestionRecordBody(body)[request.shelfId];
      return Map<String, ChapterQuestionRecord>.unmodifiable({
        for (final record in records ?? const <ChapterQuestionRecord>[])
          record.questionId: record,
      });
    } catch (_) {
      return const <String, ChapterQuestionRecord>{};
    }
  }

  List<PracticeItem> _overlayChapterRecords(
    List<PracticeItem> items,
    ChapterPracticeChapter chapter,
  ) {
    return List.unmodifiable(
      items.map((item) {
        if (item is! PracticeQuestionItem) return item;
        final record = chapter.recordsByQuestionId[item.question.id];
        final answer = record != null && record.isAnswered
            ? PracticeAnswer(
                choose: normalizePracticeChoices([record.choose]),
                isRight: record.isRight,
              )
            : null;
        return PracticeQuestionItem(item.question.withServerAnswer(answer));
      }),
    );
  }

  Future<void> _clearSelectedChapterRecords(
    List<PracticeItem> items,
    Map<String, dynamic> snapshot,
  ) async {
    final questionIds = items
        .whereType<PracticeQuestionItem>()
        .map((item) => _positiveQuestionId(item.question.id))
        .toList(growable: false);
    await _api.postBody('/app/question/deleteQuestionRecord', {
      'questionIds': questionIds,
      'subject': snapshot['selectedSubject']?.toString() ?? '',
      'level': snapshot['selectedLevel']?.toString() ?? '',
      'type': 1,
    });
  }

  Future<List<PracticeItem>> _loadFlat(HomeModule module) {
    return _loadPages(
      (page) => {'pageNum': page, 'pageSize': _pageSize, 'shelfId': module.id},
    );
  }

  Future<List<PracticeItem>> _loadStructured(HomeModule module) async {
    final body = await _api.getBody(
      '/app/shelf/getShelfTree',
      queryParameters: {'shelfId': module.id},
    );
    final roots = _parseShelfNodes(body);
    if (roots.isEmpty) {
      throw const FormatException('书架树为空');
    }

    final catalog = roots.first;
    final chapters = catalog.children.isEmpty
        ? <_ShelfNode>[catalog]
        : catalog.children;
    if (chapters.isEmpty) {
      throw const FormatException('书架目录没有章节');
    }
    final leafIds = chapters.first.leafIds;
    if (leafIds.isEmpty) {
      throw const FormatException('书架章节没有有效叶子');
    }

    if (leafIds.length > 1) {
      final listBody = await _api.getBody(
        '/app/goods/listGoods',
        queryParameters: {'shelfIds': leafIds},
      );
      return PracticePageBatch.fromListBody(listBody).items;
    }

    final shelfId = leafIds.single;
    return _loadPages(
      (page) => {
        'pageNum': page,
        'pageSize': _pageSize,
        'modelId': module.id,
        'shelfId': shelfId,
      },
    );
  }

  Future<List<PracticeItem>> _loadSkill(String skillId) async {
    final body = await _api.getBody(
      '/app/question/queryQuestionsBySkill',
      queryParameters: {'skillId': skillId},
    );
    return PracticePageBatch.fromListBody(body).items;
  }

  Future<List<PracticeItem>> _loadMineReview({
    required String path,
    required Map<String, dynamic> snapshot,
  }) {
    const pageSize = 200;
    return _loadPagedEndpoint(
      path: path,
      pageSize: pageSize,
      queryForPage: (page) => {
        'pageNum': page,
        'pageSize': pageSize,
        'subject': snapshot['selectedSubject']?.toString() ?? '',
        'level': snapshot['selectedLevel']?.toString() ?? '',
      },
    );
  }

  Future<List<PracticeItem>> _loadPagedEndpoint({
    required String path,
    required int pageSize,
    required Map<String, dynamic> Function(int page) queryForPage,
  }) async {
    final first = PracticePageBatch.fromBody(
      await _api.getBody(path, queryParameters: queryForPage(1)),
    );
    final items = <PracticeItem>[...first.items];
    final pagesFromTotal = first.total <= 0
        ? 1
        : ((first.total - 1) ~/ pageSize) + 1;
    final pageCount = first.pages > pagesFromTotal
        ? first.pages
        : pagesFromTotal;
    for (var page = 2; page <= pageCount; page += 1) {
      final batch = PracticePageBatch.fromBody(
        await _api.getBody(path, queryParameters: queryForPage(page)),
      );
      items.addAll(batch.items);
    }
    return List.unmodifiable(items);
  }

  Future<List<PracticeItem>> _loadPages(
    Map<String, dynamic> Function(int page) queryForPage,
  ) async {
    final first = PracticePageBatch.fromBody(
      await _api.getBody(
        '/app/goods/pageGoodsData',
        queryParameters: queryForPage(1),
      ),
    );
    final items = <PracticeItem>[...first.items];
    final pageCount = first.pages < 1 ? 1 : first.pages;
    for (var page = 2; page <= pageCount; page += 1) {
      final batch = PracticePageBatch.fromBody(
        await _api.getBody(
          '/app/goods/pageGoodsData',
          queryParameters: queryForPage(page),
        ),
      );
      items.addAll(batch.items);
    }
    return List.unmodifiable(items);
  }
}

int _positiveQuestionId(String value, {String name = 'question.id'}) {
  final questionId = int.tryParse(value.trim());
  if (questionId == null || questionId <= 0) {
    throw ArgumentError.value(value, name, '必须是正整数');
  }
  return questionId;
}

bool _validWrongRemovalThreshold(int value) {
  return value == -1 || (value >= 1 && value <= 7);
}

final class _ShelfNode {
  const _ShelfNode({required this.id, required this.children});

  factory _ShelfNode.fromMap(Map<String, dynamic> map) {
    final rawChildren = map['children'];
    if (rawChildren != null && rawChildren is! List) {
      throw const FormatException('书架节点 children 不是数组');
    }
    final children = <_ShelfNode>[];
    for (final rawChild in rawChildren as List? ?? const []) {
      if (rawChild is! Map) {
        throw const FormatException('书架子节点不是对象');
      }
      children.add(_ShelfNode.fromMap(Map<String, dynamic>.from(rawChild)));
    }
    return _ShelfNode(
      id: _integer(map['id']),
      children: List.unmodifiable(children),
    );
  }

  final int id;
  final List<_ShelfNode> children;

  List<int> get leafIds {
    if (children.isEmpty) {
      return id > 0 ? <int>[id] : const <int>[];
    }
    return List.unmodifiable(children.expand((child) => child.leafIds));
  }
}

List<_ShelfNode> _parseShelfNodes(Object? body) {
  if (body is! List) {
    throw const FormatException('书架树 body 不是数组');
  }
  final nodes = <_ShelfNode>[];
  for (final rawNode in body) {
    if (rawNode is! Map) {
      throw const FormatException('书架节点不是对象');
    }
    nodes.add(_ShelfNode.fromMap(Map<String, dynamic>.from(rawNode)));
  }
  return List.unmodifiable(nodes);
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
