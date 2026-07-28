import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../exam/exam_models.dart';
import '../main_tabs/main_tabs_models.dart';
import 'pre_exam_secret_paper_models.dart';
import 'pre_exam_secret_paper_repository.dart';

typedef PreExamSecretPaperExamLauncher =
    FutureOr<void> Function(BuildContext context, ExamRequest request);

enum PreExamSecretPaperUnlockSource { lockedCard, bottomAction }

typedef PreExamSecretPaperUnlockLauncher =
    FutureOr<void> Function(PreExamSecretPaperUnlockSource source);

final class PreExamSecretPaperPage extends StatefulWidget {
  const PreExamSecretPaperPage({
    required this.module,
    required this.dataSource,
    required this.examLauncher,
    this.onUnlock,
    super.key,
  });

  final HomeModule module;
  final PreExamSecretPaperDataSource dataSource;
  final PreExamSecretPaperExamLauncher examLauncher;
  final PreExamSecretPaperUnlockLauncher? onUnlock;

  @override
  State<PreExamSecretPaperPage> createState() => _PreExamSecretPaperPageState();
}

final class _PreExamSecretPaperPageState extends State<PreExamSecretPaperPage> {
  static const _heroAsset =
      'assets/images/pre_exam_secret_paper/pre_exam_before_exam_bg.png';
  static const _iconAsset =
      'assets/images/pre_exam_secret_paper/pre_exam_before_exam_ic.png';

  PreExamSecretPaperCatalog? _catalog;
  Object? _error;
  bool _loading = true;
  bool _unlocking = false;
  int? _launchingIndex;
  int _loadGeneration = 0;

  bool get _actionPending => _unlocking || _launchingIndex != null;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCatalog());
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showBottomUnlock =
        !_loading && _error == null && _catalog?.isVip == false;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          key: const ValueKey('secret-paper-back'),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: const Text(
          '最后密押卷',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(child: _buildScrollableBody()),
          if (showBottomUnlock) _buildBottomUnlock(),
        ],
      ),
    );
  }

  Widget _buildScrollableBody() {
    return SingleChildScrollView(
      key: const ValueKey('secret-paper-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset(
            _heroAsset,
            key: const ValueKey('secret-paper-hero'),
            fit: BoxFit.fitWidth,
          ),
          const SizedBox(height: 12),
          _buildCatalogState(),
        ],
      ),
    );
  }

  Widget _buildCatalogState() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          key: ValueKey('secret-paper-loading'),
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        key: const ValueKey('secret-paper-error'),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const Text('网络开小差了，请稍后重试'),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('secret-paper-retry'),
              onPressed: _retry,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    final papers = _catalog?.papers ?? const <PreExamSecretPaper>[];
    if (papers.isEmpty) {
      return const Padding(
        key: ValueKey('secret-paper-empty'),
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('暂无密押卷数据')),
      );
    }
    final visibleCount = math.min(
      papers.length,
      preExamSecretPaperCardCopies.length,
    );
    return Column(
      children: [
        for (var index = 0; index < visibleCount; index += 1) ...[
          if (index > 0) const SizedBox(height: 8),
          _buildPaperCard(papers[index], index),
        ],
      ],
    );
  }

  Widget _buildPaperCard(PreExamSecretPaper paper, int index) {
    final copy = preExamSecretPaperCardCopies[index];
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: const Color(0x24000000),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('secret-paper-card-$index'),
        onTap: _actionPending ? null : () => _activatePaper(paper, index),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: 56,
                child: Center(
                  child: Image.asset(
                    _iconAsset,
                    key: ValueKey('secret-paper-icon-$index'),
                    width: 44,
                    height: 44,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.title,
                      style: const TextStyle(
                        color: Color(0xFF793D09),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      copy.description,
                      style: const TextStyle(
                        color: Color(0xFFC5A178),
                        fontSize: 12,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 58, minHeight: 28),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFA10017)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  '拆开密卷',
                  style: TextStyle(
                    color: Color(0xFFA10017),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomUnlock() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton(
            key: const ValueKey('secret-paper-bottom-unlock'),
            onPressed: _actionPending
                ? null
                : () => _unlock(PreExamSecretPaperUnlockSource.bottomAction),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFA10017),
              disabledBackgroundColor: const Color(0x66A10017),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              '拆开密卷',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadCatalog() async {
    final generation = ++_loadGeneration;
    try {
      final catalog = await widget.dataSource.loadCatalog(widget.module);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _catalog = catalog;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _catalog = null;
        _error = error;
        _loading = false;
      });
    }
  }

  void _retry() {
    if (_loading) return;
    setState(() {
      _catalog = null;
      _error = null;
      _loading = true;
    });
    unawaited(_loadCatalog());
  }

  Future<void> _activatePaper(PreExamSecretPaper paper, int index) async {
    if (_actionPending) return;
    if (_catalog?.isVip != true) {
      await _unlock(PreExamSecretPaperUnlockSource.lockedCard);
      return;
    }
    setState(() => _launchingIndex = index);
    try {
      await widget.examLauncher(
        context,
        ExamRequest(
          module: widget.module,
          shelfId: paper.id,
          title: paper.name,
        ),
      );
    } catch (_) {
      if (mounted) _showMessage('考试入口打开失败，请重试');
    } finally {
      if (mounted) setState(() => _launchingIndex = null);
    }
  }

  Future<void> _unlock(PreExamSecretPaperUnlockSource source) async {
    if (_actionPending) return;
    final callback = widget.onUnlock;
    if (callback == null) {
      _showMessage('最后密押卷需解锁，会员与支付功能仍在迁移中');
      return;
    }
    setState(() => _unlocking = true);
    try {
      await callback(source);
      if (!mounted) return;
      setState(() {
        _catalog = null;
        _error = null;
        _loading = true;
      });
      await _loadCatalog();
    } catch (_) {
      if (mounted) _showMessage('解锁入口打开失败，请重试');
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
