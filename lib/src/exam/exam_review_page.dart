import 'package:flutter/material.dart';

import '../practice/practice_models.dart';
import 'exam_models.dart';

final class ExamReviewPage extends StatefulWidget {
  ExamReviewPage({
    required this.title,
    required this.result,
    required List<PracticeQuestion> questions,
    super.key,
  }) : questions = List<PracticeQuestion>.unmodifiable(questions);

  final String title;
  final ExamResult result;
  final List<PracticeQuestion> questions;

  @override
  State<ExamReviewPage> createState() => _ExamReviewPageState();
}

final class _ExamReviewPageState extends State<ExamReviewPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final questions = widget.questions;
    return Scaffold(
      key: const ValueKey('exam-review-page'),
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF263238),
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          key: const ValueKey('exam-review-back'),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: questions.isEmpty ? _buildEmpty() : _buildQuestion(questions),
      bottomNavigationBar: questions.isEmpty ? null : _buildNavigation(),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      key: ValueKey('exam-review-empty'),
      child: Text('暂无题目'),
    );
  }

  Widget _buildQuestion(List<PracticeQuestion> questions) {
    final question = questions[_currentIndex];
    final originalIndex = widget.result.questions.indexOf(question);
    final selected = widget.result.selectionFor(question);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / questions.length,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(3),
                  backgroundColor: const Color(0xFFE8EDF3),
                  color: const Color(0xFF237DED),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_currentIndex + 1} / ${questions.length}',
                style: const TextStyle(
                  color: Color(0xFF637083),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE9EDF2)),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('exam-review-question'),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${originalIndex >= 0 ? originalIndex + 1 : _currentIndex + 1}. '
                  '${question.displayTitle}',
                  style: const TextStyle(
                    color: Color(0xFF1F2933),
                    fontSize: 17,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                for (final option in question.options) ...[
                  _ReviewOption(
                    option: option,
                    selected: selected.contains(option.key),
                    correct: question.normalizedAnswer.contains(option.key),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 10),
                Text(
                  '你的答案：${selected.isEmpty ? '未作答' : selected}',
                  style: const TextStyle(
                    color: Color(0xFF52606D),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '正确答案：${question.normalizedAnswer}',
                  style: const TextStyle(
                    color: Color(0xFF22A06B),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '题目解析',
                  style: TextStyle(
                    color: Color(0xFF263238),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  question.analysis.trim().isEmpty ? '暂无解析' : question.analysis,
                  style: const TextStyle(
                    color: Color(0xFF52606D),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigation() {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE3E8EF))),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: IconButton(
                  key: const ValueKey('exam-review-previous'),
                  tooltip: '上一题',
                  onPressed: _currentIndex > 0
                      ? () => setState(() => _currentIndex -= 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
              ),
              Expanded(
                child: IconButton(
                  key: const ValueKey('exam-review-next'),
                  tooltip: '下一题',
                  onPressed: _currentIndex < widget.questions.length - 1
                      ? () => setState(() => _currentIndex += 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ReviewOption extends StatelessWidget {
  const _ReviewOption({
    required this.option,
    required this.selected,
    required this.correct,
  });

  final PracticeOption option;
  final bool selected;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final borderColor = correct
        ? const Color(0xFF22A06B)
        : selected
        ? const Color(0xFFD14343)
        : const Color(0xFFDDE2E8);
    return Container(
      key: ValueKey('exam-review-option-${option.key}'),
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: correct
            ? const Color(0xFFE9F7F1)
            : selected
            ? const Color(0xFFFFEEEE)
            : const Color(0xFFF7F8FA),
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Text(
            option.key,
            style: TextStyle(color: borderColor, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              option.text,
              style: const TextStyle(color: Color(0xFF263238), fontSize: 15),
            ),
          ),
          if (selected)
            Text(
              '已选',
              key: ValueKey('exam-review-selected-${option.key}'),
              style: const TextStyle(
                color: Color(0xFFD14343),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (selected && correct) const SizedBox(width: 6),
          if (correct)
            Text(
              '正确',
              key: ValueKey('exam-review-correct-${option.key}'),
              style: const TextStyle(
                color: Color(0xFF22A06B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
