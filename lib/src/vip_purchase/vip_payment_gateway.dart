import 'package:flutter/services.dart';

import 'vip_purchase_models.dart';

enum VipNativePaymentStatus { success, cancelled, failed, unavailable }

final class VipNativePaymentResult {
  const VipNativePaymentResult({required this.status, this.message = ''});

  final VipNativePaymentStatus status;
  final String message;
}

abstract interface class VipPaymentGateway {
  Future<bool> isWechatInstalled();

  Future<VipNativePaymentResult> payWechat(VipWechatCredential credential);

  Future<VipNativePaymentResult> payAlipay(String orderInfo);
}

final class MethodChannelVipPaymentGateway implements VipPaymentGateway {
  MethodChannelVipPaymentGateway({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.xmzj.ult.agg/vip_payment';

  final MethodChannel _channel;

  @override
  Future<bool> isWechatInstalled() async {
    try {
      return await _channel.invokeMethod<bool>('isWechatInstalled') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<VipNativePaymentResult> payWechat(VipWechatCredential credential) {
    return _invoke('payWechat', credential.toMap());
  }

  @override
  Future<VipNativePaymentResult> payAlipay(String orderInfo) {
    return _invoke('payAlipay', {'orderInfo': orderInfo});
  }

  Future<VipNativePaymentResult> _invoke(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      final raw = await _channel.invokeMethod<Object?>(method, arguments);
      return _parseResult(raw);
    } on PlatformException catch (error) {
      return VipNativePaymentResult(
        status: VipNativePaymentStatus.failed,
        message: _failureMessage(error.message),
      );
    } on MissingPluginException catch (error) {
      return VipNativePaymentResult(
        status: VipNativePaymentStatus.failed,
        message: _failureMessage(error.message),
      );
    }
  }
}

VipNativePaymentResult _parseResult(Object? raw) {
  if (raw is! Map) return _failedResult();
  final values = Map<Object?, Object?>.from(raw);
  final message = values['message']?.toString() ?? '';
  return switch (values['status']?.toString()) {
    'success' => const VipNativePaymentResult(
      status: VipNativePaymentStatus.success,
    ),
    'cancelled' => const VipNativePaymentResult(
      status: VipNativePaymentStatus.cancelled,
    ),
    'failed' => VipNativePaymentResult(
      status: VipNativePaymentStatus.failed,
      message: _failureMessage(message),
    ),
    'unavailable' => VipNativePaymentResult(
      status: VipNativePaymentStatus.unavailable,
      message: _failureMessage(message),
    ),
    _ => _failedResult(),
  };
}

VipNativePaymentResult _failedResult() => const VipNativePaymentResult(
  status: VipNativePaymentStatus.failed,
  message: '支付失败',
);

String _failureMessage(String? value) {
  final message = value?.trim() ?? '';
  return message.isEmpty ? '支付失败' : message;
}
