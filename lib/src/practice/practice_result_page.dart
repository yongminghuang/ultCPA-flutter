import 'package:flutter/material.dart';

import 'practice_session.dart';

final class PracticeResultPage extends StatelessWidget {
  const PracticeResultPage({required this.session, super.key});

  final PracticeSession session;

  @override
  Widget build(BuildContext context) {
    final accuracy = (session.accuracy * 100).round();
    return Scaffold(
      key: const ValueKey('practice-result-page'),
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF263238),
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text('练习结果'),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          children: [
            const Icon(
              Icons.task_alt_rounded,
              size: 64,
              color: Color(0xFF22A06B),
            ),
            const SizedBox(height: 18),
            Text(
              '正确率 $accuracy%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF263238),
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _ResultMetric(
                  label: '已答',
                  value: session.answeredCount,
                  color: const Color(0xFF237DED),
                ),
                _ResultMetric(
                  label: '答对',
                  value: session.rightCount,
                  color: const Color(0xFF22A06B),
                ),
                _ResultMetric(
                  label: '答错',
                  value: session.wrongCount,
                  color: const Color(0xFFD14343),
                ),
                _ResultMetric(
                  label: '未答',
                  value: session.unansweredCount,
                  color: const Color(0xFF7A869A),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('practice-result-back'),
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('返回'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('practice-result-retry'),
                onPressed: () {
                  session.reset();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('再练一次'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: const Color(0xFF237DED),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
