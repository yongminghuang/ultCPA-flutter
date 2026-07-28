import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_detail_page.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_models.dart';

void main() {
  testWidgets('renders the mnemonic detail and counts down from 30 seconds', (
    tester,
  ) async {
    const tick = Duration(milliseconds: 100);
    await tester.pumpWidget(
      const MaterialApp(
        home: SkillMnemonicsDetailPage(
          item: _item,
          position: 0,
          module: _module,
          tickDuration: tick,
        ),
      ),
    );

    expect(find.text('技巧记忆'), findsOneWidget);
    expect(find.text('00:30'), findsOneWidget);
    expect(find.text('技巧口诀'), findsOneWidget);
    expect(find.text('技巧解析'), findsOneWidget);
    expect(find.text('看到必须先排除', findRichText: true), findsOneWidget);
    expect(find.text('必须结合题干排除绝对表述', findRichText: true), findsOneWidget);
    expect(find.text('掌握该技巧能做 7 题', findRichText: true), findsOneWidget);

    final mnemonicText = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey('mnemonic-detail-text')),
        matching: find.byType(RichText),
      ),
    );
    final spans = (mnemonicText.text as TextSpan).children!.cast<TextSpan>();
    expect(
      spans.any(
        (span) =>
            span.text == '必须' && span.style?.color == const Color(0xFFFF2200),
      ),
      isTrue,
    );

    await tester.pump(tick);
    expect(find.text('00:29'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mnemonic-practice-action')));
    await tester.pump();
    expect(find.text('关联做题功能仍在迁移中'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(tick * 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the name when the API text is empty and supports back', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => const SkillMnemonicsDetailPage(
                    item: _nameOnlyItem,
                    position: 1,
                    module: _module,
                  ),
                ),
              );
            },
            child: const Text('打开详情'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开详情'));
    await tester.pumpAndSettle();
    expect(find.text('备用口诀名称', findRichText: true), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('打开详情'), findsOneWidget);
  });
}

const _module = HomeModule(id: 42, name: '技巧口诀', page: '技巧口诀', tag: '');

const _item = SkillMnemonic(
  skillId: '11',
  text: '看到必须先排除',
  name: '',
  keyword: '必须,排除',
  textKeyword: '',
  note: '必须结合题干排除绝对表述',
  imgUrl: null,
  videoUrl: null,
  voiceUrl: null,
  coverUrl: null,
  questionCount: 7,
  shelfId: '42',
  goodsId: 'g-1',
  type: '大招',
  content: '',
  extend: null,
  sort: 1,
  status: true,
);

const _nameOnlyItem = SkillMnemonic(
  skillId: '12',
  text: '',
  name: '备用口诀名称',
  keyword: '',
  textKeyword: '',
  note: '',
  imgUrl: null,
  videoUrl: null,
  voiceUrl: null,
  coverUrl: null,
  questionCount: 0,
  shelfId: '',
  goodsId: '',
  type: '大招',
  content: '',
  extend: null,
  sort: 2,
  status: true,
);
