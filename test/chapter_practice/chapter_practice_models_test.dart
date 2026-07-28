import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/chapter_practice/chapter_practice_models.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';

void main() {
  group('chapter shelf tree parsing', () {
    test('preserves direct-entry and descendant leaf structure', () {
      final roots = parseChapterShelfTree(_tree);

      expect(roots, hasLength(3));
      expect(roots.first.leafIds, [100]);
      expect(roots[1].leafIds, [212, 220]);
      expect(roots[1].children.first.firstDescendantLeaf?.name, '显示叶子');
      expect(roots[1].children.first.firstDescendantLeaf?.difficulty, 5);
    });

    test('rejects malformed tree and child containers', () {
      expect(
        () => parseChapterShelfTree(const {'id': 1}),
        throwsFormatException,
      );
      expect(
        () => parseChapterShelfTree(const [
          {'id': 1, 'children': 'bad'},
        ]),
        throwsFormatException,
      );
    });

    test('defaults and clamps difficulty to the Android range', () {
      final roots = parseChapterShelfTree(const [
        {'id': 1, 'difficult': '-2'},
        {'id': 2, 'difficult': '8'},
        {'id': 3, 'difficult': 'unknown'},
      ]);

      expect(roots.map((node) => node.difficulty), [0, 5, 3]);
    });
  });

  group('chapter question records', () {
    test('parses shelf order, choices, and right flags', () {
      final records = parseChapterQuestionRecordBody(const [
        {
          'shelfId': '212',
          'questionRecordResponseList': [
            {'questionId': 9007199254740993, 'choose': 'AC', 'isRight': 1},
            {'questionId': 2, 'choose': '', 'isRight': 0},
          ],
        },
      ]);

      expect(records.keys, [212]);
      expect(records[212]!.first.questionId, '9007199254740993');
      expect(records[212]!.first.choose, 'AC');
      expect(records[212]!.first.isRight, isTrue);
      expect(records[212]!.last.isAnswered, isFalse);
    });

    test('rejects malformed record bodies', () {
      expect(
        () => parseChapterQuestionRecordBody(const {'shelfId': 1}),
        throwsFormatException,
      );
      expect(
        () => parseChapterQuestionRecordBody(const [
          {'shelfId': 1, 'questionRecordResponseList': 'bad'},
        ]),
        throwsFormatException,
      );
    });
  });

  group('chapter catalog progress', () {
    test('builds progress, titles, access, and direct-entry groups', () {
      final catalog = ChapterPracticeCatalog.build(
        module: _module,
        roots: parseChapterShelfTree(_tree),
        recordsByShelf: parseChapterQuestionRecordBody(_records),
        fullAccess: false,
        previewGroupCount: 2,
      );

      expect(catalog.groups, hasLength(3));
      expect(catalog.groups.first.directEntry, isTrue);
      expect(catalog.groups.first.chapters.single.sectionShelfId, 100);
      expect(catalog.groups.first.unlocked, isTrue);
      expect(catalog.groups[1].unlocked, isTrue);
      expect(catalog.groups[2].unlocked, isFalse);

      final chapter = catalog.groups[1].chapters.first;
      expect(chapter.title, '显示叶子');
      expect(chapter.sectionShelfId, 210);
      expect(chapter.catalogIndex, 1);
      expect(chapter.chapterIndex, 0);
      expect(chapter.leafShelfIds, [212]);
      expect(chapter.questionIds, ['1', '2', '3']);
      expect(chapter.doneCount, 2);
      expect(chapter.rightCount, 1);
      expect(chapter.totalCount, 3);
      expect(chapter.accuracyPercent, 50);
      expect(chapter.difficulty, 5);
      expect(chapter.isCompleted, isFalse);
      expect(chapter.isInProgress, isTrue);
      expect(chapter.recordsByQuestionId['1']!.choose, 'A');

      final completed = catalog.groups[1].chapters[1];
      expect(completed.doneCount, 1);
      expect(completed.totalCount, 1);
      expect(completed.isCompleted, isTrue);
    });

    test('falls total back to known unique ids and clamps preview count', () {
      final catalog = ChapterPracticeCatalog.build(
        module: _module,
        roots: parseChapterShelfTree(const [
          {'id': 1, 'name': '一', 'goodsCount': 0},
          {'id': 2, 'name': '二', 'goodsCount': -3},
        ]),
        recordsByShelf: parseChapterQuestionRecordBody(const [
          {
            'shelfId': 1,
            'questionRecordResponseList': [
              {'questionId': 7, 'choose': ''},
              {'questionId': 7, 'choose': 'A', 'isRight': 1},
            ],
          },
        ]),
        fullAccess: false,
        previewGroupCount: -4,
      );

      expect(catalog.groups.first.chapters.single.totalCount, 1);
      expect(catalog.groups.first.chapters.single.doneCount, 1);
      expect(catalog.groups.first.chapters.single.rightCount, 1);
      expect(catalog.groups.every((group) => !group.unlocked), isTrue);
    });

    test('full access unlocks all groups and resolves the next chapter', () {
      final catalog = ChapterPracticeCatalog.build(
        module: _module,
        roots: parseChapterShelfTree(_tree),
        recordsByShelf: const {},
        fullAccess: true,
        previewGroupCount: 0,
      );

      expect(catalog.groups.every((group) => group.unlocked), isTrue);
      expect(
        catalog.chapterAt(catalogIndex: 1, chapterIndex: 0)?.title,
        '显示叶子',
      );
      final next = catalog.nextChapterAfter(catalogIndex: 1, chapterIndex: 1);
      expect(next?.catalogIndex, 2);
      expect(next?.chapterIndex, 0);
      expect(next?.title, '第三组');
      expect(
        catalog.nextChapterAfter(catalogIndex: 2, chapterIndex: 0),
        isNull,
      );
    });
  });
}

const _module = HomeModule(
  id: 42,
  name: '章节练习',
  page: '章节练习',
  tag: '',
  type: '结构化',
);

const _tree = <Object?>[
  {'id': 100, 'name': '直达章节', 'goodsCount': 1, 'difficult': '2'},
  {
    'id': 200,
    'name': '第二组',
    'children': [
      {
        'id': 210,
        'name': '隐藏标题',
        'status': false,
        'goodsCount': 3,
        'children': [
          {
            'id': 211,
            'name': '中间层',
            'children': [
              {'id': 212, 'name': '显示叶子', 'difficult': '9'},
            ],
          },
        ],
      },
      {'id': 220, 'name': '第二节', 'goodsCount': 1},
    ],
  },
  {'id': 300, 'name': '第三组', 'goodsCount': 0},
];

const _records = <Object?>[
  {
    'shelfId': 212,
    'questionRecordResponseList': [
      {'questionId': 1, 'choose': 'A', 'isRight': 1},
      {'questionId': 2, 'choose': 'B', 'isRight': 0},
      {'questionId': 3, 'choose': '', 'isRight': 0},
      {'questionId': 1, 'choose': 'B', 'isRight': 0},
    ],
  },
  {
    'shelfId': 220,
    'questionRecordResponseList': [
      {'questionId': 4, 'choose': 'A', 'isRight': true},
    ],
  },
];
