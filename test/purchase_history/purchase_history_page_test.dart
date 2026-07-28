import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';
import 'package:ultcpa_flutter/src/purchase_history/purchase_history_data_source.dart';
import 'package:ultcpa_flutter/src/purchase_history/purchase_history_models.dart';
import 'package:ultcpa_flutter/src/purchase_history/purchase_history_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'starts with Android empty view then renders exact order fields',
    (tester) async {
      final pending = Completer<List<PurchaseHistoryOrder>>();
      final source = _Source(() => pending.future);
      await tester.pumpWidget(_app(source));
      await tester.pump();

      expect(find.text('我的订单'), findsOneWidget);
      expect(find.text('暂无购买记录'), findsOneWidget);
      expect(find.text('下拉可刷新列表'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      pending.complete([_order]);
      await tester.pumpAndSettle();

      expect(find.text('季度大招练题功能'), findsOneWidget);
      expect(find.text(_longOrderId), findsOneWidget);
      expect(find.text('支付状态：支付成功'), findsOneWidget);
      expect(find.text('订单金额：¥9.9'), findsOneWidget);
      expect(find.text('付费时间：2026-05-10 12:00:00'), findsOneWidget);
      expect(find.text('到期时间：2026-08-10 12:00:00'), findsOneWidget);
      expect(find.text('暂无购买记录'), findsNothing);
      expect(source.loadCalls, 1);

      final orderId = tester.widget<Text>(find.text(_longOrderId));
      expect(orderId.maxLines, 1);
      expect(orderId.overflow, TextOverflow.ellipsis);
    },
  );

  testWidgets('renders Android null text and multiline item-title fallback', (
    tester,
  ) async {
    const order = PurchaseHistoryOrder(
      orderId: '',
      commodityName: '',
      orderAmount: null,
      payTime: null,
      orderStatus: null,
      benefitsExpireTime: null,
      items: [
        PurchaseHistoryItem(productName: '技巧练题'),
        PurchaseHistoryItem(productName: '速成300题'),
      ],
    );
    await tester.pumpWidget(_app(_Source(() async => [order])));
    await tester.pumpAndSettle();

    expect(find.text('技巧练题\n速成300题'), findsOneWidget);
    expect(find.text('支付状态：null'), findsOneWidget);
    expect(find.text('订单金额：¥0'), findsOneWidget);
    expect(find.text('付费时间：null'), findsOneWidget);
    expect(find.text('到期时间：null'), findsOneWidget);
  });

  testWidgets('copies the complete order ID and shows Android feedback', (
    tester,
  ) async {
    MethodCall? clipboardCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') clipboardCall = call;
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.pumpWidget(_app(_Source(() async => [_order])));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('purchase-order-copy-0')));
    await tester.pump();

    expect(clipboardCall?.arguments, {'text': _longOrderId});
    expect(find.text('订单号已复制'), findsOneWidget);
  });

  testWidgets('pull refresh replaces records and ignores a duplicate load', (
    tester,
  ) async {
    final refresh = Completer<List<PurchaseHistoryOrder>>();
    var attempt = 0;
    final source = _Source(
      () => attempt++ == 0 ? Future.value([_order]) : refresh.future,
    );
    await tester.pumpWidget(_app(source));
    await tester.pumpAndSettle();

    await _pullToRefresh(tester);
    expect(source.loadCalls, 2);
    await _pullToRefresh(tester);
    expect(source.loadCalls, 2);

    refresh.complete([_secondOrder]);
    await tester.pumpAndSettle();

    expect(find.text('季度大招练题功能'), findsNothing);
    expect(find.text('续费会员'), findsOneWidget);
  });

  testWidgets(
    'server or parse failure clears records and keeps empty refresh',
    (tester) async {
      var attempt = 0;
      final source = _Source(() async {
        if (attempt++ == 0) return [_order];
        throw const AppApiException('订单查询失败', code: 409);
      });
      await tester.pumpWidget(_app(source));
      await tester.pumpAndSettle();

      await _pullToRefresh(tester);
      await tester.pumpAndSettle();

      expect(find.text('订单查询失败'), findsOneWidget);
      expect(find.text('季度大招练题功能'), findsNothing);
      expect(find.text('暂无购买记录'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('purchase-history-scroll')),
        findsOneWidget,
      );
    },
  );

  testWidgets('uses parsing and network fallback messages', (tester) async {
    final errors = <Object>[
      const FormatException('订单列表解析失败'),
      StateError('offline'),
    ];
    for (final error in errors) {
      await tester.pumpWidget(
        _app(
          _Source(() async => throw error),
          key: ValueKey(error.runtimeType),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(error is FormatException ? '订单列表解析失败' : '网络异常'),
        findsOneWidget,
      );
    }
  });

  testWidgets('supports back and ignores stale completion after disposal', (
    tester,
  ) async {
    final pending = Completer<List<PurchaseHistoryOrder>>();
    await tester.pumpWidget(
      MaterialApp(home: _Harness(source: _Source(() => pending.future))),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('purchase-history-back')));
    await tester.pumpAndSettle();
    expect(find.text('host'), findsOneWidget);

    pending.complete([_order]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits populated and empty states at 320 by 568', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_Source(() async => [_order])));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('purchase-order-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _longOrderId = '4200001988202605129980807045';

const _order = PurchaseHistoryOrder(
  orderId: _longOrderId,
  commodityName: '季度大招练题功能',
  orderAmount: 9.9,
  payTime: '2026-05-10 12:00:00',
  orderStatus: '支付成功',
  benefitsExpireTime: '2026-08-10 12:00:00',
  items: [],
);

const _secondOrder = PurchaseHistoryOrder(
  orderId: 'second',
  commodityName: '续费会员',
  orderAmount: 99,
  payTime: '2026-06-10 12:00:00',
  orderStatus: '支付成功',
  benefitsExpireTime: '2026-09-10 12:00:00',
  items: [],
);

Future<void> _pullToRefresh(WidgetTester tester) async {
  await tester.timedDrag(
    find.byKey(const ValueKey('purchase-history-scroll')),
    const Offset(0, 320),
    const Duration(milliseconds: 600),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

Widget _app(PurchaseHistoryDataSource source, {Key? key}) {
  return MaterialApp(
    key: key,
    home: PurchaseHistoryPage(dataSource: source),
  );
}

final class _Source implements PurchaseHistoryDataSource {
  _Source(this.loader);

  final Future<List<PurchaseHistoryOrder>> Function() loader;
  int loadCalls = 0;

  @override
  Future<List<PurchaseHistoryOrder>> loadOrders() {
    loadCalls += 1;
    return loader();
  }
}

final class _Harness extends StatelessWidget {
  const _Harness({required this.source});

  final PurchaseHistoryDataSource source;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('host'),
          TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => PurchaseHistoryPage(dataSource: source),
              ),
            ),
            child: const Text('open'),
          ),
        ],
      ),
    );
  }
}
