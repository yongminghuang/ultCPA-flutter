import '../main_tabs/main_tabs_models.dart';

final class ChapterShelfNode {
  const ChapterShelfNode({
    required this.id,
    required this.name,
    required this.goodsCount,
    required this.status,
    required this.difficulty,
    required this.children,
  });

  factory ChapterShelfNode.fromMap(Map<String, dynamic> map) {
    final rawChildren = map['children'];
    if (rawChildren != null && rawChildren is! List) {
      throw const FormatException('书架节点 children 不是数组');
    }
    final children = <ChapterShelfNode>[];
    for (final rawChild in rawChildren as List? ?? const <Object?>[]) {
      if (rawChild is! Map) {
        throw const FormatException('书架子节点不是对象');
      }
      children.add(
        ChapterShelfNode.fromMap(Map<String, dynamic>.from(rawChild)),
      );
    }
    return ChapterShelfNode(
      id: _integer(map['id']),
      name: _text(map['name']),
      goodsCount: _integer(map['goodsCount']),
      status: _nullableBoolean(map['status']),
      difficulty: _difficulty(map['difficult']),
      children: List.unmodifiable(children),
    );
  }

  final int id;
  final String name;
  final int goodsCount;
  final bool? status;
  final int difficulty;
  final List<ChapterShelfNode> children;

  List<int> get leafIds {
    if (children.isEmpty) {
      return id > 0 ? <int>[id] : const <int>[];
    }
    return List.unmodifiable(children.expand((child) => child.leafIds));
  }

  ChapterShelfNode? get firstDescendantLeaf {
    if (children.isEmpty) return this;
    for (final child in children) {
      final leaf = child.firstDescendantLeaf;
      if (leaf != null) return leaf;
    }
    return null;
  }
}

List<ChapterShelfNode> parseChapterShelfTree(Object? body) {
  if (body is! List) {
    throw const FormatException('书架树 body 不是数组');
  }
  final roots = <ChapterShelfNode>[];
  for (final rawNode in body) {
    if (rawNode is! Map) {
      throw const FormatException('书架节点不是对象');
    }
    roots.add(ChapterShelfNode.fromMap(Map<String, dynamic>.from(rawNode)));
  }
  return List.unmodifiable(roots);
}

final class ChapterQuestionRecord {
  const ChapterQuestionRecord({
    required this.questionId,
    required this.shelfId,
    required this.choose,
    required this.isRight,
  });

  final String questionId;
  final int shelfId;
  final String choose;
  final bool isRight;

  bool get isAnswered => choose.trim().isNotEmpty;
}

Map<int, List<ChapterQuestionRecord>> parseChapterQuestionRecordBody(
  Object? body,
) {
  if (body is! List) {
    throw const FormatException('章节答题记录 body 不是数组');
  }
  final recordsByShelf = <int, List<ChapterQuestionRecord>>{};
  for (final rawShelf in body) {
    if (rawShelf is! Map) continue;
    final shelf = Map<String, dynamic>.from(rawShelf);
    final shelfId = _integer(shelf['shelfId']);
    final rawRecords = shelf['questionRecordResponseList'];
    if (rawRecords != null && rawRecords is! List) {
      throw const FormatException('章节答题记录列表不是数组');
    }
    final records = recordsByShelf.putIfAbsent(
      shelfId,
      () => <ChapterQuestionRecord>[],
    );
    for (final rawRecord in rawRecords as List? ?? const <Object?>[]) {
      if (rawRecord is! Map) continue;
      final record = Map<String, dynamic>.from(rawRecord);
      final questionId = _positiveIdText(record['questionId']);
      if (questionId.isEmpty) continue;
      records.add(
        ChapterQuestionRecord(
          questionId: questionId,
          shelfId: shelfId,
          choose: _text(record['choose']),
          isRight: _boolean(record['isRight']),
        ),
      );
    }
  }
  return Map<int, List<ChapterQuestionRecord>>.unmodifiable({
    for (final entry in recordsByShelf.entries)
      entry.key: List<ChapterQuestionRecord>.unmodifiable(entry.value),
  });
}

final class ChapterPracticeChapter {
  const ChapterPracticeChapter({
    required this.title,
    required this.sectionShelfId,
    required this.catalogIndex,
    required this.chapterIndex,
    required this.leafShelfIds,
    required this.questionIds,
    required this.recordsByQuestionId,
    required this.unlocked,
    required this.doneCount,
    required this.rightCount,
    required this.totalCount,
    required this.accuracyPercent,
    required this.difficulty,
  });

  final String title;
  final int sectionShelfId;
  final int catalogIndex;
  final int chapterIndex;
  final List<int> leafShelfIds;
  final List<String> questionIds;
  final Map<String, ChapterQuestionRecord> recordsByQuestionId;
  final bool unlocked;
  final int doneCount;
  final int rightCount;
  final int totalCount;
  final int accuracyPercent;
  final int difficulty;

  bool get isNotStarted => doneCount <= 0;
  bool get isCompleted => totalCount > 0 && doneCount >= totalCount;
  bool get isInProgress => doneCount > 0 && !isCompleted;
}

final class ChapterPracticeGroup {
  const ChapterPracticeGroup({
    required this.id,
    required this.title,
    required this.directEntry,
    required this.unlocked,
    required this.chapters,
  });

  final int id;
  final String title;
  final bool directEntry;
  final bool unlocked;
  final List<ChapterPracticeChapter> chapters;
}

final class ChapterPracticeCatalog {
  const ChapterPracticeCatalog({
    required this.module,
    required this.groups,
    required this.fullAccess,
    required this.previewGroupCount,
  });

  factory ChapterPracticeCatalog.empty(HomeModule module) {
    return ChapterPracticeCatalog(
      module: module,
      groups: const <ChapterPracticeGroup>[],
      fullAccess: false,
      previewGroupCount: 0,
    );
  }

  factory ChapterPracticeCatalog.build({
    required HomeModule module,
    required List<ChapterShelfNode> roots,
    required Map<int, List<ChapterQuestionRecord>> recordsByShelf,
    required bool fullAccess,
    required int previewGroupCount,
  }) {
    final previewCount = previewGroupCount < 0 ? 0 : previewGroupCount;
    final groups = <ChapterPracticeGroup>[];
    for (var catalogIndex = 0; catalogIndex < roots.length; catalogIndex += 1) {
      final root = roots[catalogIndex];
      final unlocked = fullAccess || catalogIndex < previewCount;
      final chapterNodes = root.children.isEmpty
          ? <ChapterShelfNode>[root]
          : root.children;
      final chapters = <ChapterPracticeChapter>[];
      for (
        var chapterIndex = 0;
        chapterIndex < chapterNodes.length;
        chapterIndex += 1
      ) {
        chapters.add(
          _buildChapter(
            chapterNodes[chapterIndex],
            catalogIndex: catalogIndex,
            chapterIndex: chapterIndex,
            unlocked: unlocked,
            recordsByShelf: recordsByShelf,
          ),
        );
      }
      groups.add(
        ChapterPracticeGroup(
          id: root.id,
          title: root.name,
          directEntry: root.children.isEmpty,
          unlocked: unlocked,
          chapters: List.unmodifiable(chapters),
        ),
      );
    }
    return ChapterPracticeCatalog(
      module: module,
      groups: List.unmodifiable(groups),
      fullAccess: fullAccess,
      previewGroupCount: previewCount,
    );
  }

  final HomeModule module;
  final List<ChapterPracticeGroup> groups;
  final bool fullAccess;
  final int previewGroupCount;

  ChapterPracticeChapter? chapterAt({
    required int catalogIndex,
    required int chapterIndex,
  }) {
    if (catalogIndex < 0 || catalogIndex >= groups.length) return null;
    final chapters = groups[catalogIndex].chapters;
    if (chapterIndex < 0 || chapterIndex >= chapters.length) return null;
    return chapters[chapterIndex];
  }

  ChapterPracticeChapter? nextChapterAfter({
    required int catalogIndex,
    required int chapterIndex,
  }) {
    if (catalogIndex < 0 || catalogIndex >= groups.length) return null;
    final currentChapters = groups[catalogIndex].chapters;
    final nextChapterIndex = chapterIndex + 1;
    if (nextChapterIndex >= 0 && nextChapterIndex < currentChapters.length) {
      return currentChapters[nextChapterIndex];
    }
    for (var index = catalogIndex + 1; index < groups.length; index += 1) {
      if (groups[index].chapters.isNotEmpty) {
        return groups[index].chapters.first;
      }
    }
    return null;
  }
}

ChapterPracticeChapter _buildChapter(
  ChapterShelfNode node, {
  required int catalogIndex,
  required int chapterIndex,
  required bool unlocked,
  required Map<int, List<ChapterQuestionRecord>> recordsByShelf,
}) {
  final leaf = node.firstDescendantLeaf;
  final title = node.status == false && (leaf?.name.trim().isNotEmpty ?? false)
      ? leaf!.name
      : node.name;
  final questionIds = <String>[];
  final seenQuestionIds = <String>{};
  final recordsByQuestionId = <String, ChapterQuestionRecord>{};
  for (final shelfId in node.leafIds) {
    for (final record in recordsByShelf[shelfId] ?? const []) {
      if (seenQuestionIds.add(record.questionId)) {
        questionIds.add(record.questionId);
        recordsByQuestionId[record.questionId] = record;
        continue;
      }
      final existing = recordsByQuestionId[record.questionId];
      if (existing != null && !existing.isAnswered && record.isAnswered) {
        recordsByQuestionId[record.questionId] = record;
      }
    }
  }
  final answered = recordsByQuestionId.values
      .where((record) => record.isAnswered)
      .toList(growable: false);
  final rightCount = answered.where((record) => record.isRight).length;
  final totalCount = node.goodsCount > 0 ? node.goodsCount : questionIds.length;
  final doneCount = answered.length;
  return ChapterPracticeChapter(
    title: title,
    sectionShelfId: node.id,
    catalogIndex: catalogIndex,
    chapterIndex: chapterIndex,
    leafShelfIds: node.leafIds,
    questionIds: List.unmodifiable(questionIds),
    recordsByQuestionId: Map.unmodifiable(recordsByQuestionId),
    unlocked: unlocked,
    doneCount: doneCount,
    rightCount: rightCount,
    totalCount: totalCount,
    accuracyPercent: doneCount == 0 ? 0 : (rightCount * 100) ~/ doneCount,
    difficulty: leaf?.difficulty ?? node.difficulty,
  );
}

int _difficulty(Object? value) {
  final parsed = _integer(value, 3);
  return parsed.clamp(0, 5);
}

String _positiveIdText(Object? value) {
  final text = _text(value).trim();
  final parsed = int.tryParse(text);
  return parsed != null && parsed > 0 ? text : '';
}

String _text(Object? value) {
  if (value == null) return '';
  final text = value.toString();
  return text.trim().toLowerCase() == 'null' ? '' : text;
}

int _integer(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _boolean(Object? value) => _nullableBoolean(value) ?? false;

bool? _nullableBoolean(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  return switch (value.toString().trim().toLowerCase()) {
    '1' || 'true' => true,
    '0' || 'false' => false,
    _ => null,
  };
}
