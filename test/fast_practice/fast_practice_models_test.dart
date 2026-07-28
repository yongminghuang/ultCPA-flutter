import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/fast_practice/fast_practice_models.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';

void main() {
  test('recursively preserves every valid leaf in server order', () {
    final leaves = parseFastPracticeLeaves(const [
      {
        'id': 100,
        'name': '目录一',
        'children': [
          {
            'id': 110,
            'name': '中间层',
            'children': [
              {'id': 111, 'name': '精选一', 'type': '扁平化'},
              {'id': 112, 'name': '精选二', 'type': '信息化'},
            ],
          },
        ],
      },
      {'id': 200, 'name': '精选三', 'type': '扁平化'},
    ]);

    expect(leaves.map((leaf) => leaf.id), [111, 112, 200]);
    expect(leaves.map((leaf) => leaf.name), ['精选一', '精选二', '精选三']);
    expect(leaves.map((leaf) => leaf.type), ['扁平化', '信息化', '扁平化']);
  });

  test('skips unnamed and non-positive leaves without promoting parents', () {
    final leaves = parseFastPracticeLeaves(const [
      {'id': 0, 'name': '无效 ID'},
      {'id': 2, 'name': '  '},
      {
        'id': 3,
        'name': '有孩子的目录',
        'children': [
          {'id': 4, 'name': ''},
        ],
      },
      {'id': '5', 'name': '保留'},
    ]);

    expect(leaves, hasLength(1));
    expect(leaves.single.id, 5);
    expect(leaves.single.name, '保留');
  });

  test('rejects malformed root and child containers', () {
    expect(
      () => parseFastPracticeLeaves(const {'id': 1}),
      throwsFormatException,
    );
    expect(
      () => parseFastPracticeLeaves(const [
        {'id': 1, 'children': 'bad'},
      ]),
      throwsFormatException,
    );
    expect(
      () => parseFastPracticeLeaves(const [
        {
          'id': 1,
          'children': ['bad'],
        },
      ]),
      throwsFormatException,
    );
  });

  test('catalog keeps its original Home module and immutable leaves', () {
    const module = HomeModule(
      id: 42,
      name: '速成300题',
      page: '速成300题',
      tag: 'hot',
    );
    final leaves = parseFastPracticeLeaves(const [
      {'id': 11, 'name': '精选一'},
    ]);
    final catalog = FastPracticeCatalog(module: module, leaves: leaves);

    expect(catalog.module.id, 42);
    expect(catalog.leaves.single.id, 11);
    expect(
      () => catalog.leaves.add(
        const FastPracticeLeaf(id: 12, name: '精选二', type: ''),
      ),
      throwsUnsupportedError,
    );
    expect(FastPracticeEntryDestination.values, [
      FastPracticeEntryDestination.catalog,
      FastPracticeEntryDestination.landing,
      FastPracticeEntryDestination.empty,
    ]);
  });
}
