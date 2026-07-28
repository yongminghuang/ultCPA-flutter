import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/exam/exam_models.dart';
import 'package:ultcpa_flutter/src/exam/exam_result_page.dart';
import 'package:ultcpa_flutter/src/exam/exam_review_page.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/practice/practice_models.dart';

void main() {
  testWidgets('renders the Android report metrics and grouped answer cards', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_result, uploadFailed: true));

    expect(find.byKey(const ValueKey('exam-result-page')), findsOneWidget);
    expect(find.text('真题一'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('00:07:09 答题时间'), findsOneWidget);
    expect(find.text('预测考试通过率'), findsOneWidget);
    expect(find.text('使用速记技巧，轻松考过'), findsOneWidget);
    expect(find.text('很低'), findsOneWidget);
    expect(find.text('去提升'), findsOneWidget);
    expect(find.text('正确 1'), findsWidgets);
    expect(find.text('错误 1'), findsWidgets);
    expect(find.text('未答题 1'), findsWidgets);
    expect(
      find.byKey(const ValueKey('exam-result-upload-warning')),
      findsOneWidget,
    );
    expect(find.text('答题记录上传失败，结果已保留'), findsOneWidget);
    expect(find.byKey(const ValueKey('exam-result-section-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('exam-result-answer-0')), findsOneWidget);
    final grid = tester.widgetList<GridView>(find.byType(GridView)).first;
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 6);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('exam-result-section-1')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('exam-result-answer-1')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('exam-result-section-2')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('exam-result-answer-2')), findsOneWidget);
  });

  testWidgets('opens all-question and wrong-question read-only reviews', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_result));

    await tester.tap(find.byKey(const ValueKey('exam-result-all')));
    await tester.pumpAndSettle();
    expect(find.byType(ExamReviewPage), findsOneWidget);
    expect(find.text('全部题目'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('exam-review-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('exam-result-wrong')));
    await tester.pumpAndSettle();
    expect(find.byType(ExamReviewPage), findsOneWidget);
    expect(find.text('错题回看'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('2. 题目 2'), findsOneWidget);
  });

  testWidgets('reports when the result contains no wrong questions', (
    tester,
  ) async {
    final question = _question('1', questionType: '单选题', answer: 'A');
    final result = ExamResult(
      request: _request,
      questions: [question],
      selections: const {'1': 'A'},
      elapsed: const Duration(minutes: 1),
    );
    await tester.pumpWidget(_app(result));

    await tester.tap(find.byKey(const ValueKey('exam-result-wrong')));
    await tester.pump();

    expect(find.byType(ExamReviewPage), findsNothing);
    expect(find.text('真棒，没有错题哟'), findsOneWidget);
  });

  testWidgets('default and injected improvement actions stay honest', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_result));
    await tester.tap(find.byKey(const ValueKey('exam-result-improve')));
    await tester.pump();
    expect(find.text('提升与会员功能仍在迁移中'), findsOneWidget);

    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      _app(
        _result,
        onImprove: (context) {
          calls += 1;
          return pending.future;
        },
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('exam-result-improve')));
    await tester.pump();
    expect(calls, 1);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('exam-result-improve')),
    );
    expect(button.onPressed, isNull);
    pending.complete();
    await tester.pump();
  });

  testWidgets('member tier hides only the prediction card', (tester) async {
    final memberResult = ExamResult(
      request: _request,
      questions: _questions,
      selections: const {'1': 'A', '2': 'AC'},
      elapsed: const Duration(minutes: 7, seconds: 9),
      hasMemberTier: true,
    );

    await tester.pumpWidget(_app(memberResult));

    expect(
      find.byKey(const ValueKey('exam-result-prediction-card')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('exam-result-improve')), findsNothing);
    expect(find.byKey(const ValueKey('exam-result-wrong')), findsOneWidget);
    expect(find.byKey(const ValueKey('exam-result-all')), findsOneWidget);
    expect(find.byKey(const ValueKey('exam-result-mnemonics')), findsOneWidget);
  });

  testWidgets('mnemonics is an independent guarded action', (tester) async {
    await tester.pumpWidget(_app(_result));
    await tester.tap(find.byKey(const ValueKey('exam-result-mnemonics')));
    await tester.pump();
    expect(find.text('技巧口诀入口仍在迁移中'), findsOneWidget);

    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      _app(
        _result,
        onMnemonics: (context) {
          calls += 1;
          return pending.future;
        },
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('exam-result-mnemonics')));
    await tester.pump();

    expect(calls, 1);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('exam-result-mnemonics')),
    );
    expect(button.onPressed, isNull);
    pending.complete();
    await tester.pump();
  });

  testWidgets('fits the result report on a 320 by 568 viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_result));

    expect(find.byKey(const ValueKey('exam-result-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('exam-result-all')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  ExamResult result, {
  bool uploadFailed = false,
  ExamImproveLauncher? onImprove,
  ExamImproveLauncher? onMnemonics,
}) {
  return MaterialApp(
    home: ExamResultPage(
      result: result,
      uploadFailed: uploadFailed,
      onImprove: onImprove,
      onMnemonics: onMnemonics,
    ),
  );
}

final _questions = [
  _question('1', questionType: '单选题', answer: 'A'),
  _question('2', questionType: '多选题', answer: 'AB'),
  _question('3', questionType: '判断题', answer: 'A'),
];

final _result = ExamResult(
  request: _request,
  questions: _questions,
  selections: const {'1': 'A', '2': 'AC'},
  elapsed: const Duration(minutes: 7, seconds: 9),
);

const _request = ExamRequest(module: _module, shelfId: 901, title: '真题一');

const _module = HomeModule(
  id: 51,
  name: '历年真题卷',
  page: '历年真题卷',
  tag: '',
  type: '嵌套化',
);

PracticeQuestion _question(
  String id, {
  required String questionType,
  required String answer,
}) {
  return PracticeQuestion.fromMap({
    'questionId': id,
    'title': '题目 $id',
    'questionType': questionType,
    'options': {'A': '选项 A', 'B': '选项 B', 'C': '选项 C'},
    'answer': answer,
    'analysis': '解析 $id',
  });
}
