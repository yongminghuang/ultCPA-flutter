import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_models.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_page.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_repository.dart';

void main() {
  testWidgets('shows loading then Android-aligned mnemonic rows', (
    tester,
  ) async {
    final completer = Completer<SkillMnemonicsCatalog>();
    await tester.pumpWidget(
      MaterialApp(
        home: SkillMnemonicsPage(
          module: _legacyNamedModule,
          dataSource: _DataSource(() => completer.future),
          detailLauncher: (_, _, _, _) async {},
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(_catalog(freeCount: 2));
    await tester.pumpAndSettle();

    expect(find.text('技巧口诀'), findsOneWidget);
    expect(find.byKey(const ValueKey('mnemonic-row-0')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('7题'), findsOneWidget);
    expect(find.text('看到必须先排除', findRichText: true), findsOneWidget);

    final title = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey('mnemonic-title-0')),
        matching: find.byType(RichText),
      ),
    );
    final spans = (title.text as TextSpan).children!.cast<TextSpan>();
    expect(
      spans.any(
        (span) =>
            span.text == '必须' && span.style?.color == const Color(0xFFFF2200),
      ),
      isTrue,
    );
  });

  testWidgets('retries a failed request and renders an empty catalog', (
    tester,
  ) async {
    var calls = 0;
    final source = _DataSource(() async {
      calls += 1;
      if (calls == 1) throw StateError('offline');
      return _catalog(records: const [], freeCount: 3);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: SkillMnemonicsPage(
          module: _module,
          dataSource: source,
          detailLauncher: (_, _, _, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('重新加载'), findsOneWidget);
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('暂无技巧口诀'), findsOneWidget);
  });

  testWidgets('opens only free rows and reports locked membership content', (
    tester,
  ) async {
    final opened = <({SkillMnemonic item, int position})>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SkillMnemonicsPage(
          module: _module,
          dataSource: _DataSource(() async => _catalog(freeCount: 1)),
          detailLauncher: (_, item, position, _) async {
            opened.add((item: item, position: position));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第二条私密口诀', findRichText: true), findsNothing);
    expect(find.byKey(const ValueKey('mnemonic-lock-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mnemonic-row-1')));
    await tester.pump();
    expect(find.text('会员与支付功能仍在迁移中'), findsOneWidget);
    expect(opened, isEmpty);

    await tester.tap(find.byKey(const ValueKey('mnemonic-row-0')));
    await tester.pump();
    expect(opened.single.position, 0);
    expect(opened.single.item.skillId, '11');
  });

  testWidgets('VIP policy exposes every row without changing free count', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SkillMnemonicsPage(
          module: _module,
          dataSource: _DataSource(() async => _catalog(freeCount: 0)),
          isVip: true,
          detailLauncher: (_, _, _, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第二条私密口诀', findRichText: true), findsOneWidget);
    expect(find.byKey(const ValueKey('mnemonic-lock-1')), findsNothing);
  });
}

SkillMnemonicsCatalog _catalog({
  int freeCount = 3,
  List<Map<String, Object?>>? records,
}) {
  return SkillMnemonicsCatalog.fromBody({
    'records':
        records ??
        const [
          {
            'skillId': '11',
            'text': '看到必须先排除',
            'keyword': '必须',
            'note': '解释一',
            'questionCount': 7,
          },
          {
            'skillId': '12',
            'text': '第二条私密口诀',
            'keyword': '私密',
            'note': '解释二',
            'questionCount': 3,
          },
        ],
  }, freeCount: freeCount);
}

const _module = HomeModule(id: 42, name: '技巧口诀', page: '技巧口诀', tag: '');

const _legacyNamedModule = HomeModule(
  id: 42,
  name: '大招口诀',
  page: '技巧口诀',
  tag: '',
);

final class _DataSource implements SkillMnemonicsDataSource {
  _DataSource(this.loader);

  final Future<SkillMnemonicsCatalog> Function() loader;

  @override
  Future<SkillMnemonicsCatalog> load(HomeModule module) => loader();
}
