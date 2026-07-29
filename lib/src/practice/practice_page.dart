import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chapter_practice/chapter_practice_progress_store.dart';
import '../daily_skill/daily_skill_progress_store.dart';
import '../skill_mnemonics/skill_mnemonics_models.dart';
import '../skill_mnemonics/skill_mnemonics_text.dart';
import '../vip_purchase/vip_purchase_models.dart';
import 'flat_practice_progress_store.dart';
import 'practice_media_player.dart';
import 'practice_models.dart';
import 'practice_repository.dart';
import 'practice_result_page.dart';
import 'practice_settings_store.dart';
import 'practice_session.dart';

typedef DailySkillReportLauncher =
    Future<void> Function(
      BuildContext context,
      DailySkillPracticeRequest request,
    );

typedef PracticeCustomerServiceLauncher = Future<void> Function();
typedef PracticePaymentLauncher =
    Future<VipPurchaseResult?> Function(
      BuildContext context,
      VipPaymentSource source,
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
    this.settingsStore = const DisabledPracticeSettingsStore(),
    this.customerServiceLauncher,
    this.paymentLauncher,
    super.key,
  });

  final PracticeRequest request;
  final PracticeDataSource dataSource;
  final ChapterPracticeProgressStore chapterProgressStore;
  final FlatPracticeProgressStore flatProgressStore;
  final DailySkillProgressDataSource dailySkillProgressStore;
  final DailySkillReportLauncher dailySkillReportLauncher;
  final PracticeSettingsStore settingsStore;
  final PracticeCustomerServiceLauncher? customerServiceLauncher;
  final PracticePaymentLauncher? paymentLauncher;

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
  PracticeSettings _settings = const PracticeSettings.disabledDefaults();
  Timer? _autoNextTimer;
  bool _openingPayment = false;
  bool _loadingSkillExplanation = false;
  final Map<String, List<SkillMnemonic>> _questionSkills = {};

  @override
  void initState() {
    super.initState();
    _activeRequest = widget.request;
    unawaited(_loadSettings());
    unawaited(_load(initial: true));
  }

  @override
  void dispose() {
    _loadVersion += 1;
    _autoNextTimer?.cancel();
    super.dispose();
  }

  bool get _isPromotionPractice => switch (_activeRequest) {
    ModulePracticeRequest(:final module) =>
      module.page.trim() == '推广技巧' || module.page.contains('推广'),
    _ => false,
  };

  String _pageTitle(PracticeCatalog? catalog) {
    if (_isPromotionPractice) return '技巧练题';
    return catalog?.title ?? _activeRequest.title;
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await widget.settingsStore.loadPracticeSettings();
      if (mounted) setState(() => _settings = settings);
    } catch (_) {
      // The practice runner remains usable with its safe in-memory defaults.
    }
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
        _questionSkills.clear();
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
    final palette = _PracticePalette.from(_settings.themeMode);
    if (_loading) {
      return _PracticeShell(
        title: _pageTitle(_catalog),
        palette: palette,
        body: const Center(
          key: ValueKey('practice-loading'),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return _PracticeShell(
        title: _pageTitle(null),
        palette: palette,
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
        title: _pageTitle(catalog),
        palette: palette,
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
      backgroundColor: palette.background,
      appBar: AppBar(
        toolbarHeight: 52,
        backgroundColor: palette.background,
        foregroundColor: palette.primaryText,
        elevation: 0,
        surfaceTintColor: palette.background,
        title: Text(
          _pageTitle(catalog),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          _PracticeSettingsAction(
            key: ValueKey(
              catalog.behavior.reviewKind == PracticeReviewKind.errors
                  ? 'practice-wrong-settings'
                  : 'practice-settings',
            ),
            color: palette.primaryText,
            onTap: _showPracticeSettings,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_activeRequest is DailySkillPracticeRequest)
                LinearProgressIndicator(
                  value: (session.currentIndex + 1) / session.items.length,
                  minHeight: 2,
                  backgroundColor: palette.divider,
                  color: _PracticePalette.blue,
                ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: _handleHorizontalDragEnd,
                  child: KeyedSubtree(
                    key: ValueKey(session.currentItem!.stableId),
                    child: _buildCurrentItem(session.currentItem!, palette),
                  ),
                ),
              ),
            ],
          ),
          if (_isPromotionPractice && widget.customerServiceLauncher != null)
            Positioned(
              right: 0,
              bottom: 18,
              child: InkWell(
                key: const ValueKey('practice-promotion-customer-service'),
                onTap: () => unawaited(_openCustomerService()),
                borderRadius: BorderRadius.circular(42),
                child: Image.asset(
                  'assets/images/vip_purchase/ic_promotion_add_customer_service.png',
                  width: 82,
                  height: 82,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _PracticeNavigation(
        palette: palette,
        canGoPrevious: session.currentIndex > 0,
        isLast: session.currentIndex == session.items.length - 1,
        position: session.currentIndex + 1,
        total: session.items.length,
        right: session.rightCount,
        wrong: session.wrongCount,
        loadingSkillShortcut: _loadingSkillExplanation,
        onPrevious: _previous,
        onAnswerCard: _showAnswerCard,
        onSkillShortcut: _openRelatedSkill,
        onNext: _next,
      ),
    );
  }

  Widget _buildCurrentItem(PracticeItem item, _PracticePalette palette) {
    return switch (item) {
      PracticeSkillItem(:final skill) => _PracticeSkillView(
        skill: skill,
        palette: palette,
        textScale: _settings.textScale,
        promotion: _isPromotionPractice,
        onPromotionUnlock: _isPromotionPractice
            ? () =>
                  unawaited(_openPayment(VipPaymentSource.promotionPracticePay))
            : null,
      ),
      PracticeQuestionItem(:final question) => _PracticeQuestionView(
        question: question,
        palette: palette,
        textScale: _settings.textScale,
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
        onCorrection: () => _showCorrection(question),
        onListenSkill: null,
      ),
    };
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 280) return;
    if (velocity > 0) {
      _previous();
    } else {
      unawaited(_next());
    }
  }

  List<SkillMnemonic> _fallbackRelatedSkills() {
    final session = _session;
    if (session == null || session.items.isEmpty) return const [];
    final current = session.currentItem;
    if (current is PracticeSkillItem) {
      return [current.skill];
    }
    final adjacent = <SkillMnemonic>[];
    for (final index in [session.currentIndex - 1, session.currentIndex + 1]) {
      if (index < 0 || index >= session.items.length) continue;
      final item = session.items[index];
      if (item is PracticeSkillItem) adjacent.add(item.skill);
    }
    return List.unmodifiable(adjacent);
  }

  Future<void> _openRelatedSkill() async {
    if (_loadingSkillExplanation) return;
    final session = _session!;
    final current = session.currentItem;
    List<SkillMnemonic> skills;
    if (current is PracticeSkillItem) {
      skills = [current.skill];
    } else if (current case PracticeQuestionItem(:final question)) {
      final cached = _questionSkills[question.id];
      if (cached != null) {
        skills = cached;
      } else {
        setState(() => _loadingSkillExplanation = true);
        try {
          final source = widget.dataSource;
          skills = source is PracticeSkillExplanationDataSource
              ? await (source as PracticeSkillExplanationDataSource)
                    .loadSkillsForQuestion(question.id)
              : const [];
          if (skills.isEmpty) skills = _fallbackRelatedSkills();
          _questionSkills[question.id] = List.unmodifiable(skills);
        } catch (_) {
          skills = _fallbackRelatedSkills();
        } finally {
          if (mounted) setState(() => _loadingSkillExplanation = false);
        }
      }
    } else {
      skills = const [];
    }
    if (!mounted) return;
    if (skills.isEmpty) {
      _showMessage('该题暂无技巧');
      return;
    }
    final freeCount = session.access.freeQuestionCount.clamp(0, 1 << 30);
    final requiresPayment =
        !_isPromotionPractice &&
        !session.hasFullAccess &&
        session.newlySubmittedCount >= freeCount;
    if (requiresPayment) {
      final paid = await _openPayment(VipPaymentSource.skillExplain);
      if (!paid || !mounted) return;
    }
    _autoNextTimer?.cancel();
    final palette = _PracticePalette.from(_settings.themeMode);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _PracticeExplanationSheet(
        skills: skills,
        palette: palette,
        textScale: _settings.textScale,
        fullAccess: session.hasFullAccess || _isPromotionPractice,
        remainingFreeCount: (freeCount - session.newlySubmittedCount).clamp(
          0,
          freeCount,
        ),
        onClose: () => Navigator.of(sheetContext).pop(),
        onOpenVip: () {
          Navigator.of(sheetContext).pop();
          unawaited(_openPayment(VipPaymentSource.skillExplain));
        },
      ),
    );
  }

  Future<bool> _openPayment(VipPaymentSource source) async {
    if (_openingPayment) return false;
    final launcher = widget.paymentLauncher;
    if (launcher == null) {
      _showMessage(_paymentPrompt(source));
      return false;
    }
    _openingPayment = true;
    try {
      final result = await launcher(context, source);
      if (!mounted || result != VipPurchaseResult.paid) return false;
      _session?.grantFullAccess();
      setState(() {});
      return true;
    } catch (_) {
      if (mounted) _showMessage('支付入口打开失败，请稍后重试');
      return false;
    } finally {
      _openingPayment = false;
    }
  }

  String _paymentPrompt(VipPaymentSource source) {
    return switch (source) {
      VipPaymentSource.chapterOrPastExamsUnlock => '章节练习需解锁，请开通会员后继续',
      VipPaymentSource.skillExplain => '技巧讲解需解锁，请开通会员后继续',
      VipPaymentSource.promotionPracticePay ||
      VipPaymentSource.promotionPracticeFinish => '解锁完整技巧练题内容后继续',
      _ => '免费练题次数已用完，请开通会员后继续',
    };
  }

  Future<void> _openCustomerService() async {
    try {
      await widget.customerServiceLauncher?.call();
    } catch (_) {
      if (mounted) _showMessage('暂时无法打开微信客服，请稍后重试');
    }
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
        if (answer.isRight && _settings.playCorrectSound) {
          unawaited(SystemSound.play(SystemSoundType.click));
        }
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
        if (answer.isRight && _settings.autoNext) {
          _autoNextTimer?.cancel();
          _autoNextTimer = Timer(const Duration(milliseconds: 420), () {
            if (!mounted || _session?.currentQuestion?.id != question.id) {
              return;
            }
            unawaited(_next());
          });
        } else if (!answer.isRight &&
            _settings.explainWrongAutomatically &&
            question.analysis.trim().isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _session?.currentQuestion?.id == question.id) {
              _showWrongExplanation(question);
            }
          });
        }
      case PracticeLocked():
        unawaited(_openPayment(VipPaymentSource.answerCardUnlock));
      case PracticeNoChange():
        break;
    }
  }

  Future<void> _showWrongExplanation(PracticeQuestion question) {
    final palette = _PracticePalette.from(_settings.themeMode);
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AndroidSectionTitle(
                text: '答案解析',
                palette: palette,
                trailing: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                question.analysis,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 16 * _settings.textScale,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Future<void> _showPracticeSettings() async {
    final isErrorReview =
        _catalog?.behavior.reviewKind == PracticeReviewKind.errors;
    var selectedThreshold = -1;
    if (isErrorReview) {
      try {
        selectedThreshold = await widget.dataSource.loadWrongRemovalThreshold();
      } catch (_) {
        if (mounted) _showMessage('设置读取失败，请稍后重试');
      }
    }
    if (!mounted) return;
    var draft = _settings;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final palette = _PracticePalette.from(draft.themeMode);
          void update(PracticeSettings next) {
            draft = next;
            setSheetState(() {});
            setState(() => _settings = next);
            unawaited(_saveSettings(next));
          }

          return FractionallySizedBox(
            key: ValueKey(
              isErrorReview
                  ? 'practice-wrong-settings-sheet'
                  : 'practice-settings-sheet',
            ),
            heightFactor: isErrorReview ? 0.92 : 0.72,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 4,
                        color: _PracticePalette.blue,
                      ),
                      _PracticeSwitchRow(
                        label: '答对自动跳转下一题',
                        value: draft.autoNext,
                        palette: palette,
                        onChanged: (value) =>
                            update(draft.copyWith(autoNext: value)),
                      ),
                      _PracticeSwitchRow(
                        label: '答对后播放语音',
                        value: draft.playCorrectSound,
                        palette: palette,
                        onChanged: (value) =>
                            update(draft.copyWith(playCorrectSound: value)),
                      ),
                      _PracticeSwitchRow(
                        label: '答错自动弹出语音讲解',
                        value: draft.explainWrongAutomatically,
                        palette: palette,
                        onChanged: (value) => update(
                          draft.copyWith(explainWrongAutomatically: value),
                        ),
                      ),
                      _PracticeChoiceRow<PracticeFontSize>(
                        label: '字体大小',
                        values: PracticeFontSize.values,
                        selected: draft.fontSize,
                        labels: const ['小号', '正常', '大号', '特大'],
                        palette: palette,
                        onSelected: (value) =>
                            update(draft.copyWith(fontSize: value)),
                      ),
                      _PracticeThemeRow(
                        selected: draft.themeMode,
                        palette: palette,
                        onSelected: (value) =>
                            update(draft.copyWith(themeMode: value)),
                      ),
                      if (isErrorReview) ...[
                        Divider(color: palette.divider),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '设置自动移除错题',
                              style: TextStyle(
                                color: palette.primaryText,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '请选择做对几次，自动移除错题',
                              style: TextStyle(
                                color: palette.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (final value in const [
                                1,
                                2,
                                3,
                                4,
                                5,
                                6,
                                7,
                                -1,
                              ])
                                ChoiceChip(
                                  key: ValueKey(
                                    'practice-wrong-threshold-$value',
                                  ),
                                  label: Text(
                                    _wrongRemovalThresholdLabel(value),
                                  ),
                                  selected: selectedThreshold == value,
                                  onSelected: (_) {
                                    if (value == selectedThreshold) return;
                                    setSheetState(
                                      () => selectedThreshold = value,
                                    );
                                    unawaited(
                                      _saveWrongRemovalThreshold(value),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveSettings(PracticeSettings settings) async {
    try {
      await widget.settingsStore.savePracticeSettings(settings);
    } catch (_) {
      if (mounted) _showMessage('设置保存失败，请稍后重试');
    }
  }

  Future<void> _saveWrongRemovalThreshold(int threshold) async {
    try {
      await widget.dataSource.saveWrongRemovalThreshold(threshold);
    } catch (_) {
      if (mounted) _showMessage('设置保存失败，请稍后重试');
    }
  }

  void _previous() {
    _autoNextTimer?.cancel();
    if (_session!.movePrevious()) {
      setState(() {});
      _persistCurrentPosition();
    }
  }

  Future<void> _next() async {
    _autoNextTimer?.cancel();
    final catalog = _catalog!;
    final session = _session!;
    if (session.currentIndex == session.items.length - 1) {
      if (_isPromotionPractice) {
        final paid = await _openPayment(
          VipPaymentSource.promotionPracticeFinish,
        );
        if (!paid || !mounted) return;
      }
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
      await _openPayment(VipPaymentSource.answerCardUnlock);
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
        final paid = await _openPayment(
          VipPaymentSource.chapterOrPastExamsUnlock,
        );
        if (!paid || !mounted) return;
        await _switchChapter(
          ChapterPracticeRequest(
            module: chapterContext.module,
            catalogIndex: next.catalogIndex,
            chapterIndex: next.chapterIndex,
            entryMode: ChapterPracticeEntryMode.automatic,
          ),
          successMessage:
              '已解锁，进入${next.title.trim().isEmpty ? '下一章节' : next.title}',
          failureMessage: '权益刷新失败，请稍后重试',
        );
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

  Future<bool> _clearPracticeHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空做题记录'),
        content: const Text('清空后将从第一题重新开始，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;

    try {
      if (_activeRequest is DailySkillPracticeRequest) {
        await widget.dailySkillProgressStore.clear();
      } else if (widget.dataSource
          case final PracticeMaintenanceDataSource source) {
        await source.clearPracticeRecords();
      }
    } catch (_) {
      if (mounted) _showMessage('清空失败，请稍后重试');
      return false;
    }
    if (!mounted) return false;
    _autoNextTimer?.cancel();
    _session!.reset();
    _persistCurrentPosition();
    setState(() {});
    _showMessage('做题记录已清空');
    return true;
  }

  Future<void> _showCorrection(PracticeQuestion question) async {
    final source = widget.dataSource;
    if (source is! PracticeMaintenanceDataSource) {
      _showMessage('反馈功能暂不可用');
      return;
    }
    final maintenanceSource = source as PracticeMaintenanceDataSource;
    final controller = TextEditingController();
    var selectedType = 0;
    var submitting = false;
    final palette = _PracticePalette.from(_settings.themeMode);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> submit() async {
            if (selectedType == 0 || controller.text.trim().isEmpty) {
              _showMessage('您有必填项未填写');
              return;
            }
            setSheetState(() => submitting = true);
            try {
              await maintenanceSource.submitCorrection(
                question: question,
                serialNumber: _session!.currentIndex + 1,
                type: selectedType,
                content: controller.text,
              );
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              _showMessage('提交完成,感谢您的反馈');
            } catch (_) {
              if (sheetContext.mounted) {
                setSheetState(() => submitting = false);
                _showMessage('提交失败，请稍后重试');
              }
            }
          }

          const types = <(int, String)>[
            (1, '题干有误'),
            (2, '答案有误'),
            (3, '技巧不好用'),
            (4, '图片不清晰'),
            (99, '其他'),
          ];
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              18,
              16,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AndroidSectionTitle(
                  text: '题目纠错',
                  palette: palette,
                  trailing: IconButton(
                    onPressed: submitting
                        ? null
                        : () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (final (value, label) in types)
                      ChoiceChip(
                        label: Text(label),
                        selected: selectedType == value,
                        onSelected: submitting
                            ? null
                            : (_) => setSheetState(() => selectedType = value),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  enabled: !submitting,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    hintText: '请描述题目存在的问题',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: submitting ? null : submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _PracticePalette.blue,
                    ),
                    child: submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('提交'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 400),
        controller.dispose,
      ),
    );
  }

  Future<void> _showAnswerCard() async {
    final palette = _PracticePalette.from(_settings.themeMode);
    final moved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PracticeAnswerSheet(
        items: _session!.items,
        session: _session!,
        palette: palette,
        onClear: _clearPracticeHistory,
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
      await _openPayment(VipPaymentSource.answerCardUnlock);
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

final class _PracticePalette {
  const _PracticePalette({
    required this.background,
    required this.surface,
    required this.primaryText,
    required this.secondaryText,
    required this.divider,
    required this.optionIdle,
  });

  static const blue = Color(0xFF2A82F0);
  static const green = Color(0xFF00CB94);
  static const red = Color(0xFFE0321A);
  static const orange = Color(0xFFFF9500);

  factory _PracticePalette.from(PracticeThemeMode mode) {
    return switch (mode) {
      PracticeThemeMode.standard => const _PracticePalette(
        background: Colors.white,
        surface: Colors.white,
        primaryText: Color(0xFF212121),
        secondaryText: Color(0xFF4D4D4D),
        divider: Color(0xFFF7F9FA),
        optionIdle: Color(0xFFF1F2F4),
      ),
      PracticeThemeMode.eyeCare => const _PracticePalette(
        background: Color(0xFFF9F6ED),
        surface: Color(0xFFF9F6ED),
        primaryText: Color(0xFF212121),
        secondaryText: Color(0xFF4D4D4D),
        divider: Color(0xFFE9E4D6),
        optionIdle: Color(0xFFE6E1D5),
      ),
      PracticeThemeMode.night => const _PracticePalette(
        background: Color(0xFF181A1D),
        surface: Color(0xFF181A1D),
        primaryText: Color(0xFFC9C4C4),
        secondaryText: Color(0xFF999999),
        divider: Color(0xFF282B2F),
        optionIdle: Color(0xFF34373C),
      ),
    };
  }

  final Color background;
  final Color surface;
  final Color primaryText;
  final Color secondaryText;
  final Color divider;
  final Color optionIdle;
}

final class _PracticeSettingsAction extends StatelessWidget {
  const _PracticeSettingsAction({
    required this.color,
    required this.onTap,
    super.key,
  });

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: 42,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings_outlined, size: 21, color: color),
            const SizedBox(height: 1),
            Text('设置', style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

final class _PracticeSwitchRow extends StatelessWidget {
  const _PracticeSwitchRow({
    required this.label,
    required this.value,
    required this.palette,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final _PracticePalette palette;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(
          label,
          style: TextStyle(color: palette.primaryText, fontSize: 14),
        ),
        value: value,
        activeTrackColor: _PracticePalette.blue,
        onChanged: onChanged,
      ),
    );
  }
}

final class _PracticeChoiceRow<T> extends StatelessWidget {
  const _PracticeChoiceRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.labels,
    required this.palette,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final T selected;
  final List<String> labels;
  final _PracticePalette palette;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(color: palette.primaryText, fontSize: 14),
            ),
          ),
          for (var index = 0; index < values.length; index += 1)
            Expanded(
              child: InkWell(
                onTap: () => onSelected(values[index]),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == values[index]
                        ? _PracticePalette.blue.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      color: selected == values[index]
                          ? _PracticePalette.blue
                          : palette.secondaryText,
                      fontSize: 12 + index * 2,
                      fontWeight: selected == values[index]
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class _PracticeThemeRow extends StatelessWidget {
  const _PracticeThemeRow({
    required this.selected,
    required this.palette,
    required this.onSelected,
  });

  final PracticeThemeMode selected;
  final _PracticePalette palette;
  final ValueChanged<PracticeThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    const choices = <(PracticeThemeMode, String, Color)>[
      (PracticeThemeMode.standard, '标准', Color(0xFFF7F8F9)),
      (PracticeThemeMode.eyeCare, '护眼', Color(0xFFF9F6ED)),
      (PracticeThemeMode.night, '夜间', Color(0xFF434343)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              '主题选择',
              style: TextStyle(color: palette.primaryText, fontSize: 14),
            ),
          ),
          for (final (value, label, color) in choices)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => onSelected(value),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: selected == value
                            ? _PracticePalette.blue
                            : const Color(0xFFD8DEE4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: value == PracticeThemeMode.night
                                ? Colors.white70
                                : const Color(0xFF666666),
                            fontSize: 14,
                          ),
                        ),
                        if (selected == value) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: _PracticePalette.blue,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class _PracticeShell extends StatelessWidget {
  const _PracticeShell({
    required this.title,
    required this.body,
    required this.palette,
  });

  final String title;
  final Widget body;
  final _PracticePalette palette;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.primaryText,
        elevation: 0,
        surfaceTintColor: palette.background,
        title: Text(title),
        centerTitle: true,
      ),
      body: body,
    );
  }
}

final class _PracticeSkillView extends StatelessWidget {
  const _PracticeSkillView({
    required this.skill,
    required this.palette,
    required this.textScale,
    required this.promotion,
    this.onPromotionUnlock,
  });

  final SkillMnemonic skill;
  final _PracticePalette palette;
  final double textScale;
  final bool promotion;
  final VoidCallback? onPromotionUnlock;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('practice-skill'),
      padding: EdgeInsets.zero,
      children: [
        Container(height: 8, color: palette.divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _AndroidSectionTitle(text: '技巧口诀', palette: palette),
        ),
        if (promotion)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Material(
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF662E), Color(0xFFED3C00)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: InkWell(
                  key: const ValueKey('practice-promotion-unlock'),
                  onTap: onPromotionUnlock,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      '1套技巧秒懂10类题，看见题干就会选 ¥19.9起解锁',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: SkillMnemonicHighlightedText(
            text: skill.displayText,
            terms: skill.keywordTerms,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 17 * textScale,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (skill.voiceUrl != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: PracticeMediaPlayer(
              key: const ValueKey('practice-skill-voice'),
              rawUrl: skill.voiceUrl,
              kind: PracticeMediaKind.audio,
            ),
          ),
        if (skill.videoUrl != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: PracticeMediaPlayer(
                key: const ValueKey('practice-skill-video'),
                rawUrl: skill.videoUrl,
                coverUrl: skill.coverUrl,
                kind: PracticeMediaKind.video,
              ),
            ),
          ),
        Container(height: 8, color: palette.divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _AndroidSectionTitle(text: '技巧解析', palette: palette),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SkillMnemonicHighlightedText(
            text: skill.note,
            terms: skill.keywordTerms,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 16 * textScale,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

final class _PracticeExplanationSheet extends StatelessWidget {
  const _PracticeExplanationSheet({
    required this.skills,
    required this.palette,
    required this.textScale,
    required this.fullAccess,
    required this.remainingFreeCount,
    required this.onClose,
    required this.onOpenVip,
  });

  final List<SkillMnemonic> skills;
  final _PracticePalette palette;
  final double textScale;
  final bool fullAccess;
  final int remainingFreeCount;
  final VoidCallback onClose;
  final VoidCallback onOpenVip;

  @override
  Widget build(BuildContext context) {
    final imageSkill = skills.cast<SkillMnemonic?>().firstWhere(
      (skill) => skill?.imgUrl != null,
      orElse: () => null,
    );
    return SafeArea(
      key: const ValueKey('practice-skill-explanation'),
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 7),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/practice/ic_skill_tip.png',
                      width: 24,
                      height: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '技巧讲解',
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 20 * textScale,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!fullAccess) ...[
                      const SizedBox(width: 7),
                      Text(
                        remainingFreeCount > 0
                            ? '剩余$remainingFreeCount次体验机会'
                            : '免费机会已用完',
                        style: TextStyle(
                          color: remainingFreeCount > 0
                              ? _PracticePalette.red
                              : palette.secondaryText,
                          fontSize: 13 * textScale,
                        ),
                      ),
                    ],
                    const Spacer(),
                    IconButton(
                      key: const ValueKey('practice-skill-explanation-close'),
                      onPressed: onClose,
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: palette.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: palette.divider,
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                children: [
                  for (var index = 0; index < skills.length; index += 1)
                    _PracticeExplanationSkillRow(
                      skill: skills[index],
                      index: index,
                      palette: palette,
                      textScale: textScale,
                    ),
                  if (imageSkill?.imgUrl case final imageUrl?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
                      child: Image.network(
                        resolvePracticeMediaUrl(imageUrl),
                        fit: BoxFit.fitWidth,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
            ),
            if (!fullAccess)
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 16, 15, 25),
                child: SizedBox(
                  width: 254,
                  height: 36,
                  child: FilledButton(
                    key: const ValueKey('practice-skill-open-vip'),
                    onPressed: onOpenVip,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE51C24),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      '立即开通会员',
                      style: TextStyle(fontSize: 14 * textScale),
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

final class _PracticeExplanationSkillRow extends StatelessWidget {
  const _PracticeExplanationSkillRow({
    required this.skill,
    required this.index,
    required this.palette,
    required this.textScale,
  });

  final SkillMnemonic skill;
  final int index;
  final _PracticePalette palette;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (skill.voiceUrl != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.volume_up_rounded,
                      size: (23 * textScale).clamp(20, 30),
                      color: _PracticePalette.blue,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: SkillMnemonicHighlightedText(
                    text: skill.displayText,
                    terms: skill.keywordTerms,
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: 18 * textScale,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (skill.voiceUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: PracticeMediaPlayer(
                key: index == 0
                    ? const ValueKey('practice-explanation-voice')
                    : ValueKey('practice-explanation-voice-$index'),
                rawUrl: skill.voiceUrl,
                kind: PracticeMediaKind.audio,
                autoplay: index == 0,
              ),
            ),
          if (skill.note.trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.all(8),
              color: palette.divider,
              child: SkillMnemonicHighlightedText(
                text: skill.note,
                terms: skill.keywordTerms,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 16 * textScale,
                  height: 1.45,
                ),
              ),
            ),
          if (skill.videoUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: PracticeMediaPlayer(
                  key: index == 0
                      ? const ValueKey('practice-explanation-video')
                      : ValueKey('practice-explanation-video-$index'),
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

final class _AndroidSectionTitle extends StatelessWidget {
  const _AndroidSectionTitle({
    required this.text,
    required this.palette,
    this.trailing,
  });

  final String text;
  final _PracticePalette palette;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 18, color: _PracticePalette.blue),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

typedef _OptionCallback = void Function(PracticeQuestion question, String key);

final class _PracticeQuestionView extends StatelessWidget {
  const _PracticeQuestionView({
    required this.question,
    required this.palette,
    required this.textScale,
    required this.answer,
    required this.draft,
    required this.isCollected,
    required this.removingWrong,
    required this.showWrongRemoval,
    required this.onOption,
    required this.onConfirmMultiple,
    required this.onToggleCollection,
    required this.onRemoveWrong,
    required this.onCorrection,
    required this.onListenSkill,
  });

  final PracticeQuestion question;
  final _PracticePalette palette;
  final double textScale;
  final PracticeAnswer? answer;
  final String draft;
  final bool isCollected;
  final bool removingWrong;
  final bool showWrongRemoval;
  final _OptionCallback onOption;
  final VoidCallback onConfirmMultiple;
  final VoidCallback onToggleCollection;
  final VoidCallback onRemoveWrong;
  final VoidCallback onCorrection;
  final VoidCallback? onListenSkill;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('practice-question'),
      padding: EdgeInsets.zero,
      children: [
        Container(height: 8, color: palette.divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Text(
            question.displayTitle,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 16 * textScale,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 6, 12),
          child: Row(
            children: [
              _PracticeActionChip(
                label: _questionTypeLabel(question),
                foreground: _PracticePalette.blue,
                background: _PracticePalette.blue.withValues(alpha: 0.08),
              ),
              if (question.tags.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: _PracticeActionChip(
                    label: question.tags,
                    foreground: _PracticePalette.blue,
                    background: _PracticePalette.blue.withValues(alpha: 0.08),
                  ),
                ),
              ],
              const Spacer(),
              _PracticeActionChip(
                key: const ValueKey('practice-collection-toggle'),
                label: isCollected ? '取消收藏' : '收藏',
                icon: Icon(
                  isCollected ? Icons.bookmark : Icons.bookmark_border,
                  key: ValueKey(
                    'practice-collection-${isCollected ? 'collected' : 'not-collected'}',
                  ),
                  size: 14,
                  color: _PracticePalette.green,
                ),
                foreground: _PracticePalette.green,
                background: _PracticePalette.blue.withValues(alpha: 0.06),
                onTap: onToggleCollection,
              ),
              if (showWrongRemoval) ...[
                const SizedBox(width: 8),
                _PracticeActionChip(
                  key: const ValueKey('practice-remove-wrong'),
                  label: '移除错题',
                  icon: removingWrong
                      ? const SizedBox.square(
                          dimension: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        )
                      : const Icon(
                          Icons.delete_outline,
                          size: 14,
                          color: _PracticePalette.orange,
                        ),
                  foreground: _PracticePalette.orange,
                  background: _PracticePalette.blue.withValues(alpha: 0.06),
                  onTap: removingWrong ? null : onRemoveWrong,
                ),
              ],
              if (onListenSkill != null) ...[
                const SizedBox(width: 8),
                _PracticeActionChip(
                  label: '听技巧',
                  icon: const Icon(
                    Icons.mic_none_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  foreground: Colors.white,
                  background: _PracticePalette.orange,
                  onTap: onListenSkill,
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              for (final option in question.options) ...[
                _PracticeOptionRow(
                  question: question,
                  option: option,
                  answer: answer,
                  palette: palette,
                  textScale: textScale,
                  selectedInDraft: draft.contains(option.key),
                  onTap: () => onOption(question, option.key),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        if (question.kind == PracticeQuestionKind.multiple && answer == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                key: const ValueKey('practice-confirm'),
                onPressed: draft.isEmpty ? null : onConfirmMultiple,
                style: FilledButton.styleFrom(
                  backgroundColor: _PracticePalette.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('确定'),
              ),
            ),
          ),
        if (answer != null) ...[
          const SizedBox(height: 4),
          Container(height: 8, color: palette.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              children: [
                Text(
                  '正确答案：${question.normalizedAnswer}',
                  style: TextStyle(
                    color: _PracticePalette.green,
                    fontSize: 18 * textScale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '您的答案：${answer!.choose}',
                  style: TextStyle(
                    color: answer!.isRight
                        ? _PracticePalette.green
                        : _PracticePalette.red,
                    fontSize: 18 * textScale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (question.analysis.trim().isNotEmpty) ...[
            Container(height: 8, color: palette.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _AndroidSectionTitle(
                text: '答案解析',
                palette: palette,
                trailing: InkWell(
                  key: const ValueKey('practice-correction'),
                  onTap: onCorrection,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: palette.divider,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '反馈',
                      style: TextStyle(
                        color: palette.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              child: Text(
                question.analysis,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 16 * textScale,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

final class _PracticeActionChip extends StatelessWidget {
  const _PracticeActionChip({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
    this.onTap,
    super.key,
  });

  final String label;
  final Color foreground;
  final Color background;
  final Widget? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 3)],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: foreground, fontSize: 10, height: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _PracticeOptionRow extends StatelessWidget {
  const _PracticeOptionRow({
    required this.question,
    required this.option,
    required this.answer,
    required this.palette,
    required this.textScale,
    required this.selectedInDraft,
    required this.onTap,
  });

  final PracticeQuestion question;
  final PracticeOption option;
  final PracticeAnswer? answer;
  final _PracticePalette palette;
  final double textScale;
  final bool selectedInDraft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = _optionState();
    final colors = switch (state) {
      'correct' => (
        background: _PracticePalette.green.withValues(alpha: 0.07),
        marker: _PracticePalette.green,
        markerText: Colors.white,
      ),
      'wrong' => (
        background: _PracticePalette.red.withValues(alpha: 0.07),
        marker: _PracticePalette.red,
        markerText: Colors.white,
      ),
      'selected' => (
        background: _PracticePalette.blue.withValues(alpha: 0.07),
        marker: _PracticePalette.blue,
        markerText: Colors.white,
      ),
      _ => (
        background: Colors.transparent,
        marker: palette.optionIdle,
        markerText: palette.primaryText,
      ),
    };
    return Material(
      color: colors.background,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('practice-option-${option.key}'),
        onTap: answer == null ? onTap : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 46 * textScale),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 6 * textScale,
            ),
            child: Row(
              children: [
                Container(
                  key: ValueKey('practice-option-state-${option.key}-$state'),
                  width: (24 * textScale).clamp(20, 32),
                  height: (24 * textScale).clamp(20, 32),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.marker,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    option.key,
                    style: TextStyle(
                      color: colors.markerText,
                      fontSize: 14 * textScale,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(width: 12 * textScale),
                Expanded(
                  child: Text(
                    option.text,
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: 16 * textScale,
                      height: 1.35,
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
    required this.palette,
    required this.canGoPrevious,
    required this.isLast,
    required this.position,
    required this.total,
    required this.right,
    required this.wrong,
    required this.loadingSkillShortcut,
    required this.onPrevious,
    required this.onAnswerCard,
    required this.onSkillShortcut,
    required this.onNext,
  });

  final _PracticePalette palette;
  final bool canGoPrevious;
  final bool isLast;
  final int position;
  final int total;
  final int right;
  final int wrong;
  final bool loadingSkillShortcut;
  final VoidCallback onPrevious;
  final VoidCallback onAnswerCard;
  final VoidCallback onSkillShortcut;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 96,
        color: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border(top: BorderSide(color: palette.divider)),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              height: 35,
              child: Row(
                children: [
                  _PracticeNavButton(
                    key: const ValueKey('practice-previous'),
                    label: '上一题',
                    enabled: canGoPrevious,
                    filled: false,
                    palette: palette,
                    onTap: onPrevious,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PracticeBottomStat(
                          key: const ValueKey('practice-right-count'),
                          icon: Icons.check_circle,
                          text: '$right',
                          iconColor: _PracticePalette.green,
                          palette: palette,
                        ),
                        const SizedBox(height: 4),
                        _PracticeBottomStat(
                          key: const ValueKey('practice-wrong-count'),
                          icon: Icons.cancel,
                          text: '$wrong',
                          iconColor: _PracticePalette.red,
                          palette: palette,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 64),
                  Expanded(
                    child: InkWell(
                      key: const ValueKey('practice-answer-card'),
                      onTap: onAnswerCard,
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.grid_view_rounded,
                            size: 20,
                            color: palette.primaryText,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '$position/$total',
                            key: const ValueKey('practice-position'),
                            maxLines: 1,
                            style: TextStyle(
                              color: palette.secondaryText,
                              fontSize: 11,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _PracticeNavButton(
                    key: const ValueKey('practice-next'),
                    label: isLast ? '完成' : '下一题',
                    enabled: true,
                    filled: true,
                    palette: palette,
                    onTap: onNext,
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: _PracticePalette.blue,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: InkWell(
                    key: const ValueKey('practice-skill-shortcut'),
                    onTap: loadingSkillShortcut ? null : onSkillShortcut,
                    customBorder: const CircleBorder(),
                    child: SizedBox.square(
                      dimension: 64,
                      child: loadingSkillShortcut
                          ? const Padding(
                              padding: EdgeInsets.all(21),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/practice/ic_bottom_mic2.png',
                                  width: 27,
                                  height: 27,
                                  color: Colors.white,
                                ),
                                const Text(
                                  '技巧讲解',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                    ),
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

final class _PracticeNavButton extends StatelessWidget {
  const _PracticeNavButton({
    required this.label,
    required this.enabled,
    required this.filled,
    required this.palette,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool enabled;
  final bool filled;
  final _PracticePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = filled
        ? Colors.white
        : enabled
        ? _PracticePalette.blue
        : palette.secondaryText.withValues(alpha: 0.45);
    return Material(
      color: filled ? _PracticePalette.blue : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: filled
              ? _PracticePalette.blue
              : enabled
              ? _PracticePalette.blue
              : palette.divider,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 70,
          height: 35,
          child: Center(
            child: Text(
              label,
              style: TextStyle(color: foreground, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}

final class _PracticeBottomStat extends StatelessWidget {
  const _PracticeBottomStat({
    required this.icon,
    required this.text,
    required this.iconColor,
    required this.palette,
    super.key,
  });

  final IconData icon;
  final String text;
  final Color iconColor;
  final _PracticePalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            style: TextStyle(color: palette.secondaryText, fontSize: 9),
          ),
        ),
      ],
    );
  }
}

final class _PracticeAnswerSheet extends StatelessWidget {
  const _PracticeAnswerSheet({
    required this.items,
    required this.session,
    required this.palette,
    required this.onClear,
    required this.onSelect,
  });

  final List<PracticeItem> items;
  final PracticeSession session;
  final _PracticePalette palette;
  final Future<bool> Function() onClear;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      key: const ValueKey('practice-answer-sheet'),
      heightFactor: 0.72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '答题卡',
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        key: const ValueKey('practice-answer-card-close'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: palette.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 16, 15),
                child: Row(
                  children: [
                    InkWell(
                      key: const ValueKey('practice-clear-records'),
                      onTap: () async {
                        final cleared = await onClear();
                        if (cleared && context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '清空做题记录',
                          style: TextStyle(
                            color: _PracticePalette.blue,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _AnswerLegend(
                      color: palette.optionIdle,
                      label: '未答题',
                      palette: palette,
                    ),
                    const SizedBox(width: 13),
                    _AnswerLegend(
                      color: _PracticePalette.green,
                      label: '正确',
                      palette: palette,
                    ),
                    const SizedBox(width: 13),
                    _AnswerLegend(
                      color: _PracticePalette.red,
                      label: '错误',
                      palette: palette,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(11, 0, 11, 12),
                  color: palette.background,
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final answer = item is PracticeQuestionItem
                          ? session.answerFor(item.question)
                          : null;
                      final cellColor = item is PracticeSkillItem
                          ? _PracticePalette.orange.withValues(alpha: 0.14)
                          : answer == null
                          ? palette.optionIdle
                          : answer.isRight
                          ? _PracticePalette.green
                          : _PracticePalette.red;
                      return Material(
                        color: cellColor,
                        shape: CircleBorder(
                          side: BorderSide(
                            width: index == session.currentIndex ? 2 : 1,
                            color: index == session.currentIndex
                                ? _PracticePalette.blue
                                : Colors.transparent,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: ValueKey('practice-answer-cell-$index'),
                          onTap: () => onSelect(index),
                          customBorder: const CircleBorder(),
                          child: Center(
                            child: _answerStatus(item, session, index, palette),
                          ),
                        ),
                      );
                    },
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

final class _AnswerLegend extends StatelessWidget {
  const _AnswerLegend({
    required this.color,
    required this.label,
    required this.palette,
  });

  final Color color;
  final String label;
  final _PracticePalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: palette.primaryText, fontSize: 13)),
      ],
    );
  }
}

Widget _answerStatus(
  PracticeItem item,
  PracticeSession session,
  int index,
  _PracticePalette palette,
) {
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
    return Text(
      '${index + 1}',
      key: ValueKey('practice-answer-status-$index-$status'),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
  return Text(
    '${index + 1}',
    key: ValueKey(
      'practice-answer-status-$index-${session.canVisit(index) ? 'open' : 'locked'}',
    ),
    style: TextStyle(
      color: session.canVisit(index)
          ? palette.primaryText
          : palette.secondaryText.withValues(alpha: 0.45),
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
