import 'package:flutter/services.dart';

import 'customer_service_data_source.dart';

const customerServiceFallbackUrl =
    'https://work.weixin.qq.com/u/vcd963cf9c328b1b9f?src=wx&bb=a184893e4e';

abstract interface class CustomerServiceMiniProgramGateway {
  Future<void> launch(String h5Url);
}

final class MethodChannelCustomerServiceGateway
    implements CustomerServiceMiniProgramGateway {
  MethodChannelCustomerServiceGateway({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.xmzj.ult.agg/mine_actions';

  final MethodChannel _channel;

  @override
  Future<void> launch(String h5Url) {
    return _channel.invokeMethod<void>('openCustomerServiceMiniProgram', {
      'url': h5Url,
    });
  }
}

final class CustomerServiceCoordinator {
  const CustomerServiceCoordinator({
    required CustomerServiceDataSource dataSource,
    required CustomerServiceMiniProgramGateway gateway,
  }) : _dataSource = dataSource,
       _gateway = gateway;

  final CustomerServiceDataSource _dataSource;
  final CustomerServiceMiniProgramGateway _gateway;

  Future<void> open() async {
    var url = customerServiceFallbackUrl;
    try {
      final remoteUrl = await _dataSource.loadUrl();
      if (remoteUrl != null && remoteUrl.isNotEmpty) url = remoteUrl;
    } catch (_) {
      // Android deliberately falls back when the remote URL cannot be used.
    }
    await _gateway.launch(url);
  }
}
