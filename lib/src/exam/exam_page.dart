import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../practice/practice_models.dart';
import 'exam_models.dart';
import 'exam_repository.dart';
import 'exam_session.dart';

typedef ExamResultLauncher =
    FutureOr<void> Function(
      BuildContext context, {
      required ExamResult result,
      required bool uploadFailed,
    });

final class ExamPage extends StatefulWidget {
  const ExamPage({
    required this.request,
    required this.dataSource,
    required this.resultLauncher,
    super.key,
  });

  final ExamRequest request;
  final ExamDataSource dataSource;
  final ExamResultLauncher resultLauncher;

  @override
  State<ExamPage> createState() => _ExamPageState();
}

final class _ExamPageState extends State<ExamPage> {
  ExamCatalog? _catalog;
  ExamSession? _session;
  Object? _error;
  bool _loading = true;
  bool _submitting = false;
  bool _resultLaunched = false;
  bool _allowPop = false;
  int _loadGeneration = 0;
  Timer? _timer;
  late Duration _remaining = widget.request.duration;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_confirmAbandon());
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF263238),
          elevation: 0,
          surfaceTintColor: Colors.white,
          leading: IconButton(
            key: const ValueKey('exam-back'),
            tooltip: '返回',
            onPressed: _confirmAbandon,
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          title: Text(
            widget.request.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          actions: [
            Center(
              child: Text(
                _formatDuration(_remaining),
                key: const ValueKey('exam-countdown'),
                style: const TextStyle(
                  color: Color(0xFFE5484D),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        key: ValueKey('exam-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      return Center(
        key: const ValueKey('exam-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('考试题目加载失败，请重试'),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('exam-retry'),
              onPressed: _retry,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    final session = _session;
    final catalog = _catalog;
    if (session == null || catalog == null || catalog.questions.isEmpty) {
      return const Center(key: ValueKey('exam-empty'), child: Text('暂无考试题目'));
    }
    final question = session.currentQuestion!;
    final current = session.currentIndex;
    final total = catalog.questions.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  key: const ValueKey('exam-progress'),
                  value: (current + 1) / total,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(3),
                  backgroundColor: const Color(0xFFE8EDF3),
                  color: const Color(0xFF237DED),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 48,
                child: Text(
                  '${current + 1} / $total',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Color(0xFF637083),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE9EDF2)),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('exam-question'),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _kindLabel(question.kind),
                  style: const TextStyle(
                    color: Color(0xFF237DED),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${current + 1}. ${question.displayTitle}',
                  style: const TextStyle(
                    color: Color(0xFF1F2933),
                    fontSize: 17,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                for (final option in question.options) ...[
                  _ExamOption(
                    option: option,
                    selected: session
                        .selectedFor(question)
                        .contains(option.key),
                    onTap: () => _select(option.key),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildBottomBar() {
    final session = _session;
    final catalog = _catalog;
    if (_loading ||
        _error != null ||
        session == null ||
        catalog == null ||
        catalog.questions.isEmpty) {
      return null;
    }
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE3E8EF))),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('exam-previous'),
                tooltip: '上一题',
                onPressed: session.currentIndex > 0 && !_submitting
                    ? _previous
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('exam-answer-card'),
                  onPressed: _submitting ? null : _showAnswerCard,
                  icon: const Icon(Icons.grid_view_rounded, size: 18),
                  label: const Text('答题卡'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('exam-next'),
                tooltip: '下一题',
                onPressed:
                    session.currentIndex < catalog.questions.length - 1 &&
                        !_submitting
                    ? _next
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 68,
                child: FilledButton(
                  key: const ValueKey('exam-submit'),
                  onPressed: _submitting || _resultLaunched
                      ? null
                      : _confirmHandIn,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(68, 44),
                    padding: EdgeInsets.zero,
                    backgroundColor: const Color(0xFFE5484D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('交卷'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final catalog = await widget.dataSource.load(widget.request);
      if (!mounted || generation != _loadGeneration) return;
      final session = ExamSession(catalog);
      setState(() {
        _catalog = catalog;
        _session = session;
        _loading = false;
        _error = null;
        _remaining = widget.request.duration;
      });
      if (catalog.questions.isNotEmpty) _startTimer(generation);
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _retry() {
    if (_loading) return;
    _timer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
      _catalog = null;
      _session = null;
      _remaining = widget.request.duration;
    });
    unawaited(_load());
  }

  void _startTimer(int generation) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || generation != _loadGeneration) {
        timer.cancel();
        return;
      }
      if (_remaining <= const Duration(seconds: 1)) {
        timer.cancel();
        setState(() => _remaining = Duration.zero);
        unawaited(_handIn());
        return;
      }
      setState(() => _remaining -= const Duration(seconds: 1));
    });
  }

  void _select(String choice) {
    final session = _session;
    if (session == null || _submitting) return;
    if (session.select(choice)) setState(() {});
  }

  void _previous() {
    if (_session?.movePrevious() ?? false) setState(() {});
  }

  void _next() {
    if (_session?.moveNext() ?? false) setState(() {});
  }

  Future<void> _showAnswerCard() async {
    final session = _session;
    final catalog = _catalog;
    if (session == null || catalog == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final height = math.min(
          420.0,
          MediaQuery.sizeOf(sheetContext).height * 0.65,
        );
        return SafeArea(
          child: SizedBox(
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    '答题卡',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                    itemCount: catalog.questions.length,
                    itemBuilder: (context, index) {
                      final question = catalog.questions[index];
                      final answered = session.selectedFor(question).isNotEmpty;
                      final current = index == session.currentIndex;
                      return InkWell(
                        key: ValueKey('exam-answer-$index'),
                        onTap: () {
                          if (session.jumpTo(index)) setState(() {});
                          Navigator.of(sheetContext).pop();
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: answered
                                ? const Color(0xFFE8F1FF)
                                : const Color(0xFFF3F5F7),
                            border: Border.all(
                              color: current
                                  ? const Color(0xFF237DED)
                                  : const Color(0xFFD8DEE7),
                              width: current ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: answered
                                    ? const Color(0xFF237DED)
                                    : const Color(0xFF637083),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmHandIn() async {
    if (_submitting || _resultLaunched) return;
    final unanswered = _session?.unansweredCount ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认交卷'),
        content: Text(
          unanswered > 0 ? '仍有 $unanswered 道题未作答，确认交卷吗？' : '已完成全部题目，确认交卷吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('exam-confirm-submit'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认交卷'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _handIn();
  }

  Future<void> _handIn() async {
    final session = _session;
    if (session == null || _submitting || _resultLaunched) return;
    final generation = _loadGeneration;
    _timer?.cancel();
    if (mounted) setState(() => _submitting = true);
    final result = session.finish(
      elapsed: widget.request.duration - _remaining,
    );
    var uploadFailed = false;
    try {
      await widget.dataSource.submit(result);
    } catch (_) {
      uploadFailed = true;
    }
    if (!mounted || generation != _loadGeneration) return;
    _resultLaunched = true;
    await widget.resultLauncher(
      context,
      result: result,
      uploadFailed: uploadFailed,
    );
  }

  Future<void> _confirmAbandon() async {
    if (_allowPop) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出考试'),
        content: const Text('考试进行中，确认退出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('继续作答'),
          ),
          FilledButton(
            key: const ValueKey('exam-confirm-abandon'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _timer?.cancel();
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }
}

final class _ExamOption extends StatelessWidget {
  const _ExamOption({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PracticeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        key: ValueKey('exam-option-${option.key}'),
        duration: const Duration(milliseconds: 120),
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F1FF) : const Color(0xFFF7F8FA),
          border: Border.all(
            color: selected ? const Color(0xFF237DED) : const Color(0xFFDDE2E8),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF237DED)
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF237DED)
                        : const Color(0xFF9AA5B1),
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    option.key,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF52606D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                option.text,
                style: const TextStyle(
                  color: Color(0xFF263238),
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ),
            if (selected)
              Icon(
                Icons.check,
                key: ValueKey('exam-option-selected-${option.key}'),
                size: 20,
                color: const Color(0xFF237DED),
              ),
          ],
        ),
      ),
    );
  }
}

String _kindLabel(PracticeQuestionKind kind) {
  return switch (kind) {
    PracticeQuestionKind.single => '单项选择题',
    PracticeQuestionKind.multiple => '多项选择题',
    PracticeQuestionKind.judgment => '判断题',
  };
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
