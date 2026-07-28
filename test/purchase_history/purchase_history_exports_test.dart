import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/ultcpa_flutter.dart';

void main() {
  test('exports the complete purchase-history public surface', () {
    expect(<Type>[
      PurchaseHistoryItem,
      PurchaseHistoryOrder,
      PurchaseHistoryDataSource,
      DioPurchaseHistoryRepository,
      PurchaseHistoryPage,
    ], hasLength(5));

    expect(formatPurchaseAmount(9.90), '¥9.9');
    expect(parsePurchaseTimeMillis('bad'), 0);
  });
}
