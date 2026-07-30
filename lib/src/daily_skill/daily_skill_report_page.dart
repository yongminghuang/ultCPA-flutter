import 'dart:async';

import 'package:flutter/material.dart';

import '../practice/practice_models.dart';
import '../practice/practice_page.dart';
import '../practice/practice_repository.dart';
import 'daily_skill_models.dart';
import 'daily_skill_progress_store.dart';
import 'daily_skill_repository.dart';

typedef DailySkillAnalysisLauncher =
    Future<void> Function(BuildContext context, PracticeCatalog catalog);
typedef DailySkillReportImproveLauncher =
    Future<void> Function(BuildContext context);

final class DailySkillReportPage extends StatefulWidget {
  const DailySkillReportPage({
    required this.request,
    required this.dataSource,
    required this.progressStore,
    required this.improveLauncher,
    this.analysisLauncher,
    this.skillExplanationDataSource,
    super.key,
  });

  final DailySkillPracticeRequest request;
  final DailySkillDataSource dataSource;
  final DailySkillProgressDataSource progressStore;
  final DailySkillAnalysisLauncher? analysisLauncher;
  final DailySkillReportImproveLauncher improveLauncher;
  final PracticeSkillExplanationDataSource? skillExplanationDataSource;

  @override
  State<DailySkillReportPage> createState() => _DailySkillReportPageState();
}

final class _DailySkillReportPageState extends State<DailySkillReportPage> {
  DailySkillProgress? _progress;
  bool _loading = true;
  bool _missing = false;
  bool _openingAnalysis = false;
  bool _openingImprove = false;
  int _completedDays = 0;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _loadVersion += 1;
    super.dispose();
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    DailySkillProgress? progress;
    try {
      progress = await widget.progressStore.loadToday();
    } catch (_) {
      progress = null;
    }
    if (!mounted || version != _loadVersion) return;
    if (progress == null) {
      setState(() {
        _loading = false;
        _missing = true;
      });
      _showMessage('暂无练习记录');
      await Navigator.of(context).maybePop();
      return;
    }

    var completedDays = 0;
    try {
      completedDays = await widget.progressStore.completedDaysCount();
    } catch (_) {
      completedDays = 0;
    }
    if (!mounted || version != _loadVersion) return;
    setState(() {
      _progress = progress;
      _completedDays = completedDays < 0 ? 0 : completedDays;
      _loading = false;
      _missing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF263238),
        elevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text('本次练习报告'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        key: ValueKey('daily-skill-report-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_missing || _progress == null) {
      return const Center(
        key: ValueKey('daily-skill-report-empty'),
        child: Text('暂无练习记录'),
      );
    }

    final progress = _progress!;
    final total = progress.questionOrder.length;
    final undone = total > progress.doneCount ? total - progress.doneCount : 0;
    final accuracy = progress.doneCount == 0
        ? 0
        : progress.rightCount * 100 ~/ progress.doneCount;
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          if (_completedDays > 0)
            Text(
              '已打卡$_completedDays天',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF222222), fontSize: 14),
            ),
          SizedBox(height: _completedDays > 0 ? 18 : 4),
          _AccuracyCircle(accuracy: accuracy),
          const SizedBox(height: 16),
          _ReportActions(
            analysisEnabled: !_openingAnalysis,
            improveEnabled: !_openingImprove,
            onWrong: () => _openAnalysis(onlyWrong: true),
            onAll: () => _openAnalysis(onlyWrong: false),
            onImprove: _openImprove,
          ),
          const SizedBox(height: 22),
          const Text(
            '答题卡',
            style: TextStyle(
              color: Color(0xFF202124),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _ReportCounts(
            right: progress.rightCount,
            wrong: progress.wrongCount,
            undone: undone,
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisExtent: 52,
              crossAxisSpacing: 4,
              mainAxisSpacing: 8,
            ),
            itemCount: total,
            itemBuilder: (context, index) {
              final questionId = progress.questionOrder[index];
              final state = progress.rightQuestionIds.contains(questionId)
                  ? _AnswerCellState.right
                  : progress.wrongQuestionIds.contains(questionId)
                  ? _AnswerCellState.wrong
                  : _AnswerCellState.undone;
              return _AnswerCell(index: index, state: state);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openAnalysis({required bool onlyWrong}) async {
    if (_openingAnalysis || _progress == null) return;
    final progress = _progress!;
    if (onlyWrong && progress.wrongQuestionIds.isEmpty) {
      _showMessage('暂无错题');
      return;
    }
    setState(() => _openingAnalysis = true);
    try {
      final skillId = progress.skillId.trim().isEmpty
          ? widget.request.skillId.trim()
          : progress.skillId.trim();
      final questions = await widget.dataSource.loadQuestions(skillId);
      final catalog = buildDailySkillAnalysisCatalog(
        questions: questions,
        answers: progress.answers,
        wrongQuestionIds: progress.wrongQuestionIds,
        onlyWrong: onlyWrong,
      );
      if (catalog.items.isEmpty) {
        if (mounted) {
          _showMessage(onlyWrong ? '暂无错题' : '暂无解析数据');
        }
        return;
      }
      if (!mounted) return;
      final launcher = widget.analysisLauncher;
      if (launcher != null) {
        await launcher(context, catalog);
      } else {
        await _openDefaultAnalysis(catalog);
      }
    } catch (_) {
      if (mounted) _showMessage('解析加载失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _openingAnalysis = false);
    }
  }

  Future<void> _openDefaultAnalysis(PracticeCatalog catalog) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PracticePage(
          request: SkillPracticeRequest(
            skillId: widget.request.skillId,
            title: catalog.title,
          ),
          dataSource: _DailySkillAnalysisDataSource(catalog),
          skillExplanationDataSource: widget.skillExplanationDataSource,
        ),
      ),
    );
  }

  Future<void> _openImprove() async {
    if (_openingImprove) return;
    setState(() => _openingImprove = true);
    try {
      await widget.improveLauncher(context);
    } catch (_) {
      if (mounted) _showMessage('入口数据加载中，请稍后重试');
    } finally {
      if (mounted) setState(() => _openingImprove = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _AccuracyCircle extends StatelessWidget {
  const _AccuracyCircle({required this.accuracy});

  final int accuracy;

  @override
  Widget build(BuildContext context) {
    final successful = accuracy >= 90;
    final foreground = successful
        ? const Color(0xFF237DED)
        : const Color(0xFFE0321A);
    final background = successful
        ? const Color(0xFFEAF3FF)
        : const Color(0xFFFFEEE9);
    return Center(
      child: SizedBox(
        key: const ValueKey('daily-skill-report-accuracy'),
        width: 142,
        height: 142,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: background,
            border: Border.all(color: foreground, width: 4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$accuracy%',
                style: TextStyle(
                  color: foreground,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text('正确率', style: TextStyle(color: foreground, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ReportActions extends StatelessWidget {
  const _ReportActions({
    required this.analysisEnabled,
    required this.improveEnabled,
    required this.onWrong,
    required this.onAll,
    required this.onImprove,
  });

  final bool analysisEnabled;
  final bool improveEnabled;
  final VoidCallback onWrong;
  final VoidCallback onAll;
  final VoidCallback onImprove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const ValueKey('daily-skill-report-wrong'),
            onPressed: analysisEnabled ? onWrong : null,
            style: _secondaryActionStyle,
            child: const Text('错题解析'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            key: const ValueKey('daily-skill-report-all'),
            onPressed: analysisEnabled ? onAll : null,
            style: _secondaryActionStyle,
            child: const Text('查看全部解析'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            key: const ValueKey('daily-skill-report-improve'),
            onPressed: improveEnabled ? onImprove : null,
            style: _primaryActionStyle,
            child: const Text('去提升'),
          ),
        ),
      ],
    );
  }
}

final ButtonStyle _secondaryActionStyle = OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(49),
  padding: const EdgeInsets.symmetric(horizontal: 4),
  foregroundColor: const Color(0xFF237DED),
  backgroundColor: const Color(0xFFE4F0FF),
  side: const BorderSide(color: Color(0xFFC3DDFF)),
  textStyle: const TextStyle(fontSize: 13),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
);

final ButtonStyle _primaryActionStyle = FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(49),
  padding: const EdgeInsets.symmetric(horizontal: 4),
  backgroundColor: const Color(0xFF237DED),
  foregroundColor: Colors.white,
  textStyle: const TextStyle(fontSize: 13),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
);

final class _ReportCounts extends StatelessWidget {
  const _ReportCounts({
    required this.right,
    required this.wrong,
    required this.undone,
  });

  final int right;
  final int wrong;
  final int undone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CountLabel(color: const Color(0xFF00CB94), text: '正确 $right'),
        ),
        Expanded(
          child: _CountLabel(color: const Color(0xFFE0321A), text: '错误 $wrong'),
        ),
        Expanded(
          child: _CountLabel(
            color: const Color(0xFFEEEEEE),
            text: '未答题 $undone',
          ),
        ),
      ],
    );
  }
}

final class _CountLabel extends StatelessWidget {
  const _CountLabel({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            style: const TextStyle(color: Color(0xFF333333), fontSize: 13),
          ),
        ),
      ],
    );
  }
}

enum _AnswerCellState { right, wrong, undone }

final class _AnswerCell extends StatelessWidget {
  const _AnswerCell({required this.index, required this.state});

  final int index;
  final _AnswerCellState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _AnswerCellState.right => const Color(0xFF00CB94),
      _AnswerCellState.wrong => const Color(0xFFE0321A),
      _AnswerCellState.undone => const Color(0xFFEEEEEE),
    };
    final foreground = state == _AnswerCellState.undone
        ? const Color(0xFF5F6368)
        : Colors.white;
    return Center(
      child: Container(
        key: ValueKey('daily-skill-report-cell-$index'),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          '${index + 1}',
          style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

final class _DailySkillAnalysisDataSource implements PracticeDataSource {
  const _DailySkillAnalysisDataSource(this.catalog);

  final PracticeCatalog catalog;

  @override
  Future<PracticeCatalog> load(PracticeRequest request) async => catalog;

  @override
  Future<void> saveAnswer(
    PracticeQuestion question,
    PracticeAnswer answer,
  ) async {}

  @override
  Future<void> setCollected(PracticeQuestion question, bool collected) async {}

  @override
  Future<void> removeWrongQuestion(PracticeQuestion question) async {}

  @override
  Future<ErrorPracticeAvailability> probeErrorPractice() async {
    return const ErrorPracticeAvailability(requiresLogin: false);
  }

  @override
  Future<int> loadWrongRemovalThreshold() async => -1;

  @override
  Future<void> saveWrongRemovalThreshold(int threshold) async {}

  @override
  Future<bool> recordWrongQuestionCorrect(PracticeQuestion question) async {
    return false;
  }
}
