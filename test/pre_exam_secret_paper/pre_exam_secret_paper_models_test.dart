import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/pre_exam_secret_paper/pre_exam_secret_paper_models.dart';

void main() {
  test('recursively keeps valid leaves in depth-first server order', () {
    final papers = parsePreExamSecretPapers(const [
      {
        'id': 10,
        'name': '一级目录',
        'children': [
          {'id': 11, 'name': '卷一', 'children': []},
          {
            'id': 12,
            'name': '二级目录',
            'children': [
              {'id': 13, 'name': ' 卷二 '},
              {'id': 14, 'name': '   ', 'children': []},
            ],
          },
        ],
      },
      {'id': 15, 'name': '卷三'},
    ]);

    expect(papers.map((paper) => paper.id), [11, 13, 15]);
    expect(papers.map((paper) => paper.name), ['卷一', '卷二', '卷三']);
  });

  test('skips invalid leaf identities and ignores non-object nodes', () {
    final papers = parsePreExamSecretPapers(const [
      null,
      'not-a-node',
      {'id': 0, 'name': '零编号'},
      {'id': 'bad', 'name': '坏编号'},
      {'id': '21', 'name': '有效密卷'},
      {
        'id': 22,
        'name': '有子节点的目录',
        'children': [
          {'id': 23, 'name': '叶子密卷'},
        ],
      },
    ]);

    expect(papers.map((paper) => paper.id), [21, 23]);
  });

  test('rejects malformed shelf-tree shapes', () {
    expect(
      () => parsePreExamSecretPapers(const {'id': 1}),
      throwsFormatException,
    );
    expect(
      () => parsePreExamSecretPapers(const [
        {'id': 1, 'name': '目录', 'children': 'not-a-list'},
      ]),
      throwsFormatException,
    );
  });

  test('owns immutable paper and catalog snapshots', () {
    final source = <PreExamSecretPaper>[
      const PreExamSecretPaper(id: 31, name: '卷一'),
    ];
    final parsed = parsePreExamSecretPapers(const [
      {'id': 32, 'name': '卷二'},
    ]);
    final catalog = PreExamSecretPaperCatalog(
      module: const HomeModule(id: 8, name: '最后密押卷', page: '最后密押卷', tag: ''),
      papers: source,
      isVip: true,
    );

    source.clear();
    expect(catalog.papers.map((paper) => paper.id), [31]);
    expect(() => catalog.papers.clear(), throwsUnsupportedError);
    expect(() => parsed.clear(), throwsUnsupportedError);
  });

  test('pins the three Android card presentations', () {
    expect(
      preExamSecretPaperCardCopies.map(
        (copy) => (copy.title, copy.description),
      ),
      const [
        ('密卷A: 新规智能预测卷', '动态追踪政策变化, AI预测重点考题'),
        ('密卷B: 单元强化提分卷', '针对性强化训练, 快速提升薄弱模块'),
        ('密卷C: 高频易错冲刺卷', '直击历年失分率最高题型, 考前精准加固'),
      ],
    );
  });
}
