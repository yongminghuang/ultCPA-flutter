import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_checkout_coordinator.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_payment_gateway.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_models.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_repository.dart';

void main() {
  group('VIP checkout coordinator', () {
    test(
      'rejects an empty cart without touching payment dependencies',
      () async {
        final dataSource = _DataSource();
        final gateway = _Gateway();
        final coordinator = VipCheckoutCoordinator(
          dataSource: dataSource,
          paymentGateway: gateway,
        );

        final outcome = await coordinator.checkout(
          session: _session,
          channel: VipPaymentChannel.wechat,
          shopCart: const [],
        );

        expect(outcome, const VipCheckoutOutcome.failed('请选择商品'));
        expect(dataSource.orderCalls, 0);
        expect(dataSource.confirmCalls, 0);
        expect(gateway.wechatInstalledCalls, 0);
      },
    );

    test('checks WeChat installation before creating an order', () async {
      final dataSource = _DataSource();
      final gateway = _Gateway(wechatInstalled: false);
      final coordinator = VipCheckoutCoordinator(
        dataSource: dataSource,
        paymentGateway: gateway,
      );

      final outcome = await coordinator.checkout(
        session: _session,
        channel: VipPaymentChannel.wechat,
        shopCart: _shopCart,
      );

      expect(outcome, const VipCheckoutOutcome.failed('您没有安装微信'));
      expect(gateway.wechatInstalledCalls, 1);
      expect(dataSource.orderCalls, 0);
    });

    test('creates an Alipay order and accepts only native success', () async {
      final dataSource = _DataSource(order: _alipayOrder);
      final gateway = _Gateway(alipayResult: _success);
      final coordinator = VipCheckoutCoordinator(
        dataSource: dataSource,
        paymentGateway: gateway,
      );

      final outcome = await coordinator.checkout(
        session: _session,
        channel: VipPaymentChannel.alipay,
        shopCart: _shopCart,
      );

      expect(outcome, const VipCheckoutOutcome.paid());
      expect(dataSource.channels, [VipPaymentChannel.alipay]);
      expect(dataSource.carts.single, _shopCart);
      expect(gateway.alipayOrders, ['signed-order']);
      expect(dataSource.confirmCalls, 0);
    });

    test('keeps cancellation silent and normalizes native failures', () async {
      for (final entry in <(VipNativePaymentResult, VipCheckoutOutcome)>[
        (
          const VipNativePaymentResult(
            status: VipNativePaymentStatus.cancelled,
          ),
          const VipCheckoutOutcome.cancelled(),
        ),
        (
          const VipNativePaymentResult(
            status: VipNativePaymentStatus.failed,
            message: ' SDK 拒绝 ',
          ),
          const VipCheckoutOutcome.failed('SDK 拒绝'),
        ),
        (
          const VipNativePaymentResult(
            status: VipNativePaymentStatus.unavailable,
          ),
          const VipCheckoutOutcome.failed('支付失败'),
        ),
      ]) {
        final coordinator = VipCheckoutCoordinator(
          dataSource: _DataSource(order: _alipayOrder),
          paymentGateway: _Gateway(alipayResult: entry.$1),
        );

        expect(
          await coordinator.checkout(
            session: _session,
            channel: VipPaymentChannel.alipay,
            shopCart: _shopCart,
          ),
          entry.$2,
        );
      }
    });

    test('requires server confirmation after WeChat native success', () async {
      for (final confirmed in [true, false]) {
        final dataSource = _DataSource(
          order: _wechatOrder,
          confirmed: confirmed,
        );
        final gateway = _Gateway(wechatResult: _success);
        final coordinator = VipCheckoutCoordinator(
          dataSource: dataSource,
          paymentGateway: gateway,
        );

        final outcome = await coordinator.checkout(
          session: _session,
          channel: VipPaymentChannel.wechat,
          shopCart: _shopCart,
        );

        expect(
          outcome,
          confirmed
              ? const VipCheckoutOutcome.paid()
              : const VipCheckoutOutcome.failed('支付结果确认失败，请稍后重试'),
        );
        expect(gateway.wechatInstalledCalls, 1);
        expect(gateway.wechatCredentials, [_wechatCredential]);
        expect(dataSource.confirmCalls, 1);
      }
    });

    test('turns order and malformed credential errors into messages', () async {
      final orderError = VipCheckoutCoordinator(
        dataSource: _DataSource(orderError: StateError(' order offline ')),
        paymentGateway: _Gateway(),
      );
      final malformedAlipay = VipCheckoutCoordinator(
        dataSource: _DataSource(order: const VipPaymentOrder(orderId: 'bad')),
        paymentGateway: _Gateway(),
      );

      expect(
        await orderError.checkout(
          session: _session,
          channel: VipPaymentChannel.alipay,
          shopCart: _shopCart,
        ),
        const VipCheckoutOutcome.failed('Bad state:  order offline'),
      );
      expect(
        await malformedAlipay.checkout(
          session: _session,
          channel: VipPaymentChannel.alipay,
          shopCart: _shopCart,
        ),
        const VipCheckoutOutcome.failed('支付宝支付参数错误'),
      );
    });

    test(
      'stops before native payment when the host becomes inactive',
      () async {
        var active = true;
        final dataSource = _DataSource(onOrderCreated: () => active = false);
        final gateway = _Gateway();
        final coordinator = VipCheckoutCoordinator(
          dataSource: dataSource,
          paymentGateway: gateway,
        );

        final outcome = await coordinator.checkout(
          session: _session,
          channel: VipPaymentChannel.alipay,
          shopCart: _shopCart,
          isActive: () => active,
        );

        expect(outcome, const VipCheckoutOutcome.cancelled());
        expect(gateway.alipayOrders, isEmpty);
        expect(dataSource.confirmCalls, 0);
      },
    );
  });
}

const _shopCart = [VipShopCartItem(productId: 'product', productSkuId: 7)];

final _session = VipPurchaseSession(
  request: VipPurchaseRequest.popup(entry: VipPayEntry.fast300),
  category: 'joy-ledger',
  level: '初级会计',
  subjects: [VipSubject(id: 6, name: '会计实务')],
  initialSubjectIndex: 0,
  productTypes: [VipProductType.skill],
  initialProductType: VipProductType.skill,
  isLoggedIn: true,
  showWechatPay: true,
  initialPaymentChannel: VipPaymentChannel.wechat,
  payPageSourceId: 1010,
  nickname: '',
  avatarUrl: '',
  benefitLines: [],
);

const _wechatCredential = VipWechatCredential(
  appId: 'app',
  partnerId: 'partner',
  prepayId: 'prepay',
  nonceStr: 'nonce',
  timeStamp: '123',
  packageValue: 'Sign=WXPay',
  sign: 'signature',
);

const _wechatOrder = VipPaymentOrder(
  orderId: 'wx-order',
  wechatCredential: _wechatCredential,
);

const _alipayOrder = VipPaymentOrder(
  orderId: 'ali-order',
  alipayOrderInfo: 'signed-order',
);

const _success = VipNativePaymentResult(status: VipNativePaymentStatus.success);

final class _DataSource implements VipPurchaseDataSource {
  _DataSource({
    this.order = _alipayOrder,
    this.orderError,
    this.confirmed = true,
    this.onOrderCreated,
  });

  final VipPaymentOrder order;
  final Object? orderError;
  final bool confirmed;
  final void Function()? onOrderCreated;
  int orderCalls = 0;
  int confirmCalls = 0;
  final channels = <VipPaymentChannel>[];
  final carts = <List<VipShopCartItem>>[];

  @override
  Future<VipPaymentOrder> createOrder({
    required VipPurchaseSession session,
    required VipPaymentChannel channel,
    required List<VipShopCartItem> shopCart,
  }) async {
    orderCalls += 1;
    channels.add(channel);
    carts.add(List<VipShopCartItem>.unmodifiable(shopCart));
    if (orderError case final Object error) throw error;
    onOrderCreated?.call();
    return order;
  }

  @override
  Future<bool> confirmWechatPayment() async {
    confirmCalls += 1;
    return confirmed;
  }

  @override
  Future<VipPurchaseSession> loadSession(VipPurchaseRequest request) =>
      throw UnimplementedError();

  @override
  Future<VipSkuSelection> loadSkus({
    required VipPurchaseSession session,
    required VipProductType type,
    required List<VipSubject> subjects,
  }) => throw UnimplementedError();

  @override
  Future<VipPurchaseSuccessSummary> loadSuccessSummary(
    VipPurchaseSession session,
  ) => throw UnimplementedError();
}

final class _Gateway implements VipPaymentGateway {
  _Gateway({
    this.wechatInstalled = true,
    this.wechatResult = const VipNativePaymentResult(
      status: VipNativePaymentStatus.cancelled,
    ),
    this.alipayResult = const VipNativePaymentResult(
      status: VipNativePaymentStatus.cancelled,
    ),
  });

  final bool wechatInstalled;
  final VipNativePaymentResult wechatResult;
  final VipNativePaymentResult alipayResult;
  int wechatInstalledCalls = 0;
  final alipayOrders = <String>[];
  final wechatCredentials = <VipWechatCredential>[];

  @override
  Future<bool> isWechatInstalled() async {
    wechatInstalledCalls += 1;
    return wechatInstalled;
  }

  @override
  Future<VipNativePaymentResult> payAlipay(String orderInfo) async {
    alipayOrders.add(orderInfo);
    return alipayResult;
  }

  @override
  Future<VipNativePaymentResult> payWechat(
    VipWechatCredential credential,
  ) async {
    wechatCredentials.add(credential);
    return wechatResult;
  }
}
