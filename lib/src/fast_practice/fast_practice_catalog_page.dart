import 'dart:async';

import 'package:flutter/material.dart';

import '../main_tabs/main_tabs_models.dart';
import '../practice/flat_practice_progress_store.dart';
import '../practice/practice_page.dart';
import '../practice/practice_repository.dart';
import '../practice/practice_settings_store.dart';
import 'fast_practice_models.dart';
import 'fast_practice_repository.dart';

typedef FastPracticeLauncher =
    Future<void> Function(BuildContext context, FastPracticeRequest request);

final class FastPracticeCatalogPage extends StatefulWidget {
  const FastPracticeCatalogPage({
    required this.module,
    required this.dataSource,
    this.practiceDataSource,
    this.practiceLauncher,
    this.flatProgressStore = const DisabledFlatPracticeProgressStore(),
    this.settingsStore = const DisabledPracticeSettingsStore(),
    this.paymentLauncher,
    super.key,
  }) : assert(practiceDataSource != null || practiceLauncher != null);

  final HomeModule module;
  final FastPracticeDataSource dataSource;
  final PracticeDataSource? practiceDataSource;
  final FastPracticeLauncher? practiceLauncher;
  final FlatPracticeProgressStore flatProgressStore;
  final PracticeSettingsStore settingsStore;
  final PracticePaymentLauncher? paymentLauncher;

  @override
  State<FastPracticeCatalogPage> createState() =>
      _FastPracticeCatalogPageState();
}

final class _FastPracticeCatalogPageState
    extends State<FastPracticeCatalogPage> {
  FastPracticeCatalog? _catalog;
  Object? _error;
  bool _loading = true;
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
      final catalog = await widget.dataSource.loadCatalog(widget.module);
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _catalog = catalog;
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
    final title = widget.module.name.trim();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF263238),
        elevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: Text(title.isEmpty ? '速成200题' : title),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        key: ValueKey('fast-practice-catalog-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      return Center(
        key: const ValueKey('fast-practice-catalog-error'),
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
              key: const ValueKey('fast-practice-catalog-retry'),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新加载'),
            ),
          ],
        ),
      );
    }
    final leaves = _catalog!.leaves;
    if (leaves.isEmpty) {
      return const Center(
        key: ValueKey('fast-practice-catalog-empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 44, color: Color(0xFF7A869A)),
            SizedBox(height: 12),
            Text('暂无速成练习内容'),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: leaves.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 16, color: Color(0xFFE8ECF0)),
      itemBuilder: (context, index) {
        final leaf = leaves[index];
        return ListTile(
          key: ValueKey('fast-practice-leaf-${leaf.id}'),
          tileColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          minTileHeight: 58,
          title: Text(
            leaf.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF263238),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF97A0AF),
          ),
          onTap: () => _selectLeaf(leaf),
        );
      },
    );
  }

  Future<void> _selectLeaf(FastPracticeLeaf leaf) async {
    final request = FastPracticeRequest(
      module: widget.module,
      shelfId: leaf.id,
      shelfName: leaf.name,
      shelfType: leaf.type,
    );
    final launcher = widget.practiceLauncher;
    if (launcher != null) {
      await launcher(context, request);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PracticePage(
          request: request,
          dataSource: widget.practiceDataSource!,
          flatProgressStore: widget.flatProgressStore,
          settingsStore: widget.settingsStore,
          paymentLauncher: widget.paymentLauncher,
        ),
      ),
    );
  }
}
