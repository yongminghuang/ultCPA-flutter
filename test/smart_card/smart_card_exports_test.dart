import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/ultcpa_flutter.dart';

void main() {
  test('exports the complete smart-card public surface', () {
    expect(SmartCardEntryDestination.page.name, 'page');
    expect(<Type>[
      SmartCardRequest,
      SmartCardEntry,
      SmartCardDataSource,
      SmartCardRepository,
      SmartCardPage,
      SmartCardEntryPage,
    ], hasLength(6));

    void launch() {}
    final SmartCardUnlockLauncher typedLauncher = launch;
    expect(typedLauncher, isNotNull);
  });
}
