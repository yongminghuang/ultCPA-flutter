import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/ultcpa_flutter.dart';

void main() {
  test('exports the complete account-profile public surface', () {
    expect(<Type>[
      AccountProfileSnapshot,
      AccountProfileDataSource,
      AccountProfileNativeStore,
      MethodChannelAccountProfileNativeStore,
      AccountProfileRepository,
      AccountSignOutGateway,
      DioAccountSignOutGateway,
      AccountProfilePage,
    ], hasLength(8));

    expect(AccountProfileResult.values, [AccountProfileResult.signedOut]);
  });
}
