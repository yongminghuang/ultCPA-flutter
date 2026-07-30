import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_pay_sheet.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_payment_gateway.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_models.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_repository.dart';

void main() {
  testWidgets('eligible sheet delegates to difference upgrade once', (
    tester,
  ) async {
    VipPurchaseRequest? differenceRequest;
    final dataSource = _DataSource(
      sessionHandler: (_) async => _session(hasPracticePackage: true),
      skuHandler: (_, _, _) async => _selection(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: _Host(
          dataSource: dataSource,
          differenceUpgradeLauncher: (_, request) async {
            differenceRequest = request;
            return VipPurchaseResult.paid;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-vip-pay-sheet')));
    await tester.pumpAndSettle();

    expect(differenceRequest?.differencePayPageSourceId, 2003);
    expect(dataSource.skuTypes, isEmpty);
    expect(find.byKey(const ValueKey('vip-pay-sheet')), findsNothing);
    expect(find.text('result:paid'), findsOneWidget);
  });

  testWidgets(
    'renders the Android popup and updates subject and SKU selection',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final dataSource = _DataSource(
        sessionHandler: (_) async => _session(),
        skuHandler: (_, type, subjects) async => _selection(type: type),
      );

      await tester.pumpWidget(MaterialApp(home: _Host(dataSource: dataSource)));
      await tester.tap(find.byKey(const ValueKey('open-vip-pay-sheet')));
      await tester.pumpAndSettle();

      final sheet = find.byKey(const ValueKey('vip-pay-sheet'));
      expect(sheet, findsOneWidget);
      expect(tester.getSize(sheet).height, lessThanOrEqualTo(640 * 0.82 + 1));
      expect(find.byKey(const ValueKey('vip-pay-sheet-close')), findsOneWidget);
      expect(find.text('答题技巧VIP'), findsOneWidget);
      expect(find.text('全能 SVIP'), findsOneWidget);
      expect(find.text('课程VIP'), findsOneWidget);
      expect(find.text('会计实务'), findsOneWidget);
      expect(find.text('经济法基础'), findsOneWidget);
      expect(find.text('月卡'), findsOneWidget);
      expect(find.text('季卡'), findsOneWidget);
      expect(find.text('速成300题'), findsOneWidget);
      expect(find.text('立即支付'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('vip-pay-sheet-subject-1')));
      await tester.pumpAndSettle();
      expect(dataSource.skuSubjects.last, const [
        VipSubject(id: 6, name: '会计实务'),
        VipSubject(id: 7, name: '经济法基础'),
      ]);

      await tester.tap(find.byKey(const ValueKey('vip-pay-sheet-price-1')));
      await tester.pump();
      expect(find.text('¥59.9'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('vip-pay-sheet-type-course')));
      await tester.pumpAndSettle();
      expect(dataSource.skuTypes.last, VipProductType.course);
      expect(dataSource.skuSubjects.last, const [
        VipSubject(id: 6, name: '会计实务'),
      ]);
    },
  );

  testWidgets('hides WeChat and uses the saved Alipay channel', (tester) async {
    final dataSource = _DataSource(
      sessionHandler: (_) async => _session(
        showWechatPay: false,
        initialChannel: VipPaymentChannel.alipay,
      ),
      skuHandler: (_, _, _) async => _selection(),
    );

    await tester.pumpWidget(MaterialApp(home: _Host(dataSource: dataSource)));
    await tester.tap(find.byKey(const ValueKey('open-vip-pay-sheet')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('vip-pay-sheet-channel-wechat')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('vip-pay-sheet-channel-alipay')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
  });

  testWidgets('successful login reloads without automatically ordering', (
    tester,
  ) async {
    var loginCalls = 0;
    final dataSource = _DataSource(
      sessionHandler: (_) async => _session(
        isLoggedIn: dataSourceSessionCalls > 0,
        initialChannel: VipPaymentChannel.alipay,
      ),
      skuHandler: (_, _, _) async => _selection(),
    );
    dataSourceSessionCalls = -1;
    dataSource.sessionBeforeLoad = () => dataSourceSessionCalls += 1;

    await tester.pumpWidget(
      MaterialApp(
        home: _Host(
          dataSource: dataSource,
          loginLauncher: (_) async {
            loginCalls += 1;
            return {'isLoggedIn': true};
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-vip-pay-sheet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vip-pay-sheet-checkout')));
    await tester.pumpAndSettle();

    expect(loginCalls, 1);
    expect(dataSource.sessionCalls, 2);
    expect(dataSource.orderCalls, 0);
    expect(find.byKey(const ValueKey('vip-pay-sheet')), findsOneWidget);
  });

  testWidgets('Alipay success opens the success page then returns paid', (
    tester,
  ) async {
    final dataSource = _DataSource(
      sessionHandler: (_) async =>
          _session(initialChannel: VipPaymentChannel.alipay),
      skuHandler: (_, _, _) async => _selection(),
      orderHandler: (_, _, _) async => _alipayOrder,
      successSummaryHandler: (_) async => const VipPurchaseSuccessSummary(
        title: '恭喜！会员开通成功',
        expiresOn: '2026-08-01',
        hasMemberTier: true,
      ),
    );
    final gateway = _Gateway(alipayResult: _successfulPayment);

    await tester.pumpWidget(
      MaterialApp(
        home: _Host(dataSource: dataSource, gateway: gateway),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-vip-pay-sheet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vip-pay-sheet-checkout')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('vip-pay-sheet')), findsNothing);
    expect(find.text('恭喜！会员开通成功'), findsOneWidget);
    expect(find.text('有效期至 2026-08-01'), findsOneWidget);
    expect(dataSource.orderCalls, 1);
    expect(gateway.alipayOrders, ['signed-order']);
    expect(find.text('result:none'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('vip-success-back')));
    await tester.pumpAndSettle();
    expect(find.text('result:paid'), findsOneWidget);
  });

  testWidgets('cancellation stays silent and failure restores checkout', (
    tester,
  ) async {
    final dataSource = _DataSource(
      sessionHandler: (_) async =>
          _session(initialChannel: VipPaymentChannel.alipay),
      skuHandler: (_, _, _) async => _selection(),
      orderHandler: (_, _, _) async => _alipayOrder,
    );
    final gateway = _Gateway(alipayResult: _cancelledPayment);

    await tester.pumpWidget(
      MaterialApp(
        home: _Host(dataSource: dataSource, gateway: gateway),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-vip-pay-sheet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vip-pay-sheet-checkout')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.byKey(const ValueKey('vip-pay-sheet')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('vip-pay-sheet-checkout')),
          )
          .onPressed,
      isNotNull,
    );

    gateway.alipayResult = const VipNativePaymentResult(
      status: VipNativePaymentStatus.failed,
      message: '支付通道忙',
    );
    await tester.tap(find.byKey(const ValueKey('vip-pay-sheet-checkout')));
    await tester.pumpAndSettle();
    expect(find.text('支付通道忙'), findsOneWidget);
    expect(find.byKey(const ValueKey('vip-pay-sheet')), findsOneWidget);
  });

  testWidgets('fits compact Android viewports without overflow', (
    tester,
  ) async {
    for (final size in [const Size(320, 568), const Size(360, 640)]) {
      await tester.binding.setSurfaceSize(size);
      final dataSource = _DataSource(
        sessionHandler: (_) async => _session(),
        skuHandler: (_, _, _) async => _selection(),
      );
      await tester.pumpWidget(MaterialApp(home: _Host(dataSource: dataSource)));
      await tester.tap(find.byKey(const ValueKey('open-vip-pay-sheet')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.tap(find.byKey(const ValueKey('vip-pay-sheet-close')));
      await tester.pumpAndSettle();
    }
    await tester.binding.setSurfaceSize(null);
  });
}

int dataSourceSessionCalls = 0;

final class _Host extends StatefulWidget {
  const _Host({
    required this.dataSource,
    this.gateway,
    this.loginLauncher,
    this.differenceUpgradeLauncher,
  });

  final VipPurchaseDataSource dataSource;
  final VipPaymentGateway? gateway;
  final VipPaySheetLoginLauncher? loginLauncher;
  final Future<VipPurchaseResult?> Function(BuildContext, VipPurchaseRequest)?
  differenceUpgradeLauncher;

  @override
  State<_Host> createState() => _HostState();
}

final class _HostState extends State<_Host> {
  VipPurchaseResult? _result;

  Future<void> _open() async {
    final result = await showVipPaySheet(
      context,
      request: VipPurchaseRequest.popup(entry: VipPayEntry.fast300),
      dataSource: widget.dataSource,
      paymentGateway: widget.gateway ?? _Gateway(),
      loginLauncher: widget.loginLauncher,
      differenceUpgradeLauncher: widget.differenceUpgradeLauncher,
    );
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('result:${_result?.name ?? 'none'}'),
          FilledButton(
            key: const ValueKey('open-vip-pay-sheet'),
            onPressed: _open,
            child: const Text('open'),
          ),
        ],
      ),
    );
  }
}

VipPurchaseSession _session({
  bool isLoggedIn = true,
  bool showWechatPay = true,
  VipPaymentChannel initialChannel = VipPaymentChannel.wechat,
  bool hasPracticePackage = false,
}) {
  return VipPurchaseSession(
    request: VipPurchaseRequest.popup(entry: VipPayEntry.fast300),
    category: 'joy-ledger',
    level: '初级会计',
    subjects: const [
      VipSubject(id: 6, name: '会计实务'),
      VipSubject(id: 7, name: '经济法基础'),
    ],
    initialSubjectIndex: 0,
    productTypes: const [
      VipProductType.svip,
      VipProductType.skill,
      VipProductType.course,
    ],
    initialProductType: VipProductType.skill,
    isLoggedIn: isLoggedIn,
    showWechatPay: showWechatPay,
    initialPaymentChannel: initialChannel,
    payPageSourceId: 1010,
    nickname: '',
    avatarUrl: '',
    benefitLines: const [],
    hasPracticePackage: hasPracticePackage,
  );
}

VipSkuSelection _selection({VipProductType type = VipProductType.skill}) {
  return VipSkuSelection(
    products: [
      VipProduct(
        productId: 'product-${type.name}',
        productName: type.label,
        category: 'joy-ledger',
        level: '初级会计',
        subject: '会计实务',
        productType: type.apiValue,
        skus: const [
          VipProductSku(skuName: '月卡', benefitsExpiryMinute: 43200),
          VipProductSku(skuName: '季卡', benefitsExpiryMinute: 129600),
        ],
      ),
    ],
    skus: [
      VipCommonSku(
        skuName: '月卡',
        totalPrice: 29.9,
        shopCart: const [
          VipShopCartItem(productId: 'product', productSkuId: 1),
        ],
      ),
      VipCommonSku(
        skuName: '季卡',
        totalPrice: 59.9,
        shopCart: const [
          VipShopCartItem(productId: 'product', productSkuId: 2),
        ],
      ),
    ],
  );
}

const _alipayOrder = VipPaymentOrder(
  orderId: 'ali-order',
  alipayOrderInfo: 'signed-order',
);

const _successfulPayment = VipNativePaymentResult(
  status: VipNativePaymentStatus.success,
);

const _cancelledPayment = VipNativePaymentResult(
  status: VipNativePaymentStatus.cancelled,
);

final class _DataSource implements VipPurchaseDataSource {
  _DataSource({
    required this.sessionHandler,
    required this.skuHandler,
    this.orderHandler,
    this.successSummaryHandler,
  });

  final Future<VipPurchaseSession> Function(VipPurchaseRequest request)
  sessionHandler;
  final Future<VipSkuSelection> Function(
    VipPurchaseSession session,
    VipProductType type,
    List<VipSubject> subjects,
  )
  skuHandler;
  final Future<VipPaymentOrder> Function(
    VipPurchaseSession session,
    VipPaymentChannel channel,
    List<VipShopCartItem> shopCart,
  )?
  orderHandler;
  final Future<VipPurchaseSuccessSummary> Function(VipPurchaseSession session)?
  successSummaryHandler;
  void Function()? sessionBeforeLoad;
  int sessionCalls = 0;
  int orderCalls = 0;
  final skuTypes = <VipProductType>[];
  final skuSubjects = <List<VipSubject>>[];

  @override
  Future<VipPurchaseSession> loadSession(VipPurchaseRequest request) {
    sessionBeforeLoad?.call();
    sessionCalls += 1;
    return sessionHandler(request);
  }

  @override
  Future<VipSkuSelection> loadSkus({
    required VipPurchaseSession session,
    required VipProductType type,
    required List<VipSubject> subjects,
  }) {
    final copy = List<VipSubject>.unmodifiable(subjects);
    skuTypes.add(type);
    skuSubjects.add(copy);
    return skuHandler(session, type, copy);
  }

  @override
  Future<VipPaymentOrder> createOrder({
    required VipPurchaseSession session,
    required VipPaymentChannel channel,
    required List<VipShopCartItem> shopCart,
  }) {
    orderCalls += 1;
    return orderHandler?.call(session, channel, shopCart) ??
        Future.value(_alipayOrder);
  }

  @override
  Future<bool> confirmWechatPayment() async => true;

  @override
  Future<VipPurchaseSuccessSummary> loadSuccessSummary(
    VipPurchaseSession session,
  ) {
    return successSummaryHandler?.call(session) ??
        Future.value(const VipPurchaseSuccessSummary.generic());
  }
}

final class _Gateway implements VipPaymentGateway {
  _Gateway({this.alipayResult = _cancelledPayment});

  VipNativePaymentResult alipayResult;
  final alipayOrders = <String>[];

  @override
  Future<bool> isWechatInstalled() async => true;

  @override
  Future<VipNativePaymentResult> payAlipay(String orderInfo) async {
    alipayOrders.add(orderInfo);
    return alipayResult;
  }

  @override
  Future<VipNativePaymentResult> payWechat(
    VipWechatCredential credential,
  ) async => _cancelledPayment;
}
