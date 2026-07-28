import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/chapter_practice/chapter_practice_models.dart';
import 'package:ultcpa_flutter/src/chapter_practice/chapter_practice_page.dart';
import 'package:ultcpa_flutter/src/chapter_practice/chapter_practice_progress_store.dart';
import 'package:ultcpa_flutter/src/chapter_practice/chapter_practice_repository.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/practice/practice_repository.dart';

void main() {
  testWidgets('renders loading, retryable failure, and loaded catalog', (
    tester,
  ) async {
    final first = Completer<ChapterPracticeCatalog>();
    var calls = 0;
    final source = _Source((_) {
      calls += 1;
      return calls == 1 ? first.future : Future.value(_catalog);
    });

    await tester.pumpWidget(_app(source: source));
    expect(
      find.byKey(const ValueKey('chapter-practice-loading')),
      findsOneWidget,
    );

    first.completeError(StateError('offline'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('chapter-practice-error')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('chapter-practice-retry')));
    await tester.pumpAndSettle();
    expect(find.text('第一目录'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('renders the Android-style empty state', (tester) async {
    final source = _Source((_) async => ChapterPracticeCatalog.empty(_module));

    await tester.pumpWidget(_app(source: source));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('chapter-practice-empty')),
      findsOneWidget,
    );
    expect(find.text('暂无章节练习内容'), findsOneWidget);
  });

  testWidgets('restores one unlocked group and persists exclusive expansion', (
    tester,
  ) async {
    final progress = _ProgressStore(expandedCatalog: 1);

    await tester.pumpWidget(_app(progressStore: progress));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('chapter-practice-chapter-1-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chapter-practice-chapter-0-0')),
      findsNothing,
    );
    expect(find.text('正确率 50%'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chapter-practice-group-0')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('chapter-practice-chapter-0-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chapter-practice-chapter-1-0')),
      findsNothing,
    );
    expect(progress.savedExpanded, [(moduleId: 42, catalogIndex: 0)]);
  });

  testWidgets('falls back from a saved locked group to first unlocked group', (
    tester,
  ) async {
    final progress = _ProgressStore(expandedCatalog: 2);

    await tester.pumpWidget(_app(progressStore: progress));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('chapter-practice-chapter-0-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chapter-practice-chapter-2-0')),
      findsNothing,
    );
  });

  testWidgets('locked groups report unlock migration and never launch', (
    tester,
  ) async {
    final launched = <ChapterPracticeRequest>[];

    await tester.pumpWidget(
      _app(launcher: (_, request) async => launched.add(request)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chapter-practice-group-2')));
    await tester.pump();

    expect(find.text('章节练习需解锁，会员与支付功能仍在迁移中'), findsOneWidget);
    expect(launched, isEmpty);
  });

  testWidgets('in-progress chapter resumes and refreshes after return', (
    tester,
  ) async {
    final launched = <ChapterPracticeRequest>[];
    final source = _Source((_) async => _catalog);

    await tester.pumpWidget(
      _app(
        source: source,
        launcher: (_, request) async => launched.add(request),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('chapter-practice-chapter-0-0')),
    );
    await tester.pumpAndSettle();

    expect(launched.single.catalogIndex, 0);
    expect(launched.single.chapterIndex, 0);
    expect(launched.single.entryMode, ChapterPracticeEntryMode.resume);
    expect(source.loadCount, 2);
  });

  testWidgets('completed chapter offers exact redo and view choices', (
    tester,
  ) async {
    final launched = <ChapterPracticeRequest>[];

    await tester.pumpWidget(
      _app(launcher: (_, request) async => launched.add(request)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('chapter-practice-chapter-0-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('本章已全部学完'), findsOneWidget);
    expect(find.text('重练本章'), findsOneWidget);
    expect(find.text('进入查看'), findsOneWidget);

    await tester.tap(find.text('进入查看'));
    await tester.pumpAndSettle();
    expect(launched.single.entryMode, ChapterPracticeEntryMode.view);

    await tester.tap(
      find.byKey(const ValueKey('chapter-practice-chapter-0-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('重练本章'));
    await tester.pumpAndSettle();
    expect(launched.last.entryMode, ChapterPracticeEntryMode.redo);
    expect(launched, hasLength(2));
  });

  testWidgets('ignores a load result after disposal', (tester) async {
    final pending = Completer<ChapterPracticeCatalog>();
    final source = _Source((_) => pending.future);

    await tester.pumpWidget(_app(source: source));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete(_catalog);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  ChapterPracticeDataSource? source,
  ChapterPracticeProgressStore? progressStore,
  ChapterPracticeLauncher? launcher,
}) {
  return MaterialApp(
    home: ChapterPracticePage(
      module: _module,
      dataSource: source ?? _Source((_) async => _catalog),
      progressStore: progressStore ?? _ProgressStore(expandedCatalog: 0),
      practiceLauncher: launcher ?? (_, _) async {},
    ),
  );
}

const _module = HomeModule(
  id: 42,
  name: '章节练习',
  page: '章节练习',
  tag: '',
  type: '结构化',
);

const _catalog = ChapterPracticeCatalog(
  module: _module,
  fullAccess: false,
  previewGroupCount: 2,
  groups: [
    ChapterPracticeGroup(
      id: 10,
      title: '第一目录',
      directEntry: false,
      unlocked: true,
      chapters: [
        ChapterPracticeChapter(
          title: '进行中章节',
          sectionShelfId: 11,
          catalogIndex: 0,
          chapterIndex: 0,
          leafShelfIds: [11],
          questionIds: ['1', '2'],
          recordsByQuestionId: {},
          unlocked: true,
          doneCount: 1,
          rightCount: 1,
          totalCount: 2,
          accuracyPercent: 100,
          difficulty: 3,
        ),
        ChapterPracticeChapter(
          title: '已完成章节',
          sectionShelfId: 12,
          catalogIndex: 0,
          chapterIndex: 1,
          leafShelfIds: [12],
          questionIds: ['3'],
          recordsByQuestionId: {},
          unlocked: true,
          doneCount: 1,
          rightCount: 1,
          totalCount: 1,
          accuracyPercent: 100,
          difficulty: 2,
        ),
      ],
    ),
    ChapterPracticeGroup(
      id: 20,
      title: '第二目录',
      directEntry: true,
      unlocked: true,
      chapters: [
        ChapterPracticeChapter(
          title: '第二目录',
          sectionShelfId: 20,
          catalogIndex: 1,
          chapterIndex: 0,
          leafShelfIds: [20],
          questionIds: ['4', '5'],
          recordsByQuestionId: {},
          unlocked: true,
          doneCount: 1,
          rightCount: 1,
          totalCount: 2,
          accuracyPercent: 50,
          difficulty: 5,
        ),
      ],
    ),
    ChapterPracticeGroup(
      id: 30,
      title: '第三目录',
      directEntry: true,
      unlocked: false,
      chapters: [
        ChapterPracticeChapter(
          title: '第三目录',
          sectionShelfId: 30,
          catalogIndex: 2,
          chapterIndex: 0,
          leafShelfIds: [30],
          questionIds: ['6'],
          recordsByQuestionId: {},
          unlocked: false,
          doneCount: 0,
          rightCount: 0,
          totalCount: 1,
          accuracyPercent: 0,
          difficulty: 1,
        ),
      ],
    ),
  ],
);

final class _Source implements ChapterPracticeDataSource {
  _Source(this.responder);

  final Future<ChapterPracticeCatalog> Function(HomeModule module) responder;
  int loadCount = 0;

  @override
  Future<ChapterPracticeCatalog> load(HomeModule module) {
    loadCount += 1;
    return responder(module);
  }
}

final class _ProgressStore implements ChapterPracticeProgressStore {
  _ProgressStore({required this.expandedCatalog});

  final int expandedCatalog;
  final List<({int moduleId, int catalogIndex})> savedExpanded = [];

  @override
  Future<int> loadExpandedCatalog({required int moduleId}) async {
    return expandedCatalog;
  }

  @override
  Future<void> saveExpandedCatalog({
    required int moduleId,
    required int catalogIndex,
  }) async {
    savedExpanded.add((moduleId: moduleId, catalogIndex: catalogIndex));
  }

  @override
  Future<int> loadQuestionPosition({
    required int moduleId,
    required int catalogIndex,
    required int chapterIndex,
  }) async => 0;

  @override
  Future<void> saveQuestionPosition({
    required int moduleId,
    required int catalogIndex,
    required int chapterIndex,
    required int position,
  }) async {}
}
