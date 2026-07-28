import 'dart:async';

import 'package:flutter/material.dart';

import '../exam/exam_models.dart';
import '../main_tabs/main_tabs_models.dart';
import 'past_exams_models.dart';
import 'past_exams_repository.dart';

typedef PastExamLauncher =
    FutureOr<void> Function(BuildContext context, ExamRequest request);

typedef PastExamsUnlockLauncher = FutureOr<void> Function();

final class PastExamsPage extends StatefulWidget {
  const PastExamsPage({
    required this.module,
    required this.dataSource,
    required this.examLauncher,
    this.onUnlock,
    super.key,
  });

  final HomeModule module;
  final PastExamsDataSource dataSource;
  final PastExamLauncher examLauncher;
  final PastExamsUnlockLauncher? onUnlock;

  @override
  State<PastExamsPage> createState() => _PastExamsPageState();
}

final class _PastExamsPageState extends State<PastExamsPage> {
  PastExamsCatalog? _catalog;
  Object? _error;
  bool _loading = true;
  int? _launchingIndex;
  int? _unlockingIndex;
  int _loadGeneration = 0;

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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF263238),
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          key: const ValueKey('past-exams-back'),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: const Text(
          '历年真题卷',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        key: ValueKey('past-exams-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      return Center(
        key: const ValueKey('past-exams-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('网络开小差了，请稍后重试'),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('past-exams-retry'),
              onPressed: _retry,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    final papers = _catalog?.papers ?? const <PastExamPaper>[];
    if (papers.isEmpty) {
      return const Center(
        key: ValueKey('past-exams-empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 44,
              color: Color(0xFF7A869A),
            ),
            SizedBox(height: 12),
            Text('暂无历年真题卷'),
          ],
        ),
      );
    }
    return ListView.separated(
      key: const ValueKey('past-exams-list'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      itemCount: papers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 20),
      itemBuilder: (context, index) => _buildRow(papers[index], index),
    );
  }

  Widget _buildRow(PastExamPaper paper, int index) {
    return ConstrainedBox(
      key: ValueKey('past-exams-row-$index'),
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          if (paper.locked) ...[
            const Icon(Icons.lock, size: 18, color: Color(0xFF7A869A)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              paper.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF333333),
                fontSize: 15,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (paper.locked)
            TextButton(
              key: ValueKey('past-exams-unlock-$index'),
              onPressed: _unlockingIndex == null && _launchingIndex == null
                  ? () => _unlock(index)
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF6830D),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                minimumSize: const Size(0, 40),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('去解锁', style: TextStyle(fontSize: 15)),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right, size: 16),
                ],
              ),
            )
          else
            SizedBox(
              width: 80,
              height: 32,
              child: FilledButton(
                key: ValueKey('past-exams-start-$index'),
                onPressed: _launchingIndex == null && _unlockingIndex == null
                    ? () => _launch(paper, index)
                    : null,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: const Color(0xFF237DED),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  '开始考试',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
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
        _loading = false;
        _error = null;
      });
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
    setState(() {
      _loading = true;
      _error = null;
      _catalog = null;
    });
    unawaited(_loadCatalog());
  }

  Future<void> _launch(PastExamPaper paper, int index) async {
    if (_launchingIndex != null || _unlockingIndex != null) return;
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

  Future<void> _unlock(int index) async {
    if (_unlockingIndex != null || _launchingIndex != null) return;
    final callback = widget.onUnlock;
    if (callback == null) {
      _showMessage('历年真题卷需解锁，会员与支付功能仍在迁移中');
      return;
    }
    setState(() => _unlockingIndex = index);
    try {
      await callback();
      if (!mounted) return;
      setState(() {
        _loading = true;
        _error = null;
        _catalog = null;
      });
      await _loadCatalog();
    } catch (_) {
      if (mounted) _showMessage('解锁入口打开失败，请重试');
    } finally {
      if (mounted) setState(() => _unlockingIndex = null);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
