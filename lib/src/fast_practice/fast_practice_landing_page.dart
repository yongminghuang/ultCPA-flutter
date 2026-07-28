import 'dart:async';

import 'package:flutter/material.dart';

import '../main_tabs/main_tabs_models.dart';

const _assetRoot = 'assets/images/fast_practice';

typedef FastPracticeUnlockLauncher = FutureOr<void> Function();

final class FastPracticeLandingPage extends StatelessWidget {
  const FastPracticeLandingPage({
    required this.module,
    this.onUnlock,
    super.key,
  });

  final HomeModule module;
  final FastPracticeUnlockLauncher? onUnlock;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FastHero(),
                const SizedBox(height: 8),
                const _SectionTitle(text: '为什么选择速成300题?'),
                const SizedBox(height: 14),
                const _FastComparison(),
                const SizedBox(height: 26),
                const _SectionTitle(text: '功能亮点'),
                const SizedBox(height: 12),
                const _FeatureRow(
                  assetName: 'ic_fast300_feature_book.png',
                  title: '刷1题顶5题',
                  description: '甄选高频母题，吃透1题等于掌握5个考点，拒绝无效刷题！',
                ),
                const _FeatureRow(
                  assetName: 'ic_fast300_feature_medal.png',
                  title: '只刷必考真题',
                  description: '剔除冷门偏题，锁定历年高频原题，刷到的每一题都是分！',
                ),
                const _FeatureRow(
                  assetName: 'ic_fast300_feature_lightning.png',
                  title: '短期稳拿分',
                  description: '独家技巧，10分钟搞懂1类题，冲刺及格线！',
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: IconButton(
                key: const ValueKey('fast-practice-back'),
                tooltip: '返回',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x66000000),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: ColoredBox(
          color: const Color(0xFFFFF8F2),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SizedBox(
              height: 50,
              child: FilledButton(
                key: const ValueKey('fast-practice-unlock'),
                onPressed: () => _unlock(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE5242D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  '立即领取速成300题',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _unlock(BuildContext context) {
    final callback = onUnlock;
    if (callback != null) {
      callback();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('速成300题需解锁，会员与支付功能仍在迁移中')));
  }
}

final class _FastHero extends StatelessWidget {
  const _FastHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('fast-practice-hero'),
      height: 330,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            '$_assetRoot/img_fast300_hero_title.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 54, 28, 16),
              child: Column(
                children: [
                  Image.asset(
                    '$_assetRoot/ic_fast_300.png',
                    width: 250,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '省时拿高分，直击考点，快速通关！',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '时间不够？就用速成300题！',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '300题精选题库 = 省下',
                        style: TextStyle(
                          color: Color(0xFFF54811),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Image.asset(
                        '$_assetRoot/ic_fast_80.png',
                        width: 64,
                        fit: BoxFit.contain,
                      ),
                      const Text(
                        '时间',
                        style: TextStyle(
                          color: Color(0xFFF54811),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFFFB088))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF33333D),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFFFFB088))),
        ],
      ),
    );
  }
}

final class _FastComparison extends StatelessWidget {
  const _FastComparison();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Image.asset(
              '$_assetRoot/img_fast300_bubble.png',
              fit: BoxFit.fill,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 22, 12, 16),
            child: Row(
              children: [
                const Expanded(
                  child: _ComparisonColumn(
                    label: '普通题库',
                    count: '2000题',
                    summary: '超多无效题，费时费力',
                    emphasized: false,
                  ),
                ),
                Image.asset(
                  '$_assetRoot/ic_fast300_vs.png',
                  width: 46,
                  height: 46,
                ),
                const Expanded(
                  child: _ComparisonColumn(
                    label: '速成300题',
                    count: '300题',
                    summary: '少刷题，拿高分！',
                    emphasized: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _ComparisonColumn extends StatelessWidget {
  const _ComparisonColumn({
    required this.label,
    required this.count,
    required this.summary,
    required this.emphasized,
  });

  final String label;
  final String count;
  final String summary;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final color = emphasized
        ? const Color(0xFFF64C10)
        : const Color(0xFF5E5D5A);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          count,
          style: TextStyle(
            color: color,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          summary,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 12, height: 1.35),
        ),
      ],
    );
  }
}

final class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.assetName,
    required this.title,
    required this.description,
  });

  final String assetName;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Image.asset('$_assetRoot/$assetName', width: 42, height: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF7500F),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF33333D),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
