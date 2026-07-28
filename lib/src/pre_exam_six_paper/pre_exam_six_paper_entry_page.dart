import 'dart:async';

import 'package:flutter/material.dart';

import '../main_tabs/main_tabs_models.dart';
import 'pre_exam_six_paper_file_transfer.dart';
import 'pre_exam_six_paper_landing_page.dart';
import 'pre_exam_six_paper_models.dart';
import 'pre_exam_six_paper_preview_page.dart';
import 'pre_exam_six_paper_repository.dart';

final class PreExamSixPaperEntryPage extends StatefulWidget {
  const PreExamSixPaperEntryPage({
    required this.module,
    required this.dataSource,
    required this.fileTransfer,
    this.contentBuilder,
    this.onUnlock,
    super.key,
  });

  final HomeModule module;
  final PreExamSixPaperDataSource dataSource;
  final PreExamSixPaperFileTransfer fileTransfer;
  final PreExamSixPaperContentBuilder? contentBuilder;
  final PreExamSixPaperUnlockLauncher? onUnlock;

  @override
  State<PreExamSixPaperEntryPage> createState() =>
      _PreExamSixPaperEntryPageState();
}

final class _PreExamSixPaperEntryPageState
    extends State<PreExamSixPaperEntryPage> {
  PreExamSixPaperEntry? _entry;
  Object? _error;
  int _resolveGeneration = 0;
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  @override
  void dispose() {
    _resolveGeneration += 1;
    super.dispose();
  }

  Future<void> _resolve() async {
    final generation = ++_resolveGeneration;
    if (mounted) {
      setState(() {
        _entry = null;
        _error = null;
      });
    }
    PreExamSixPaperEntry entry;
    try {
      entry = await widget.dataSource.resolveEntry(widget.module);
    } catch (error) {
      if (!mounted || generation != _resolveGeneration) return;
      setState(() => _error = error);
      return;
    }
    if (!mounted || generation != _resolveGeneration) return;
    if (entry.destination == PreExamSixPaperEntryDestination.unavailable) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('入口数据加载中，请稍后重试')));
      final popped = await Navigator.of(context).maybePop();
      if (!mounted || generation != _resolveGeneration) return;
      if (!popped) setState(() => _entry = entry);
      return;
    }
    setState(() => _entry = entry);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('考前6页纸')),
        body: Center(
          key: const ValueKey('pre-exam-six-entry-error'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('入口加载失败，请重试'),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('pre-exam-six-entry-retry'),
                onPressed: _resolve,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    final entry = _entry;
    if (entry == null) {
      return const Scaffold(
        body: Center(
          key: ValueKey('pre-exam-six-entry-loading'),
          child: CircularProgressIndicator(),
        ),
      );
    }
    return switch (entry.destination) {
      PreExamSixPaperEntryDestination.landing => PreExamSixPaperLandingPage(
        module: widget.module,
        onUnlock: widget.onUnlock == null ? null : _unlock,
      ),
      PreExamSixPaperEntryDestination.preview => PreExamSixPaperPreviewPage(
        module: widget.module,
        initialFile: entry.file,
        dataSource: widget.dataSource,
        fileTransfer: widget.fileTransfer,
        contentBuilder: widget.contentBuilder,
      ),
      PreExamSixPaperEntryDestination.empty => const _EmptyEntry(),
      PreExamSixPaperEntryDestination.unavailable => const _EmptyEntry(),
    };
  }

  Future<void> _unlock() async {
    if (_unlocking) return;
    final callback = widget.onUnlock;
    if (callback == null) return;
    _unlocking = true;
    try {
      await Future<void>.sync(callback);
      if (!mounted) return;
      await _resolve();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('解锁入口打开失败，请重试')));
    } finally {
      _unlocking = false;
    }
  }
}

final class _EmptyEntry extends StatelessWidget {
  const _EmptyEntry();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('考前6页纸')),
      body: const Center(
        key: ValueKey('pre-exam-six-entry-empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 44,
              color: Color(0xFF7A869A),
            ),
            SizedBox(height: 12),
            Text('暂无考前6页纸内容'),
          ],
        ),
      ),
    );
  }
}
