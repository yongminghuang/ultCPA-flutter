import 'dart:async';

import 'package:flutter/material.dart';

import '../chapter_practice/chapter_practice_progress_store.dart';
import '../daily_skill/daily_skill_progress_store.dart';
import '../skill_mnemonics/skill_mnemonics_models.dart';
import '../skill_mnemonics/skill_mnemonics_text.dart';
import 'flat_practice_progress_store.dart';
import 'practice_models.dart';
import 'practice_repository.dart';
import 'practice_result_page.dart';
import 'practice_session.dart';

typedef DailySkillReportLauncher =
    Future<void> Function(
      BuildContext context,
      DailySkillPracticeRequest request,
    );

Future<void> _closeDailySkillPractice(
  BuildContext context,
  DailySkillPracticeRequest request,
) async {
  Navigator.of(context).pop();
}

final class PracticePage extends StatefulWidget {
  const PracticePage({
    required this.request,
    required this.dataSource,
    this.chapterProgressStore = const DisabledChapterPracticeProgressStore(),
    this.flatProgressStore = const DisabledFlatPracticeProgressStore(),
    this.dailySkillProgressStore = const DisabledDailySkillProgressStore(),
    this.dailySkillReportLauncher = _closeDailySkillPractice,
    super.key,
  });

  final PracticeRequest request;
  final PracticeDataSource dataSource;
  final ChapterPracticeProgressStore chapterProgressStore;
  final FlatPracticeProgressStore flatProgressStore;
  final DailySkillProgressDataSource dailySkillProgressStore;
  final DailySkillReportLauncher dailySkillReportLauncher;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

final class _PracticePageState extends State<PracticePage> {
  PracticeCatalog? _catalog;
  PracticeSession? _session;
  Object? _error;
  bool _loading = true;
  int _loadVersion = 0;
  late PracticeRequest _activeRequest;
  final Set<String> _removingWrongIds = {};
  bool _openingDailySkillReport = false;
  Future<void> _pendingDailyProgressWrite = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _activeRequest = widget.request;
    unawaited(_load(initial: true));
  }

  @override
  void dispose() {
    _loadVersion += 1;
    super.dispose();
  }

  Future<void> _load({bool initial = false, PracticeRequest? request}) async {
    final version = ++_loadVersion;
    final targetRequest = request ?? _activeRequest;
    if (!initial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final catalog = await widget.dataSource.load(targetRequest);
      final session = await _createSession(catalog, targetRequest);
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _catalog = catalog;
        _session = session;
        _activeRequest = targetRequest;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<PracticeSession> _createSession(
    PracticeCatalog catalog,
    PracticeRequest request,
  ) async {
    final session = PracticeSession(catalog);
    if (session.items.isEmpty) {
      return session;
    }

    if (request is DailySkillPracticeRequest) {
      return _restoreDailySkillSession(session);
    }

    if (request is FastPracticeRequest) {
      var position = 0;
      try {
        position = await widget.flatProgressStore.loadFlatQuestionPosition(
          shelfId: request.shelfId,
        );
      } catch (_) {
        position = 0;
      }
      position = position.clamp(0, session.items.length - 1);
      session.jumpTo(position);
      return session;
    }

    if (request is! ChapterPracticeRequest || catalog.chapterContext == null) {
      return session;
    }

    var position = 0;
    final shouldResume =
        request.entryMode == ChapterPracticeEntryMode.resume &&
        session.answeredCount > 0 &&
        session.unansweredCount > 0;
    if (shouldResume) {
      try {
        position = await widget.chapterProgressStore.loadQuestionPosition(
          moduleId: request.module.id,
          catalogIndex: request.catalogIndex,
          chapterIndex: request.chapterIndex,
        );
      } catch (_) {
        position = 0;
      }
    }
    position = position.clamp(0, session.items.length - 1);
    session.jumpTo(position);
    if (!shouldResume) {
      await _saveChapterPosition(request, 0);
    }
    return session;
  }

  Future<PracticeSession> _restoreDailySkillSession(
    PracticeSession session,
  ) async {
    final questions = session.items
        .whereType<PracticeQuestionItem>()
        .map((item) => item.question)
        .toList(growable: false);
    final order = questions
        .map((question) => int.tryParse(question.id.trim()) ?? 0)
        .where((id) => id > 0)
        .toList(growable: false);
    DailySkillProgress? progress;
    try {
      progress = await widget.dailySkillProgressStore.loadToday();
    } catch (_) {
      progress = null;
    }
    if (progress != null) {
      for (final question in questions) {
        final questionId = int.tryParse(question.id.trim());
        final saved = questionId == null ? null : progress.answers[questionId];
        if (saved == null) continue;
        session.restoreAnswer(
          question,
          PracticeAnswer(choose: saved.choose, isRight: saved.isRight),
        );
      }
    }
    if (order.isNotEmpty) {
      try {
        await widget.dailySkillProgressStore.persistQuestionOrder(order);
      } catch (_) {
        // The loaded practice remains usable when a local checkpoint fails.
      }
    }
    if (progress == null || order.isEmpty) return session;
    final resumeOrderIndex = progress.resolveResumeIndex(order);
    final resumeQuestionId = order[resumeOrderIndex.clamp(0, order.length - 1)];
    final itemIndex = session.items.indexWhere(
      (item) =>
          item is PracticeQuestionItem &&
          int.tryParse(item.question.id.trim()) == resumeQuestionId,
    );
    if (itemIndex >= 0) session.jumpTo(itemIndex);
    return session;
  }

  Future<void> _saveChapterPosition(
    ChapterPracticeRequest request,
    int position,
  ) async {
    try {
      await widget.chapterProgressStore.saveQuestionPosition(
        moduleId: request.module.id,
        catalogIndex: request.catalogIndex,
        chapterIndex: request.chapterIndex,
        position: position,
      );
    } catch (_) {
      // A failed local checkpoint must not interrupt answering.
    }
  }

  Future<void> _saveFlatPosition(
    FastPracticeRequest request,
    int position,
  ) async {
    try {
      await widget.flatProgressStore.saveFlatQuestionPosition(
        shelfId: request.shelfId,
        position: position,
      );
    } catch (_) {
      // A failed local checkpoint must not interrupt answering.
    }
  }

  void _persistCurrentPosition() {
    final request = _activeRequest;
    final session = _session;
    if (session == null) return;
    switch (request) {
      case ChapterPracticeRequest():
        unawaited(_saveChapterPosition(request, session.currentIndex));
      case FastPracticeRequest():
        unawaited(_saveFlatPosition(request, session.currentIndex));
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _buildPage(context);
    if (_activeRequest is! DailySkillPracticeRequest) return page;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_openDailySkillReport());
      },
      child: page,
    );
  }

  Widget _buildPage(BuildContext context) {
    if (_loading) {
      return _PracticeShell(
        title: _catalog?.title ?? _activeRequest.title,
        body: const Center(
          key: ValueKey('practice-loading'),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return _PracticeShell(
        title: _activeRequest.title,
        body: Center(
          key: const ValueKey('practice-error'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: Color(0xFF7A869A),
                size: 42,
              ),
              const SizedBox(height: 12),
              const Text('加载失败'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('practice-retry'),
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    }

    final catalog = _catalog!;
    final session = _session!;
    if (session.items.isEmpty) {
      return _PracticeShell(
        title: catalog.title,
        body: Center(
          key: const ValueKey('practice-empty'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.inbox_outlined,
                color: Color(0xFF7A869A),
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(catalog.behavior.emptyMessage),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF263238),
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text(catalog.title),
        centerTitle: true,
        actions: [
          if (catalog.behavior.reviewKind == PracticeReviewKind.errors)
            IconButton(
              key: const ValueKey('practice-wrong-settings'),
              tooltip: '错题移除设置',
              onPressed: _showWrongRemovalSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          _PracticeProgress(
            position: session.currentIndex + 1,
            total: session.items.length,
            right: session.rightCount,
            wrong: session.wrongCount,
          ),
          const Divider(height: 1, color: Color(0xFFE8ECF0)),
          Expanded(child: _buildCurrentItem(session.currentItem!)),
        ],
      ),
      bottomNavigationBar: _PracticeNavigation(
        canGoPrevious: session.currentIndex > 0,
        isLast: session.currentIndex == session.items.length - 1,
        onPrevious: _previous,
        onAnswerCard: _showAnswerCard,
        onNext: _next,
      ),
    );
  }

  Widget _buildCurrentItem(PracticeItem item) {
    return switch (item) {
      PracticeSkillItem(:final skill) => _PracticeSkillView(skill: skill),
      PracticeQuestionItem(:final question) => _PracticeQuestionView(
        question: question,
        answer: _session!.answerFor(question),
        draft: _session!.draftFor(question),
        isCollected: _session!.isCollected(question),
        removingWrong: _removingWrongIds.contains(question.id),
        showWrongRemoval:
            _catalog!.behavior.reviewKind == PracticeReviewKind.errors,
        onOption: _selectOption,
        onConfirmMultiple: _confirmMultiple,
        onToggleCollection: () => _toggleCollection(question),
        onRemoveWrong: () => _removeWrongQuestion(question),
      ),
    };
  }

  void _selectOption(PracticeQuestion question, String choice) {
    final transition = question.kind == PracticeQuestionKind.multiple
        ? _session!.toggleMultiple(choice)
        : _session!.select(choice);
    _handleTransition(transition);
  }

  void _confirmMultiple() {
    _handleTransition(_session!.confirmMultiple());
  }

  void _handleTransition(PracticeTransition transition) {
    switch (transition) {
      case PracticeDraftChanged():
        setState(() {});
      case PracticeSubmitted(:final question, :final answer):
        setState(() {});
        if (_catalog!.behavior.persistAnswers) {
          unawaited(_saveAnswer(question, answer));
        }
        if (_activeRequest is DailySkillPracticeRequest) {
          _pendingDailyProgressWrite = _pendingDailyProgressWrite.then(
            (_) => _saveDailySkillAnswer(question, answer),
          );
          unawaited(_pendingDailyProgressWrite);
        }
        if (_catalog!.behavior.reviewKind == PracticeReviewKind.errors &&
            answer.isRight) {
          unawaited(_recordWrongQuestionCorrect(question));
        }
      case PracticeLocked():
        _showMessage('免费练题次数已用完，会员与支付功能仍在迁移中');
      case PracticeNoChange():
        break;
    }
  }

  Future<void> _saveAnswer(
    PracticeQuestion question,
    PracticeAnswer answer,
  ) async {
    try {
      await widget.dataSource.saveAnswer(question, answer);
    } catch (_) {
      if (mounted) _showMessage('答题记录同步失败，请稍后重试');
    }
  }

  Future<void> _saveDailySkillAnswer(
    PracticeQuestion question,
    PracticeAnswer answer,
  ) async {
    final questionId = int.tryParse(question.id.trim());
    try {
      if (questionId == null || questionId <= 0) {
        throw ArgumentError.value(question.id, 'question.id');
      }
      await widget.dailySkillProgressStore.recordAnswer(
        questionId: questionId,
        choose: answer.choose,
        isRight: answer.isRight,
        currentIndex: _session!.currentIndex,
        questionOrder: _dailyQuestionOrder(),
      );
    } catch (_) {
      if (mounted) _showMessage('今日进度保存失败，请稍后重试');
    }
  }

  List<int> _dailyQuestionOrder() {
    return _session!.items
        .whereType<PracticeQuestionItem>()
        .map((item) => int.tryParse(item.question.id.trim()) ?? 0)
        .where((id) => id > 0)
        .toList(growable: false);
  }

  void _toggleCollection(PracticeQuestion question) {
    final messenger = ScaffoldMessenger.of(context);
    final collected = !_session!.isCollected(question);
    _session!.setCollected(question, collected);
    final removeFromReview =
        !collected &&
        _catalog!.behavior.reviewKind == PracticeReviewKind.collections;
    if (removeFromReview) {
      _session!.removeQuestion(question.id);
    }
    unawaited(_syncCollection(question, collected, messenger));
    if (removeFromReview) {
      _renderAfterRemoval();
    } else {
      setState(() {});
    }
  }

  Future<void> _syncCollection(
    PracticeQuestion question,
    bool collected,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      await widget.dataSource.setCollected(question, collected);
      if (messenger.mounted) {
        _showMessengerMessage(messenger, collected ? '收藏成功' : '取消收藏');
      }
    } catch (_) {
      if (messenger.mounted) {
        _showMessengerMessage(messenger, '操作失败，请稍后重试');
      }
    }
  }

  Future<void> _removeWrongQuestion(PracticeQuestion question) async {
    if (!_removingWrongIds.add(question.id)) return;
    setState(() {});
    try {
      await widget.dataSource.removeWrongQuestion(question);
      if (!mounted) return;
      _removingWrongIds.remove(question.id);
      if (_session!.removeQuestion(question.id)) {
        _renderAfterRemoval();
        if (mounted) _showMessage('已移除');
      } else {
        setState(() {});
      }
    } catch (_) {
      if (!mounted) return;
      _removingWrongIds.remove(question.id);
      setState(() {});
      _showMessage('移除失败，请稍后重试');
    }
  }

  Future<void> _recordWrongQuestionCorrect(PracticeQuestion question) async {
    bool reachedThreshold;
    try {
      reachedThreshold = await widget.dataSource.recordWrongQuestionCorrect(
        question,
      );
    } catch (_) {
      return;
    }
    if (!mounted || !reachedThreshold) return;
    if (!_session!.removeQuestion(question.id)) return;
    unawaited(_removeWrongQuestionAfterThreshold(question));
    _renderAfterRemoval();
    if (mounted) _showMessage('已移除');
  }

  Future<void> _removeWrongQuestionAfterThreshold(
    PracticeQuestion question,
  ) async {
    try {
      await widget.dataSource.removeWrongQuestion(question);
    } catch (_) {
      // Android keeps an automatically removed item out of the local list.
    }
  }

  void _renderAfterRemoval() {
    if (_session!.items.isEmpty && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {});
  }

  Future<void> _showWrongRemovalSettings() async {
    int selected;
    try {
      selected = await widget.dataSource.loadWrongRemovalThreshold();
    } catch (_) {
      if (mounted) _showMessage('设置读取失败，请稍后重试');
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          const values = [1, 2, 3, 4, 5, 6, 7, -1];
          return FractionallySizedBox(
            key: const ValueKey('practice-wrong-settings-sheet'),
            heightFactor: 0.9,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '设置自动移除错题',
                      style: TextStyle(
                        color: Color(0xFF263238),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '请选择做对几次，自动移除错题',
                      style: TextStyle(color: Color(0xFF7A869A)),
                    ),
                    const SizedBox(height: 8),
                    for (final value in values)
                      RadioListTile<int>(
                        key: ValueKey('practice-wrong-threshold-$value'),
                        value: value,
                        groupValue: selected,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(_wrongRemovalThresholdLabel(value)),
                        onChanged: (next) {
                          if (next == null || next == selected) return;
                          setSheetState(() => selected = next);
                          unawaited(_saveWrongRemovalThreshold(next));
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveWrongRemovalThreshold(int threshold) async {
    try {
      await widget.dataSource.saveWrongRemovalThreshold(threshold);
    } catch (_) {
      if (mounted) _showMessage('设置保存失败，请稍后重试');
    }
  }

  void _previous() {
    if (_session!.movePrevious()) {
      setState(() {});
      _persistCurrentPosition();
    }
  }

  Future<void> _next() async {
    final catalog = _catalog!;
    final session = _session!;
    if (session.currentIndex == session.items.length - 1) {
      if (_activeRequest is DailySkillPracticeRequest) {
        await _openDailySkillReport();
        return;
      }
      if (catalog.chapterContext != null) {
        await _handleChapterEnd(catalog.chapterContext!, session);
        return;
      }
      if (!catalog.behavior.showResults) {
        _showMessage(catalog.behavior.lastItemMessage);
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => PracticeResultPage(session: session)),
      );
      if (mounted) setState(() {});
      return;
    }
    if (session.moveNext()) {
      setState(() {});
      _persistCurrentPosition();
    } else {
      _showMessage('免费练题次数已用完，会员与支付功能仍在迁移中');
    }
  }

  Future<void> _openDailySkillReport() async {
    final request = _activeRequest;
    if (request is! DailySkillPracticeRequest || _openingDailySkillReport) {
      return;
    }
    _openingDailySkillReport = true;
    await _pendingDailyProgressWrite;
    if (!mounted) return;
    final session = _session;
    final hasQuestions =
        session?.items.whereType<PracticeQuestionItem>().isNotEmpty == true;
    if (hasQuestions && session!.unansweredCount == 0) {
      try {
        await widget.dailySkillProgressStore.markFinished(true);
      } catch (_) {
        if (mounted) _showMessage('今日进度保存失败，请稍后重试');
      }
    }
    if (!mounted) return;
    try {
      await widget.dailySkillReportLauncher(context, request);
    } catch (_) {
      _openingDailySkillReport = false;
      if (mounted) _showMessage('报告加载失败，请稍后重试');
    }
  }

  Future<void> _handleChapterEnd(
    PracticeChapterContext chapterContext,
    PracticeSession session,
  ) async {
    final next = chapterContext.nextChapter;
    if (next != null) {
      if (!next.unlocked) {
        _showMessage('章节练习需解锁，会员与支付功能仍在迁移中');
        return;
      }
      final name = next.title.trim().isEmpty ? '下一章节' : next.title;
      await _switchChapter(
        ChapterPracticeRequest(
          module: chapterContext.module,
          catalogIndex: next.catalogIndex,
          chapterIndex: next.chapterIndex,
          entryMode: ChapterPracticeEntryMode.automatic,
        ),
        successMessage: '已学完，自动进入$name',
        failureMessage: '章节加载失败，请稍后重试',
      );
      return;
    }

    if (session.unansweredCount == 0) {
      final redo = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('本章已全部学完'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('重练本章'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
          ],
        ),
      );
      if (redo != true || !mounted) return;
      await _switchChapter(
        ChapterPracticeRequest(
          module: chapterContext.module,
          catalogIndex: chapterContext.catalogIndex,
          chapterIndex: chapterContext.chapterIndex,
          entryMode: ChapterPracticeEntryMode.redo,
        ),
        failureMessage: '重练失败，请稍后重试',
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => PracticeResultPage(session: session)),
    );
    if (mounted) setState(() {});
  }

  Future<bool> _switchChapter(
    ChapterPracticeRequest request, {
    String? successMessage,
    required String failureMessage,
  }) async {
    final version = ++_loadVersion;
    try {
      final catalog = await widget.dataSource.load(request);
      final session = await _createSession(catalog, request);
      if (!mounted || version != _loadVersion) return false;
      setState(() {
        _catalog = catalog;
        _session = session;
        _activeRequest = request;
        _error = null;
        _loading = false;
      });
      if (successMessage != null) _showMessage(successMessage);
      return true;
    } catch (_) {
      if (!mounted || version != _loadVersion) return false;
      _showMessage(failureMessage);
      return false;
    }
  }

  Future<void> _showAnswerCard() async {
    final moved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => _PracticeAnswerSheet(
        items: _session!.items,
        session: _session!,
        onSelect: (index) {
          final didMove = _session!.jumpTo(index);
          Navigator.of(sheetContext).pop(didMove);
        },
      ),
    );
    if (!mounted || moved == null) return;
    if (moved) {
      setState(() {});
      _persistCurrentPosition();
    } else {
      _showMessage('免费练题次数已用完，会员与支付功能仍在迁移中');
    }
  }

  void _showMessage(String message) {
    _showMessengerMessage(ScaffoldMessenger.of(context), message);
  }
}

void _showMessengerMessage(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

final class _PracticeShell extends StatelessWidget {
  const _PracticeShell({required this.title, required this.body});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF263238),
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text(title),
        centerTitle: true,
      ),
      body: body,
    );
  }
}

final class _PracticeProgress extends StatelessWidget {
  const _PracticeProgress({
    required this.position,
    required this.total,
    required this.right,
    required this.wrong,
  });

  final int position;
  final int total;
  final int right;
  final int wrong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$position / $total',
                style: const TextStyle(
                  color: Color(0xFF44546F),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '正确 $right',
                style: const TextStyle(color: Color(0xFF22A06B)),
              ),
              const SizedBox(width: 16),
              Text(
                '错误 $wrong',
                style: const TextStyle(color: Color(0xFFD14343)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: total == 0 ? 0 : position / total,
            minHeight: 3,
            backgroundColor: const Color(0xFFE8ECF0),
            color: const Color(0xFF237DED),
          ),
        ],
      ),
    );
  }
}

final class _PracticeSkillView extends StatelessWidget {
  const _PracticeSkillView({required this.skill});

  final SkillMnemonic skill;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('practice-skill'),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        const _SectionTitle(icon: Icons.lightbulb_rounded, text: '技巧口诀'),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFFFF6DE),
          child: SkillMnemonicHighlightedText(
            text: skill.displayText,
            terms: skill.keywordTerms,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF3E4C59),
              fontSize: 17,
              height: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 28),
        const _SectionTitle(icon: Icons.auto_awesome, text: '技巧解析'),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFF2F7F9),
          child: SkillMnemonicHighlightedText(
            text: skill.note,
            terms: skill.keywordTerms,
            style: const TextStyle(
              color: Color(0xFF44546F),
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

final class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFE6A23C)),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF263238),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

typedef _OptionCallback = void Function(PracticeQuestion question, String key);

final class _PracticeQuestionView extends StatelessWidget {
  const _PracticeQuestionView({
    required this.question,
    required this.answer,
    required this.draft,
    required this.isCollected,
    required this.removingWrong,
    required this.showWrongRemoval,
    required this.onOption,
    required this.onConfirmMultiple,
    required this.onToggleCollection,
    required this.onRemoveWrong,
  });

  final PracticeQuestion question;
  final PracticeAnswer? answer;
  final String draft;
  final bool isCollected;
  final bool removingWrong;
  final bool showWrongRemoval;
  final _OptionCallback onOption;
  final VoidCallback onConfirmMultiple;
  final VoidCallback onToggleCollection;
  final VoidCallback onRemoveWrong;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('practice-question'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FD),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _questionTypeLabel(question),
                style: const TextStyle(
                  color: Color(0xFF237DED),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              key: const ValueKey('practice-collection-toggle'),
              tooltip: isCollected ? '取消收藏' : '收藏',
              onPressed: onToggleCollection,
              icon: Icon(
                isCollected ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(
                  'practice-collection-${isCollected ? 'collected' : 'not-collected'}',
                ),
                color: isCollected
                    ? const Color(0xFFD14343)
                    : const Color(0xFF7A869A),
              ),
            ),
            if (showWrongRemoval)
              IconButton(
                key: const ValueKey('practice-remove-wrong'),
                tooltip: '移除错题',
                onPressed: removingWrong ? null : onRemoveWrong,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          question.displayTitle,
          style: const TextStyle(
            color: Color(0xFF263238),
            fontSize: 18,
            height: 1.55,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        for (final option in question.options) ...[
          _PracticeOptionRow(
            question: question,
            option: option,
            answer: answer,
            selectedInDraft: draft.contains(option.key),
            onTap: () => onOption(question, option.key),
          ),
          const SizedBox(height: 10),
        ],
        if (question.kind == PracticeQuestionKind.multiple && answer == null)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const ValueKey('practice-confirm'),
              onPressed: draft.isEmpty ? null : onConfirmMultiple,
              icon: const Icon(Icons.check_rounded),
              label: const Text('确定'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF237DED),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        if (answer != null) ...[
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE8ECF0)),
          const SizedBox(height: 8),
          Text(
            '正确答案：${question.normalizedAnswer}',
            style: const TextStyle(
              color: Color(0xFF22A06B),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (question.analysis.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              question.analysis,
              style: const TextStyle(
                color: Color(0xFF44546F),
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

final class _PracticeOptionRow extends StatelessWidget {
  const _PracticeOptionRow({
    required this.question,
    required this.option,
    required this.answer,
    required this.selectedInDraft,
    required this.onTap,
  });

  final PracticeQuestion question;
  final PracticeOption option;
  final PracticeAnswer? answer;
  final bool selectedInDraft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = _optionState();
    final colors = switch (state) {
      'correct' => (
        background: const Color(0xFFE8F6EF),
        border: const Color(0xFF22A06B),
        marker: const Color(0xFF22A06B),
      ),
      'wrong' => (
        background: const Color(0xFFFCEBEB),
        border: const Color(0xFFD14343),
        marker: const Color(0xFFD14343),
      ),
      'selected' => (
        background: const Color(0xFFEAF2FD),
        border: const Color(0xFF237DED),
        marker: const Color(0xFF237DED),
      ),
      _ => (
        background: Colors.white,
        border: const Color(0xFFD8DEE4),
        marker: const Color(0xFF7A869A),
      ),
    };
    return Material(
      color: colors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('practice-option-${option.key}'),
        onTap: answer == null ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  key: ValueKey('practice-option-state-${option.key}-$state'),
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.marker,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    option.key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.text,
                    style: const TextStyle(
                      color: Color(0xFF263238),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _optionState() {
    if (answer == null) return selectedInDraft ? 'selected' : 'idle';
    if (question.normalizedAnswer.contains(option.key)) return 'correct';
    if (answer!.choose.contains(option.key)) return 'wrong';
    return 'idle';
  }
}

final class _PracticeNavigation extends StatelessWidget {
  const _PracticeNavigation({
    required this.canGoPrevious,
    required this.isLast,
    required this.onPrevious,
    required this.onAnswerCard,
    required this.onNext,
  });

  final bool canGoPrevious;
  final bool isLast;
  final VoidCallback onPrevious;
  final VoidCallback onAnswerCard;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton.outlined(
              key: const ValueKey('practice-previous'),
              tooltip: '上一项',
              onPressed: canGoPrevious ? onPrevious : null,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            IconButton.outlined(
              key: const ValueKey('practice-answer-card'),
              tooltip: '答题卡',
              onPressed: onAnswerCard,
              icon: const Icon(Icons.grid_view_rounded),
            ),
            IconButton.filled(
              key: const ValueKey('practice-next'),
              tooltip: isLast ? '查看结果' : '下一项',
              onPressed: onNext,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF237DED),
                foregroundColor: Colors.white,
              ),
              icon: Icon(
                isLast
                    ? Icons.assessment_outlined
                    : Icons.arrow_forward_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PracticeAnswerSheet extends StatelessWidget {
  const _PracticeAnswerSheet({
    required this.items,
    required this.session,
    required this.onSelect,
  });

  final List<PracticeItem> items;
  final PracticeSession session;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      key: const ValueKey('practice-answer-sheet'),
      heightFactor: 0.7,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                '答题卡',
                style: TextStyle(
                  color: Color(0xFF263238),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE8ECF0)),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final status = _answerStatus(item, session, index);
                  return Material(
                    color: index == session.currentIndex
                        ? const Color(0xFFEAF2FD)
                        : const Color(0xFFF6F8FA),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(
                        color: index == session.currentIndex
                            ? const Color(0xFF237DED)
                            : const Color(0xFFD8DEE4),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey('practice-answer-cell-$index'),
                      onTap: () => onSelect(index),
                      child: Center(child: status),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _answerStatus(PracticeItem item, PracticeSession session, int index) {
  if (item is PracticeSkillItem) {
    return Icon(
      Icons.lightbulb_rounded,
      key: ValueKey('practice-answer-status-$index-skill'),
      color: const Color(0xFFE6A23C),
      size: 22,
    );
  }
  final question = (item as PracticeQuestionItem).question;
  final answer = session.answerFor(question);
  if (answer != null) {
    final status = answer.isRight ? 'right' : 'wrong';
    return Icon(
      answer.isRight ? Icons.check_rounded : Icons.close_rounded,
      key: ValueKey('practice-answer-status-$index-$status'),
      color: answer.isRight ? const Color(0xFF22A06B) : const Color(0xFFD14343),
      size: 22,
    );
  }
  return Text(
    '${index + 1}',
    key: ValueKey(
      'practice-answer-status-$index-${session.canVisit(index) ? 'open' : 'locked'}',
    ),
    style: TextStyle(
      color: session.canVisit(index)
          ? const Color(0xFF44546F)
          : const Color(0xFFA5ADBA),
      fontWeight: FontWeight.w600,
    ),
  );
}

String _questionTypeLabel(PracticeQuestion question) {
  if (question.questionType.trim().isNotEmpty) return question.questionType;
  return switch (question.kind) {
    PracticeQuestionKind.judgment => '判断题',
    PracticeQuestionKind.single => '单选题',
    PracticeQuestionKind.multiple => '多选题',
  };
}

String _wrongRemovalThresholdLabel(int value) {
  return switch (value) {
    1 => '做对即删除',
    -1 => '仅限手动移除',
    _ => '$value次',
  };
}
