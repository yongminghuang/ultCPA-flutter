import 'vip_payment_gateway.dart';
import 'vip_purchase_models.dart';
import 'vip_purchase_repository.dart';

enum VipCheckoutStatus { paid, cancelled, failed }

final class VipCheckoutOutcome {
  const VipCheckoutOutcome._(this.status, this.message);

  const VipCheckoutOutcome.paid() : this._(VipCheckoutStatus.paid, '');

  const VipCheckoutOutcome.cancelled()
    : this._(VipCheckoutStatus.cancelled, '');

  const VipCheckoutOutcome.failed(String message)
    : this._(VipCheckoutStatus.failed, message);

  final VipCheckoutStatus status;
  final String message;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VipCheckoutOutcome &&
            other.status == status &&
            other.message == message;
  }

  @override
  int get hashCode => Object.hash(status, message);
}

final class VipCheckoutCoordinator {
  const VipCheckoutCoordinator({
    required VipPurchaseDataSource dataSource,
    required VipPaymentGateway paymentGateway,
  }) : _dataSource = dataSource,
       _paymentGateway = paymentGateway;

  final VipPurchaseDataSource _dataSource;
  final VipPaymentGateway _paymentGateway;

  Future<VipCheckoutOutcome> checkout({
    required VipPurchaseSession session,
    required VipPaymentChannel channel,
    required List<VipShopCartItem> shopCart,
    bool Function()? isActive,
  }) {
    if (shopCart.isEmpty) {
      return Future.value(const VipCheckoutOutcome.failed('请选择商品'));
    }
    return _checkout(
      channel: channel,
      isActive: isActive,
      createOrder: () => _dataSource.createOrder(
        session: session,
        channel: channel,
        shopCart: shopCart,
      ),
    );
  }

  Future<VipCheckoutOutcome> checkoutCommodity({
    required VipPurchaseSession session,
    required VipPaymentChannel channel,
    required String commodityId,
    required VipCommodityOrderDataSource commodityDataSource,
    bool Function()? isActive,
  }) {
    if (commodityId.trim().isEmpty) {
      return Future.value(const VipCheckoutOutcome.failed('请选择商品'));
    }
    return _checkout(
      channel: channel,
      isActive: isActive,
      createOrder: () => commodityDataSource.createCommodityOrder(
        session: session,
        channel: channel,
        commodityId: commodityId,
      ),
    );
  }

  Future<VipCheckoutOutcome> _checkout({
    required VipPaymentChannel channel,
    required Future<VipPaymentOrder> Function() createOrder,
    bool Function()? isActive,
  }) async {
    try {
      if (channel == VipPaymentChannel.wechat &&
          !await _paymentGateway.isWechatInstalled()) {
        return const VipCheckoutOutcome.failed('您没有安装微信');
      }
      if (!_isActive(isActive)) {
        return const VipCheckoutOutcome.cancelled();
      }

      final order = await createOrder();
      if (!_isActive(isActive)) {
        return const VipCheckoutOutcome.cancelled();
      }
      final nativeResult = await switch (channel) {
        VipPaymentChannel.wechat => _payWechat(order),
        VipPaymentChannel.alipay => _payAlipay(order),
      };
      if (!_isActive(isActive)) {
        return const VipCheckoutOutcome.cancelled();
      }
      if (nativeResult.status == VipNativePaymentStatus.cancelled) {
        return const VipCheckoutOutcome.cancelled();
      }
      if (nativeResult.status != VipNativePaymentStatus.success) {
        return VipCheckoutOutcome.failed(_paymentFailure(nativeResult));
      }
      if (channel == VipPaymentChannel.wechat &&
          !await _dataSource.confirmWechatPayment()) {
        return const VipCheckoutOutcome.failed('支付结果确认失败，请稍后重试');
      }
      return const VipCheckoutOutcome.paid();
    } catch (error) {
      return VipCheckoutOutcome.failed(_errorText(error));
    }
  }

  Future<VipNativePaymentResult> _payWechat(VipPaymentOrder order) {
    final credential = order.wechatCredential;
    if (credential == null) {
      throw const FormatException('微信支付参数错误');
    }
    return _paymentGateway.payWechat(credential);
  }

  Future<VipNativePaymentResult> _payAlipay(VipPaymentOrder order) {
    final orderInfo = order.alipayOrderInfo?.trim() ?? '';
    if (orderInfo.isEmpty) {
      throw const FormatException('支付宝支付参数错误');
    }
    return _paymentGateway.payAlipay(orderInfo);
  }
}

bool _isActive(bool Function()? callback) => callback?.call() ?? true;

String _paymentFailure(VipNativePaymentResult result) {
  final message = result.message.trim();
  return message.isEmpty ? '支付失败' : message;
}

String _errorText(Object error) {
  if (error case FormatException(:final message)) {
    final text = message.trim();
    return text.isEmpty ? '支付失败' : text;
  }
  final text = error.toString().trim();
  return text.isEmpty ? '支付失败' : text;
}
