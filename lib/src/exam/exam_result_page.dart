import 'dart:async';

import 'package:flutter/material.dart';

import '../practice/practice_models.dart';
import 'exam_models.dart';
import 'exam_review_page.dart';

typedef ExamImproveLauncher = FutureOr<void> Function(BuildContext context);

final class ExamResultPage extends StatefulWidget {
  const ExamResultPage({
    required this.result,
    this.uploadFailed = false,
    this.onImprove,
    this.onMnemonics,
    super.key,
  });

  final ExamResult result;
  final bool uploadFailed;
  final ExamImproveLauncher? onImprove;
  final ExamImproveLauncher? onMnemonics;

  @override
  State<ExamResultPage> createState() => _ExamResultPageState();
}

final class _ExamResultPageState extends State<ExamResultPage> {
  bool _improving = false;
  bool _openingMnemonics = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return Scaffold(
      key: const ValueKey('exam-result-page'),
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF263238),
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          key: const ValueKey('exam-result-back'),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: const Text(
          '考试报告',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Text(
              result.request.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF263238),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '${result.accuracyPercent}%',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: result.accuracyPercent >= 90
                    ? const Color(0xFF237DED)
                    : const Color(0xFFE5484D),
                fontSize: 42,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              '正确率',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF7A869A), fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              '${_formatDuration(result.elapsed)} 答题时间',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF52606D),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.uploadFailed) ...[
              const SizedBox(height: 14),
              const DecoratedBox(
                key: ValueKey('exam-result-upload-warning'),
                decoration: BoxDecoration(color: Color(0xFFFFF4E5)),
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    '答题记录上传失败，结果已保留',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF9A6700), fontSize: 13),
                  ),
                ),
              ),
            ],
            if (!result.hasMemberTier) ...[
              const SizedBox(height: 14),
              _PredictionCard(
                prediction: result.prediction,
                busy: _improving,
                onPressed: _improving ? null : _improve,
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _Metric(
                  label: '正确',
                  value: result.rightCount,
                  color: const Color(0xFF22A06B),
                ),
                _Metric(
                  label: '错误',
                  value: result.wrongCount,
                  color: const Color(0xFFD14343),
                ),
                _Metric(
                  label: '未答题',
                  value: result.unansweredCount,
                  color: const Color(0xFF7A869A),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('exam-result-wrong'),
                    onPressed: _openWrongReview,
                    child: const Text(
                      '错题解析',
                      maxLines: 1,
                      style: TextStyle(fontSize: 12),
                    ),
                    style: _outlinedStyle(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('exam-result-all'),
                    onPressed: _openAllReview,
                    child: const Text(
                      '查看全部解析',
                      maxLines: 1,
                      style: TextStyle(fontSize: 12),
                    ),
                    style: _outlinedStyle(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('exam-result-mnemonics'),
                    onPressed: _openingMnemonics ? null : _openMnemonics,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      backgroundColor: const Color(0xFF237DED),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text(
                      '技巧口诀',
                      maxLines: 1,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            for (var index = 0; index < result.sections.length; index += 1) ...[
              _ResultSection(
                key: ValueKey('exam-result-section-$index'),
                section: result.sections[index],
                result: result,
              ),
              if (index < result.sections.length - 1)
                const Divider(height: 30, color: Color(0xFFE3E8EF)),
            ],
          ],
        ),
      ),
    );
  }

  ButtonStyle _outlinedStyle() {
    return OutlinedButton.styleFrom(
      minimumSize: const Size(0, 46),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }

  void _openAllReview() {
    _openReview('全部题目', widget.result.allQuestions);
  }

  void _openWrongReview() {
    final wrong = widget.result.wrongQuestions;
    if (wrong.isEmpty) {
      _showMessage('真棒，没有错题哟');
      return;
    }
    _openReview('错题回看', wrong);
  }

  void _openReview(String title, List<PracticeQuestion> questions) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExamReviewPage(
          title: title,
          result: widget.result,
          questions: questions,
        ),
      ),
    );
  }

  Future<void> _improve() async {
    if (_improving) return;
    final callback = widget.onImprove;
    if (callback == null) {
      _showMessage('提升与会员功能仍在迁移中');
      return;
    }
    setState(() => _improving = true);
    try {
      await callback(context);
    } finally {
      if (mounted) setState(() => _improving = false);
    }
  }

  Future<void> _openMnemonics() async {
    if (_openingMnemonics) return;
    final callback = widget.onMnemonics;
    if (callback == null) {
      _showMessage('技巧口诀入口仍在迁移中');
      return;
    }
    setState(() => _openingMnemonics = true);
    try {
      await callback(context);
    } finally {
      if (mounted) setState(() => _openingMnemonics = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _PredictionCard extends StatelessWidget {
  const _PredictionCard({
    required this.prediction,
    required this.busy,
    required this.onPressed,
  });

  final ExamPrediction prediction;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final levelColor = switch (prediction.band) {
      ExamPredictionBand.steady => const Color(0xFF237DED),
      ExamPredictionBand.uncertain => const Color(0xFFF6830D),
      ExamPredictionBand.low => const Color(0xFFFC4C2A),
    };
    return Material(
      key: const ValueKey('exam-result-prediction-card'),
      color: const Color(0xFFFFF8EF),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFFFDFC2)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            '预测考试通过率',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF8A5A2B),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          prediction.levelText,
                          key: const ValueKey('exam-result-prediction-level'),
                          style: TextStyle(
                            color: levelColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '使用速记技巧，轻松考过',
                      style: TextStyle(color: Color(0xFF8A5A2B), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 88,
                child: FilledButton(
                  key: const ValueKey('exam-result-improve'),
                  onPressed: busy ? null : onPressed,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(88, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    backgroundColor: const Color(0xFFFF7A1C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    prediction.actionText,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 48,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFF5F7F9)),
        child: Center(
          child: Text(
            '$label $value',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

final class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.section,
    required this.result,
    super.key,
  });

  final ExamAnswerSection section;
  final ExamResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          section.title,
          style: const TextStyle(
            color: Color(0xFF263238),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          children: [
            Text(
              '正确 ${section.rightCount}',
              style: const TextStyle(color: Color(0xFF22A06B), fontSize: 12),
            ),
            Text(
              '错误 ${section.wrongCount}',
              style: const TextStyle(color: Color(0xFFD14343), fontSize: 12),
            ),
            Text(
              '未答题 ${section.unansweredCount}',
              style: const TextStyle(color: Color(0xFF7A869A), fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: section.indexes.length,
          itemBuilder: (context, localIndex) {
            final globalIndex = section.indexes[localIndex];
            final question = result.questions[globalIndex];
            final status = result.statusFor(question);
            final color = switch (status) {
              ExamQuestionStatus.right => const Color(0xFF22A06B),
              ExamQuestionStatus.wrong => const Color(0xFFD14343),
              ExamQuestionStatus.unanswered => const Color(0xFF7A869A),
            };
            return DecoratedBox(
              key: ValueKey('exam-result-answer-$globalIndex'),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                border: Border.all(color: color),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  '${globalIndex + 1}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

String _formatDuration(Duration duration) {
  final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final hours = seconds ~/ 3600;
  final minutes = seconds % 3600 ~/ 60;
  final remainder = seconds % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${remainder.toString().padLeft(2, '0')}';
}
