import 'dart:async';

import 'package:flutter/material.dart';

import '../practice/practice_models.dart';
import '../practice/practice_media_player.dart';
import '../practice/practice_repository.dart';
import '../skill_mnemonics/skill_mnemonics_models.dart';
import '../skill_mnemonics/skill_mnemonics_text.dart';
import 'exam_models.dart';

final class ExamReviewPage extends StatefulWidget {
  ExamReviewPage({
    required this.title,
    required this.result,
    required List<PracticeQuestion> questions,
    this.skillExplanationDataSource,
    super.key,
  }) : questions = List<PracticeQuestion>.unmodifiable(questions);

  final String title;
  final ExamResult result;
  final List<PracticeQuestion> questions;
  final PracticeSkillExplanationDataSource? skillExplanationDataSource;

  @override
  State<ExamReviewPage> createState() => _ExamReviewPageState();
}

final class _ExamReviewPageState extends State<ExamReviewPage> {
  int _currentIndex = 0;
  final Map<String, List<SkillMnemonic>> _questionSkills = {};
  final Set<String> _loadingQuestionIds = {};
  final Set<String> _failedQuestionIds = {};
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scheduleCurrentSkills();
  }

  @override
  void didUpdateWidget(covariant ExamReviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questions == widget.questions &&
        oldWidget.skillExplanationDataSource ==
            widget.skillExplanationDataSource) {
      return;
    }
    _loadGeneration += 1;
    _questionSkills.clear();
    _loadingQuestionIds.clear();
    _failedQuestionIds.clear();
    _currentIndex = 0;
    _scheduleCurrentSkills();
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    super.dispose();
  }

  void _scheduleCurrentSkills() {
    if (widget.skillExplanationDataSource == null || widget.questions.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.questions.isEmpty) return;
      unawaited(_loadSkills(widget.questions[_currentIndex]));
    });
  }

  Future<void> _loadSkills(PracticeQuestion question) async {
    final source = widget.skillExplanationDataSource;
    if (source == null ||
        _questionSkills.containsKey(question.id) ||
        !_loadingQuestionIds.add(question.id)) {
      return;
    }
    final generation = _loadGeneration;
    _failedQuestionIds.remove(question.id);
    if (mounted) setState(() {});
    try {
      final skills = await source.loadSkillsForQuestion(question.id);
      if (!mounted || generation != _loadGeneration) return;
      _questionSkills[question.id] = List<SkillMnemonic>.unmodifiable(skills);
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      _failedQuestionIds.add(question.id);
    } finally {
      if (generation == _loadGeneration) {
        _loadingQuestionIds.remove(question.id);
        if (mounted) setState(() {});
      }
    }
  }

  void _moveTo(int index) {
    setState(() => _currentIndex = index);
    _scheduleCurrentSkills();
  }

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
    final skills = _questionSkills[question.id] ?? const <SkillMnemonic>[];
    final skillsLoading = _loadingQuestionIds.contains(question.id);
    final skillsFailed = _failedQuestionIds.contains(question.id);
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
                if (skillsLoading || skillsFailed || skills.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _ExamReviewSkillPanel(
                    skills: skills,
                    loading: skillsLoading,
                    failed: skillsFailed,
                    onRetry: () => unawaited(_loadSkills(question)),
                  ),
                ],
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
                      ? () => _moveTo(_currentIndex - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
              ),
              Expanded(
                child: IconButton(
                  key: const ValueKey('exam-review-next'),
                  tooltip: '下一题',
                  onPressed: _currentIndex < widget.questions.length - 1
                      ? () => _moveTo(_currentIndex + 1)
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

final class _ExamReviewSkillPanel extends StatelessWidget {
  const _ExamReviewSkillPanel({
    required this.skills,
    required this.loading,
    required this.failed,
    required this.onRetry,
  });

  final List<SkillMnemonic> skills;
  final bool loading;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (skills.isNotEmpty) {
      return Column(
        key: const ValueKey('exam-review-inline-skills'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ExamReviewSectionTitle('速记技巧'),
          const SizedBox(height: 8),
          for (var index = 0; index < skills.length; index += 1)
            _ExamReviewSkillRow(skill: skills[index], index: index),
        ],
      );
    }
    if (loading) {
      return const Padding(
        key: ValueKey('exam-review-inline-skills-loading'),
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('正在加载技巧...'),
          ],
        ),
      );
    }
    return Padding(
      key: const ValueKey('exam-review-inline-skills-error'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          const Text('技巧加载失败', style: TextStyle(color: Color(0xFF637083))),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('重新加载')),
        ],
      ),
    );
  }
}

final class _ExamReviewSectionTitle extends StatelessWidget {
  const _ExamReviewSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 18, color: const Color(0xFF237DED)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF263238),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

final class _ExamReviewSkillRow extends StatelessWidget {
  const _ExamReviewSkillRow({required this.skill, required this.index});

  final SkillMnemonic skill;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (skill.voiceUrl != null) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.volume_up_rounded,
                    size: 22,
                    color: Color(0xFF237DED),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: SkillMnemonicHighlightedText(
                  text: skill.displayText,
                  terms: skill.keywordTerms,
                  style: const TextStyle(
                    color: Color(0xFF263238),
                    fontSize: 17,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          if (skill.voiceUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: PracticeMediaPlayer(
                key: ValueKey('exam-review-skill-voice-$index'),
                rawUrl: skill.voiceUrl,
                kind: PracticeMediaKind.audio,
              ),
            ),
          if (skill.note.trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              color: const Color(0xFFF4F6F8),
              child: SkillMnemonicHighlightedText(
                text: skill.note,
                terms: skill.keywordTerms,
                style: const TextStyle(
                  color: Color(0xFF52606D),
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ),
          if (skill.videoUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: PracticeMediaPlayer(
                  key: ValueKey('exam-review-skill-video-$index'),
                  rawUrl: skill.videoUrl,
                  coverUrl: skill.coverUrl,
                  kind: PracticeMediaKind.video,
                ),
              ),
            ),
        ],
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
