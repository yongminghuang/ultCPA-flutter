import 'dart:async';

import 'package:flutter/material.dart';

import '../main_tabs/main_tabs_models.dart';
import '../skill_mnemonics/skill_mnemonics_text.dart';
import 'daily_skill_models.dart';
import 'daily_skill_progress_store.dart';
import 'daily_skill_repository.dart';

typedef DailySkillPracticeLauncher =
    Future<void> Function(BuildContext context, DailySkillDetail detail);
typedef DailySkillImproveLauncher = Future<void> Function(BuildContext context);

final class DailySkillDetailPage extends StatefulWidget {
  const DailySkillDetailPage({
    required this.module,
    required this.dataSource,
    required this.progressStore,
    required this.practiceLauncher,
    required this.improveLauncher,
    super.key,
  });

  final HomeModule module;
  final DailySkillDataSource dataSource;
  final DailySkillProgressDataSource progressStore;
  final DailySkillPracticeLauncher practiceLauncher;
  final DailySkillImproveLauncher improveLauncher;

  @override
  State<DailySkillDetailPage> createState() => _DailySkillDetailPageState();
}

final class _DailySkillDetailPageState extends State<DailySkillDetailPage> {
  DailySkillDetail? _detail;
  DailySkillProgress? _progress;
  Object? _error;
  bool _loading = true;
  bool _launching = false;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load(initial: true));
  }

  @override
  void dispose() {
    _loadVersion += 1;
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    final version = ++_loadVersion;
    if (widget.module.id <= 0) {
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _detail = null;
        _progress = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    if (!initial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final detail = await widget.dataSource.loadDetail(widget.module);
      final progress = await widget.progressStore.ensureToday(
        skillId: detail.skill.skillId,
        moduleId: detail.module.id,
        shelfId: detail.effectiveShelfId,
      );
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _detail = detail;
        _progress = progress;
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

  @override
  Widget build(BuildContext context) {
    final finished = _progress?.isFinished == true;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF36414D),
        elevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text('每日一招'),
      ),
      body: _buildBody(),
      bottomNavigationBar:
          !_loading && _error == null && _detail != null && !finished
          ? _PracticeAction(
              questionCount: _detail!.skill.questionCount,
              enabled: !_launching,
              onTap: _openPractice,
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        key: ValueKey('daily-skill-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      return Center(
        key: const ValueKey('daily-skill-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: Color(0xFF7A869A),
            ),
            const SizedBox(height: 12),
            const Text('加载失败'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('daily-skill-retry-load'),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新加载'),
            ),
          ],
        ),
      );
    }
    final detail = _detail;
    if (detail == null) {
      return const Center(
        key: ValueKey('daily-skill-empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lightbulb_outline, size: 44, color: Color(0xFF7A869A)),
            SizedBox(height: 12),
            Text('暂无每日一招内容'),
          ],
        ),
      );
    }
    final skill = detail.skill;
    final finished = _progress?.isFinished == true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        const _SectionLabel(label: '技巧口诀'),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9EFD9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: SkillMnemonicHighlightedText(
            key: const ValueKey('daily-skill-text'),
            text: skill.displayText,
            terms: skill.keywordTerms,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF515B65),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
        if (detail.imageUrl.isNotEmpty) ...[
          const SizedBox(height: 16),
          Image.network(
            detail.imageUrl,
            key: const ValueKey('daily-skill-image'),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ],
        if (skill.note.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            key: const ValueKey('daily-skill-analysis'),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F7F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFC340),
                      size: 20,
                    ),
                    SizedBox(width: 4),
                    Text('技巧解析', style: TextStyle(color: Color(0xFF36414D))),
                  ],
                ),
                const SizedBox(height: 16),
                SkillMnemonicHighlightedText(
                  text: skill.note,
                  terms: skill.keywordTerms,
                  style: const TextStyle(
                    color: Color(0xFF515B65),
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (finished) ...[
          const SizedBox(height: 16),
          Container(
            key: const ValueKey('daily-skill-finished'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            color: const Color(0xFFB9BEC7),
            child: const Text(
              '太棒了！今天目标已达成，明天记得来！',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('daily-skill-retry-practice'),
            onPressed: _launching ? null : _retryPractice,
            style: _actionStyle,
            child: const Text('再练一次'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('daily-skill-improve'),
            onPressed: _launching ? null : _openImprove,
            style: _actionStyle,
            child: const Text('用技巧解题，提分快人一步！'),
          ),
        ],
      ],
    );
  }

  Future<void> _openPractice() => _launchPractice(clearFirst: false);

  Future<void> _retryPractice() => _launchPractice(clearFirst: true);

  Future<void> _launchPractice({required bool clearFirst}) async {
    if (_launching || _detail == null) return;
    setState(() => _launching = true);
    try {
      if (clearFirst) {
        await widget.progressStore.clear();
        final detail = _detail!;
        await widget.progressStore.ensureToday(
          skillId: detail.skill.skillId,
          moduleId: detail.module.id,
          shelfId: detail.effectiveShelfId,
        );
      }
      if (!mounted) return;
      await widget.practiceLauncher(context, _detail!);
    } catch (_) {
      if (mounted) _showMessage('操作失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  Future<void> _openImprove() async {
    if (_launching) return;
    setState(() => _launching = true);
    try {
      await widget.improveLauncher(context);
    } catch (_) {
      if (mounted) _showMessage('入口数据加载中，请稍后重试');
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _PracticeAction extends StatelessWidget {
  const _PracticeAction({
    required this.questionCount,
    required this.enabled,
    required this.onTap,
  });

  final int questionCount;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: FilledButton(
        key: const ValueKey('daily-skill-practice'),
        onPressed: enabled ? onTap : null,
        style: _actionStyle,
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white, fontSize: 16),
            children: [
              const TextSpan(text: '掌握该技巧能做 '),
              TextSpan(
                text: '$questionCount',
                style: const TextStyle(
                  color: Color(0xFFFFE0B2),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(text: ' 题'),
            ],
          ),
        ),
      ),
    );
  }
}

final class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFFFE7C2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFFC28B3E), fontSize: 18),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFFFE7C2))),
      ],
    );
  }
}

final _actionStyle = FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(48),
  backgroundColor: const Color(0xFF0BA0E9),
  foregroundColor: Colors.white,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
);
