import 'dart:async';

import 'package:flutter/material.dart';

import 'smart_card_models.dart';
import 'smart_card_page.dart';
import 'smart_card_repository.dart';

final class SmartCardEntryPage extends StatefulWidget {
  const SmartCardEntryPage({
    required this.request,
    required this.dataSource,
    this.onUnlock,
    super.key,
  });

  final SmartCardRequest request;
  final SmartCardDataSource dataSource;
  final SmartCardUnlockLauncher? onUnlock;

  @override
  State<SmartCardEntryPage> createState() => _SmartCardEntryPageState();
}

final class _SmartCardEntryPageState extends State<SmartCardEntryPage> {
  SmartCardEntry? _entry;
  Object? _error;
  int _resolveGeneration = 0;

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
    SmartCardEntry entry;
    try {
      entry = await widget.dataSource.resolveEntry(widget.request);
    } catch (error) {
      if (!mounted || generation != _resolveGeneration) return;
      setState(() => _error = error);
      return;
    }
    if (!mounted || generation != _resolveGeneration) return;
    if (entry.destination == SmartCardEntryDestination.unavailable) {
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
        appBar: AppBar(title: const Text('技巧卡片')),
        body: Center(
          key: const ValueKey('smart-card-entry-error'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('入口加载失败，请重试'),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('smart-card-entry-retry'),
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
          key: ValueKey('smart-card-entry-loading'),
          child: CircularProgressIndicator(),
        ),
      );
    }
    return switch (entry.destination) {
      SmartCardEntryDestination.page => SmartCardPage(
        request: widget.request,
        dataSource: widget.dataSource,
        isVip: entry.isVip,
        initialCatalog: entry.catalog,
        onUnlock: widget.onUnlock,
      ),
      SmartCardEntryDestination.empty => const _EmptyEntry(),
      SmartCardEntryDestination.unavailable => const _EmptyEntry(),
    };
  }
}

final class _EmptyEntry extends StatelessWidget {
  const _EmptyEntry();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('技巧卡片')),
      body: const Center(
        key: ValueKey('smart-card-entry-empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.style_outlined, size: 44, color: Color(0xFF7A869A)),
            SizedBox(height: 12),
            Text('暂无技巧卡片'),
          ],
        ),
      ),
    );
  }
}
