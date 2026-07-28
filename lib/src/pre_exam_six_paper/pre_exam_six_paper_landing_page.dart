import 'dart:async';

import 'package:flutter/material.dart';

import '../main_tabs/main_tabs_models.dart';

const _assetRoot = 'assets/images/pre_exam_six_paper';
const _paperBackground = Color(0xFFFFF8F2);
const _accent = Color(0xFFF7500F);
const _text = Color(0xFF33333D);

typedef PreExamSixPaperUnlockLauncher = FutureOr<void> Function();

final class PreExamSixPaperLandingPage extends StatelessWidget {
  const PreExamSixPaperLandingPage({
    required this.module,
    this.onUnlock,
    super.key,
  });

  final HomeModule module;
  final PreExamSixPaperUnlockLauncher? onUnlock;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paperBackground,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Hero(),
                const _LandingContent(),
                const SizedBox(height: 8),
              ],
            ),
          ),
          SafeArea(
            child: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: const ValueKey('pre-exam-six-landing-back'),
                tooltip: '返回',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Image.asset(
                  '$_assetRoot/vip_open_accounting_rect_12.png',
                  width: 8,
                  height: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: ColoredBox(
          color: _paperBackground,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: SizedBox(
              height: 50,
              child: FilledButton(
                key: const ValueKey('pre-exam-six-landing-unlock'),
                onPressed: () => _unlock(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE91927),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  '立即领取考前6页纸',
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
      ..showSnackBar(const SnackBar(content: Text('考前6页纸需解锁，会员与支付功能仍在迁移中')));
  }
}

final class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('pre-exam-six-landing-hero'),
      height: 271,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/fast_practice/img_fast300_hero_title.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 45, 22, 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  FractionallySizedBox(
                    widthFactor: 0.88,
                    child: Image.asset(
                      '$_assetRoot/ic_pre_exam_six_pager_hero_banner.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 3),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE91927),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 38,
                        vertical: 7,
                      ),
                      child: Text(
                        '书太厚背不完？别背了！',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '5小时背完，抢回',
                          style: TextStyle(
                            color: Color(0xFFF54811),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Image.asset(
                          '$_assetRoot/ic_pre_exam_six_pager_80.png',
                          width: 58,
                          height: 29,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
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

final class _LandingContent extends StatelessWidget {
  const _LandingContent();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            width: 300,
            height: 146,
            child: IgnorePointer(
              child: Image.asset(
                '$_assetRoot/vip_open_accounting_layer_25.png',
                fit: BoxFit.fill,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              children: [
                const Text.rich(
                  TextSpan(
                    text: '为什么这6页纸',
                    children: [
                      TextSpan(
                        text: '能救你？',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  style: TextStyle(color: Color(0xFF0F0F0F), fontSize: 17),
                ),
                const SizedBox(height: 9),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _SellingPoint(
                        assetName: 'ic_pre_exam_six_paper_col_years.png',
                        title: '重复率91%',
                        description: '年年从里抽，全是熟面孔！',
                      ),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: _SellingPoint(
                        assetName: 'ic_pre_exam_six_paper_row_time.png',
                        title: '5小时速成',
                        description: '别人还在翻书，你已经背完两轮！',
                      ),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: _SellingPoint(
                        assetName: 'ic_pre_exam_six_paper_row_score.png',
                        title: '5年考11次',
                        description: '精准押题，考场直接“抄答案”',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '为何必背?',
                  style: TextStyle(
                    color: _text,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 15),
                const _BenefitRow(
                  assetName: 'ic_pre_exam_six_paper_col_repeat.png',
                  title: '省时间',
                  description: '别再啃厚书了！这6页纸就是为你量身定制的“作弊条”，背完就有底气。',
                ),
                const SizedBox(height: 8),
                const _BenefitRow(
                  assetName: 'ic_pre_exam_six_paper_col_speed.png',
                  title: '好拿分',
                  description: '专攻高频必考点，不浪费一秒在冷门题上，每一分钟都在涨分。',
                ),
                const SizedBox(height: 8),
                const _BenefitRow(
                  assetName: 'ic_pre_exam_six_paper_row_calm.png',
                  title: '心态稳',
                  description: '手里有这6页纸，进考场心里都不慌。临时抱佛脚，也能稳稳过关！',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _SellingPoint extends StatelessWidget {
  const _SellingPoint({
    required this.assetName,
    required this.title,
    required this.description,
  });

  final String assetName;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 154),
          margin: const EdgeInsets.only(top: 26),
          padding: const EdgeInsets.fromLTRB(6, 30, 6, 11),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                title,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0F0F0F),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(
                width: 21,
                height: 2,
                child: ColoredBox(color: _accent),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 12,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
        Image.asset(
          '$_assetRoot/$assetName',
          width: 52,
          height: 52,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}

final class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
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
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3D5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Image.asset(
            '$_assetRoot/$assetName',
            width: 37,
            height: 37,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 12,
                    height: 1.15,
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
