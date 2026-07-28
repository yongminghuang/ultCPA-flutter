import 'dart:async';

import 'package:flutter/material.dart';

import '../main_tabs/main_tabs_models.dart';
import '../practice/flat_practice_progress_store.dart';
import '../practice/practice_repository.dart';
import 'fast_practice_catalog_page.dart';
import 'fast_practice_landing_page.dart';
import 'fast_practice_models.dart';
import 'fast_practice_repository.dart';

final class FastPracticeEntryPage extends StatefulWidget {
  const FastPracticeEntryPage({
    required this.module,
    required this.dataSource,
    this.practiceDataSource,
    this.practiceLauncher,
    this.flatProgressStore = const DisabledFlatPracticeProgressStore(),
    this.onUnlock,
    super.key,
  }) : assert(practiceDataSource != null || practiceLauncher != null);

  final HomeModule module;
  final FastPracticeDataSource dataSource;
  final PracticeDataSource? practiceDataSource;
  final FastPracticeLauncher? practiceLauncher;
  final FlatPracticeProgressStore flatProgressStore;
  final FastPracticeUnlockLauncher? onUnlock;

  @override
  State<FastPracticeEntryPage> createState() => _FastPracticeEntryPageState();
}

final class _FastPracticeEntryPageState extends State<FastPracticeEntryPage> {
  FastPracticeEntryDestination? _destination;
  int _resolveVersion = 0;
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  @override
  void dispose() {
    _resolveVersion += 1;
    super.dispose();
  }

  Future<void> _resolve() async {
    final version = ++_resolveVersion;
    FastPracticeEntryDestination destination;
    try {
      destination = await widget.dataSource.resolveEntry(widget.module);
    } catch (_) {
      destination = FastPracticeEntryDestination.empty;
    }
    if (!mounted || version != _resolveVersion) return;
    setState(() => _destination = destination);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_destination) {
      null => const Scaffold(
        body: Center(
          key: ValueKey('fast-practice-entry-loading'),
          child: CircularProgressIndicator(),
        ),
      ),
      FastPracticeEntryDestination.catalog => FastPracticeCatalogPage(
        module: widget.module,
        dataSource: widget.dataSource,
        practiceDataSource: widget.practiceDataSource,
        practiceLauncher: widget.practiceLauncher,
        flatProgressStore: widget.flatProgressStore,
      ),
      FastPracticeEntryDestination.landing => FastPracticeLandingPage(
        module: widget.module,
        onUnlock: widget.onUnlock == null ? null : _unlock,
      ),
      FastPracticeEntryDestination.empty => const Scaffold(
        body: Center(
          key: ValueKey('fast-practice-entry-empty'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 44,
                color: Color(0xFF7A869A),
              ),
              SizedBox(height: 12),
              Text('暂无速成练习内容'),
            ],
          ),
        ),
      ),
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
