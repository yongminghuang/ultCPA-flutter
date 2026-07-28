import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/practice/practice_models.dart';
import 'package:ultcpa_flutter/src/practice/practice_result_page.dart';
import 'package:ultcpa_flutter/src/practice/practice_session.dart';

void main() {
  testWidgets('shows totals and returns without mutating the session', (
    tester,
  ) async {
    final session = _answeredSession();
    await tester.pumpWidget(_ResultHarness(session: session));

    await tester.tap(find.byKey(const ValueKey('open-result')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('practice-result-page')), findsOneWidget);
    expect(find.text('已答 2'), findsOneWidget);
    expect(find.text('答对 1'), findsOneWidget);
    expect(find.text('答错 1'), findsOneWidget);
    expect(find.text('未答 1'), findsOneWidget);
    expect(find.text('正确率 50%'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('practice-result-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-result')), findsOneWidget);
    expect(session.answeredCount, 2);
    expect(session.currentIndex, 1);
  });

  testWidgets('resets before returning for another attempt', (tester) async {
    final session = _answeredSession();
    await tester.pumpWidget(_ResultHarness(session: session));
    await tester.tap(find.byKey(const ValueKey('open-result')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-result-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('open-result')), findsOneWidget);
    expect(session.answeredCount, 0);
    expect(session.currentIndex, 0);
  });
}

final class _ResultHarness extends StatelessWidget {
  const _ResultHarness({required this.session});

  final PracticeSession session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey('open-result'),
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => PracticeResultPage(session: session),
                  ),
                );
              },
              child: const Text('打开结果'),
            ),
          ),
        ),
      ),
    );
  }
}

PracticeSession _answeredSession() {
  final questions = [_question('1'), _question('2'), _question('3')];
  final session = PracticeSession(
    PracticeCatalog(
      items: questions.map(PracticeQuestionItem.new).toList(growable: false),
      access: const PracticeAccess(fullAccess: true, freeQuestionCount: 0),
      title: '练题',
    ),
  );
  session.select('A');
  session.moveNext();
  session.select('B');
  return session;
}

PracticeQuestion _question(String id) {
  return PracticeQuestion.fromMap({
    'questionId': id,
    'title': '题目 $id',
    'questionType': '单选题',
    'options': {'A': '正确', 'B': '错误'},
    'answer': 'A',
  });
}
