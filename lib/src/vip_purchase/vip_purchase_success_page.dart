import 'package:flutter/material.dart';

import 'vip_purchase_models.dart';

final class VipPurchaseSuccessPage extends StatefulWidget {
  const VipPurchaseSuccessPage({
    required this.summary,
    required this.onFinished,
    this.customerServiceLauncher,
    super.key,
  });

  final VipPurchaseSuccessSummary summary;
  final VoidCallback onFinished;
  final Future<void> Function(BuildContext context)? customerServiceLauncher;

  @override
  State<VipPurchaseSuccessPage> createState() => _VipPurchaseSuccessPageState();
}

final class _VipPurchaseSuccessPageState extends State<VipPurchaseSuccessPage> {
  bool _finishing = false;
  bool _openingCustomerService = false;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFDF5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFFDF5),
          foregroundColor: const Color(0xFF4B5563),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            key: const ValueKey('vip-success-back'),
            tooltip: '返回',
            onPressed: _finish,
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          title: const SizedBox.shrink(),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            key: const ValueKey('vip-success-scroll'),
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/vip_purchase/icon_open_vip_success.png',
                    key: const ValueKey('vip-success-icon'),
                    width: 72,
                    height: 72,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.summary.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF3D2E00),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.summary.hasMemberTier &&
                    widget.summary.expiresOn.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '有效期至 ${widget.summary.expiresOn}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF3D2E00),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _TeacherCard(),
                const SizedBox(height: 20),
                Material(
                  color: const Color(0xFFFFC300),
                  borderRadius: BorderRadius.circular(25),
                  child: InkWell(
                    key: const ValueKey('vip-success-customer-service'),
                    onTap:
                        widget.customerServiceLauncher == null ||
                            _openingCustomerService
                        ? null
                        : _openCustomerService,
                    borderRadius: BorderRadius.circular(25),
                    child: SizedBox(
                      height: 48,
                      child: Center(
                        child: _openingCustomerService
                            ? const SizedBox.square(
                                key: ValueKey(
                                  'vip-success-customer-service-progress',
                                ),
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF3D2E00),
                                ),
                              )
                            : const Text(
                                '添加班主任，激活专属权益',
                                style: TextStyle(
                                  color: Color(0xFF3D2E00),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
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

  void _finish() {
    if (_finishing) return;
    _finishing = true;
    widget.onFinished();
  }

  Future<void> _openCustomerService() async {
    final launcher = widget.customerServiceLauncher;
    if (_openingCustomerService || launcher == null) return;
    setState(() => _openingCustomerService = true);
    try {
      await launcher(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('暂时无法打开微信客服，请稍后重试')));
    } finally {
      if (mounted) setState(() => _openingCustomerService = false);
    }
  }
}

final class _TeacherCard extends StatelessWidget {
  const _TeacherCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('vip-success-teacher-card'),
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 52,
                child: Icon(
                  Icons.support_agent,
                  size: 28,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text(
                        '专属班主任',
                        style: TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '官方认证',
                          style: TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '5年经验 · 3000+学员 · 好评率99%',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
