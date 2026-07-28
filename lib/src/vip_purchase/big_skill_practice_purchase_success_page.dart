import 'dart:async';

import 'package:flutter/material.dart';

import '../practice/practice_benefit_kind.dart';
import 'big_skill_practice_purchase_success_repository.dart';
import 'vip_purchase_models.dart';

typedef BigSkillPracticeSuccessLauncher =
    Future<void> Function(
      BuildContext context,
      BigSkillPracticeDestination destination,
      PracticeBenefitKind benefitKind,
    );

final class BigSkillPracticePurchaseSuccessPage extends StatefulWidget {
  const BigSkillPracticePurchaseSuccessPage({
    required this.request,
    required this.dataSource,
    required this.practiceLauncher,
    required this.onFinished,
    super.key,
  });

  final BigSkillPracticePurchaseSuccessRequest request;
  final BigSkillPracticePurchaseSuccessDataSource dataSource;
  final BigSkillPracticeSuccessLauncher practiceLauncher;
  final ValueChanged<bool> onFinished;

  @override
  State<BigSkillPracticePurchaseSuccessPage> createState() =>
      _BigSkillPracticePurchaseSuccessPageState();
}

final class _BigSkillPracticePurchaseSuccessPageState
    extends State<BigSkillPracticePurchaseSuccessPage> {
  late BigSkillPracticePurchaseSuccessSummary _summary;
  bool _openingPractice = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _summary = BigSkillPracticePurchaseSuccessSummary.generic(
      widget.request.benefitKind,
    );
    unawaited(_loadSummary());
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await widget.dataSource.loadSummary(
        widget.request.benefitKind,
      );
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (_) {
      // A benefit refresh must not hide a confirmed purchase success.
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(widget.request.navigateHomeOnBack);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFDF5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFFDF5),
          foregroundColor: const Color(0xFF4B5563),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            key: const ValueKey('big-skill-success-back'),
            tooltip: '返回',
            onPressed: () => _finish(widget.request.navigateHomeOnBack),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          title: const SizedBox.shrink(),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            key: const ValueKey('big-skill-success-scroll'),
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/vip_purchase/icon_open_vip_success.png',
                    key: const ValueKey('big-skill-success-icon'),
                    width: 72,
                    height: 72,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _summary.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF3D2E00),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_summary.expiresOn.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '有效期至 ${_summary.expiresOn}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF3D2E00),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Material(
                  key: const ValueKey('big-skill-success-action-card'),
                  color: Colors.white,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Material(
                      key: const ValueKey('big-skill-success-action-material'),
                      color: const Color(0xFF0094FF),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        key: const ValueKey('big-skill-success-action'),
                        onTap: _openingPractice || _finishing
                            ? null
                            : _openPractice,
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 48,
                          child: Center(
                            child: _openingPractice
                                ? const SizedBox.square(
                                    key: ValueKey(
                                      'big-skill-success-action-progress',
                                    ),
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    '去技巧练题',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
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

  Future<void> _openPractice() async {
    if (_openingPractice || _finishing) return;
    setState(() => _openingPractice = true);
    try {
      final destination = await widget.dataSource.loadDestination(
        cachedPracticeModule: widget.request.cachedPracticeModule,
        cachedCircleModule: widget.request.cachedCircleModule,
      );
      if (!mounted || _finishing) return;
      if (destination == null) {
        _showEntryFailure();
        return;
      }
      await widget.practiceLauncher(
        context,
        destination,
        widget.request.benefitKind,
      );
      if (!mounted || _finishing) return;
      _finish(false);
    } catch (_) {
      if (mounted && !_finishing) _showEntryFailure();
    } finally {
      if (mounted) setState(() => _openingPractice = false);
    }
  }

  void _showEntryFailure() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('入口数据加载中，请返回首页后再试')));
  }

  void _finish(bool navigateHome) {
    if (_finishing) return;
    _finishing = true;
    widget.onFinished(navigateHome);
  }
}
