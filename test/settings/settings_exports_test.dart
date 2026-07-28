import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/ultcpa_flutter.dart';

void main() {
  test('exports the complete settings-center public surface', () {
    expect(<Type>[
      SettingsSnapshot,
      SettingsDataSource,
      MethodChannelSettingsDataSource,
      SettingsPage,
      PrivacySettingsPage,
      AboutPage,
    ], hasLength(6));

    void agreementLauncher(BuildContext context, AgreementDocument document) {}
    AccountSafetyResult? accountLauncher(BuildContext context) => null;
    Future<void> mineLauncher(BuildContext context, bool isLoggedIn) async {}
    final SettingsAgreementLauncher typedAgreement = agreementLauncher;
    final SettingsAccountSafetyLauncher typedAccount = accountLauncher;
    final MineSettingsLauncher typedMine = mineLauncher;
    expect(typedAgreement, isNotNull);
    expect(typedAccount, isNotNull);
    expect(typedMine, isNotNull);
  });
}
