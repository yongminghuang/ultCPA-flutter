import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/purchase_history/purchase_history_models.dart';

void main() {
  test('parses the Android MyOrderDto fields and Gson-compatible scalars', () {
    final order = PurchaseHistoryOrder.fromMap({
      'orderId': 4200001988,
      'commodityName': '季度大招练题功能',
      'orderAmount': '9.90',
      'payTime': 1710000000000,
      'orderStatus': '支付成功',
      'benefitsExpireTime': '2026-08-10 12:00:00',
      'items': [
        {'productName': '技巧练题'},
        null,
        {'productName': 300},
      ],
    });

    expect(order.orderId, '4200001988');
    expect(order.commodityName, '季度大招练题功能');
    expect(order.orderAmount, 9.9);
    expect(order.payTime, '1710000000000');
    expect(order.orderStatus, '支付成功');
    expect(order.benefitsExpireTime, '2026-08-10 12:00:00');
    expect(order.items.map((item) => item.productName), ['技巧练题', '300']);
  });

  test('rejects malformed order and item structures', () {
    expect(
      () => PurchaseHistoryOrder.fromMap({'items': 'not-a-list'}),
      throwsFormatException,
    );
    expect(
      () => PurchaseHistoryOrder.fromMap({
        'items': [true],
      }),
      throwsFormatException,
    );
    expect(
      () => PurchaseHistoryOrder.fromMap({'orderAmount': 'not-money'}),
      throwsFormatException,
    );
  });

  test('uses commodity title then joined item names then Android fallback', () {
    const preferred = PurchaseHistoryOrder(
      orderId: '',
      commodityName: '  季度会员  ',
      orderAmount: null,
      payTime: null,
      orderStatus: null,
      benefitsExpireTime: null,
      items: [PurchaseHistoryItem(productName: '忽略的商品')],
    );
    const fromItems = PurchaseHistoryOrder(
      orderId: '',
      commodityName: '   ',
      orderAmount: null,
      payTime: null,
      orderStatus: null,
      benefitsExpireTime: null,
      items: [
        PurchaseHistoryItem(productName: '技巧练题'),
        PurchaseHistoryItem(productName: '  '),
        PurchaseHistoryItem(productName: '速成300题'),
      ],
    );
    const empty = PurchaseHistoryOrder(
      orderId: '',
      commodityName: null,
      orderAmount: null,
      payTime: null,
      orderStatus: null,
      benefitsExpireTime: null,
      items: [],
    );

    expect(preferred.displayTitle, '  季度会员  ');
    expect(fromItems.displayTitle, '技巧练题\n速成300题');
    expect(empty.displayTitle, '--');
  });

  test('formats yuan with Android trailing-zero and plain-decimal rules', () {
    expect(formatPurchaseAmount(null), '¥0');
    expect(formatPurchaseAmount(0), '¥0');
    expect(formatPurchaseAmount(-0.0), '¥0');
    expect(formatPurchaseAmount(9.90), '¥9.9');
    expect(formatPurchaseAmount(99.0), '¥99');
    expect(formatPurchaseAmount(0.0000001), '¥0.0000001');
    expect(formatPurchaseAmount(double.nan), '¥0');
    expect(formatPurchaseAmount(double.infinity), '¥0');
  });

  test('parses Android order time variants and invalid values as zero', () {
    expect(
      parsePurchaseTimeMillis('2026-05-10 12:34:56'),
      DateTime(2026, 5, 10, 12, 34, 56).millisecondsSinceEpoch,
    );
    expect(
      parsePurchaseTimeMillis('2026-05-10'),
      DateTime(2026, 5, 10).millisecondsSinceEpoch,
    );
    expect(
      parsePurchaseTimeMillis('2026-05-10T04:34:56Z'),
      DateTime.utc(2026, 5, 10, 4, 34, 56).millisecondsSinceEpoch,
    );
    expect(parsePurchaseTimeMillis('1710000000000'), 1710000000000);
    expect(parsePurchaseTimeMillis(''), 0);
    expect(parsePurchaseTimeMillis('not-a-time'), 0);
  });

  test('sorts newest first and preserves server order for equal times', () {
    final first = _order('first', '2026-05-10 12:00:00');
    final invalid = _order('invalid', 'bad');
    final older = _order('older', '2026-05-09 12:00:00');
    final tied = _order('tied', '2026-05-10 12:00:00');
    final original = [first, invalid, older, tied];

    final sorted = sortPurchaseOrdersNewestFirst(original);

    expect(sorted.map((order) => order.orderId), [
      'first',
      'tied',
      'older',
      'invalid',
    ]);
    expect(original.map((order) => order.orderId), [
      'first',
      'invalid',
      'older',
      'tied',
    ]);
  });
}

PurchaseHistoryOrder _order(String id, String? payTime) {
  return PurchaseHistoryOrder(
    orderId: id,
    commodityName: id,
    orderAmount: 1,
    payTime: payTime,
    orderStatus: '支付成功',
    benefitsExpireTime: null,
    items: const [],
  );
}
