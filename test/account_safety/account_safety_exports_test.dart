import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/ultcpa_flutter.dart';

void main() {
  test('exports the complete account-safety public surface', () {
    expect(<Type>[
      AccountSafetySnapshot,
      AccountSafetyDataSource,
      AccountSafetyNativeStore,
      MethodChannelAccountSafetyNativeStore,
      AccountSafetyRepository,
      AccountDeactivationGateway,
      DioAccountDeactivationGateway,
      AccountSafetyPage,
      AccountDeactivationPage,
    ], hasLength(9));

    Future<AccountSafetyResult?> launcher(BuildContext context) async {
      return AccountSafetyResult.deactivated;
    }

    final AccountDeactivationLauncher typedLauncher = launcher;
    expect(typedLauncher, isNotNull);
    expect(AccountSafetyResult.values, [AccountSafetyResult.deactivated]);
  });
}
