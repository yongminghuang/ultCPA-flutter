import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/category_selector_page.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';

void main() {
  testWidgets('shows grouped options and returns the selected category', (
    tester,
  ) async {
    CategoryOption? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<CategoryOption>(
                MaterialPageRoute(
                  builder: (_) => const CategorySelectorPage(
                    groups: _groups,
                    selectedKey: 'social-work_1016',
                  ),
                ),
              );
            },
            child: const Text('打开分类'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开分类'));
    await tester.pumpAndSettle();

    expect(find.text('请选择考试类目'), findsOneWidget);
    expect(find.byKey(const ValueKey('category-section-社工')), findsOneWidget);
    expect(find.byKey(const ValueKey('category-section-会计')), findsOneWidget);
    expect(find.text('初级社工'), findsOneWidget);
    final selected = tester.widget<Semantics>(
      find.byKey(const ValueKey('category-option-social-work_1016')),
    );
    expect(selected.properties.selected, isTrue);

    await tester.tap(find.byKey(const ValueKey('category-group-会计')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('category-option-joy-ledger_6')),
    );
    await tester.pumpAndSettle();

    expect(result?.key, 'joy-ledger_6');
    expect(find.text('打开分类'), findsOneWidget);
  });

  testWidgets('close returns without selecting a category', (tester) async {
    CategoryOption? result = _accountingOption;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<CategoryOption>(
                MaterialPageRoute(
                  builder: (_) => const CategorySelectorPage(
                    groups: _groups,
                    selectedKey: 'social-work_1016',
                  ),
                ),
              );
            },
            child: const Text('打开分类'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-selector-close')));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets(
    'scrolls back to the first group after selecting the last group',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategorySelectorPage(
            groups: _scrollGroups,
            selectedKey: _scrollGroups.first.options.first.key,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstSection = find.byKey(const ValueKey('category-section-分组 1'));
      final initialSectionTop = tester.getTopLeft(firstSection).dy;

      await tester.tap(find.byKey(const ValueKey('category-group-分组 5')));
      await tester.pumpAndSettle();

      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('category-section-分组 5')))
            .dy,
        closeTo(initialSectionTop, 1),
      );

      await tester.tap(find.byKey(const ValueKey('category-group-分组 1')));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(firstSection).dy, closeTo(initialSectionTop, 1));
    },
  );
}

const _socialSubjects = [
  CategorySubject(id: 1023, name: '社工实务'),
  CategorySubject(id: 1024, name: '综合能力'),
];

const _accountingSubjects = [
  CategorySubject(id: 61, name: '会计实务'),
  CategorySubject(id: 62, name: '经济法'),
];

const _socialOption = CategoryOption(
  key: 'social-work_1016',
  appType: 'social-work',
  id: 1016,
  label: '初级社工',
  subjects: _socialSubjects,
  raw: {'id': 1016, 'appType': 'social-work', 'level': '初级社工'},
);

const _accountingOption = CategoryOption(
  key: 'joy-ledger_6',
  appType: 'joy-ledger',
  id: 6,
  label: '初级会计',
  subjects: _accountingSubjects,
  raw: {'id': 6, 'appType': 'joy-ledger', 'level': '初级会计'},
);

const _groups = [
  CategoryGroup(label: '社工', options: [_socialOption]),
  CategoryGroup(label: '会计', options: [_accountingOption]),
];

final _scrollGroups = List.generate(5, (groupIndex) {
  final optionCount = groupIndex == 0 || groupIndex == 4 ? 1 : 3;
  return CategoryGroup(
    label: '分组 ${groupIndex + 1}',
    options: List.generate(optionCount, (optionIndex) {
      final id = groupIndex * 10 + optionIndex + 1;
      return CategoryOption(
        key: 'group-$groupIndex-$optionIndex',
        appType: 'group-$groupIndex',
        id: id,
        label: '类目 $id',
        subjects: const [CategorySubject(id: 1, name: '科目')],
        raw: {'id': id, 'level': '类目 $id'},
      );
    }),
  );
});
