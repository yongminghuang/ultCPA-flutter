import 'dart:async';

import 'package:flutter/material.dart';

import '../main_tabs/main_tabs_models.dart';
import 'skill_mnemonics_models.dart';
import 'skill_mnemonics_repository.dart';
import 'skill_mnemonics_text.dart';

typedef SkillMnemonicDetailLauncher =
    Future<void> Function(
      BuildContext context,
      SkillMnemonic item,
      int position,
      HomeModule module,
    );

final class SkillMnemonicsPage extends StatefulWidget {
  const SkillMnemonicsPage({
    required this.module,
    required this.dataSource,
    this.detailLauncher,
    this.isVip,
    super.key,
  });

  final HomeModule module;
  final SkillMnemonicsDataSource dataSource;
  final SkillMnemonicDetailLauncher? detailLauncher;
  final bool? isVip;

  @override
  State<SkillMnemonicsPage> createState() => _SkillMnemonicsPageState();
}

final class _SkillMnemonicsPageState extends State<SkillMnemonicsPage> {
  SkillMnemonicsCatalog? _catalog;
  Object? _error;
  bool _loading = true;
  int _requestNumber = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final requestNumber = ++_requestNumber;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await widget.dataSource.load(widget.module);
      if (!mounted || requestNumber != _requestNumber) return;
      setState(() {
        _catalog = catalog;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestNumber != _requestNumber) return;
      setState(() {
        _catalog = null;
        _error = error;
        _loading = false;
      });
    }
  }

  void _openItem(int index) {
    final catalog = _catalog;
    if (catalog == null) return;
    if (!catalog.isUnlocked(index, isVip: widget.isVip)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('会员与支付功能仍在迁移中')));
      return;
    }
    final launcher = widget.detailLauncher;
    if (launcher != null) {
      unawaited(
        launcher(context, catalog.records[index], index, widget.module),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text(
          _displayTitle(widget.module.name),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _LoadFailure(error: _error, onRetry: _load);
    }
    final catalog = _catalog!;
    if (catalog.records.isEmpty) {
      return const Center(
        child: Text(
          '暂无技巧口诀',
          style: TextStyle(color: Color(0xFF98A1AA), fontSize: 14),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(5),
      itemCount: catalog.records.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, thickness: 1, color: Color(0xFFF2F7F9)),
      itemBuilder: (context, index) {
        final unlocked = catalog.isUnlocked(index, isVip: widget.isVip);
        return _MnemonicRow(
          item: catalog.records[index],
          position: index,
          unlocked: unlocked,
          onTap: () => _openItem(index),
        );
      },
    );
  }
}

final class _MnemonicRow extends StatelessWidget {
  const _MnemonicRow({
    required this.item,
    required this.position,
    required this.unlocked,
    required this.onTap,
  });

  final SkillMnemonic item;
  final int position;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        key: ValueKey('mnemonic-row-$position'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Row(
              children: [
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE3F4FD),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${position + 1}',
                    style: const TextStyle(
                      color: Color(0xFF0BA0E9),
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: unlocked
                      ? SkillMnemonicHighlightedText(
                          key: ValueKey('mnemonic-title-$position'),
                          text: item.displayText,
                          terms: item.keywordTerms,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        )
                      : _LockedMnemonic(position: position),
                ),
                const SizedBox(width: 8),
                if (!unlocked) ...[
                  const Icon(
                    Icons.workspace_premium_outlined,
                    color: Color(0xFFE6A23C),
                    size: 25,
                  ),
                  const SizedBox(width: 4),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 35),
                  child: Text(
                    '${item.questionCount}题',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: Color(0xFFA1A9B2),
                      fontSize: 16,
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
}

final class _LockedMnemonic extends StatelessWidget {
  const _LockedMnemonic({required this.position});

  final int position;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('mnemonic-lock-$position'),
      height: 30,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDF1),
        borderRadius: BorderRadius.circular(3),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: const Text(
        '会员专享技巧口诀',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Color(0xFF9AA3AB), fontSize: 14),
      ),
    );
  }
}

final class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: Color(0xFF98A1AA),
            size: 36,
          ),
          const SizedBox(height: 10),
          const Text('加载失败', style: TextStyle(fontSize: 16)),
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error.toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF98A1AA), fontSize: 12),
            ),
          ],
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新加载'),
          ),
        ],
      ),
    );
  }
}

String _displayTitle(String value) {
  final title = value.trim();
  if (title.isEmpty || title == '大招口诀') return '技巧口诀';
  return title;
}
