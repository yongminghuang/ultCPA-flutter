import 'dart:async';

import 'package:flutter/material.dart';

import '../main_tabs/main_tabs_models.dart';
import '../practice/practice_page.dart';
import '../practice/practice_repository.dart';
import '../practice/practice_settings_store.dart';
import 'chapter_practice_models.dart';
import 'chapter_practice_progress_store.dart';
import 'chapter_practice_repository.dart';

typedef ChapterPracticeLauncher =
    Future<void> Function(BuildContext context, ChapterPracticeRequest request);
typedef ChapterPracticeUnlockLauncher =
    Future<bool> Function(BuildContext context);

final class ChapterPracticePage extends StatefulWidget {
  const ChapterPracticePage({
    required this.module,
    required this.dataSource,
    required this.progressStore,
    this.practiceDataSource,
    this.practiceLauncher,
    this.settingsStore = const DisabledPracticeSettingsStore(),
    this.paymentLauncher,
    this.onUnlock,
    super.key,
  }) : assert(practiceDataSource != null || practiceLauncher != null);

  final HomeModule module;
  final ChapterPracticeDataSource dataSource;
  final ChapterPracticeProgressStore progressStore;
  final PracticeDataSource? practiceDataSource;
  final ChapterPracticeLauncher? practiceLauncher;
  final PracticeSettingsStore settingsStore;
  final PracticePaymentLauncher? paymentLauncher;
  final ChapterPracticeUnlockLauncher? onUnlock;

  @override
  State<ChapterPracticePage> createState() => _ChapterPracticePageState();
}

final class _ChapterPracticePageState extends State<ChapterPracticePage> {
  ChapterPracticeCatalog? _catalog;
  Object? _error;
  bool _loading = true;
  int _expandedIndex = -1;
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
    if (!initial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final catalog = await widget.dataSource.load(widget.module);
      var savedIndex = -1;
      try {
        savedIndex = await widget.progressStore.loadExpandedCatalog(
          moduleId: widget.module.id,
        );
      } catch (_) {
        savedIndex = -1;
      }
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _catalog = catalog;
        _expandedIndex = _resolvedExpandedIndex(catalog, savedIndex);
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

  int _resolvedExpandedIndex(ChapterPracticeCatalog catalog, int savedIndex) {
    if (savedIndex >= 0 &&
        savedIndex < catalog.groups.length &&
        catalog.groups[savedIndex].unlocked) {
      return savedIndex;
    }
    return catalog.groups.indexWhere((group) => group.unlocked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF263238),
        elevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text('章节练习'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        key: ValueKey('chapter-practice-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      return Center(
        key: const ValueKey('chapter-practice-error'),
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
              key: const ValueKey('chapter-practice-retry'),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新加载'),
            ),
          ],
        ),
      );
    }
    final catalog = _catalog!;
    if (catalog.groups.isEmpty) {
      return const Center(
        key: ValueKey('chapter-practice-empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 44, color: Color(0xFF7A869A)),
            SizedBox(height: 12),
            Text('暂无章节练习内容'),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: catalog.groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final group = catalog.groups[index];
        return _ChapterGroupSection(
          index: index,
          group: group,
          expanded: index == _expandedIndex,
          onGroupTap: () => _selectGroup(index, group),
          onChapterTap: _selectChapter,
        );
      },
    );
  }

  Future<void> _selectGroup(int index, ChapterPracticeGroup group) async {
    if (!group.unlocked) {
      await _unlock();
      return;
    }
    if (_expandedIndex == index) return;
    setState(() => _expandedIndex = index);
    unawaited(_persistExpandedIndex(index));
  }

  Future<void> _persistExpandedIndex(int index) async {
    try {
      await widget.progressStore.saveExpandedCatalog(
        moduleId: widget.module.id,
        catalogIndex: index,
      );
    } catch (_) {
      // A failed local preference write does not make the catalog unusable.
    }
  }

  Future<void> _selectChapter(ChapterPracticeChapter chapter) async {
    if (!chapter.unlocked) {
      await _unlock();
      return;
    }
    var mode = ChapterPracticeEntryMode.resume;
    if (chapter.isCompleted) {
      final selected = await showDialog<ChapterPracticeEntryMode>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('本章已全部学完'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(ChapterPracticeEntryMode.redo),
              child: const Text('重练本章'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(ChapterPracticeEntryMode.view),
              child: const Text('进入查看'),
            ),
          ],
        ),
      );
      if (selected == null || !mounted) return;
      mode = selected;
    }
    final request = ChapterPracticeRequest(
      module: widget.module,
      catalogIndex: chapter.catalogIndex,
      chapterIndex: chapter.chapterIndex,
      entryMode: mode,
    );
    final launcher = widget.practiceLauncher;
    if (launcher != null) {
      await launcher(context, request);
    } else {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PracticePage(
            request: request,
            dataSource: widget.practiceDataSource!,
            chapterProgressStore: widget.progressStore,
            settingsStore: widget.settingsStore,
            paymentLauncher: widget.paymentLauncher,
          ),
        ),
      );
    }
    if (mounted) await _load();
  }

  Future<void> _unlock() async {
    final launcher = widget.onUnlock;
    if (launcher == null) {
      _showUnlockMessage();
      return;
    }
    try {
      final paid = await launcher(context);
      if (paid && mounted) await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('支付入口打开失败，请稍后重试')));
      }
    }
  }

  void _showUnlockMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('章节练习需解锁，请开通会员后继续')));
  }
}

final class _ChapterGroupSection extends StatelessWidget {
  const _ChapterGroupSection({
    required this.index,
    required this.group,
    required this.expanded,
    required this.onGroupTap,
    required this.onChapterTap,
  });

  final int index;
  final ChapterPracticeGroup group;
  final bool expanded;
  final VoidCallback onGroupTap;
  final ValueChanged<ChapterPracticeChapter> onChapterTap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          InkWell(
            key: ValueKey('chapter-practice-group-$index'),
            onTap: onGroupTap,
            child: SizedBox(
              height: 58,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF263238),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!group.unlocked) ...[
                      const Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: Color(0xFF7A869A),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        '去解锁',
                        style: TextStyle(color: Color(0xFF237DED)),
                      ),
                    ] else
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF7A869A),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: Color(0xFFE8ECF0)),
            for (final chapter in group.chapters)
              _ChapterRow(chapter: chapter, onTap: () => onChapterTap(chapter)),
          ],
        ],
      ),
    );
  }
}

final class _ChapterRow extends StatelessWidget {
  const _ChapterRow({required this.chapter, required this.onTap});

  final ChapterPracticeChapter chapter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey(
        'chapter-practice-chapter-${chapter.catalogIndex}-${chapter.chapterIndex}',
      ),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 13, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    chapter.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF344563),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!chapter.unlocked)
                  const Icon(
                    Icons.lock_outline,
                    size: 17,
                    color: Color(0xFF7A869A),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF97A0AF),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${chapter.doneCount} / ${chapter.totalCount}',
                  style: const TextStyle(
                    color: Color(0xFF44546F),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '正确率 ${chapter.accuracyPercent}%',
                  style: const TextStyle(
                    color: Color(0xFF22A06B),
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                for (var index = 0; index < 5; index += 1)
                  Icon(
                    index < chapter.difficulty
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 15,
                    color: index < chapter.difficulty
                        ? const Color(0xFFE6A23C)
                        : const Color(0xFFC1C7D0),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            LinearProgressIndicator(
              value: chapter.totalCount <= 0
                  ? 0
                  : (chapter.doneCount / chapter.totalCount).clamp(0, 1),
              minHeight: 3,
              backgroundColor: const Color(0xFFE8ECF0),
              color: chapter.isCompleted
                  ? const Color(0xFF22A06B)
                  : const Color(0xFF237DED),
            ),
          ],
        ),
      ),
    );
  }
}
