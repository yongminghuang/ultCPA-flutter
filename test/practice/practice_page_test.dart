import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/chapter_practice/chapter_practice_progress_store.dart';
import 'package:ultcpa_flutter/src/daily_skill/daily_skill_models.dart';
import 'package:ultcpa_flutter/src/daily_skill/daily_skill_progress_store.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/practice/flat_practice_progress_store.dart';
import 'package:ultcpa_flutter/src/practice/practice_models.dart';
import 'package:ultcpa_flutter/src/practice/practice_page.dart';
import 'package:ultcpa_flutter/src/practice/practice_repository.dart';
import 'package:ultcpa_flutter/src/practice/practice_result_page.dart';
import 'package:ultcpa_flutter/src/practice/practice_settings_store.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_models.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_models.dart';

void main() {
  testWidgets('shows loading before the catalog resolves', (tester) async {
    final completer = Completer<PracticeCatalog>();
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: _request,
          dataSource: _DataSource((_) => completer.future),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('practice-loading')), findsOneWidget);

    completer.complete(_catalog(const []));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('practice-empty')), findsOneWidget);
    expect(find.text('暂无练习内容'), findsOneWidget);
  });

  testWidgets('retries a failed catalog request', (tester) async {
    var calls = 0;
    final source = _DataSource((_) async {
      calls += 1;
      if (calls == 1) throw StateError('offline');
      return _catalog([PracticeQuestionItem(_question('1'))]);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(request: _request, dataSource: source),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('practice-error')), findsOneWidget);
    expect(find.text('加载失败'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('practice-retry')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(const ValueKey('practice-question')), findsOneWidget);
    expect(_questionStem('题目 1'), findsOneWidget);
  });

  testWidgets('toolbar exposes a tappable Android back affordance', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const SizedBox(key: ValueKey('practice-test-host')),
      ),
    );
    unawaited(
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => PracticePage(
            request: _request,
            dataSource: _DataSource(
              (_) async => _catalog([PracticeQuestionItem(_question('1'))]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final back = find.byKey(const ValueKey('practice-back'));
    expect(back, findsOneWidget);

    await tester.tap(back);
    await tester.pumpAndSettle();

    expect(find.byType(PracticePage), findsNothing);
    expect(find.byKey(const ValueKey('practice-test-host')), findsOneWidget);
  });

  testWidgets('applies and persists Android practice settings', (tester) async {
    final settingsStore = _SettingsStore(
      const PracticeSettings(
        autoNext: false,
        playCorrectSound: false,
        explainWrongAutomatically: false,
        fontSize: PracticeFontSize.normal,
        themeMode: PracticeThemeMode.standard,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: _request,
          dataSource: _DataSource(
            (_) async => _catalog([PracticeQuestionItem(_question('1'))]),
          ),
          settingsStore: settingsStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-settings')));
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('practice-settings-sheet'));
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('设置')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('practice-settings-close')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('practice-font-size-slider')),
      findsOneWidget,
    );
    expect(find.text('答对自动跳转下一题'), findsOneWidget);

    final scaffoldHeight = tester.getSize(find.byType(Scaffold).first).height;
    expect(
      tester.getSize(sheet).height,
      lessThan(scaffoldHeight * 0.72),
      reason: '普通设置面板应按内容高度展示，而不是固定占屏幕 72%',
    );

    await tester.tap(find.text('护眼'));
    await tester.pumpAndSettle();

    expect(settingsStore.saved.last.themeMode, PracticeThemeMode.eyeCare);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, const Color(0xFFF9F6ED));

    await tester.tap(find.byKey(const ValueKey('practice-settings-close')));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
  });

  testWidgets('renders the type inline and keeps question tags left aligned', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: _request,
          dataSource: _DataSource(
            (_) async => _catalog([
              PracticeQuestionItem(_question('1', tags: '2023年真题')),
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final typeRect = tester.getRect(find.text('单选题'));
    final stemRect = tester.getRect(_questionStem('题目 1'));
    final tagRect = tester.getRect(find.text('2023年真题'));
    final collectionRect = tester.getRect(
      find.byKey(const ValueKey('practice-collection-toggle')),
    );
    final pageWidth = tester.getSize(find.byType(Scaffold).first).width;

    expect(typeRect.left, inInclusiveRange(stemRect.left, stemRect.left + 16));
    expect(typeRect.top, lessThan(stemRect.bottom));
    expect(typeRect.bottom, greaterThan(stemRect.top));
    expect(tagRect.top, greaterThan(stemRect.bottom));
    expect(tagRect.left, lessThan(pageWidth / 2));
    expect(collectionRect.left, lessThan(pageWidth / 2));
    expect(tagRect.right, lessThanOrEqualTo(collectionRect.left));
  });

  testWidgets('auto-next follows the persisted Android setting', (
    tester,
  ) async {
    final settingsStore = _SettingsStore(
      const PracticeSettings(
        autoNext: true,
        playCorrectSound: false,
        explainWrongAutomatically: false,
        fontSize: PracticeFontSize.normal,
        themeMode: PracticeThemeMode.standard,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: _request,
          dataSource: _DataSource(
            (_) async => _catalog([
              PracticeQuestionItem(_question('1')),
              PracticeQuestionItem(_question('2')),
            ]),
          ),
          settingsStore: settingsStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pump(const Duration(milliseconds: 421));

    expect(_questionStem('题目 2'), findsOneWidget);
  });

  testWidgets('always shows Android skill shortcut and loads current skills', (
    tester,
  ) async {
    final source = _DataSource(
      (_) async => _catalog([PracticeQuestionItem(_question('1'))]),
      skillLoader: (questionId) async => [_skill('related-$questionId').skill],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(request: _request, dataSource: source),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('practice-skill-shortcut')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('practice-skill-shortcut')));
    await tester.pumpAndSettle();

    expect(source.skillQuestionIds, ['1']);
    expect(
      find.byKey(const ValueKey('practice-skill-explanation')),
      findsOneWidget,
    );
    expect(find.text('技巧讲解'), findsWidgets);
    expect(find.text('技巧解释 related-1', findRichText: true), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('practice-skill-explanation-close')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('practice-skill-shortcut')));
    await tester.pumpAndSettle();
    expect(source.skillQuestionIds, ['1']);
  });

  testWidgets('reports the Android no-skill state for the current question', (
    tester,
  ) async {
    final source = _DataSource(
      (_) async => _catalog([PracticeQuestionItem(_question('1'))]),
      skillLoader: (_) async => const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(request: _request, dataSource: source),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-skill-shortcut')));
    await tester.pumpAndSettle();

    expect(find.text('该题暂无技巧'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('practice-skill-explanation')),
      findsNothing,
    );
  });

  testWidgets('answering automatically renders related mnemonic content', (
    tester,
  ) async {
    final source = _DataSource(
      (_) async => _catalog([PracticeQuestionItem(_question('1'))]),
      skillLoader: (questionId) async => [_skill('related-$questionId').skill],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(request: _request, dataSource: source),
      ),
    );
    await tester.pumpAndSettle();

    expect(source.skillQuestionIds, isEmpty);
    expect(find.text('速记技巧'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pump();
    await tester.pump();

    expect(source.skillQuestionIds, ['1']);
    expect(find.text('速记技巧'), findsOneWidget);
    expect(find.text('技巧 related-1', findRichText: true), findsOneWidget);
    expect(find.text('技巧解释 related-1', findRichText: true), findsOneWidget);
  });

  testWidgets('stale skill requests cannot overwrite a new chapter session', (
    tester,
  ) async {
    final staleSkills = Completer<List<SkillMnemonic>>();
    var skillLoadCount = 0;
    final source = _DataSource(
      (request) async {
        final chapterRequest = request as ChapterPracticeRequest;
        if (chapterRequest.entryMode == ChapterPracticeEntryMode.automatic) {
          return _chapterCatalog(
            [PracticeQuestionItem(_question('1'))],
            catalogIndex: 2,
            chapterIndex: 0,
            title: '下一章节',
          );
        }
        return _chapterCatalog(
          [PracticeQuestionItem(_question('1'))],
          nextChapter: const PracticeChapterTarget(
            catalogIndex: 2,
            chapterIndex: 0,
            title: '下一章节',
            unlocked: true,
          ),
        );
      },
      skillLoader: (_) {
        skillLoadCount += 1;
        if (skillLoadCount == 1) return staleSkills.future;
        return Future.value([_skill('current').skill]);
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(request: _chapterRequest(), dataSource: source),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pump();
    expect(skillLoadCount, 1);

    await tester.tap(find.byKey(const ValueKey('practice-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pump();
    await tester.pump();

    expect(skillLoadCount, 2);
    expect(
      find.byKey(const ValueKey('practice-inline-skills-loading')),
      findsNothing,
    );
    expect(find.text('技巧 current', findRichText: true), findsOneWidget);

    staleSkills.complete([_skill('stale').skill]);
    await tester.pump();
    await tester.pump();

    expect(find.text('技巧 stale', findRichText: true), findsNothing);
    expect(find.text('技巧 current', findRichText: true), findsOneWidget);
  });

  testWidgets('a failed chapter switch keeps the current skill request valid', (
    tester,
  ) async {
    final pendingSkills = Completer<List<SkillMnemonic>>();
    final source = _DataSource((request) async {
      final chapterRequest = request as ChapterPracticeRequest;
      if (chapterRequest.entryMode == ChapterPracticeEntryMode.automatic) {
        throw StateError('offline');
      }
      return _chapterCatalog(
        [PracticeQuestionItem(_question('1'))],
        nextChapter: const PracticeChapterTarget(
          catalogIndex: 2,
          chapterIndex: 0,
          title: '下一章节',
          unlocked: true,
        ),
      );
    }, skillLoader: (_) => pendingSkills.future);
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(request: _chapterRequest(), dataSource: source),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('practice-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('章节加载失败，请稍后重试'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('practice-inline-skills-loading')),
      findsOneWidget,
    );

    pendingSkills.complete([_skill('current').skill]);
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('practice-inline-skills-loading')),
      findsNothing,
    );
    expect(find.text('技巧 current', findRichText: true), findsOneWidget);
  });

  testWidgets('skill shortcut exposes a visible pulse mid-frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: _request,
          dataSource: _DataSource(
            (_) async => _catalog([PracticeQuestionItem(_question('1'))]),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final pulse = find.byKey(const ValueKey('practice-skill-pulse'));
    expect(pulse, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 250));

    final transform = tester.widget<Transform>(pulse);
    expect(transform.transform.getMaxScaleOnAxis(), greaterThan(1));
    final opacity = find.descendant(of: pulse, matching: find.byType(Opacity));
    expect(opacity, findsOneWidget);
    expect(tester.widget<Opacity>(opacity).opacity, lessThan(1));
  });

  testWidgets(
    'renders a skill card then submits and persists a single choice',
    (tester) async {
      final source = _DataSource(
        (_) async => _catalog([
          _skill('s-1'),
          PracticeQuestionItem(
            _question('1', analysis: '解析内容', keyword: '关键词'),
          ),
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PracticePage(request: _request, dataSource: source),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('practice-skill')), findsOneWidget);
      expect(find.text('技巧口诀'), findsOneWidget);
      expect(find.text('技巧 s-1', findRichText: true), findsOneWidget);
      expect(find.text('技巧解析'), findsOneWidget);
      expect(find.text('技巧解释 s-1', findRichText: true), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('practice-next')));
      await tester.pump();
      expect(find.text('单选题'), findsOneWidget);
      expect(_questionStem('题目 1'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('practice-option-A')));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('practice-option-state-A-correct')),
        findsOneWidget,
      );
      expect(find.text('正确答案：A'), findsOneWidget);
      expect(find.text('解析内容'), findsOneWidget);
      expect(_bottomStatText(tester, 'practice-right-count'), '1');
      expect(_bottomStatText(tester, 'practice-wrong-count'), '0');
      expect(source.saved.single.answer.choose, 'A');
      expect(source.saved.single.answer.isRight, isTrue);
    },
  );

  testWidgets('toggles multiple choices, confirms, and uses the answer card', (
    tester,
  ) async {
    final first = _question('1');
    final multiple = _question(
      '2',
      questionType: '多选题',
      answer: 'AC',
      options: const {'A': '甲', 'B': '乙', 'C': '丙'},
    );
    final source = _DataSource(
      (_) async => _catalog([
        PracticeQuestionItem(first),
        PracticeQuestionItem(multiple),
      ]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(request: _request, dataSource: source),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-next')));
    await tester.pump();
    expect(find.text('多选题'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('practice-option-C')));
    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('practice-option-state-A-selected')),
      findsOneWidget,
    );
    expect(source.saved, isEmpty);
    await tester.tap(find.byKey(const ValueKey('practice-confirm')));
    await tester.pump();
    expect(source.saved.single.answer.choose, 'AC');

    await tester.tap(find.byKey(const ValueKey('practice-previous')));
    await tester.pump();
    expect(_questionStem('题目 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('practice-answer-card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('practice-answer-sheet')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('practice-answer-status-1-right')),
      findsOneWidget,
    );
    final unanswered = tester.widget<Text>(
      find.byKey(const ValueKey('practice-answer-status-0-open')),
    );
    expect(unanswered.style?.fontSize, 14);
    expect(unanswered.style?.fontWeight, FontWeight.w400);
    expect(
      tester.getSize(find.byKey(const ValueKey('practice-answer-cell-0'))),
      const Size.square(44),
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('practice-answer-status-1-right')),
          )
          .style
          ?.fontWeight,
      FontWeight.w400,
    );
    await tester.tap(find.byKey(const ValueKey('practice-answer-cell-1')));
    await tester.pumpAndSettle();
    expect(_questionStem('题目 2'), findsOneWidget);
  });

  testWidgets('answer card clears remote and local practice records', (
    tester,
  ) async {
    final source = _DataSource(
      (_) async => _catalog([PracticeQuestionItem(_question('1'))]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(request: _request, dataSource: source),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pump();
    expect(find.text('正确答案：A'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('practice-answer-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('practice-clear-records')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空').last);
    await tester.pumpAndSettle();

    expect(source.clearCalls, 1);
    expect(find.text('正确答案：A'), findsNothing);
    expect(find.text('做题记录已清空'), findsOneWidget);
  });

  testWidgets('renders judgment questions and wrong option states', (
    tester,
  ) async {
    final source = _DataSource(
      (_) async => _catalog([
        PracticeQuestionItem(_question('1', questionType: '判断题', answer: 'B')),
      ]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(request: _request, dataSource: source),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('判断题'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('practice-option-state-A-wrong')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('practice-option-state-B-correct')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('practice-wrong-count')),
              matching: find.byType(Text),
            ),
          )
          .data,
      '1',
    );
  });

  testWidgets('keeps a local answer and reports record sync failure', (
    tester,
  ) async {
    final source = _DataSource(
      (_) async => _catalog([PracticeQuestionItem(_question('1'))]),
      failSave: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(request: _request, dataSource: source),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pumpAndSettle();

    expect(find.text('正确答案：A'), findsOneWidget);
    expect(find.text('答题记录同步失败，请稍后重试'), findsOneWidget);
  });

  testWidgets('answered questions do not expose a correction feedback entry', (
    tester,
  ) async {
    final source = _DataSource(
      (_) async =>
          _catalog([PracticeQuestionItem(_question('1', analysis: '解析内容'))]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(request: _request, dataSource: source),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pump();

    expect(find.text('反馈'), findsNothing);
    expect(find.byKey(const ValueKey('practice-correction')), findsNothing);
    expect(source.corrections, isEmpty);
  });

  testWidgets('reports a pending membership boundary without saving', (
    tester,
  ) async {
    final source = _DataSource(
      (_) async => _catalog(
        [PracticeQuestionItem(_question('1'))],
        fullAccess: false,
        freeQuestionCount: 0,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(request: _request, dataSource: source),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pump();

    expect(find.text('免费练题次数已用完，请开通会员后继续'), findsOneWidget);
    expect(source.saved, isEmpty);
    expect(find.text('正确答案：A'), findsNothing);
  });

  testWidgets('opens the Android answer-card payment source at the boundary', (
    tester,
  ) async {
    final sources = <VipPaymentSource>[];
    final source = _DataSource(
      (_) async => _catalog(
        [PracticeQuestionItem(_question('1'))],
        fullAccess: false,
        freeQuestionCount: 0,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: _request,
          dataSource: source,
          paymentLauncher: (_, paymentSource) async {
            sources.add(paymentSource);
            return VipPurchaseResult.paid;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pump();
    expect(sources, [VipPaymentSource.answerCardUnlock]);

    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pump();
    expect(find.text('正确答案：A'), findsOneWidget);
    expect(source.saved, hasLength(1));
  });

  testWidgets('uses Android payment sources for skill explanation', (
    tester,
  ) async {
    final sources = <VipPaymentSource>[];
    final source = _DataSource(
      (_) async => _catalog(
        [PracticeQuestionItem(_question('1')), _skill('s-1')],
        fullAccess: false,
        freeQuestionCount: 0,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: _request,
          dataSource: source,
          paymentLauncher: (_, paymentSource) async {
            sources.add(paymentSource);
            return VipPurchaseResult.paid;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-skill-shortcut')));
    await tester.pumpAndSettle();

    expect(sources, [VipPaymentSource.skillExplain]);
    expect(
      find.byKey(const ValueKey('practice-skill-explanation')),
      findsOneWidget,
    );
    expect(find.text('技巧解释 s-1', findRichText: true), findsOneWidget);
  });

  testWidgets('promotion banner and completion use their exact pay sources', (
    tester,
  ) async {
    final sources = <VipPaymentSource>[];
    final request = ModulePracticeRequest(
      module: const HomeModule(id: 9, name: '推广练题', page: '推广技巧', tag: ''),
    );
    final source = _DataSource(
      (_) async =>
          _catalog([_skill('s-1'), PracticeQuestionItem(_question('1'))]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: request,
          dataSource: source,
          paymentLauncher: (_, paymentSource) async {
            sources.add(paymentSource);
            return paymentSource == VipPaymentSource.promotionPracticeFinish
                ? VipPurchaseResult.paid
                : null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-promotion-unlock')));
    await tester.pump();
    expect(sources, [VipPaymentSource.promotionPracticePay]);

    await tester.tap(find.byKey(const ValueKey('practice-next')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('practice-next')));
    await tester.pumpAndSettle();

    expect(sources, [
      VipPaymentSource.promotionPracticePay,
      VipPaymentSource.promotionPracticeFinish,
    ]);
    expect(find.byType(PracticeResultPage), findsOneWidget);
  });

  testWidgets('opens the result page from the last item', (tester) async {
    final source = _DataSource(
      (_) async => _catalog([PracticeQuestionItem(_question('1'))]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(request: _request, dataSource: source),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('practice-next')));
    await tester.pumpAndSettle();

    expect(find.byType(PracticeResultPage), findsOneWidget);
    expect(find.text('练习结果'), findsOneWidget);
    expect(find.text('正确率 100%'), findsOneWidget);
  });

  testWidgets('shows the Android Mine review empty message', (tester) async {
    final source = _DataSource(
      (_) async => _catalog(
        const [],
        behavior: const PracticeBehavior.review(emptyMessage: '还没有错题哟'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(request: _request, dataSource: source),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('practice-empty')), findsOneWidget);
    expect(find.text('还没有错题哟'), findsOneWidget);
    expect(find.text('暂无练习内容'), findsNothing);
  });

  testWidgets('Mine review keeps answers local and stays on the last item', (
    tester,
  ) async {
    final source = _DataSource(
      (_) async => _catalog([
        PracticeQuestionItem(_question('1')),
      ], behavior: const PracticeBehavior.errorReview(emptyMessage: '还没有错题哟')),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(request: _request, dataSource: source),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pump();
    expect(find.text('正确答案：A'), findsOneWidget);
    expect(source.saved, isEmpty);

    await tester.tap(find.byKey(const ValueKey('practice-next')));
    await tester.pump();
    expect(find.text('当前已是最后一题'), findsOneWidget);
    expect(find.byType(PracticeResultPage), findsNothing);
  });

  testWidgets('toggles collection optimistically and reports API results', (
    tester,
  ) async {
    final source = _DataSource(
      (_) async => _catalog([PracticeQuestionItem(_question('1'))]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(request: _request, dataSource: source),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('practice-collection-not-collected')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('practice-collection-toggle')));
    await tester.pumpAndSettle();

    expect(source.collectionChanges.single.collected, isTrue);
    expect(
      find.byKey(const ValueKey('practice-collection-collected')),
      findsOneWidget,
    );
    expect(find.text('收藏成功'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('practice-collection-toggle')));
    await tester.pumpAndSettle();
    expect(source.collectionChanges.last.collected, isFalse);
    expect(find.text('取消收藏'), findsOneWidget);
  });

  testWidgets(
    'collection review removes an uncollected item before a failed request',
    (tester) async {
      final pending = Completer<void>();
      final source = _DataSource(
        (_) async => _catalog(
          [
            PracticeQuestionItem(_question('1')),
            PracticeQuestionItem(_question('2')),
          ],
          behavior: const PracticeBehavior.collectionReview(
            emptyMessage: '暂无收藏题目',
          ),
        ),
        collectionResult: pending,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PracticePage(
            request: const CollectionPracticeRequest(),
            dataSource: source,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('practice-collection-collected')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('practice-collection-toggle')),
      );
      await tester.pump();

      expect(_questionStem('题目 1'), findsNothing);
      expect(_questionStem('题目 2'), findsOneWidget);
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();

      expect(_questionStem('题目 2'), findsOneWidget);
      expect(find.text('操作失败，请稍后重试'), findsOneWidget);
    },
  );

  testWidgets('last collection removal reports its result after closing', (
    tester,
  ) async {
    final pending = Completer<void>();
    final source = _DataSource(
      (_) async => _catalog(
        [PracticeQuestionItem(_question('1'))],
        behavior: const PracticeBehavior.collectionReview(
          emptyMessage: '暂无收藏题目',
        ),
      ),
      collectionResult: pending,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => PracticePage(
                      request: const CollectionPracticeRequest(),
                      dataSource: source,
                    ),
                  ),
                ),
                child: const Text('打开收藏'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开收藏'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-collection-toggle')));
    await tester.pumpAndSettle();
    expect(find.byType(PracticePage), findsNothing);

    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();

    expect(find.text('操作失败，请稍后重试'), findsOneWidget);
  });

  testWidgets('manual wrong removal waits for success and keeps failures', (
    tester,
  ) async {
    final pending = Completer<void>();
    final source = _DataSource(
      (_) async => _catalog([
        PracticeQuestionItem(_question('1')),
        PracticeQuestionItem(_question('2')),
      ], behavior: const PracticeBehavior.errorReview(emptyMessage: '还没有错题哟')),
      wrongRemovalResult: pending,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: const ErrorPracticeRequest(),
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-remove-wrong')));
    await tester.pump();
    expect(_questionStem('题目 1'), findsOneWidget);

    pending.complete();
    await tester.pumpAndSettle();
    expect(_questionStem('题目 1'), findsNothing);
    expect(_questionStem('题目 2'), findsOneWidget);
    expect(find.text('已移除'), findsOneWidget);

    source.failWrongRemoval = true;
    await tester.tap(find.byKey(const ValueKey('practice-remove-wrong')));
    await tester.pumpAndSettle();
    expect(_questionStem('题目 2'), findsOneWidget);
    expect(find.text('移除失败，请稍后重试'), findsOneWidget);
  });

  testWidgets('automatic removal counts only correct review answers', (
    tester,
  ) async {
    final source = _DataSource(
      (_) async => _catalog([
        PracticeQuestionItem(_question('1')),
        PracticeQuestionItem(_question('2')),
      ], behavior: const PracticeBehavior.errorReview(emptyMessage: '还没有错题哟')),
      thresholdReached: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: const ErrorPracticeRequest(),
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pumpAndSettle();

    expect(source.recordedCorrect.map((question) => question.id), ['1']);
    expect(source.removedWrong.map((question) => question.id), ['1']);
    expect(_questionStem('题目 2'), findsOneWidget);
    expect(find.text('已移除'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('practice-option-B')));
    await tester.pumpAndSettle();
    expect(source.recordedCorrect, hasLength(1));
    expect(_questionStem('题目 2'), findsOneWidget);
  });

  testWidgets('delayed automatic removal targets the submitted question', (
    tester,
  ) async {
    final pending = Completer<bool>();
    final source = _DataSource(
      (_) async => _catalog([
        PracticeQuestionItem(_question('1')),
        PracticeQuestionItem(_question('2')),
      ], behavior: const PracticeBehavior.errorReview(emptyMessage: '还没有错题哟')),
      correctResult: pending,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: const ErrorPracticeRequest(),
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('practice-next')));
    await tester.pump();
    expect(_questionStem('题目 2'), findsOneWidget);

    pending.complete(true);
    await tester.pumpAndSettle();

    expect(_questionStem('题目 2'), findsOneWidget);
    expect(source.removedWrong.single.id, '1');
  });

  testWidgets('error review exposes and persists every removal threshold', (
    tester,
  ) async {
    final source = _DataSource(
      (_) async => _catalog([
        PracticeQuestionItem(_question('1')),
      ], behavior: const PracticeBehavior.errorReview(emptyMessage: '还没有错题哟')),
      threshold: 3,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: const ErrorPracticeRequest(),
          dataSource: source,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-wrong-settings')));
    await tester.pumpAndSettle();

    for (final value in [-1, 1, 2, 3, 4, 5, 6, 7]) {
      expect(
        find.byKey(ValueKey('practice-wrong-threshold-$value')),
        findsOneWidget,
      );
    }
    expect(find.text('请选择做对几次，自动移除错题'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('practice-wrong-threshold-5')));
    await tester.pumpAndSettle();

    expect(source.savedThresholds, [5]);
  });

  testWidgets('chapter resume restores only an in-progress position', (
    tester,
  ) async {
    final progress = _ChapterProgressStore(position: 1);
    final source = _DataSource(
      (_) async => _chapterCatalog([
        PracticeQuestionItem(_question('1', choose: 'A', isRight: true)),
        PracticeQuestionItem(_question('2', choose: 'B', isRight: false)),
        PracticeQuestionItem(_question('3')),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: _chapterRequest(),
          dataSource: source,
          chapterProgressStore: progress,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_questionStem('题目 2'), findsOneWidget);
    expect(progress.loadedPositions, [
      (moduleId: 42, catalogIndex: 1, chapterIndex: 2),
    ]);
  });

  testWidgets('non-resume chapter entries start and persist at zero', (
    tester,
  ) async {
    for (final mode in [
      ChapterPracticeEntryMode.view,
      ChapterPracticeEntryMode.redo,
      ChapterPracticeEntryMode.automatic,
    ]) {
      final progress = _ChapterProgressStore(position: 2);
      final source = _DataSource(
        (_) async => _chapterCatalog([
          PracticeQuestionItem(_question('1', choose: 'A', isRight: true)),
          PracticeQuestionItem(_question('2', choose: 'A', isRight: true)),
          PracticeQuestionItem(_question('3')),
        ]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PracticePage(
            key: ValueKey(mode),
            request: _chapterRequest(mode: mode),
            dataSource: source,
            chapterProgressStore: progress,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_questionStem('题目 1'), findsOneWidget, reason: mode.name);
      expect(progress.loadedPositions, isEmpty, reason: mode.name);
      expect(progress.savedPositions.last.position, 0, reason: mode.name);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    }
  });

  testWidgets(
    'chapter navigation persists previous next and answer-card jumps',
    (tester) async {
      final progress = _ChapterProgressStore(position: 0);
      final source = _DataSource(
        (_) async => _chapterCatalog([
          PracticeQuestionItem(_question('1')),
          PracticeQuestionItem(_question('2')),
          PracticeQuestionItem(_question('3')),
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PracticePage(
            request: _chapterRequest(),
            dataSource: source,
            chapterProgressStore: progress,
          ),
        ),
      );
      await tester.pumpAndSettle();
      progress.savedPositions.clear();

      await tester.tap(find.byKey(const ValueKey('practice-next')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('practice-previous')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('practice-answer-card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('practice-answer-cell-2')));
      await tester.pumpAndSettle();

      expect(progress.savedPositions.map((value) => value.position), [1, 0, 2]);
      expect(_questionStem('题目 3'), findsOneWidget);
    },
  );

  testWidgets('fast practice restores the selected leaf position', (
    tester,
  ) async {
    final progress = _FlatProgressStore(position: 1);
    final source = _DataSource(
      (_) async => _catalog([
        PracticeQuestionItem(_question('1')),
        PracticeQuestionItem(_question('2')),
        PracticeQuestionItem(_question('3')),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: _fastRequest,
          dataSource: source,
          flatProgressStore: progress,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_questionStem('题目 2'), findsOneWidget);
    expect(progress.loadedShelfIds, [111]);
    expect(progress.savedPositions, isEmpty);
  });

  testWidgets('fast practice clamps a stale position to the final item', (
    tester,
  ) async {
    final progress = _FlatProgressStore(position: 99);
    final source = _DataSource(
      (_) async => _catalog([
        PracticeQuestionItem(_question('1')),
        PracticeQuestionItem(_question('2')),
        PracticeQuestionItem(_question('3')),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: _fastRequest,
          dataSource: source,
          flatProgressStore: progress,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_questionStem('题目 3'), findsOneWidget);
  });

  testWidgets('fast navigation persists previous next and answer-card jumps', (
    tester,
  ) async {
    final progress = _FlatProgressStore(position: 0);
    final source = _DataSource(
      (_) async => _catalog([
        PracticeQuestionItem(_question('1')),
        PracticeQuestionItem(_question('2')),
        PracticeQuestionItem(_question('3')),
      ]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: _fastRequest,
          dataSource: source,
          flatProgressStore: progress,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-next')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('practice-previous')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('practice-answer-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('practice-answer-cell-2')));
    await tester.pumpAndSettle();

    expect(progress.savedPositions, [
      (shelfId: 111, position: 1),
      (shelfId: 111, position: 0),
      (shelfId: 111, position: 2),
    ]);
    expect(_questionStem('题目 3'), findsOneWidget);
  });

  testWidgets('ordinary and chapter requests never touch flat progress', (
    tester,
  ) async {
    for (final request in <PracticeRequest>[_request, _chapterRequest()]) {
      final progress = _FlatProgressStore(position: 1);
      final source = _DataSource(
        (_) async => request is ChapterPracticeRequest
            ? _chapterCatalog([
                PracticeQuestionItem(_question('1')),
                PracticeQuestionItem(_question('2')),
              ])
            : _catalog([
                PracticeQuestionItem(_question('1')),
                PracticeQuestionItem(_question('2')),
              ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PracticePage(
            key: ValueKey(request.runtimeType),
            request: request,
            dataSource: source,
            flatProgressStore: progress,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('practice-next')));
      await tester.pump();

      expect(progress.loadedShelfIds, isEmpty, reason: '$request');
      expect(progress.savedPositions, isEmpty, reason: '$request');
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    }
  });

  testWidgets('chapter end automatically enters an unlocked next chapter', (
    tester,
  ) async {
    final progress = _ChapterProgressStore(position: 0);
    final source = _DataSource((request) async {
      final chapterRequest = request as ChapterPracticeRequest;
      if (chapterRequest.entryMode == ChapterPracticeEntryMode.automatic) {
        return _chapterCatalog(
          [PracticeQuestionItem(_question('2'))],
          catalogIndex: 2,
          chapterIndex: 0,
          title: '下一章节',
        );
      }
      return _chapterCatalog(
        [PracticeQuestionItem(_question('1'))],
        nextChapter: const PracticeChapterTarget(
          catalogIndex: 2,
          chapterIndex: 0,
          title: '下一章节',
          unlocked: true,
        ),
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: _chapterRequest(),
          dataSource: source,
          chapterProgressStore: progress,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('practice-next')));
    await tester.pumpAndSettle();

    expect(_questionStem('题目 2'), findsOneWidget);
    expect(find.text('已学完，自动进入下一章节'), findsOneWidget);
    expect(source.loadedRequests, hasLength(2));
    final nextRequest = source.loadedRequests.last as ChapterPracticeRequest;
    expect(nextRequest.catalogIndex, 2);
    expect(nextRequest.chapterIndex, 0);
    expect(nextRequest.entryMode, ChapterPracticeEntryMode.automatic);
    expect(progress.savedPositions.last.position, 0);
  });

  testWidgets('chapter end gates a locked next group without leaving', (
    tester,
  ) async {
    final source = _DataSource(
      (_) async => _chapterCatalog(
        [PracticeQuestionItem(_question('1'))],
        nextChapter: const PracticeChapterTarget(
          catalogIndex: 2,
          chapterIndex: 0,
          title: '锁定章节',
          unlocked: false,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(request: _chapterRequest(), dataSource: source),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('practice-next')));
    await tester.pumpAndSettle();

    expect(find.text('章节练习需解锁，请开通会员后继续'), findsOneWidget);
    expect(_questionStem('题目 1'), findsOneWidget);
    expect(find.byType(PracticeResultPage), findsNothing);
    expect(source.loadedRequests, hasLength(1));
  });

  testWidgets('completed final chapter offers redo and resets after success', (
    tester,
  ) async {
    final source = _DataSource((request) async {
      final chapterRequest = request as ChapterPracticeRequest;
      final question = chapterRequest.entryMode == ChapterPracticeEntryMode.redo
          ? _question('1')
          : _question('1', choose: 'A', isRight: true);
      return _chapterCatalog([PracticeQuestionItem(question)]);
    });
    final progress = _ChapterProgressStore(position: 0);
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: _chapterRequest(),
          dataSource: source,
          chapterProgressStore: progress,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-next')));
    await tester.pumpAndSettle();

    expect(find.text('本章已全部学完'), findsOneWidget);
    expect(find.text('重练本章'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.byType(PracticeResultPage), findsNothing);

    await tester.tap(find.text('重练本章'));
    await tester.pumpAndSettle();

    final redo = source.loadedRequests.last as ChapterPracticeRequest;
    expect(redo.entryMode, ChapterPracticeEntryMode.redo);
    expect(_questionStem('题目 1'), findsOneWidget);
    expect(find.text('正确答案：A'), findsNothing);
    expect(progress.savedPositions.last.position, 0);
  });

  testWidgets('failed final chapter redo preserves the current session', (
    tester,
  ) async {
    final source = _DataSource((request) async {
      final chapterRequest = request as ChapterPracticeRequest;
      if (chapterRequest.entryMode == ChapterPracticeEntryMode.redo) {
        throw StateError('delete offline');
      }
      return _chapterCatalog([
        PracticeQuestionItem(_question('1', choose: 'A', isRight: true)),
      ]);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(request: _chapterRequest(), dataSource: source),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('practice-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重练本章'));
    await tester.pumpAndSettle();

    expect(_questionStem('题目 1'), findsOneWidget);
    expect(find.text('正确答案：A'), findsOneWidget);
    expect(find.text('重练失败，请稍后重试'), findsOneWidget);
    expect(find.byKey(const ValueKey('practice-error')), findsNothing);
  });

  testWidgets('incomplete final chapter keeps the existing result flow', (
    tester,
  ) async {
    final source = _DataSource(
      (_) async => _chapterCatalog([
        PracticeQuestionItem(_question('1')),
        PracticeQuestionItem(_question('2', choose: 'A', isRight: true)),
      ]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: _chapterRequest(),
          dataSource: source,
          chapterProgressStore: _ChapterProgressStore(position: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_questionStem('题目 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('practice-next')));
    await tester.pumpAndSettle();

    expect(find.byType(PracticeResultPage), findsOneWidget);
    expect(find.text('练习结果'), findsOneWidget);
  });

  testWidgets(
    'daily practice restores answers and resumes at the first unanswered item',
    (tester) async {
      final progress = _DailyProgressStore(
        progress: _dailyProgress(
          questionOrder: const [101, 102, 103],
          answers: const {
            101: DailySkillAnswer(
              questionId: 101,
              pick: 1,
              isRight: true,
              timestamp: 10,
            ),
            103: DailySkillAnswer(
              questionId: 103,
              pick: 2,
              isRight: false,
              timestamp: 20,
            ),
          },
        ),
      );
      final source = _DataSource(
        (_) async => _catalog([
          PracticeQuestionItem(_question('101')),
          PracticeQuestionItem(_question('102')),
          PracticeQuestionItem(_question('103')),
        ]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PracticePage(
            request: _dailyRequest,
            dataSource: source,
            dailySkillProgressStore: progress,
            dailySkillReportLauncher: (_, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_questionStem('题目 102'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const ValueKey('practice-right-count')),
                matching: find.byType(Text),
              ),
            )
            .data,
        '1',
      );
      expect(_bottomStatText(tester, 'practice-wrong-count'), '1');
      expect(source.saved, isEmpty);
      expect(progress.loadCalls, 1);
      expect(progress.persistedOrders, [
        [101, 102, 103],
      ]);
    },
  );

  testWidgets('fully answered daily practice resumes on the final item', (
    tester,
  ) async {
    final progress = _DailyProgressStore(
      progress: _dailyProgress(
        questionOrder: const [101, 102],
        answers: const {
          101: DailySkillAnswer(
            questionId: 101,
            pick: 1,
            isRight: true,
            timestamp: 10,
          ),
          102: DailySkillAnswer(
            questionId: 102,
            pick: 2,
            isRight: false,
            timestamp: 20,
          ),
        },
      ),
    );
    final launches = <DailySkillPracticeRequest>[];
    final source = _DataSource(
      (_) async => _catalog([
        PracticeQuestionItem(_question('101')),
        PracticeQuestionItem(_question('102')),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: _dailyRequest,
          dataSource: source,
          dailySkillProgressStore: progress,
          dailySkillReportLauncher: (_, request) async => launches.add(request),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_questionStem('题目 102'), findsOneWidget);
    expect(find.text('正确答案：A'), findsOneWidget);
    expect(source.saved, isEmpty);

    await tester.tap(find.byKey(const ValueKey('practice-next')));
    await tester.pumpAndSettle();

    expect(progress.finishedValues, [true]);
    expect(launches, [_dailyRequest]);
    expect(find.byType(PracticeResultPage), findsNothing);
  });

  testWidgets('daily submission saves both local and remote answer records', (
    tester,
  ) async {
    final progress = _DailyProgressStore(progress: _dailyProgress());
    final source = _DataSource(
      (_) async => _catalog([PracticeQuestionItem(_question('101'))]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: _dailyRequest,
          dataSource: source,
          dailySkillProgressStore: progress,
          dailySkillReportLauncher: (_, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pumpAndSettle();

    expect(source.saved.single.question.id, '101');
    expect(source.saved.single.answer.choose, 'A');
    expect(progress.records.single.questionId, 101);
    expect(progress.records.single.choose, 'A');
    expect(progress.records.single.isRight, isTrue);
    expect(progress.records.single.currentIndex, 0);
    expect(progress.records.single.questionOrder, [101]);
  });

  testWidgets('daily local save failure keeps the answer and reports it', (
    tester,
  ) async {
    final progress = _DailyProgressStore(
      progress: _dailyProgress(),
      failRecord: true,
    );
    final source = _DataSource(
      (_) async => _catalog([PracticeQuestionItem(_question('101'))]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: _dailyRequest,
          dataSource: source,
          dailySkillProgressStore: progress,
          dailySkillReportLauncher: (_, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pumpAndSettle();

    expect(find.text('正确答案：A'), findsOneWidget);
    expect(find.text('今日进度保存失败，请稍后重试'), findsOneWidget);
    expect(source.saved, hasLength(1));
  });

  testWidgets('daily completion waits for the pending local answer write', (
    tester,
  ) async {
    final pendingRecord = Completer<void>();
    final progress = _DailyProgressStore(
      progress: _dailyProgress(),
      recordResult: pendingRecord,
    );
    final launches = <DailySkillPracticeRequest>[];
    final source = _DataSource(
      (_) async => _catalog([PracticeQuestionItem(_question('101'))]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticePage(
          request: _dailyRequest,
          dataSource: source,
          dailySkillProgressStore: progress,
          dailySkillReportLauncher: (_, request) async => launches.add(request),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-option-A')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('practice-next')));
    await tester.pump();

    expect(progress.records, hasLength(1));
    expect(progress.finishedValues, isEmpty);
    expect(launches, isEmpty);

    pendingRecord.complete();
    await tester.pumpAndSettle();

    expect(progress.finishedValues, [true]);
    expect(launches, [_dailyRequest]);
  });

  testWidgets(
    'daily back opens one report without marking an incomplete session',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final progress = _DailyProgressStore(progress: _dailyProgress());
      final pendingReport = Completer<void>();
      final launches = <DailySkillPracticeRequest>[];
      final source = _DataSource(
        (_) async => _catalog([
          PracticeQuestionItem(_question('101')),
          PracticeQuestionItem(_question('102')),
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
      );
      unawaited(
        navigatorKey.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => PracticePage(
              request: _dailyRequest,
              dataSource: source,
              dailySkillProgressStore: progress,
              dailySkillReportLauncher: (_, request) {
                launches.add(request);
                return pendingReport.future;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await navigatorKey.currentState!.maybePop();
      await navigatorKey.currentState!.maybePop();
      await tester.pump();

      expect(launches, [_dailyRequest]);
      expect(progress.finishedValues, isEmpty);
      expect(find.byType(PracticePage), findsOneWidget);
      expect(find.byType(PracticeResultPage), findsNothing);

      pendingReport.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('non-daily requests never touch daily progress', (tester) async {
    for (final request in <PracticeRequest>[
      _request,
      _chapterRequest(),
      _fastRequest,
    ]) {
      final progress = _DailyProgressStore(progress: _dailyProgress());
      final source = _DataSource(
        (_) async => request is ChapterPracticeRequest
            ? _chapterCatalog([PracticeQuestionItem(_question('101'))])
            : _catalog([PracticeQuestionItem(_question('101'))]),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PracticePage(
            key: ValueKey('daily-isolation-${request.runtimeType}'),
            request: request,
            dataSource: source,
            dailySkillProgressStore: progress,
            dailySkillReportLauncher: (_, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('practice-option-A')));
      await tester.pumpAndSettle();

      expect(progress.totalCalls, 0, reason: '$request');
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    }
  });
}

Finder _questionStem(String title) {
  return find.byWidgetPredicate((widget) {
    if (widget.key != const ValueKey('practice-question-stem')) return false;
    return switch (widget) {
      Text(:final data, :final textSpan) =>
        (data ?? textSpan?.toPlainText() ?? '').trim().endsWith(title),
      RichText(:final text) => text.toPlainText().trim().endsWith(title),
      _ => false,
    };
  });
}

const _request = SkillPracticeRequest(skillId: 'skill-1');

const _dailyModule = HomeModule(id: 42, name: '每日一招', page: '每日一招', tag: '');

const _dailyRequest = DailySkillPracticeRequest(
  module: _dailyModule,
  skillId: '11',
  shelfId: 111,
);

const _fastRequest = FastPracticeRequest(
  module: HomeModule(id: 42, name: '速成300题', page: '速成300题', tag: ''),
  shelfId: 111,
  shelfName: '精选一',
  shelfType: '扁平化',
);

PracticeCatalog _catalog(
  List<PracticeItem> items, {
  bool fullAccess = true,
  int freeQuestionCount = 5,
  PracticeBehavior behavior = const PracticeBehavior.standard(),
}) {
  return PracticeCatalog(
    items: items,
    access: PracticeAccess(
      fullAccess: fullAccess,
      freeQuestionCount: freeQuestionCount,
    ),
    title: '技巧练题',
    behavior: behavior,
  );
}

const _chapterModule = HomeModule(
  id: 42,
  name: '章节练习',
  page: '章节练习',
  tag: '',
  type: '结构化',
);

ChapterPracticeRequest _chapterRequest({
  ChapterPracticeEntryMode mode = ChapterPracticeEntryMode.resume,
  int catalogIndex = 1,
  int chapterIndex = 2,
}) {
  return ChapterPracticeRequest(
    module: _chapterModule,
    catalogIndex: catalogIndex,
    chapterIndex: chapterIndex,
    entryMode: mode,
  );
}

PracticeCatalog _chapterCatalog(
  List<PracticeItem> items, {
  PracticeChapterTarget? nextChapter,
  int catalogIndex = 1,
  int chapterIndex = 2,
  String title = '当前章节',
}) {
  return PracticeCatalog(
    items: items,
    access: const PracticeAccess(fullAccess: true, freeQuestionCount: 0),
    title: title,
    chapterContext: PracticeChapterContext(
      module: _chapterModule,
      catalogIndex: catalogIndex,
      chapterIndex: chapterIndex,
      title: title,
      questionIds: items
          .whereType<PracticeQuestionItem>()
          .map((item) => item.question.id)
          .toList(growable: false),
      nextChapter: nextChapter,
    ),
  );
}

PracticeQuestion _question(
  String id, {
  String questionType = '单选题',
  String answer = 'A',
  Map<String, String> options = const {'A': '正确', 'B': '错误'},
  String analysis = '',
  String keyword = '',
  String choose = '',
  bool? isRight,
  String tags = '',
  bool isCollected = false,
}) {
  return PracticeQuestion.fromMap({
    'questionId': id,
    'title': '题目 $id',
    'questionType': questionType,
    'options': options,
    'answer': answer,
    'analysis': analysis,
    'keyword': keyword,
    'choose': choose,
    'isRight': ?isRight,
    'tags': tags,
    'isCollect': isCollected,
    'subject': '社工实务',
    'level': '初级社工',
  });
}

PracticeSkillItem _skill(String id) {
  return PracticeSkillItem(
    SkillMnemonic.fromMap({
      'skillId': id,
      'text': '技巧 $id',
      'keyword': '技巧',
      'note': '技巧解释 $id',
      'type': '大招',
    }),
  );
}

final class _SavedAnswer {
  const _SavedAnswer({required this.question, required this.answer});

  final PracticeQuestion question;
  final PracticeAnswer answer;
}

final class _CollectionChange {
  const _CollectionChange({required this.question, required this.collected});

  final PracticeQuestion question;
  final bool collected;
}

final class _DataSource
    implements
        PracticeDataSource,
        PracticeMaintenanceDataSource,
        PracticeSkillExplanationDataSource {
  _DataSource(
    this.loader, {
    this.failSave = false,
    this.collectionResult,
    this.wrongRemovalResult,
    this.correctResult,
    this.threshold = -1,
    this.thresholdReached = false,
    this.skillLoader,
  });

  final Future<PracticeCatalog> Function(PracticeRequest request) loader;
  final bool failSave;
  final Completer<void>? collectionResult;
  final Completer<void>? wrongRemovalResult;
  final Completer<bool>? correctResult;
  final int threshold;
  final bool thresholdReached;
  final Future<List<SkillMnemonic>> Function(String questionId)? skillLoader;
  bool failWrongRemoval = false;
  final List<_SavedAnswer> saved = [];
  final List<_CollectionChange> collectionChanges = [];
  final List<PracticeQuestion> removedWrong = [];
  final List<PracticeQuestion> recordedCorrect = [];
  final List<int> savedThresholds = [];
  final List<PracticeRequest> loadedRequests = [];
  final List<String> skillQuestionIds = [];
  int clearCalls = 0;
  final List<
    ({PracticeQuestion question, int serialNumber, int type, String content})
  >
  corrections = [];

  @override
  Future<PracticeCatalog> load(PracticeRequest request) {
    loadedRequests.add(request);
    return loader(request);
  }

  @override
  Future<void> saveAnswer(
    PracticeQuestion question,
    PracticeAnswer answer,
  ) async {
    saved.add(_SavedAnswer(question: question, answer: answer));
    if (failSave) throw StateError('offline');
  }

  @override
  Future<void> setCollected(PracticeQuestion question, bool collected) async {
    collectionChanges.add(
      _CollectionChange(question: question, collected: collected),
    );
    if (collectionResult != null) await collectionResult!.future;
  }

  @override
  Future<void> removeWrongQuestion(PracticeQuestion question) async {
    removedWrong.add(question);
    if (wrongRemovalResult != null && !wrongRemovalResult!.isCompleted) {
      await wrongRemovalResult!.future;
    }
    if (failWrongRemoval) throw StateError('offline');
  }

  @override
  Future<ErrorPracticeAvailability> probeErrorPractice() async {
    return const ErrorPracticeAvailability(requiresLogin: false, total: 1);
  }

  @override
  Future<int> loadWrongRemovalThreshold() async => threshold;

  @override
  Future<void> saveWrongRemovalThreshold(int value) async {
    savedThresholds.add(value);
  }

  @override
  Future<bool> recordWrongQuestionCorrect(PracticeQuestion question) async {
    recordedCorrect.add(question);
    return correctResult == null
        ? thresholdReached
        : await correctResult!.future;
  }

  @override
  Future<void> clearPracticeRecords() async {
    clearCalls += 1;
  }

  @override
  Future<void> submitCorrection({
    required PracticeQuestion question,
    required int serialNumber,
    required int type,
    required String content,
  }) async {
    corrections.add((
      question: question,
      serialNumber: serialNumber,
      type: type,
      content: content,
    ));
  }

  @override
  Future<List<SkillMnemonic>> loadSkillsForQuestion(String questionId) async {
    skillQuestionIds.add(questionId);
    return await skillLoader?.call(questionId) ?? const [];
  }
}

String? _bottomStatText(WidgetTester tester, String key) {
  return tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Text),
        ),
      )
      .data;
}

final class _SettingsStore implements PracticeSettingsStore {
  _SettingsStore(this.settings);

  PracticeSettings settings;
  final List<PracticeSettings> saved = [];

  @override
  Future<PracticeSettings> loadPracticeSettings() async => settings;

  @override
  Future<void> savePracticeSettings(PracticeSettings value) async {
    settings = value;
    saved.add(value);
  }
}

final class _ChapterProgressStore implements ChapterPracticeProgressStore {
  _ChapterProgressStore({required this.position});

  final int position;
  final List<({int moduleId, int catalogIndex, int chapterIndex})>
  loadedPositions = [];
  final List<({int moduleId, int catalogIndex, int chapterIndex, int position})>
  savedPositions = [];

  @override
  Future<int> loadExpandedCatalog({required int moduleId}) async => -1;

  @override
  Future<void> saveExpandedCatalog({
    required int moduleId,
    required int catalogIndex,
  }) async {}

  @override
  Future<int> loadQuestionPosition({
    required int moduleId,
    required int catalogIndex,
    required int chapterIndex,
  }) async {
    loadedPositions.add((
      moduleId: moduleId,
      catalogIndex: catalogIndex,
      chapterIndex: chapterIndex,
    ));
    return position;
  }

  @override
  Future<void> saveQuestionPosition({
    required int moduleId,
    required int catalogIndex,
    required int chapterIndex,
    required int position,
  }) async {
    savedPositions.add((
      moduleId: moduleId,
      catalogIndex: catalogIndex,
      chapterIndex: chapterIndex,
      position: position,
    ));
  }
}

final class _FlatProgressStore implements FlatPracticeProgressStore {
  _FlatProgressStore({required this.position});

  final int position;
  final List<int> loadedShelfIds = [];
  final List<({int shelfId, int position})> savedPositions = [];

  @override
  Future<int> loadFlatQuestionPosition({required int shelfId}) async {
    loadedShelfIds.add(shelfId);
    return position;
  }

  @override
  Future<void> saveFlatQuestionPosition({
    required int shelfId,
    required int position,
  }) async {
    savedPositions.add((shelfId: shelfId, position: position));
  }
}

final class _DailyProgressStore implements DailySkillProgressDataSource {
  _DailyProgressStore({
    this.progress,
    this.failRecord = false,
    this.recordResult,
  });

  final DailySkillProgress? progress;
  final bool failRecord;
  final Completer<void>? recordResult;
  int loadCalls = 0;
  int ensureCalls = 0;
  int persistOrderCalls = 0;
  int completedDaysCalls = 0;
  int clearCalls = 0;
  final List<List<int>> persistedOrders = [];
  final List<
    ({
      int questionId,
      String choose,
      bool isRight,
      int currentIndex,
      List<int> questionOrder,
    })
  >
  records = [];
  final List<bool> finishedValues = [];

  int get totalCalls =>
      loadCalls +
      ensureCalls +
      persistOrderCalls +
      records.length +
      finishedValues.length +
      completedDaysCalls +
      clearCalls;

  @override
  Future<DailySkillProgress?> loadToday() async {
    loadCalls += 1;
    return progress;
  }

  @override
  Future<DailySkillProgress> ensureToday({
    required String skillId,
    required int moduleId,
    required int shelfId,
  }) async {
    ensureCalls += 1;
    return progress ??
        DailySkillProgress.empty(
          date: '2026-07-16',
          skillId: skillId,
          moduleId: moduleId,
          shelfId: shelfId,
        );
  }

  @override
  Future<void> persistQuestionOrder(List<int> questionOrder) async {
    persistOrderCalls += 1;
    persistedOrders.add(List<int>.of(questionOrder));
  }

  @override
  Future<void> recordAnswer({
    required int questionId,
    required String choose,
    required bool isRight,
    required int currentIndex,
    required List<int> questionOrder,
  }) async {
    records.add((
      questionId: questionId,
      choose: choose,
      isRight: isRight,
      currentIndex: currentIndex,
      questionOrder: List<int>.of(questionOrder),
    ));
    if (recordResult != null) await recordResult!.future;
    if (failRecord) throw StateError('local write failed');
  }

  @override
  Future<void> markFinished(bool finished) async {
    finishedValues.add(finished);
  }

  @override
  Future<int> completedDaysCount() async {
    completedDaysCalls += 1;
    return 0;
  }

  @override
  Future<void> clear() async {
    clearCalls += 1;
  }
}

DailySkillProgress _dailyProgress({
  List<int> questionOrder = const [],
  Map<int, DailySkillAnswer> answers = const {},
  int currentIndex = 0,
  bool isFinished = false,
}) {
  return DailySkillProgress(
    date: '2026-07-16',
    skillId: '11',
    moduleId: 42,
    shelfId: 111,
    currentIndex: currentIndex,
    isFinished: isFinished,
    questionOrder: questionOrder,
    rightQuestionIds: [
      for (final entry in answers.entries)
        if (entry.value.isRight) entry.key,
    ],
    wrongQuestionIds: [
      for (final entry in answers.entries)
        if (!entry.value.isRight) entry.key,
    ],
    answers: answers,
  );
}
