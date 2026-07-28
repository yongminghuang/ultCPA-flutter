import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../skill_mnemonics/skill_mnemonics_models.dart';
import '../skill_mnemonics/skill_mnemonics_text.dart';
import 'smart_card_models.dart';
import 'smart_card_repository.dart';

const _assetRoot = 'assets/images/smart_card';
const _pageBackground = Color(0xFFFAD6A5);

typedef SmartCardUnlockLauncher = FutureOr<void> Function();

final class SmartCardPage extends StatefulWidget {
  const SmartCardPage({
    required this.request,
    required this.dataSource,
    required this.isVip,
    this.initialCatalog,
    this.onUnlock,
    super.key,
  });

  final SmartCardRequest request;
  final SmartCardDataSource dataSource;
  final bool isVip;
  final SkillMnemonicsCatalog? initialCatalog;
  final SmartCardUnlockLauncher? onUnlock;

  @override
  State<SmartCardPage> createState() => _SmartCardPageState();
}

final class _SmartCardPageState extends State<SmartCardPage> {
  late SkillMnemonicsCatalog? _catalog = widget.initialCatalog;
  late bool _loading = widget.initialCatalog == null;
  late bool _isVip = widget.isVip;
  Object? _error;
  bool _unlocking = false;
  int _loadGeneration = 0;
  int _currentPage = 0;
  final PageController _pageController = PageController(viewportFraction: 0.92);

  @override
  void initState() {
    super.initState();
    if (_catalog == null) unawaited(_fetchCatalog());
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 600;
          return Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: double.infinity,
                  height: math.min(360, constraints.maxHeight * 0.7),
                  child: Image.asset(
                    '$_assetRoot/bg_smard_card_top.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          key: const ValueKey('smart-card-back'),
                          tooltip: '返回',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Color(0xFF333333),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 30 : 105),
                    Expanded(child: _buildContent()),
                    const SizedBox(height: 5),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _isVip ? null : _buildUnlockBar(),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        key: ValueKey('smart-card-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      return Center(
        key: const ValueKey('smart-card-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('网络开小差了，请稍后重试'),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('smart-card-retry'),
              onPressed: _retry,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    final records = _catalog?.records ?? const <SkillMnemonic>[];
    if (records.isEmpty) {
      return const Center(
        key: ValueKey('smart-card-empty'),
        child: Text('暂无技巧卡片'),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = math.min(468.0, constraints.maxHeight);
        final maxWidth = math.min(312.0, constraints.maxWidth);
        final width = math.min(maxWidth, maxHeight * 2 / 3);
        final height = math.min(maxHeight, width * 3 / 2);
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: PageView.builder(
              key: const ValueKey('smart-card-pager'),
              controller: _pageController,
              itemCount: records.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                return AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  scale: index == _currentPage ? 1 : 0.96,
                  child: _SmartCardItem(
                    item: records[index],
                    index: index,
                    isVip: _isVip,
                    isUnlocked: _isVip || index < 3,
                    onLockedTap: () => _showMessage('开通会员以解锁所有技巧卡片'),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnlockBar() {
    return SafeArea(
      top: false,
      child: ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: SizedBox(
            height: 50,
            child: FilledButton(
              key: const ValueKey('smart-card-unlock'),
              onPressed: _unlocking ? null : _unlock,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE91927),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                '立即领取技巧卡片',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _fetchCatalog() async {
    final generation = ++_loadGeneration;
    try {
      final catalog = await widget.dataSource.loadCatalog(
        widget.request,
        isVip: _isVip,
      );
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
    });
    unawaited(_fetchCatalog());
  }

  Future<void> _unlock() async {
    if (_unlocking) return;
    final callback = widget.onUnlock;
    if (callback == null) {
      _showMessage('技巧卡片需解锁，会员与支付功能仍在迁移中');
      return;
    }
    setState(() => _unlocking = true);
    try {
      await callback();
      if (!mounted) return;
      final entry = await widget.dataSource.resolveEntry(widget.request);
      if (!mounted ||
          entry.destination != SmartCardEntryDestination.page ||
          !entry.isVip) {
        return;
      }
      final prefetched = entry.catalog;
      setState(() {
        _isVip = true;
        _catalog = prefetched;
        _loading = prefetched == null;
        _error = null;
      });
      if (prefetched == null) await _fetchCatalog();
    } catch (_) {
      if (mounted) _showMessage('解锁状态刷新失败，请重试');
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

final class _SmartCardItem extends StatelessWidget {
  const _SmartCardItem({
    required this.item,
    required this.index,
    required this.isVip,
    required this.isUnlocked,
    required this.onLockedTap,
  });

  final SkillMnemonic item;
  final int index;
  final bool isVip;
  final bool isUnlocked;
  final VoidCallback onLockedTap;

  @override
  Widget build(BuildContext context) {
    final locked = !isUnlocked;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 9),
      child: GestureDetector(
        key: ValueKey('smart-card-item-$index'),
        behavior: HitTestBehavior.opaque,
        onTap: locked ? onLockedTap : null,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 42, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFE6EAF2),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    SkillMnemonicHighlightedText(
                      text: item.displayText,
                      terms: item.keywordTerms,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF121212),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const SizedBox(
                      height: 5,
                      width: double.infinity,
                      child: ColoredBox(color: Color(0xFFD6DEFF)),
                    ),
                    const SizedBox(height: 30),
                    Expanded(
                      child: SingleChildScrollView(
                        child: SkillMnemonicHighlightedText(
                          text: item.note,
                          terms: item.keywordTerms,
                          style: const TextStyle(
                            color: Color(0xFF3A3A3A),
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (locked)
              Positioned.fill(
                key: ValueKey('smart-card-lock-$index'),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: const ColoredBox(color: Color(0x55FFFFFF)),
                      ),
                      Center(
                        child: Image.asset(
                          '$_assetRoot/ic_lock.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!isVip)
              Positioned(
                top: 2,
                right: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: index < 3
                        ? const Color(0xFF59CB4B)
                        : const Color(0xFFED3C00),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(5),
                      topLeft: Radius.circular(15),
                      bottomLeft: Radius.circular(15),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    child: Text(
                      index < 3 ? '体验卡片' : '技巧卡片',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
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
