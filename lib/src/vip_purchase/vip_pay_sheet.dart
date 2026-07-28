import 'dart:async';

import 'package:flutter/material.dart';

import 'vip_checkout_coordinator.dart';
import 'vip_payment_gateway.dart';
import 'vip_purchase_models.dart';
import 'vip_purchase_repository.dart';
import 'vip_purchase_success_page.dart';

typedef VipPaySheetLoginLauncher =
    Future<Map<String, dynamic>?> Function(BuildContext context);
typedef VipPaySheetActionLauncher = Future<void> Function(BuildContext context);

Future<VipPurchaseResult?> showVipPaySheet(
  BuildContext context, {
  required VipPurchaseRequest request,
  required VipPurchaseDataSource dataSource,
  required VipPaymentGateway paymentGateway,
  VipPaySheetLoginLauncher? loginLauncher,
  VipPaySheetActionLauncher? agreementLauncher,
  VipPaySheetActionLauncher? customerServiceLauncher,
}) async {
  final paid = await showModalBottomSheet<_VipPaySheetPaid>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8A000000),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.82,
      alignment: Alignment.bottomCenter,
      child: VipPaySheet(
        request: request,
        dataSource: dataSource,
        paymentGateway: paymentGateway,
        loginLauncher: loginLauncher,
        agreementLauncher: agreementLauncher,
      ),
    ),
  );
  if (paid == null) return null;

  var summary = const VipPurchaseSuccessSummary.generic();
  try {
    summary = await dataSource.loadSuccessSummary(paid.session);
  } catch (_) {
    // Confirmed payment must still reach the success surface.
  }
  if (!context.mounted) return VipPurchaseResult.paid;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (successContext) => VipPurchaseSuccessPage(
        summary: summary,
        onFinished: () => Navigator.of(successContext).pop(),
        customerServiceLauncher: customerServiceLauncher,
      ),
    ),
  );
  return VipPurchaseResult.paid;
}

final class VipPaySheet extends StatefulWidget {
  const VipPaySheet({
    required this.request,
    required this.dataSource,
    required this.paymentGateway,
    this.loginLauncher,
    this.agreementLauncher,
    super.key,
  });

  final VipPurchaseRequest request;
  final VipPurchaseDataSource dataSource;
  final VipPaymentGateway paymentGateway;
  final VipPaySheetLoginLauncher? loginLauncher;
  final VipPaySheetActionLauncher? agreementLauncher;

  @override
  State<VipPaySheet> createState() => _VipPaySheetState();
}

final class _VipPaySheetState extends State<VipPaySheet> {
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
  bool _openingAgreement = false;
  bool _closing = false;
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
      final fallback = _fallbackSubjectIndex(session);
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
        _selectedSkuIndex = selection.skus.isEmpty ? -1 : 0;
        _loadingSkus = false;
      });
    } catch (error) {
      if (!mounted || generation != _skuGeneration) return;
      setState(() {
        _skuSelection = VipSkuSelection(products: const [], skus: const []);
        _selectedSkuIndex = -1;
        _loadingSkus = false;
      });
      _showMessage(_errorText(error));
    }
  }

  void _switchType(VipProductType type) {
    final session = _session;
    if (session == null || type == _selectedType || _checkoutInFlight) return;
    final fallback = _fallbackSubjectIndex(session);
    setState(() {
      _selectedType = type;
      _selectedSubjectIndices = fallback < 0 ? const {} : {fallback};
    });
    unawaited(_loadSkus());
  }

  void _toggleSubject(int index) {
    if (_checkoutInFlight) return;
    final next = toggleVipSubject(_selectedSubjectIndices, subjectIndex: index);
    if (_sameIndices(next, _selectedSubjectIndices)) return;
    setState(() => _selectedSubjectIndices = next);
    unawaited(_loadSkus());
  }

  void _toggleAllSubjects() {
    final session = _session;
    if (session == null || _checkoutInFlight) return;
    final next = toggleAllVipSubjects(
      _selectedSubjectIndices,
      subjectCount: session.subjects.length,
      fallbackIndex: session.initialSubjectIndex,
    );
    if (_sameIndices(next, _selectedSubjectIndices)) return;
    setState(() => _selectedSubjectIndices = next);
    unawaited(_loadSkus());
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
        isActive: () => mounted && !_closing,
      );
      if (!mounted || _closing) return;
      switch (outcome.status) {
        case VipCheckoutStatus.paid:
          _closing = true;
          Navigator.of(context).pop(_VipPaySheetPaid(session));
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
      if (mounted && !_closing) setState(() => _checkoutInFlight = false);
    }
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

  void _close() {
    if (_closing || _checkoutInFlight) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return PopScope<Object?>(
      canPop: !_checkoutInFlight,
      child: Material(
        key: const ValueKey('vip-pay-sheet'),
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
            if (session != null) _buildFooter(session),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            '开通VIP',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          Positioned(
            right: 4,
            child: IconButton(
              key: const ValueKey('vip-pay-sheet-close'),
              tooltip: '关闭',
              onPressed: _checkoutInFlight ? null : _close,
              icon: const Icon(Icons.close_rounded, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingSession) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sessionError != null || _session == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('加载失败，请重试'),
            const SizedBox(height: 10),
            OutlinedButton(
              key: const ValueKey('vip-pay-sheet-retry'),
              onPressed: _loadSession,
              child: const Text('重新加载'),
            ),
          ],
        ),
      );
    }
    final session = _session!;
    return SingleChildScrollView(
      key: const ValueKey('vip-pay-sheet-scroll'),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTypeTabs(session),
          const SizedBox(height: 16),
          _buildSubjectHeader(session),
          const SizedBox(height: 9),
          _buildSubjects(session),
          const SizedBox(height: 16),
          const Text(
            '选择套餐',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _buildPriceCards(),
          const SizedBox(height: 18),
          _buildPrivileges(),
        ],
      ),
    );
  }

  Widget _buildTypeTabs(VipPurchaseSession session) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          for (final type in session.productTypes)
            Expanded(
              child: InkWell(
                key: ValueKey('vip-pay-sheet-type-${type.name}'),
                onTap: () => _switchType(type),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      type.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: type == _selectedType
                            ? const Color(0xFF1F83E0)
                            : const Color(0xFF666666),
                        fontSize: 14,
                        fontWeight: type == _selectedType
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 7),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 28,
                      height: 3,
                      color: type == _selectedType
                          ? const Color(0xFF1F83E0)
                          : Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubjectHeader(VipPurchaseSession session) {
    final allSelected =
        session.subjects.isNotEmpty &&
        _selectedSubjectIndices.length == session.subjects.length;
    return Row(
      children: [
        Text(
          '选择科目（${_selectedSubjectIndices.length}科）',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        TextButton.icon(
          key: const ValueKey('vip-pay-sheet-select-all'),
          onPressed: _checkoutInFlight ? null : _toggleAllSubjects,
          icon: Icon(
            allSelected ? Icons.check_box : Icons.check_box_outline_blank,
            size: 18,
          ),
          label: Text(allSelected ? '清除' : '全选'),
        ),
      ],
    );
  }

  Widget _buildSubjects(VipPurchaseSession session) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < session.subjects.length; index++)
          ChoiceChip(
            key: ValueKey('vip-pay-sheet-subject-$index'),
            label: Text(session.subjects[index].name),
            selected: _selectedSubjectIndices.contains(index),
            onSelected: (_) => _toggleSubject(index),
            showCheckmark: true,
            selectedColor: const Color(0xFFEAF5FF),
            side: BorderSide(
              color: _selectedSubjectIndices.contains(index)
                  ? const Color(0xFF2792F0)
                  : const Color(0xFFD7D7D7),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }

  Widget _buildPriceCards() {
    if (_loadingSkus) {
      return const SizedBox(
        height: 104,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final selection = _skuSelection;
    if (selection == null || selection.skus.isEmpty) {
      return const SizedBox(height: 72, child: Center(child: Text('暂无商品')));
    }
    final productSkus = selection.products
        .expand((product) => product.skus)
        .toList(growable: false);
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: selection.skus.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final sku = selection.skus[index];
          final selected = index == _selectedSkuIndex;
          final days = resolveVipSkuDays(sku.skuName, productSkus);
          final daily = formatVipDailyPrice(
            totalPrice: sku.totalPrice,
            subjectCount: sku.shopCart.length,
            days: days,
          );
          return InkWell(
            key: ValueKey('vip-pay-sheet-price-$index'),
            onTap: _checkoutInFlight
                ? null
                : () => setState(() => _selectedSkuIndex = index),
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 118,
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFF3FAFF) : Colors.white,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF2792F0)
                      : const Color(0xFFD9D9D9),
                  width: selected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  Text(
                    sku.skuName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¥${formatVipMoney(sku.totalPrice)}',
                    style: const TextStyle(
                      color: Color(0xFFE5242D),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    daily,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrivileges() {
    final type = _selectedType;
    if (type == null) return const SizedBox.shrink();
    final privileges = vipPrivilegesFor(type);
    final bonus = vipBonusPrivilegesFor(type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '会员权益',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: privileges.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisExtent: 66,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (_, index) => _PrivilegeTile(privileges[index]),
        ),
        if (bonus.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            '加赠课程权益',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final privilege in bonus) _BonusPrivilegeRow(privilege),
        ],
      ],
    );
  }

  Widget _buildFooter(VipPurchaseSession session) {
    final sku = _selectedSku;
    final enabled =
        !_loadingSkus && !_checkoutInFlight && sku?.shopCart.isNotEmpty == true;
    final amount = sku == null ? '' : '¥${formatVipMoney(sku.totalPrice)}';
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEAEAEA))),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (session.showWechatPay)
                  Expanded(
                    child: _ChannelControl(
                      key: const ValueKey('vip-pay-sheet-channel-wechat'),
                      label: '微信支付',
                      icon: Icons.chat_bubble_outline,
                      selected: _selectedChannel == VipPaymentChannel.wechat,
                      onTap: _checkoutInFlight
                          ? null
                          : () => setState(
                              () => _selectedChannel = VipPaymentChannel.wechat,
                            ),
                    ),
                  ),
                if (session.showWechatPay) const SizedBox(width: 8),
                Expanded(
                  child: _ChannelControl(
                    key: const ValueKey('vip-pay-sheet-channel-alipay'),
                    label: '支付宝',
                    icon: Icons.account_balance_wallet_outlined,
                    selected: _selectedChannel == VipPaymentChannel.alipay,
                    onTap: _checkoutInFlight
                        ? null
                        : () => setState(
                            () => _selectedChannel = VipPaymentChannel.alipay,
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                key: const ValueKey('vip-pay-sheet-checkout'),
                onPressed: enabled ? _checkout : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE5242D),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD6D6D6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: _checkoutInFlight
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : _loadingSkus
                    ? const Text('加载中')
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (amount.isNotEmpty) ...[
                            Text(
                              amount,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            _selectedSubjectIndices.isEmpty
                                ? '请选择科目'
                                : sku == null
                                ? '暂无商品'
                                : '立即支付',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
              ),
            ),
            InkWell(
              key: const ValueKey('vip-pay-sheet-agreement'),
              onTap: widget.agreementLauncher == null || _openingAgreement
                  ? null
                  : _openAgreement,
              child: const Padding(
                padding: EdgeInsets.only(top: 7),
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _VipPaySheetPaid {
  const _VipPaySheetPaid(this.session);

  final VipPurchaseSession session;
}

final class _PrivilegeTile extends StatelessWidget {
  const _PrivilegeTile(this.privilege);

  final VipPrivilege privilege;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/images/vip_purchase/${privilege.assetName}',
          width: 30,
          height: 30,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 5),
        Text(
          privilege.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }
}

final class _BonusPrivilegeRow extends StatelessWidget {
  const _BonusPrivilegeRow(this.privilege);

  final VipPrivilege privilege;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Image.asset(
            'assets/images/vip_purchase/${privilege.assetName}',
            width: 26,
            height: 26,
          ),
          const SizedBox(width: 8),
          Text(privilege.title),
          if (privilege.subtitle case final String subtitle) ...[
            const SizedBox(width: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

final class _ChannelControl extends StatelessWidget {
  const _ChannelControl({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 34,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF444444)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected
                  ? const Color(0xFF2792F0)
                  : const Color(0xFFAAAAAA),
            ),
          ],
        ),
      ),
    );
  }
}

int _fallbackSubjectIndex(VipPurchaseSession session) {
  if (session.subjects.isEmpty) return -1;
  return session.initialSubjectIndex >= 0 &&
          session.initialSubjectIndex < session.subjects.length
      ? session.initialSubjectIndex
      : 0;
}

bool _sameIndices(Set<int> left, Set<int> right) {
  return left.length == right.length && left.containsAll(right);
}

String _errorText(Object error) {
  final text = error.toString().trim();
  return text.isEmpty ? '加载失败，请重试' : text;
}
