import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/past_exams/past_exams_models.dart';

void main() {
  test('keeps only top-level flat papers and locks after the first two', () {
    final papers = parsePastExamPapers([
      {'id': '11', 'name': '真题一', 'type': ' 扁平化 '},
      {
        'id': 12,
        'name': '容器',
        'type': '嵌套化',
        'children': [
          {'id': 13, 'name': '不应递归', 'type': '扁平化'},
        ],
      },
      {'id': 14, 'name': '真题二', 'type': '扁平化'},
      {'id': 15, 'name': '真题三', 'type': '扁平化'},
    ], hasFullAccess: false);

    expect(pastExamFreePaperCount, 2);
    expect(papers.map((paper) => paper.id), [11, 14, 15]);
    expect(papers.map((paper) => paper.name), ['真题一', '真题二', '真题三']);
    expect(papers.map((paper) => paper.type), ['扁平化', '扁平化', '扁平化']);
    expect(papers.map((paper) => paper.locked), [false, false, true]);
  });

  test('full access unlocks every valid paper', () {
    final papers = parsePastExamPapers([
      for (var index = 0; index < 4; index += 1)
        {'id': index + 1, 'name': '真题 ${index + 1}', 'type': '扁平化'},
    ], hasFullAccess: true);

    expect(papers, hasLength(4));
    expect(papers.every((paper) => !paper.locked), isTrue);
  });

  test('skips invalid paper identity and non-flat top-level nodes', () {
    final papers = parsePastExamPapers(const [
      {'id': 0, 'name': '无效 ID', 'type': '扁平化'},
      {'id': 2, 'name': '  ', 'type': '扁平化'},
      {'id': 3, 'name': 'null', 'type': '扁平化'},
      {'id': 4, 'name': '结构化', 'type': '结构化'},
      {'id': '5', 'name': ' 有效真题 ', 'type': ' 扁平化 '},
    ], hasFullAccess: false);

    expect(papers, hasLength(1));
    expect(papers.single.id, 5);
    expect(papers.single.name, '有效真题');
    expect(papers.single.locked, isFalse);
  });

  test('rejects malformed shelf-tree shapes', () {
    expect(
      () => parsePastExamPapers(const {'id': 1}, hasFullAccess: false),
      throwsFormatException,
    );
    expect(
      () => parsePastExamPapers(const [
        {'id': 1, 'name': '真题一', 'type': '扁平化'},
        'bad-node',
      ], hasFullAccess: false),
      throwsFormatException,
    );
  });

  test('catalog owns an immutable snapshot', () {
    final source = <PastExamPaper>[
      const PastExamPaper(id: 1, name: '真题一', type: '扁平化', locked: false),
    ];
    final catalog = PastExamsCatalog(
      module: _module,
      papers: source,
      hasFullAccess: false,
    );
    source.clear();

    expect(catalog.module, same(_module));
    expect(catalog.papers, hasLength(1));
    expect(
      () => catalog.papers.add(
        const PastExamPaper(id: 2, name: '真题二', type: '扁平化', locked: false),
      ),
      throwsUnsupportedError,
    );
  });
}

const _module = HomeModule(
  id: 51,
  name: '历年真题卷',
  page: '历年真题卷',
  tag: '',
  type: '嵌套化',
);
