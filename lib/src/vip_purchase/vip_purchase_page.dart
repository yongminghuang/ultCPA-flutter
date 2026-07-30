import 'dart:async';

import 'package:flutter/material.dart';

import 'vip_checkout_coordinator.dart';
import 'vip_payment_gateway.dart';
import 'vip_purchase_marketing.dart';
import 'vip_purchase_models.dart';
import 'vip_purchase_repository.dart';
import 'vip_purchase_success_page.dart';

typedef VipPurchaseActionLauncher = Future<void> Function(BuildContext context);
typedef VipPurchaseLoginLauncher =
    Future<Map<String, dynamic>?> Function(BuildContext context);

final class VipPurchasePage extends StatefulWidget {
  const VipPurchasePage({
    required this.request,
    required this.dataSource,
    required this.paymentGateway,
    this.loginLauncher,
    this.customerServiceLauncher,
    this.agreementLauncher,
    this.differenceUpgradeLauncher,
    super.key,
  });

  final VipPurchaseRequest request;
  final VipPurchaseDataSource dataSource;
  final VipPaymentGateway paymentGateway;
  final VipPurchaseLoginLauncher? loginLauncher;
  final VipPurchaseActionLauncher? customerServiceLauncher;
  final VipPurchaseActionLauncher? agreementLauncher;
  final Future<VipPurchaseResult?> Function(
    BuildContext context,
    VipPurchaseRequest request,
  )?
  differenceUpgradeLauncher;

  @override
  State<VipPurchasePage> createState() => _VipPurchasePageState();
}

final class _VipPurchasePageState extends State<VipPurchasePage> {
  VipPurchaseSession? _session;
  Object? _sessionError;
  bool _loadingSession = true;
  VipProductType? _selectedType;
  Set<int> _selectedSubjectIndices = const {};
  VipPaymentChannel _selectedChannel = VipPaymentChannel.wechat;
  VipSkuSelection? _skuSelection;
  int _selectedSkuIndex = 0;
  bool _loadingSkus = false;
  int _skuGeneration = 0;
  bool _checkoutInFlight = false;
  bool _openingCustomerService = false;
  bool _openingAgreement = false;
  bool _openingDifferenceUpgrade = false;
  VipPurchaseSuccessSummary? _successSummary;
  bool _finishingSuccess = false;
  late final VipCheckoutCoordinator _checkoutCoordinator;

  @override
  void initState() {
    super.initState();
    _checkoutCoordinator = VipCheckoutCoordinator(
      dataSource: widget.dataSource,
      paymentGateway: widget.paymentGateway,
    );
    unawaited(_loadSession());
  }

  Future<void> _loadSession() async {
    _skuGeneration += 1;
    if (mounted) {
      setState(() {
        _loadingSession = true;
        _sessionError = null;
      });
    }
    try {
      final session = await widget.dataSource.loadSession(widget.request);
      if (!mounted) return;
      final differenceLauncher = widget.differenceUpgradeLauncher;
      if (!_openingDifferenceUpgrade &&
          differenceLauncher != null &&
          widget.request.allowDifferenceUpgrade &&
          !session.isFullMember &&
          session.hasPracticePackage) {
        _openingDifferenceUpgrade = true;
        final result = await differenceLauncher(context, widget.request);
        if (mounted) Navigator.of(context).pop(result);
        return;
      }
      final fallback =
          session.initialSubjectIndex >= 0 &&
              session.initialSubjectIndex < session.subjects.length
          ? session.initialSubjectIndex
          : session.subjects.isEmpty
          ? -1
          : 0;
      setState(() {
        _session = session;
        _loadingSession = false;
        _selectedType = session.initialProductType;
        _selectedSubjectIndices = fallback < 0 ? const {} : {fallback};
        _selectedChannel = session.initialPaymentChannel;
        _skuSelection = null;
        _selectedSkuIndex = 0;
      });
      await _loadSkus();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingSession = false;
        _sessionError = error;
      });
    }
  }

  Future<void> _loadSkus() async {
    final session = _session;
    final type = _selectedType;
    if (session == null || type == null || _selectedSubjectIndices.isEmpty) {
      return;
    }
    final generation = ++_skuGeneration;
    final subjects = _selectedSubjectIndices
        .where((index) => index >= 0 && index < session.subjects.length)
        .map((index) => session.subjects[index])
        .toList(growable: false);
    setState(() {
      _loadingSkus = true;
      _skuSelection = null;
      _selectedSkuIndex = 0;
    });
    try {
      final selection = await widget.dataSource.loadSkus(
        session: session,
        type: type,
        subjects: subjects,
      );
      if (!mounted || generation != _skuGeneration) return;
      setState(() {
        _skuSelection = selection;
        _selectedSkuIndex = 0;
        _loadingSkus = false;
      });
    } catch (error) {
      if (!mounted || generation != _skuGeneration) return;
      setState(() {
        _skuSelection = VipSkuSelection(products: const [], skus: const []);
        _loadingSkus = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_errorText(error))));
    }
  }

  void _switchType(VipProductType type) {
    final session = _session;
    if (session == null || type == _selectedType) return;
    final fallback =
        session.initialSubjectIndex >= 0 &&
            session.initialSubjectIndex < session.subjects.length
        ? session.initialSubjectIndex
        : 0;
    setState(() {
      _selectedType = type;
      _selectedSubjectIndices = session.subjects.isEmpty
          ? const {}
          : {fallback};
    });
    unawaited(_loadSkus());
  }

  void _toggleSubject(int index) {
    final next = toggleVipSubject(_selectedSubjectIndices, subjectIndex: index);
    if (_sameIndices(next, _selectedSubjectIndices)) return;
    setState(() => _selectedSubjectIndices = next);
    unawaited(_loadSkus());
  }

  void _toggleAllSubjects() {
    final session = _session;
    if (session == null) return;
    final next = toggleAllVipSubjects(
      _selectedSubjectIndices,
      subjectCount: session.subjects.length,
      fallbackIndex: session.initialSubjectIndex,
    );
    if (_sameIndices(next, _selectedSubjectIndices)) return;
    setState(() => _selectedSubjectIndices = next);
    unawaited(_loadSkus());
  }

  @override
  Widget build(BuildContext context) {
    final successSummary = _successSummary;
    if (successSummary != null) {
      return VipPurchaseSuccessPage(
        summary: successSummary,
        onFinished: _finishSuccess,
        customerServiceLauncher: widget.customerServiceLauncher,
      );
    }
    final session = _session;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8E1D0),
        foregroundColor: const Color(0xFF33333D),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          key: const ValueKey('vip-purchase-back'),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          '开通VIP，急速考证',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: session == null ? null : _buildCheckoutBar(session),
      floatingActionButton: session == null
          ? null
          : SizedBox(
              width: 72,
              height: 72,
              child: InkWell(
                key: const ValueKey('vip-customer-service'),
                onTap:
                    widget.customerServiceLauncher == null ||
                        _openingCustomerService
                    ? null
                    : _openCustomerService,
                child: Image.asset(
                  '${_assetRoot}ic_promotion_add_customer_service.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_loadingSession) {
      return const Center(child: CircularProgressIndicator());
    }
    final session = _session;
    if (session == null) {
      return _SessionFailure(error: _sessionError, onRetry: _loadSession);
    }
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 300,
          child: Image.asset(
            '${_assetRoot}vip_open_accounting_layer_36.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            children: [
              if (session.isLoggedIn && session.benefitLines.isNotEmpty) ...[
                _buildUserHeader(session),
                const SizedBox(height: 12),
              ],
              _buildSelector(session),
              const SizedBox(height: 16),
              _buildPrivilegeSection(session),
              const SizedBox(height: 8),
              _buildMarketing(session),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserHeader(VipPurchaseSession session) {
    final preview = session.benefitLines.take(2).toList(growable: false);
    return Container(
      key: const ValueKey('vip-user-header'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xF7FFFFFF),
        border: Border.all(color: const Color(0x66D7BBA5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 52,
              height: 52,
              child: session.avatarUrl.isEmpty
                  ? Image.asset('${_assetRoot}ic_default_avatar.png')
                  : Image.network(
                      session.avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Image.asset('${_assetRoot}ic_default_avatar.png'),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                for (final line in preview)
                  Text(
                    line.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF596273),
                      fontSize: 11,
                    ),
                  ),
                if (session.benefitLines.length > 2)
                  GestureDetector(
                    onTap: () => _showBenefits(session),
                    child: const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Text(
                        '查看更多',
                        style: TextStyle(
                          color: Color(0xFFB45D45),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelector(VipPurchaseSession session) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xF7FFFFFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final type in session.productTypes)
                Expanded(child: _buildTypeTab(type)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  '请选择 (已选${_selectedSubjectIndices.length}科）',
                  style: const TextStyle(
                    color: Color(0xFF33333D),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              InkWell(
                key: const ValueKey('vip-select-all'),
                onTap: _toggleAllSubjects,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _selectedSubjectIndices.length ==
                                session.subjects.length
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: const Color(0xFFE6533C),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedSubjectIndices.length ==
                                session.subjects.length
                            ? '清除'
                            : '全选',
                        style: const TextStyle(
                          color: Color(0xFF33333D),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < session.subjects.length; index++)
                _buildSubjectChip(session.subjects[index], index),
            ],
          ),
          const SizedBox(height: 14),
          _buildPriceCards(),
        ],
      ),
    );
  }

  Widget _buildTypeTab(VipProductType type) {
    final selected = type == _selectedType;
    return InkWell(
      key: ValueKey('vip-type-${type.name}'),
      onTap: () => _switchType(type),
      child: SizedBox(
        height: 34,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                type.label,
                style: TextStyle(
                  color: const Color(0xFF33333D),
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 20,
              height: 3,
              color: selected ? const Color(0xFFE6533C) : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectChip(VipSubject subject, int index) {
    final selected = _selectedSubjectIndices.contains(index);
    final label = subject.name.startsWith('经济法') ? '经济法' : subject.name;
    return Material(
      key: ValueKey('vip-subject-${subject.id}'),
      color: selected ? const Color(0xFFFFECE6) : const Color(0xFFF4F4F5),
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: () => _toggleSubject(index),
        borderRadius: BorderRadius.circular(5),
        child: Container(
          constraints: const BoxConstraints(minWidth: 82, minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? const Color(0xFFE6533C)
                  : const Color(0xFFE2E2E4),
            ),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFFE6533C),
                  size: 14,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: const Color(0xFF33333D),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceCards() {
    if (_loadingSkus) return const SizedBox(height: 104);
    final selection = _skuSelection;
    if (selection == null || selection.skus.isEmpty) {
      return const SizedBox.shrink();
    }
    final productSkus = selection.products
        .expand((product) => product.skus)
        .toList(growable: false);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < selection.skus.length; index++) ...[
            _PriceCard(
              cardKey: ValueKey('vip-price-card-$index'),
              sku: selection.skus[index],
              dailyText: formatVipDailyPrice(
                totalPrice: selection.skus[index].totalPrice,
                subjectCount: selection.skus[index].shopCart.length,
                days: resolveVipSkuDays(
                  selection.skus[index].skuName,
                  productSkus,
                ),
              ),
              selected: index == _selectedSkuIndex,
              onTap: () => setState(() => _selectedSkuIndex = index),
            ),
            if (index != selection.skus.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildPrivilegeSection(VipPurchaseSession session) {
    final type = _selectedType ?? VipProductType.skill;
    final privileges = vipPrivilegesFor(type);
    final bonus = vipBonusPrivilegesFor(type);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            _privilegeTitle(session, type),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF0F0F0F), fontSize: 17),
          ),
          if (type != VipProductType.course) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEFE5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '200+答题技巧 一技巧练多题',
                style: TextStyle(color: Color(0xFFF85B0C), fontSize: 11),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _PrivilegeGrid(items: privileges),
          if (bonus.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '加赠权益',
                style: TextStyle(
                  color: Color(0xFF33333D),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _PrivilegeGrid(items: bonus),
          ],
        ],
      ),
    );
  }

  String _privilegeTitle(VipPurchaseSession session, VipProductType type) {
    if (type == VipProductType.svip) return '尊享全能 SVIP无缝通关';
    String selectionName;
    if (_selectedSubjectIndices.length >= 2) {
      selectionName = session.level;
    } else if (_selectedSubjectIndices.isNotEmpty) {
      final index = _selectedSubjectIndices.first;
      final raw = session.subjects[index].name;
      selectionName = raw.startsWith('经济法') ? '经济法' : raw;
    } else {
      selectionName = '';
    }
    return type == VipProductType.course
        ? '畅听 $selectionName 课程视频'
        : '畅享 $selectionName 答题技巧';
  }

  Widget _buildMarketing(VipPurchaseSession session) {
    final content = resolveVipPurchaseMarketing(
      category: session.category,
      level: session.level,
    );
    return Column(
      children: [
        _PainMarketing(content: content),
        const SizedBox(height: 12),
        if (content.showAccountingGuarantee)
          _AccountingGuarantee(content: content),
        if (content.showSocialComparison) _SocialGuarantee(content: content),
        const SizedBox(height: 12),
        const _ExampleMarketing(),
        const SizedBox(height: 12),
        _StudentShares(content: content),
      ],
    );
  }

  Widget _buildCheckoutBar(VipPurchaseSession session) {
    final sku = _selectedSku;
    final enabled =
        !_loadingSkus &&
        !_checkoutInFlight &&
        sku != null &&
        sku.shopCart.isNotEmpty;
    final priceText = _loadingSkus
        ? '加载中'
        : sku == null
        ? '暂无商品'
        : '¥${formatVipMoney(sku.totalPrice)}';
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: Color(0xFFF9F9FB),
          boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 8)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (session.showWechatPay)
                  _PaymentChannelButton(
                    buttonKey: const ValueKey('vip-payment-wechat'),
                    label: '微信',
                    assetName: 'icon_vip_wx.png',
                    selected: _selectedChannel == VipPaymentChannel.wechat,
                    onTap: () => setState(
                      () => _selectedChannel = VipPaymentChannel.wechat,
                    ),
                  ),
                if (session.showWechatPay) const SizedBox(width: 28),
                _PaymentChannelButton(
                  buttonKey: const ValueKey('vip-payment-alipay'),
                  label: '支付宝',
                  assetName: 'icon_vip_zfb.png',
                  selected: _selectedChannel == VipPaymentChannel.alipay,
                  onTap: () => setState(
                    () => _selectedChannel = VipPaymentChannel.alipay,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Material(
              key: const ValueKey('vip-checkout-button'),
              color: enabled
                  ? const Color(0xFFE94F3D)
                  : const Color(0xFFD7D7DA),
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: enabled ? () => unawaited(_checkout()) : null,
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '限时特惠：',
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      Text(
                        priceText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(width: 1, height: 22, color: Color(0x80FFFFFF)),
                      const SizedBox(width: 10),
                      Text(
                        _checkoutInFlight ? '支付中' : '立即支付',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            InkWell(
              key: const ValueKey('vip-agreement'),
              onTap: widget.agreementLauncher == null || _openingAgreement
                  ? null
                  : _openAgreement,
              child: const Padding(
                padding: EdgeInsets.only(top: 9, bottom: 2),
                child: Text(
                  '开通前请阅读《考有招会员协议》',
                  style: TextStyle(color: Color(0xFF999999), fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  VipCommonSku? get _selectedSku {
    final skus = _skuSelection?.skus ?? const [];
    if (_selectedSkuIndex < 0 || _selectedSkuIndex >= skus.length) return null;
    return skus[_selectedSkuIndex];
  }

  Future<void> _checkout() async {
    if (_checkoutInFlight || _loadingSkus) return;
    final session = _session;
    final sku = _selectedSku;
    if (session == null || sku == null || sku.shopCart.isEmpty) return;

    setState(() => _checkoutInFlight = true);
    try {
      if (!session.isLoggedIn) {
        await _loginAndReload();
        return;
      }

      final outcome = await _checkoutCoordinator.checkout(
        session: session,
        channel: _selectedChannel,
        shopCart: sku.shopCart,
        isActive: () => mounted,
      );
      if (!mounted) return;
      switch (outcome.status) {
        case VipCheckoutStatus.paid:
          await _loadSuccessSummary(session);
          return;
        case VipCheckoutStatus.cancelled:
          return;
        case VipCheckoutStatus.failed:
          _showMessage(outcome.message);
          return;
      }
    } catch (error) {
      if (mounted) _showMessage(_errorText(error));
    } finally {
      if (mounted) setState(() => _checkoutInFlight = false);
    }
  }

  Future<void> _loadSuccessSummary(VipPurchaseSession session) async {
    var summary = const VipPurchaseSuccessSummary.generic();
    try {
      summary = await widget.dataSource.loadSuccessSummary(session);
    } catch (_) {
      // A confirmed payment must still reach the success surface.
    }
    if (!mounted) return;
    setState(() => _successSummary = summary);
  }

  void _finishSuccess() {
    if (_finishingSuccess || !mounted) return;
    _finishingSuccess = true;
    Navigator.of(context).pop(VipPurchaseResult.paid);
  }

  Future<void> _loginAndReload() async {
    final launcher = widget.loginLauncher;
    if (launcher == null) {
      _showMessage('请先登录账号');
      return;
    }
    final result = await launcher(context);
    if (!mounted || result == null) return;
    await _loadSession();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openCustomerService() async {
    final launcher = widget.customerServiceLauncher;
    if (launcher == null || _openingCustomerService) return;
    setState(() => _openingCustomerService = true);
    try {
      await launcher(context);
    } finally {
      if (mounted) setState(() => _openingCustomerService = false);
    }
  }

  Future<void> _openAgreement() async {
    final launcher = widget.agreementLauncher;
    if (launcher == null || _openingAgreement) return;
    setState(() => _openingAgreement = true);
    try {
      await launcher(context);
    } finally {
      if (mounted) setState(() => _openingAgreement = false);
    }
  }

  Future<void> _showBenefits(VipPurchaseSession session) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('会员权益'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in session.benefitLines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(line.text),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

final class _SessionFailure extends StatelessWidget {
  const _SessionFailure({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '加载失败，请重试',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error.toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF777777), fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              key: const ValueKey('vip-purchase-retry'),
              onPressed: onRetry,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.cardKey,
    required this.sku,
    required this.dailyText,
    required this.selected,
    required this.onTap,
  });

  final Key cardKey;
  final VipCommonSku sku;
  final String dailyText;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: cardKey,
      color: selected ? const Color(0xFFFFF3EA) : const Color(0xFFF7F7F8),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 104,
          height: 104,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? const Color(0xFFE6533C)
                  : const Color(0xFFE2E2E4),
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                sku.skuName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF33333D),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                formatVipMoney(sku.totalPrice),
                style: const TextStyle(
                  color: Color(0xFFE6533C),
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                dailyText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF33333D),
                  backgroundColor: selected
                      ? const Color(0xFFE6533C)
                      : const Color(0xFFE9E9EB),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _PrivilegeGrid extends StatelessWidget {
  const _PrivilegeGrid({required this.items});

  final List<VipPrivilege> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = items.length > 4 ? 3 : items.length;
        final width = columns == 0
            ? constraints.maxWidth
            : constraints.maxWidth / columns;
        return Wrap(
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 3,
                  ),
                  child: Column(
                    children: [
                      Image.asset(
                        '$_assetRoot${item.assetName}',
                        width: 38,
                        height: 38,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            color: Color(0xFF33333D),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (item.subtitle != null)
                        Text(
                          item.subtitle!,
                          style: const TextStyle(
                            color: Color(0xFF8A8A91),
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

final class _PaymentChannelButton extends StatelessWidget {
  const _PaymentChannelButton({
    required this.buttonKey,
    required this.label,
    required this.assetName,
    required this.selected,
    required this.onTap,
  });

  final Key buttonKey;
  final String label;
  final String assetName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: buttonKey,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: const Color(0xFFE6533C),
            ),
            const SizedBox(width: 5),
            Image.asset('$_assetRoot$assetName', width: 18, height: 18),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

final class _PainMarketing extends StatelessWidget {
  const _PainMarketing({required this.content});

  final VipPurchaseMarketing content;

  @override
  Widget build(BuildContext context) {
    return _MarketingFrame(
      frameKey: const ValueKey('vip-marketing-pain'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MarketingTitle('技巧人群痛点'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < vipPurchasePainPoints.length;
                      index++
                    )
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE6533C),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                vipPurchasePainPoints[index],
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Image.asset(
                '${_assetRoot}vip_open_accounting_asset_7cb1f20d.png',
                width: 104,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _AccountingGuarantee extends StatelessWidget {
  const _AccountingGuarantee({required this.content});

  final VipPurchaseMarketing content;

  @override
  Widget build(BuildContext context) {
    return _MarketingFrame(
      frameKey: const ValueKey('vip-marketing-accounting'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MarketingTitle('技巧内容保障'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _GuaranteePanel(
                  title: '你是否面临以下问题',
                  items: const [
                    '死记硬背知识点回头忘',
                    '无效刷题，刷不到重点',
                    '听课但做题不会',
                    '学习时间有限',
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GuaranteePanel(
                  title: '方法比努力更重要',
                  tags: content.guaranteeTags,
                  items: content.guaranteeBullets,
                  accent: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _SocialGuarantee extends StatelessWidget {
  const _SocialGuarantee({required this.content});

  final VipPurchaseMarketing content;

  @override
  Widget build(BuildContext context) {
    return _MarketingFrame(
      frameKey: const ValueKey('vip-marketing-social'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MarketingTitle('技巧内容保障'),
          const SizedBox(height: 12),
          for (final row in content.socialComparisons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _ComparisonCell(
                      title: row.leftTitle,
                      description: row.leftDescription,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _ComparisonCell(
                      title: row.rightTitle,
                      description: row.rightDescription,
                      accent: true,
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

final class _ExampleMarketing extends StatelessWidget {
  const _ExampleMarketing();

  @override
  Widget build(BuildContext context) {
    return _MarketingFrame(
      frameKey: const ValueKey('vip-marketing-example'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MarketingTitle('技巧实例'),
          const SizedBox(height: 10),
          Image.asset(
            '${_assetRoot}vip_open_accounting_group_14_v2.png',
            width: double.infinity,
            fit: BoxFit.fitWidth,
          ),
        ],
      ),
    );
  }
}

final class _StudentShares extends StatelessWidget {
  const _StudentShares({required this.content});

  final VipPurchaseMarketing content;

  @override
  Widget build(BuildContext context) {
    return _MarketingFrame(
      frameKey: const ValueKey('vip-marketing-shares'),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('千万考生的', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 5),
              Image.asset(
                '${_assetRoot}vip_open_accounting_layer_28.png',
                height: 28,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final vertical = constraints.maxWidth < 310;
              final cards = content.studentShares
                  .map((share) => _ShareCard(share: share))
                  .toList(growable: false);
              return vertical
                  ? Column(
                      children: [
                        for (var index = 0; index < cards.length; index++) ...[
                          cards[index],
                          if (index != cards.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var index = 0; index < cards.length; index++) ...[
                          Expanded(child: cards[index]),
                          if (index != cards.length - 1)
                            const SizedBox(width: 8),
                        ],
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }
}

final class _MarketingFrame extends StatelessWidget {
  const _MarketingFrame({required this.frameKey, required this.child});

  final Key frameKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 337),
        child: Container(
          key: frameKey,
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF8),
            image: const DecorationImage(
              image: AssetImage(
                '${_assetRoot}vip_open_accounting_layer_25.png',
              ),
              alignment: Alignment.topRight,
              fit: BoxFit.fitWidth,
            ),
            border: Border.all(color: const Color(0xFFF0D8C7)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      ),
    );
  }
}

final class _MarketingTitle extends StatelessWidget {
  const _MarketingTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Color(0xFFF36B3F),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

final class _GuaranteePanel extends StatelessWidget {
  const _GuaranteePanel({
    required this.title,
    required this.items,
    this.tags = const [],
    this.accent = false,
  });

  final String title;
  final List<String> items;
  final List<String> tags;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent ? const Color(0xFFFFE4D3) : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: accent ? const Color(0xFF843B18) : const Color(0xFF33333D),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final tag in tags)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              color: const Color(0xFFB45D45),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tag,
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
            ),
          const SizedBox(height: 5),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    accent
                        ? '${_assetRoot}vip_open_accounting_asset_c18dffb6.png'
                        : '${_assetRoot}vip_open_accounting_group_14.png',
                    width: 10,
                    height: 10,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: accent
                            ? const Color(0xFFB45D45)
                            : const Color(0xFF33333D),
                        fontSize: 9,
                      ),
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

final class _ComparisonCell extends StatelessWidget {
  const _ComparisonCell({
    required this.title,
    required this.description,
    this.accent = false,
  });

  final String title;
  final String description;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: accent ? const Color(0xFFFFE8D9) : const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }
}

final class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.share});

  final VipStudentShare share;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6EF),
        border: Border.all(color: const Color(0xFFF1D9C9)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            share.name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            share.content,
            style: const TextStyle(fontSize: 9, height: 1.45),
          ),
        ],
      ),
    );
  }
}

bool _sameIndices(Set<int> left, Set<int> right) {
  return left.length == right.length && left.containsAll(right);
}

String _errorText(Object error) {
  final text = error.toString().trim();
  return text.isEmpty ? '加载失败，请重试' : text;
}

const _assetRoot = 'assets/images/vip_purchase/';
