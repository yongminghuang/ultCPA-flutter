import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/ultcpa_flutter.dart';

void main() {
  test('exports the complete Mine customer-service public surface', () {
    expect(<Type>[
      CustomerServiceDataSource,
      AppApiCustomerServiceDataSource,
      CustomerServiceMiniProgramGateway,
      MethodChannelCustomerServiceGateway,
      CustomerServiceCoordinator,
      MineCustomerServiceLauncher,
    ], hasLength(6));
    expect(
      customerServiceFallbackUrl,
      'https://work.weixin.qq.com/u/vcd963cf9c328b1b9f?src=wx&bb=a184893e4e',
    );
  });
}
