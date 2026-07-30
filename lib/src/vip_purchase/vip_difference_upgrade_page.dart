import 'dart:async';

import 'package:flutter/material.dart';

import 'vip_checkout_coordinator.dart';
import 'vip_difference_upgrade_models.dart';
import 'vip_difference_upgrade_repository.dart';
import 'vip_payment_gateway.dart';
import 'vip_purchase_models.dart';
import 'vip_purchase_repository.dart';
import 'vip_purchase_success_page.dart';

typedef VipDifferenceLoginLauncher =
    Future<Map<String, dynamic>?> Function(BuildContext context);
typedef VipDifferenceActionLauncher = Future<void> Function(BuildContext context);
typedef VipNormalPurchaseLauncher =
    Future<VipPurchaseResult?> Function(
      BuildContext context,
      VipPurchaseRequest request,
    );

final class VipDifferenceUpgradePage extends StatefulWidget {
  const VipDifferenceUpgradePage({
    required this.request,
    required this.dataSource,
    required this.purchaseDataSource,
    required this.commodityOrderDataSource,
    required this.paymentGateway,
    required this.normalPurchaseLauncher,
    this.loginLauncher,
    this.agreementLauncher,
    this.customerServiceLauncher,
    super.key,
  });

  final VipPurchaseRequest request;
  final VipDifferenceUpgradeDataSource dataSource;
  final VipPurchaseDataSource purchaseDataSource;
  final VipCommodityOrderDataSource commodityOrderDataSource;
  final VipPaymentGateway paymentGateway;
  final VipNormalPurchaseLauncher normalPurchaseLauncher;
  final VipDifferenceLoginLauncher? loginLauncher;
  final VipDifferenceActionLauncher? agreementLauncher;
  final VipDifferenceActionLauncher? customerServiceLauncher;

  @override
  State<VipDifferenceUpgradePage> createState() =>
      _VipDifferenceUpgradePageState();
}

final class _VipDifferenceUpgradePageState
    extends State<VipDifferenceUpgradePage> {
  VipDifferenceUpgradeSession? _session;
  VipPurchaseSuccessSummary? _successSummary;
  Object? _error;
  bool _loading = true;
  bool _checkoutInFlight = false;
  bool _redirecting = false;
  bool _finishing = false;
  VipPaymentChannel _channel = VipPaymentChannel.wechat;
  late final VipCheckoutCoordinator _checkoutCoordinator;

  @override
  void initState() {
    super.initState();
    _checkoutCoordinator = VipCheckoutCoordinator(
      dataSource: widget.purchaseDataSource,
      paymentGateway: widget.paymentGateway,
    );
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await widget.dataSource.load(widget.request);
      if (!mounted) return;
      setState(() {
        _session = session;
        _loading = false;
        _channel = session.purchaseSession.initialPaymentChannel;
      });
      if (session.shouldOpenNormalPurchase) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_openNormalPurchase());
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _openNormalPurchase() async {
    if (_redirecting) return;
    _redirecting = true;
    final result = await widget.normalPurchaseLauncher(
      context,
      widget.request.withoutDifferenceUpgrade(),
    );
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _checkout() async {
    final session = _session;
    if (_checkoutInFlight || session == null || session.shouldOpenNormalPurchase) {
      return;
    }
    if (!session.purchaseSession.isLoggedIn) {
      final launcher = widget.loginLauncher;
      if (launcher == null) {
        _showMessage('请先登录账号');
        return;
      }
      final result = await launcher(context);
      if (mounted && result != null) await _load();
      return;
    }
    setState(() => _checkoutInFlight = true);
    try {
      final outcome = await _checkoutCoordinator.checkoutCommodity(
        session: session.purchaseSession,
        channel: _channel,
        commodityId: session.commodities.levelMember.commodityId,
        commodityDataSource: widget.commodityOrderDataSource,
        isActive: () => mounted,
      );
      if (!mounted) return;
      switch (outcome.status) {
        case VipCheckoutStatus.paid:
          var summary = const VipPurchaseSuccessSummary.generic();
          try {
            summary = await widget.purchaseDataSource.loadSuccessSummary(
              session.purchaseSession,
            );
          } catch (_) {
            // Confirmed payment still reaches the success surface.
          }
          if (mounted) setState(() => _successSummary = summary);
          return;
        case VipCheckoutStatus.cancelled:
          return;
        case VipCheckoutStatus.failed:
          _showMessage(outcome.message);
      }
    } finally {
      if (mounted) setState(() => _checkoutInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _successSummary;
    if (summary != null) {
      return VipPurchaseSuccessPage(
        summary: summary,
        onFinished: _finishPaid,
        customerServiceLauncher: widget.customerServiceLauncher,
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8E1D0),
        foregroundColor: const Color(0xFF33333D),
        surfaceTintColor: Colors.transparent,
        title: const Text('补差价升级畅学卡'),
      ),
      body: _buildBody(),
      bottomNavigationBar: _session == null || _redirecting
          ? null
          : _buildCheckoutBar(_session!),
    );
  }

  Widget _buildBody() {
    if (_loading || _redirecting) {
      return const Center(child: CircularProgressIndicator());
    }
    final session = _session;
    if (session == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('升级信息加载失败'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _error.toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF9CA3AF)),
                ),
              ),
            TextButton(onPressed: _load, child: const Text('重新加载')),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        _UserBenefitCard(session: session),
        const SizedBox(height: 16),
        _BenefitTable(session: session),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('vip-difference-formula'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3DC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            session.formulaText,
            style: const TextStyle(
              color: Color(0xFF8A4B08),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 18),
        _PaymentChannelTile(
          channel: VipPaymentChannel.wechat,
          selected: _channel == VipPaymentChannel.wechat,
          visible: session.purchaseSession.showWechatPay,
          onTap: () => setState(() => _channel = VipPaymentChannel.wechat),
        ),
        _PaymentChannelTile(
          channel: VipPaymentChannel.alipay,
          selected: _channel == VipPaymentChannel.alipay,
          onTap: () => setState(() => _channel = VipPaymentChannel.alipay),
        ),
        if (widget.agreementLauncher != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('vip-difference-agreement'),
              onPressed: () => widget.agreementLauncher!(context),
              child: const Text('《会员协议》'),
            ),
          ),
      ],
    );
  }

  Widget _buildCheckoutBar(VipDifferenceUpgradeSession session) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: FilledButton(
          key: const ValueKey('vip-difference-checkout'),
          onPressed: _checkoutInFlight ? null : _checkout,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: const Color(0xFFFFA300),
            foregroundColor: const Color(0xFF3D2E00),
          ),
          child: _checkoutInFlight
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  '补差价 ¥${formatVipMoney(session.payAmount)}元 立即升级',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }

  void _finishPaid() {
    if (_finishing || !mounted) return;
    _finishing = true;
    Navigator.of(context).pop(VipPurchaseResult.paid);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _UserBenefitCard extends StatelessWidget {
  const _UserBenefitCard({required this.session});

  final VipDifferenceUpgradeSession session;

  @override
  Widget build(BuildContext context) {
    final purchase = session.purchaseSession;
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              purchase.isLoggedIn && purchase.nickname.trim().isNotEmpty
                  ? purchase.nickname
                  : purchase.isLoggedIn
                  ? '已登录用户'
                  : '未登录',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              purchase.benefitLines.isEmpty
                  ? '当前分类下已购部分权益，升级畅学卡可解锁全部特权'
                  : purchase.benefitLines.map((line) => line.text).join('\n'),
              style: const TextStyle(color: Color(0xFF6B7280), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

final class _BenefitTable extends StatelessWidget {
  const _BenefitTable({required this.session});

  final VipDifferenceUpgradeSession session;

  @override
  Widget build(BuildContext context) {
    const rows = <(String, String?)>[
      ('技巧练题(200+技巧解析)', 'practice_skill'),
      ('速成300题(热门)', 'practice_speed'),
      ('章节练习', 'practice_chapter'),
      ('历年真题卷(近5年真题)', 'past_exams'),
      ('技巧口诀(一技巧练多题)', null),
      ('技巧卡片', null),
      ('最后密押卷(多年押题命中)', null),
      ('考前六页纸(浓缩高频考点)', null),
      ('督学服务', null),
    ];
    return Card(
      color: Colors.white,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(child: Text('功能', textAlign: TextAlign.center)),
                Expanded(child: Text('当前权益', textAlign: TextAlign.center)),
                Expanded(child: Text('升级畅学卡', textAlign: TextAlign.center)),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final row in rows) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  Expanded(child: Text(row.$1, textAlign: TextAlign.center)),
                  Expanded(
                    child: Text(
                      row.$2 == null
                          ? '-'
                          : session.purchaseSession.ownedPracticeBenefitTypes
                                .contains(row.$2)
                          ? '已购买'
                          : '未购买',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Expanded(
                    child: Text('✓', textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
            if (row != rows.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

final class _PaymentChannelTile extends StatelessWidget {
  const _PaymentChannelTile({
    required this.channel,
    required this.selected,
    required this.onTap,
    this.visible = true,
  });

  final VipPaymentChannel channel;
  final bool selected;
  final VoidCallback onTap;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final isWechat = channel == VipPaymentChannel.wechat;
    return Card(
      color: selected ? const Color(0xFFFFF4D6) : Colors.white,
      child: ListTile(
        key: ValueKey('vip-difference-channel-${channel.name}'),
        onTap: onTap,
        leading: Icon(
          isWechat ? Icons.wechat : Icons.account_balance_wallet_outlined,
          color: isWechat ? const Color(0xFF22C55E) : const Color(0xFF1677FF),
        ),
        title: Text(isWechat ? '微信支付' : '支付宝支付'),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? const Color(0xFFFFA300) : const Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}
