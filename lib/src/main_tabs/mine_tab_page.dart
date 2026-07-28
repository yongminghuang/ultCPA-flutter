import 'package:flutter/material.dart';

import '../account_profile/account_profile_models.dart';
import '../vip_purchase/vip_purchase_models.dart';
import '../web/legacy_webview_page.dart';
import 'main_tabs_models.dart';
import 'main_tabs_repository.dart';

enum MineReviewKind { errors, collections }

typedef MineReviewLauncher =
    Future<void> Function(BuildContext context, MineReviewKind kind);

typedef MineSettingsLauncher =
    Future<void> Function(BuildContext context, bool isLoggedIn);

typedef MineProfileLauncher =
    Future<AccountProfileResult?> Function(BuildContext context);

typedef MinePurchaseHistoryLauncher =
    Future<void> Function(BuildContext context);

typedef MineCustomerServiceLauncher =
    Future<void> Function(BuildContext context);

typedef MineAppUpdateLauncher = Future<void> Function(BuildContext context);

typedef MineVipPurchaseLauncher =
    Future<VipPurchaseResult?> Function(BuildContext context);

typedef MineWebLauncher =
    Future<void> Function(BuildContext context, LegacyWebRequest request);

final class MineTabPage extends StatefulWidget {
  const MineTabPage({
    required this.dataSource,
    this.reloadToken = 0,
    this.selectionRevision = 0,
    this.onLoginRequested,
    this.appUpdateLauncher,
    this.customerServiceLauncher,
    this.profileLauncher,
    this.purchaseHistoryLauncher,
    this.reviewLauncher,
    this.settingsLauncher,
    this.vipPurchaseLauncher,
    this.webLauncher,
    super.key,
  });

  final MainTabsDataSource dataSource;
  final int reloadToken;
  final int selectionRevision;
  final Future<void> Function()? onLoginRequested;
  final MineAppUpdateLauncher? appUpdateLauncher;
  final MineCustomerServiceLauncher? customerServiceLauncher;
  final MineProfileLauncher? profileLauncher;
  final MinePurchaseHistoryLauncher? purchaseHistoryLauncher;
  final MineReviewLauncher? reviewLauncher;
  final MineSettingsLauncher? settingsLauncher;
  final MineVipPurchaseLauncher? vipPurchaseLauncher;
  final MineWebLauncher? webLauncher;

  @override
  State<MineTabPage> createState() => _MineTabPageState();
}

final class _MineTabPageState extends State<MineTabPage> {
  MineTabData? _data;
  Object? _error;
  bool _loading = true;
  bool _checkingForUpdate = false;
  bool _openingCustomerService = false;
  bool _openingVipPurchase = false;
  LegacyWebRequest? _openingWebRequest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MineTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken ||
        oldWidget.selectionRevision != widget.selectionRevision) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = _data == null;
        _error = null;
      });
    }
    try {
      final data = await widget.dataSource.loadMine();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: Color(0xFFF8FAFD),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_data == null) {
      return ColoredBox(
        color: const Color(0xFFF8FAFD),
        child: _MineLoadFailure(error: _error, onRetry: _load),
      );
    }
    return ColoredBox(
      color: const Color(0xFFF8FAFD),
      child: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF237DED),
        child: _MineContent(
          data: _data!,
          appUpdateBusy: _checkingForUpdate,
          customerServiceBusy: _openingCustomerService,
          vipPurchaseBusy: _openingVipPurchase,
          openingWebRequest: _openingWebRequest,
          onLoginRequested: widget.onLoginRequested,
          onAppUpdatePressed: widget.appUpdateLauncher == null
              ? null
              : _checkForUpdate,
          onCustomerServicePressed: widget.customerServiceLauncher == null
              ? null
              : _openCustomerService,
          profileLauncher: widget.profileLauncher,
          purchaseHistoryLauncher: widget.purchaseHistoryLauncher,
          reviewLauncher: widget.reviewLauncher,
          settingsLauncher: widget.settingsLauncher,
          onVipPurchasePressed: widget.vipPurchaseLauncher == null
              ? null
              : _openVipPurchase,
          onWebPressed: widget.webLauncher == null ? null : _openWeb,
        ),
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    final launcher = widget.appUpdateLauncher;
    if (_checkingForUpdate || launcher == null) return;
    setState(() => _checkingForUpdate = true);
    try {
      await launcher(context);
    } catch (_) {
      // Android's manual check restores the row without showing error copy.
    } finally {
      if (mounted) setState(() => _checkingForUpdate = false);
    }
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

  Future<void> _openVipPurchase() async {
    final launcher = widget.vipPurchaseLauncher;
    if (_openingVipPurchase || launcher == null) return;
    setState(() => _openingVipPurchase = true);
    try {
      await launcher(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('暂时无法打开会员页面，请稍后重试')));
    } finally {
      if (mounted) setState(() => _openingVipPurchase = false);
    }
  }

  Future<void> _openWeb(LegacyWebRequest request) async {
    final launcher = widget.webLauncher;
    if (_openingWebRequest != null || launcher == null) return;
    setState(() => _openingWebRequest = request);
    try {
      await launcher(context, request);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('暂时无法打开页面，请稍后重试')));
    } finally {
      if (mounted) setState(() => _openingWebRequest = null);
    }
  }
}

final class _MineContent extends StatelessWidget {
  const _MineContent({
    required this.data,
    required this.appUpdateBusy,
    required this.customerServiceBusy,
    required this.vipPurchaseBusy,
    required this.openingWebRequest,
    required this.onLoginRequested,
    required this.onAppUpdatePressed,
    required this.onCustomerServicePressed,
    required this.profileLauncher,
    required this.purchaseHistoryLauncher,
    required this.reviewLauncher,
    required this.settingsLauncher,
    required this.onVipPurchasePressed,
    required this.onWebPressed,
  });

  final MineTabData data;
  final bool appUpdateBusy;
  final bool customerServiceBusy;
  final bool vipPurchaseBusy;
  final LegacyWebRequest? openingWebRequest;
  final Future<void> Function()? onLoginRequested;
  final VoidCallback? onAppUpdatePressed;
  final VoidCallback? onCustomerServicePressed;
  final MineProfileLauncher? profileLauncher;
  final MinePurchaseHistoryLauncher? purchaseHistoryLauncher;
  final MineReviewLauncher? reviewLauncher;
  final MineSettingsLauncher? settingsLauncher;
  final VoidCallback? onVipPurchasePressed;
  final Future<void> Function(LegacyWebRequest request)? onWebPressed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        SizedBox(height: MediaQuery.paddingOf(context).top),
        _UserBand(
          data: data,
          onLoginRequested: onLoginRequested,
          profileLauncher: profileLauncher,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _VipFeaturePanel(
            purchaseBusy: vipPurchaseBusy,
            onPurchase: onVipPurchasePressed,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ColoredBox(
            color: Colors.white,
            child: Column(
              children: [
                _MenuRow(
                  rowKey: const ValueKey('mine-review-errors'),
                  icon: Icons.fact_check_outlined,
                  label: '错题集',
                  count: data.errorCount,
                  onTap: () => _openReview(
                    context,
                    MineReviewKind.errors,
                    data.errorCount,
                  ),
                ),
                _MenuRow(
                  rowKey: const ValueKey('mine-review-collections'),
                  icon: Icons.bookmark_border_rounded,
                  label: '我的收藏',
                  count: data.collectionCount,
                  onTap: () => _openReview(
                    context,
                    MineReviewKind.collections,
                    data.collectionCount,
                  ),
                ),
                _MenuRow(
                  rowKey: const ValueKey('mine-purchase-history'),
                  icon: Icons.shopping_bag_outlined,
                  label: '我的订单',
                  onTap: () => _openPurchaseHistory(context),
                ),
                if (data.collectBookRequest case final request?)
                  _MenuRow(
                    rowKey: const ValueKey('mine-collect-book'),
                    icon: Icons.menu_book_outlined,
                    label: '领取书籍',
                    showProgress: identical(openingWebRequest, request),
                    progressKey: const ValueKey('mine-web-progress'),
                    onTap: openingWebRequest == null
                        ? () => _openWeb(context, request)
                        : null,
                  ),
                if (data.inviteFriendsRequest case final request?)
                  _MenuRow(
                    rowKey: const ValueKey('mine-invite-friends'),
                    icon: Icons.ios_share_rounded,
                    label: '邀请好友',
                    showProgress: identical(openingWebRequest, request),
                    progressKey: const ValueKey('mine-web-progress'),
                    onTap: openingWebRequest == null
                        ? () => _openWeb(context, request)
                        : null,
                  ),
                _MenuRow(
                  rowKey: const ValueKey('mine-customer-service'),
                  icon: Icons.headset_mic_outlined,
                  label: '添加客服',
                  showProgress: customerServiceBusy,
                  progressKey: const ValueKey('mine-customer-service-progress'),
                  onTap: customerServiceBusy ? null : onCustomerServicePressed,
                ),
                _MenuRow(
                  rowKey: const ValueKey('mine-check-update'),
                  icon: Icons.refresh_rounded,
                  label: '检查更新',
                  trailingText: 'V1.2.5',
                  onTap: appUpdateBusy ? null : onAppUpdatePressed,
                ),
                _MenuRow(
                  rowKey: const ValueKey('mine-settings'),
                  icon: Icons.settings_outlined,
                  label: '设置',
                  showDivider: false,
                  onTap: settingsLauncher == null
                      ? null
                      : () => settingsLauncher!(context, data.isLoggedIn),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            children: [
              Text(
                '客服电话: 05926251660',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
              SizedBox(height: 6),
              Text(
                '工作日：9:00-18:00',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
              SizedBox(height: 6),
              Text(
                '联系邮箱:kefu@xmzhujing.com',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openReview(
    BuildContext context,
    MineReviewKind kind,
    int count,
  ) async {
    if (!data.isLoggedIn) {
      await onLoginRequested?.call();
      return;
    }
    if (count <= 0) {
      final message = kind == MineReviewKind.errors ? '还没有错题哟' : '还没有收藏哟';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    await reviewLauncher?.call(context, kind);
  }

  Future<void> _openPurchaseHistory(BuildContext context) async {
    if (!data.isLoggedIn) {
      await onLoginRequested?.call();
      return;
    }
    await purchaseHistoryLauncher?.call(context);
  }

  Future<void> _openWeb(BuildContext context, LegacyWebRequest request) async {
    if (!data.isLoggedIn) {
      await onLoginRequested?.call();
      return;
    }
    await onWebPressed?.call(request);
  }
}

final class _UserBand extends StatelessWidget {
  const _UserBand({
    required this.data,
    required this.onLoginRequested,
    required this.profileLauncher,
  });

  final MineTabData data;
  final Future<void> Function()? onLoginRequested;
  final MineProfileLauncher? profileLauncher;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('mine-profile'),
      color: Colors.white,
      child: InkWell(
        onTap: data.isLoggedIn
            ? profileLauncher == null
                  ? null
                  : () => profileLauncher!(context)
            : onLoginRequested == null
            ? null
            : () => onLoginRequested!(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              _Avatar(url: data.profile.avatar),
              const SizedBox(width: 16),
              if (data.isLoggedIn)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              data.profile.nickname.isEmpty
                                  ? '考友'
                                  : data.profile.nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF111827),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: Color(0xFF9CA3AF),
                          ),
                        ],
                      ),
                      if (data.profile.phone.isNotEmpty ||
                          data.profile.userRole == 'creator') ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (data.profile.phone.isNotEmpty)
                              Flexible(
                                child: Text(
                                  data.profile.phone,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            if (data.profile.userRole == 'creator') ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF191C22),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  '考有招达人',
                                  style: TextStyle(
                                    color: Color(0xFFE5C158),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (data.profile.userId.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'ID: ${data.profile.userId}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: Color(0xFF9CA3AF),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else
                const Text(
                  '一键登录',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final fallback = const ColoredBox(
      color: Color(0xFFEFF4FA),
      child: Image(
        image: AssetImage(_MineAssets.defaultAvatar),
        fit: BoxFit.cover,
      ),
    );
    return ClipOval(
      child: SizedBox(
        width: 72,
        height: 72,
        child: url.isEmpty
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
      ),
    );
  }
}

abstract final class _MineAssets {
  static const defaultAvatar = 'assets/images/main_tabs/ic_default_avatar.png';
}

final class _VipFeaturePanel extends StatelessWidget {
  const _VipFeaturePanel({
    required this.purchaseBusy,
    required this.onPurchase,
  });

  final bool purchaseBusy;
  final VoidCallback? onPurchase;

  static const _features = [
    (Icons.bolt_rounded, '技巧练题'),
    (Icons.edit_note_rounded, '速成300\n题'),
    (Icons.lock_outline_rounded, '最后密押\n卷'),
    (Icons.style_outlined, '技巧口诀'),
    (Icons.library_books_outlined, '考前6\n页纸'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF111827), Color(0xFF1F2937)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final feature in _features)
                Expanded(
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0x26FFFFFF),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              feature.$1,
                              size: 20,
                              color: Color(0xFFFFE6B3),
                            ),
                          ),
                          const Positioned(
                            right: 0,
                            bottom: 0,
                            child: Icon(
                              Icons.lock_rounded,
                              size: 12,
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          feature.$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFE6B3),
                            fontSize: 10,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0x26FFFFFF)),
          const SizedBox(height: 14),
          Material(
            key: const ValueKey('mine-vip-purchase'),
            color: Colors.transparent,
            child: InkWell(
              onTap: purchaseBusy ? null : onPurchase,
              borderRadius: BorderRadius.circular(24),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '解锁全部学习特权',
                      style: TextStyle(color: Color(0xFFFFE6B3), fontSize: 11),
                    ),
                  ),
                  if (purchaseBusy)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      child: SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFFD580),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD580), Color(0xFFFFB732)],
                        ),
                        borderRadius: BorderRadius.circular(64),
                      ),
                      child: const Text(
                        '开通会员',
                        style: TextStyle(
                          color: Color(0xFF593D00),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
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

final class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.rowKey,
    this.count,
    this.trailingText,
    this.onTap,
    this.showDivider = true,
    this.showProgress = false,
    this.progressKey,
  });

  final IconData icon;
  final String label;
  final Key? rowKey;
  final int? count;
  final String? trailingText;
  final VoidCallback? onTap;
  final bool showDivider;
  final bool showProgress;
  final Key? progressKey;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: rowKey,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, size: 22, color: const Color(0xFF475569)),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      border: showDivider
                          ? const Border(
                              bottom: BorderSide(
                                color: Color(0xFFE5E7EB),
                                width: 0.5,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (count != null && count! > 0)
                          Text(
                            '共$count题',
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 13,
                            ),
                          ),
                        if (trailingText != null)
                          Text(
                            trailingText!,
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(width: 6),
                        if (showProgress)
                          SizedBox.square(
                            key: progressKey,
                            dimension: 20,
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF9CA3AF),
                            size: 20,
                          ),
                      ],
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

final class _MineLoadFailure extends StatelessWidget {
  const _MineLoadFailure({required this.error, required this.onRetry});

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
            color: Color(0xFF94A3B8),
            size: 36,
          ),
          const SizedBox(height: 12),
          const Text('个人中心加载失败'),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                error.toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
            ),
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
