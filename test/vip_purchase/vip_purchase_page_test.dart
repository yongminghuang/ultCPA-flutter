import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_payment_gateway.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_models.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_page.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_repository.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_success_page.dart';

void main() {
  testWidgets(
    'renders Android expanded session header tabs prices and content',
    (tester) async {
      final dataSource = _DataSource(
        session: _session(expanded: true, withBenefits: true),
        skuHandler: (_, _) async => _selection(),
      );

      await tester.pumpWidget(_app(dataSource));
      await tester.pumpAndSettle();

      expect(find.text('开通VIP，急速考证'), findsOneWidget);
      expect(find.byKey(const ValueKey('vip-purchase-back')), findsOneWidget);
      expect(find.byKey(const ValueKey('vip-user-header')), findsOneWidget);
      expect(find.text('迁移用户'), findsOneWidget);
      expect(find.text('查看更多'), findsOneWidget);
      expect(find.byKey(const ValueKey('vip-type-svip')), findsOneWidget);
      expect(find.byKey(const ValueKey('vip-type-skill')), findsOneWidget);
      expect(find.byKey(const ValueKey('vip-type-course')), findsOneWidget);
      expect(dataSource.skuRequests.single.type, VipProductType.svip);
      expect(dataSource.skuRequests.single.subjects, const [
        VipSubject(id: 8, name: '财务管理'),
      ]);
      expect(find.text('月卡'), findsOneWidget);
      expect(find.text('季卡'), findsOneWidget);
      expect(find.text('尊享全能 SVIP无缝通关'), findsOneWidget);
      expect(find.text('速成300题'), findsOneWidget);
      expect(find.text('名师全科课程'), findsOneWidget);
      expect(find.byKey(const ValueKey('vip-marketing-pain')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('vip-marketing-accounting')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('vip-marketing-social')), findsNothing);
      expect(
        find.byKey(const ValueKey('vip-marketing-example')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('vip-marketing-shares')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('vip-content-detail')), findsNothing);
      expect(find.byKey(const ValueKey('vip-common-questions')), findsNothing);
      expect(find.text('¥29.9'), findsOneWidget);
      expect(find.text('立即支付'), findsOneWidget);
      expect(find.text('开通前请阅读《考有招会员协议》'), findsOneWidget);
    },
  );

  testWidgets('uses skill-only fallback and hides empty user header', (
    tester,
  ) async {
    final dataSource = _DataSource(
      session: _session(expanded: false),
      skuHandler: (_, _) async => _selection(),
    );

    await tester.pumpWidget(_app(dataSource));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('vip-user-header')), findsNothing);
    expect(find.byKey(const ValueKey('vip-type-skill')), findsOneWidget);
    expect(find.byKey(const ValueKey('vip-type-svip')), findsNothing);
    expect(find.byKey(const ValueKey('vip-type-course')), findsNothing);
    expect(dataSource.skuRequests.single.type, VipProductType.skill);
    expect(find.text('畅享 财务管理 答题技巧'), findsOneWidget);
  });

  testWidgets('retries an initial session failure', (tester) async {
    var attempts = 0;
    final dataSource = _DataSource(
      sessionHandler: () async {
        attempts += 1;
        if (attempts == 1) throw StateError('session offline');
        return _session(expanded: false);
      },
      skuHandler: (_, _) async => _selection(),
    );

    await tester.pumpWidget(_app(dataSource));
    await tester.pumpAndSettle();

    expect(find.text('加载失败，请重试'), findsOneWidget);
    expect(find.textContaining('session offline'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('vip-purchase-retry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('答题技巧VIP'), findsOneWidget);
  });

  testWidgets('keeps one subject and implements select all then clear', (
    tester,
  ) async {
    final dataSource = _DataSource(
      session: _session(expanded: false),
      skuHandler: (_, _) async => _selection(),
    );

    await tester.pumpWidget(_app(dataSource));
    await tester.pumpAndSettle();

    expect(find.text('请选择 (已选1科）'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('vip-subject-8')));
    await tester.pumpAndSettle();
    expect(dataSource.skuRequests, hasLength(1));

    await tester.tap(find.byKey(const ValueKey('vip-subject-7')));
    await tester.pumpAndSettle();
    expect(dataSource.skuRequests.last.subjects, const [
      VipSubject(id: 7, name: '经济法'),
      VipSubject(id: 8, name: '财务管理'),
    ]);
    expect(find.text('请选择 (已选2科）'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('vip-select-all')));
    await tester.pumpAndSettle();
    expect(dataSource.skuRequests.last.subjects, const [
      VipSubject(id: 6, name: '会计实务'),
      VipSubject(id: 7, name: '经济法'),
      VipSubject(id: 8, name: '财务管理'),
    ]);
    expect(find.text('清除'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('vip-select-all')));
    await tester.pumpAndSettle();
    expect(dataSource.skuRequests.last.subjects, const [
      VipSubject(id: 8, name: '财务管理'),
    ]);
    expect(find.text('全选'), findsOneWidget);
  });

  testWidgets('switches type resets subject and selects another price card', (
    tester,
  ) async {
    final dataSource = _DataSource(
      session: _session(expanded: true),
      skuHandler: (_, _) async => _selection(),
    );

    await tester.pumpWidget(_app(dataSource));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vip-subject-6')));
    await tester.pumpAndSettle();
    expect(dataSource.skuRequests.last.subjects, hasLength(2));

    await tester.tap(find.byKey(const ValueKey('vip-type-course')));
    await tester.pumpAndSettle();

    expect(dataSource.skuRequests.last.type, VipProductType.course);
    expect(dataSource.skuRequests.last.subjects, const [
      VipSubject(id: 8, name: '财务管理'),
    ]);
    expect(find.text('畅听 财务管理 课程视频'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('vip-price-card-1')));
    await tester.pump();
    expect(find.text('¥59.9'), findsOneWidget);
  });

  testWidgets('ignores a stale SKU completion after selection changes', (
    tester,
  ) async {
    final oldRequest = Completer<VipSkuSelection>();
    final newRequest = Completer<VipSkuSelection>();
    var calls = 0;
    final dataSource = _DataSource(
      session: _session(expanded: false),
      skuHandler: (_, _) {
        calls += 1;
        return calls == 1 ? oldRequest.future : newRequest.future;
      },
    );

    await tester.pumpWidget(_app(dataSource));
    await tester.pump();
    expect(find.text('加载中'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('vip-subject-7')));
    await tester.pump();
    newRequest.complete(_selection(firstName: '新月卡'));
    await tester.pump();
    expect(find.text('新月卡'), findsOneWidget);

    oldRequest.complete(_selection(firstName: '旧月卡'));
    await tester.pump();
    expect(find.text('新月卡'), findsOneWidget);
    expect(find.text('旧月卡'), findsNothing);
  });

  testWidgets('opens benefit dialog customer service and agreement once', (
    tester,
  ) async {
    var customerServiceCalls = 0;
    var agreementCalls = 0;
    final dataSource = _DataSource(
      session: _session(expanded: true, withBenefits: true),
      skuHandler: (_, _) async => _selection(),
    );

    await tester.pumpWidget(
      _app(
        dataSource,
        customerServiceLauncher: (_) async => customerServiceCalls += 1,
        agreementLauncher: (_) async => agreementCalls += 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看更多'));
    await tester.pumpAndSettle();
    expect(find.text('会员权益'), findsOneWidget);
    expect(find.text('财务管理 课程VIP 有效期至 2026-08-01'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('vip-customer-service')));
    await tester.tap(find.byKey(const ValueKey('vip-agreement')));
    await tester.pump();
    expect(customerServiceCalls, 1);
    expect(agreementCalls, 1);
  });

  testWidgets('renders social marketing and payment channels correctly', (
    tester,
  ) async {
    final dataSource = _DataSource(
      session: _session(
        expanded: false,
        category: 'social-work',
        level: '初级社工',
        showWechatPay: false,
      ),
      skuHandler: (_, _) async => _selection(),
    );

    await tester.pumpWidget(_app(dataSource));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('vip-marketing-social')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vip-marketing-accounting')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('vip-payment-wechat')), findsNothing);
    expect(find.byKey(const ValueKey('vip-payment-alipay')), findsOneWidget);
  });

  testWidgets('does not overflow on a narrow short viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final dataSource = _DataSource(
      session: _session(expanded: true, withBenefits: true),
      skuHandler: (_, _) async => _selection(),
    );

    await tester.pumpWidget(_app(dataSource));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('vip-checkout-button')), findsOneWidget);
  });

  testWidgets('logged-out checkout launches login once and cancel is silent', (
    tester,
  ) async {
    final loginResult = Completer<Map<String, dynamic>?>();
    var loginCalls = 0;
    final dataSource = _DataSource(
      session: _session(expanded: false, isLoggedIn: false),
      skuHandler: (_, _) async => _selection(),
    );

    await tester.pumpWidget(
      _app(
        dataSource,
        loginLauncher: (_) {
          loginCalls += 1;
          return loginResult.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
    await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
    await tester.pump();

    expect(loginCalls, 1);
    expect(dataSource.orderRequests, isEmpty);

    loginResult.complete(null);
    await tester.pumpAndSettle();

    expect(dataSource.sessionRequests, 1);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('开通VIP，急速考证'), findsOneWidget);
  });

  testWidgets('successful login reloads session without automatically paying', (
    tester,
  ) async {
    var sessionCall = 0;
    final dataSource = _DataSource(
      sessionHandler: () async {
        sessionCall += 1;
        return sessionCall == 1
            ? _session(expanded: false, isLoggedIn: false)
            : _session(expanded: false, withBenefits: true);
      },
      skuHandler: (_, _) async => _selection(),
    );

    await tester.pumpWidget(
      _app(dataSource, loginLauncher: (_) async => const {'token': 'fresh'}),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
    await tester.pumpAndSettle();

    expect(dataSource.sessionRequests, 2);
    expect(dataSource.orderRequests, isEmpty);
    expect(find.byKey(const ValueKey('vip-user-header')), findsOneWidget);
  });

  testWidgets('empty selected cart never creates an order', (tester) async {
    final dataSource = _DataSource(
      session: _session(expanded: false),
      skuHandler: (_, _) async => _selection(emptyCart: true),
    );

    await tester.pumpWidget(_app(dataSource));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
    await tester.pump();

    expect(dataSource.orderRequests, isEmpty);
  });

  testWidgets(
    'unavailable WeChat shows Android message before order creation',
    (tester) async {
      final gateway = _Gateway(isWechatInstalled: false);
      final dataSource = _DataSource(
        session: _session(expanded: false),
        skuHandler: (_, _) async => _selection(),
      );

      await tester.pumpWidget(_app(dataSource, gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
      await tester.pumpAndSettle();

      expect(gateway.wechatInstalledChecks, 1);
      expect(dataSource.orderRequests, isEmpty);
      expect(find.text('您没有安装微信'), findsOneWidget);
    },
  );

  testWidgets(
    'allows only one order and native action while payment is active',
    (tester) async {
      final nativeResult = Completer<VipNativePaymentResult>();
      final gateway = _Gateway(alipayHandler: (_) => nativeResult.future);
      final dataSource = _DataSource(
        session: _session(expanded: false, showWechatPay: false),
        skuHandler: (_, _) async => _selection(),
        orderHandler: (_, channel, _) async => _alipayOrder,
      );

      await tester.pumpWidget(_app(dataSource, gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
      await tester.pump();

      expect(dataSource.orderRequests, hasLength(1));
      expect(gateway.alipayOrderInfos, const ['signed-order']);
      expect(find.text('支付中'), findsOneWidget);

      nativeResult.complete(_cancelledPayment);
      await tester.pumpAndSettle();
      expect(find.text('立即支付'), findsOneWidget);
    },
  );

  testWidgets('native cancellation is silent and restores checkout', (
    tester,
  ) async {
    final gateway = _Gateway(alipayHandler: (_) async => _cancelledPayment);
    final dataSource = _DataSource(
      session: _session(expanded: false, showWechatPay: false),
      skuHandler: (_, _) async => _selection(),
      orderHandler: (_, _, _) async => _alipayOrder,
    );

    await tester.pumpWidget(_app(dataSource, gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('开通VIP，急速考证'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
    await tester.pumpAndSettle();
    expect(dataSource.orderRequests, hasLength(2));
  });

  testWidgets('Alipay success shows summary and finishes only after back', (
    tester,
  ) async {
    final session = _session(expanded: false, showWechatPay: false);
    var customerServiceCalls = 0;
    final gateway = _Gateway(alipayHandler: (_) async => _successfulPayment);
    final dataSource = _DataSource(
      session: session,
      skuHandler: (_, _) async => _selection(),
      orderHandler: (_, _, _) async => _alipayOrder,
      successSummaryHandler: (_) async => const VipPurchaseSuccessSummary(
        title: '恭喜！【中级会计畅学卡】开通成功',
        expiresOn: '2026-08-01',
        hasMemberTier: true,
      ),
    );

    await tester.pumpWidget(
      _resultApp(
        dataSource,
        gateway,
        customerServiceLauncher: (_) async => customerServiceCalls += 1,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-vip-purchase')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
    await tester.pumpAndSettle();

    expect(find.byType(VipPurchaseSuccessPage), findsOneWidget);
    expect(find.text('恭喜！【中级会计畅学卡】开通成功'), findsOneWidget);
    expect(find.text('result:none'), findsNothing);
    expect(gateway.alipayOrderInfos, const ['signed-order']);
    expect(dataSource.confirmRequests, 0);
    expect(dataSource.successSummaryRequests, 1);
    expect(dataSource.successSummarySessions.single, same(session));

    await tester.tap(
      find.byKey(const ValueKey('vip-success-customer-service')),
    );
    await tester.pumpAndSettle();
    expect(customerServiceCalls, 1);

    await tester.tap(find.byKey(const ValueKey('vip-success-back')));
    await tester.pumpAndSettle();
    expect(find.text('result:paid'), findsOneWidget);
  });

  testWidgets(
    'WeChat success refreshes only after server confirmation and waits for back',
    (tester) async {
      final gateway = _Gateway(wechatHandler: (_) async => _successfulPayment);
      final dataSource = _DataSource(
        session: _session(expanded: false),
        skuHandler: (_, _) async => _selection(),
        orderHandler: (_, _, _) async => _wechatOrder,
        confirmHandler: () async => true,
        successSummaryHandler: (_) async =>
            const VipPurchaseSuccessSummary.generic(),
      );

      await tester.pumpWidget(_resultApp(dataSource, gateway));
      await tester.tap(find.byKey(const ValueKey('open-vip-purchase')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
      await tester.pumpAndSettle();

      expect(dataSource.confirmRequests, 1);
      expect(dataSource.successSummaryRequests, 1);
      expect(gateway.wechatCredentials, hasLength(1));
      expect(find.byType(VipPurchaseSuccessPage), findsOneWidget);
      expect(find.text('恭喜！会员开通成功'), findsOneWidget);
      expect(find.text('result:none'), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('result:paid'), findsOneWidget);
    },
  );

  testWidgets('success summary failure still shows generic success', (
    tester,
  ) async {
    final gateway = _Gateway(alipayHandler: (_) async => _successfulPayment);
    final dataSource = _DataSource(
      session: _session(expanded: false, showWechatPay: false),
      skuHandler: (_, _) async => _selection(),
      orderHandler: (_, _, _) async => _alipayOrder,
      successSummaryHandler: (_) async => throw StateError('benefits offline'),
    );

    await tester.pumpWidget(_resultApp(dataSource, gateway));
    await tester.tap(find.byKey(const ValueKey('open-vip-purchase')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
    await tester.pumpAndSettle();

    expect(dataSource.successSummaryRequests, 1);
    expect(find.byType(VipPurchaseSuccessPage), findsOneWidget);
    expect(find.text('恭喜！会员开通成功'), findsOneWidget);
    expect(find.textContaining('benefits offline'), findsNothing);
    expect(find.text('result:none'), findsNothing);
  });

  testWidgets('pending WeChat confirmation stays and restores checkout', (
    tester,
  ) async {
    final gateway = _Gateway(wechatHandler: (_) async => _successfulPayment);
    final dataSource = _DataSource(
      session: _session(expanded: false),
      skuHandler: (_, _) async => _selection(),
      orderHandler: (_, _, _) async => _wechatOrder,
      confirmHandler: () async => false,
    );

    await tester.pumpWidget(_app(dataSource, gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
    await tester.pumpAndSettle();

    expect(dataSource.confirmRequests, 1);
    expect(find.text('支付结果确认失败，请稍后重试'), findsOneWidget);
    expect(find.text('开通VIP，急速考证'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
    await tester.pumpAndSettle();
    expect(dataSource.orderRequests, hasLength(2));
  });

  testWidgets('native failure and order exception stay and restore checkout', (
    tester,
  ) async {
    var throwOrder = false;
    final gateway = _Gateway(
      alipayHandler: (_) async => const VipNativePaymentResult(
        status: VipNativePaymentStatus.failed,
        message: '支付宝调用失败',
      ),
    );
    final dataSource = _DataSource(
      session: _session(expanded: false, showWechatPay: false),
      skuHandler: (_, _) async => _selection(),
      orderHandler: (_, _, _) async {
        if (throwOrder) throw StateError('order offline');
        return _alipayOrder;
      },
    );

    await tester.pumpWidget(_app(dataSource, gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
    await tester.pumpAndSettle();
    expect(find.text('支付宝调用失败'), findsOneWidget);

    throwOrder = true;
    await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
    await tester.pumpAndSettle();

    expect(dataSource.orderRequests, hasLength(2));
    expect(find.textContaining('order offline'), findsOneWidget);
    expect(find.text('开通VIP，急速考证'), findsOneWidget);
  });

  testWidgets('ignores an order completion after the page is disposed', (
    tester,
  ) async {
    final orderResult = Completer<VipPaymentOrder>();
    final gateway = _Gateway();
    final dataSource = _DataSource(
      session: _session(expanded: false, showWechatPay: false),
      skuHandler: (_, _) async => _selection(),
      orderHandler: (_, _, _) => orderResult.future,
    );

    await tester.pumpWidget(_app(dataSource, gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    orderResult.complete(_alipayOrder);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(gateway.alipayOrderInfos, isEmpty);
  });

  testWidgets('ignores a native completion after the page is disposed', (
    tester,
  ) async {
    final nativeResult = Completer<VipNativePaymentResult>();
    final gateway = _Gateway(alipayHandler: (_) => nativeResult.future);
    final dataSource = _DataSource(
      session: _session(expanded: false, showWechatPay: false),
      skuHandler: (_, _) async => _selection(),
      orderHandler: (_, _, _) async => _alipayOrder,
    );

    await tester.pumpWidget(_app(dataSource, gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    nativeResult.complete(_successfulPayment);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores a success summary completion after disposal', (
    tester,
  ) async {
    final summary = Completer<VipPurchaseSuccessSummary>();
    final gateway = _Gateway(alipayHandler: (_) async => _successfulPayment);
    final dataSource = _DataSource(
      session: _session(expanded: false, showWechatPay: false),
      skuHandler: (_, _) async => _selection(),
      orderHandler: (_, _, _) async => _alipayOrder,
      successSummaryHandler: (_) => summary.future,
    );

    await tester.pumpWidget(_app(dataSource, gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
    await tester.pump();
    expect(dataSource.successSummaryRequests, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    summary.complete(const VipPurchaseSuccessSummary.generic());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  VipPurchaseDataSource dataSource, {
  VipPaymentGateway? gateway,
  VipPurchaseLoginLauncher? loginLauncher,
  VipPurchaseActionLauncher? customerServiceLauncher,
  VipPurchaseActionLauncher? agreementLauncher,
}) {
  return MaterialApp(
    home: VipPurchasePage(
      request: const VipPurchaseRequest.mine(),
      dataSource: dataSource,
      paymentGateway: gateway ?? _Gateway(),
      loginLauncher: loginLauncher,
      customerServiceLauncher: customerServiceLauncher,
      agreementLauncher: agreementLauncher,
    ),
  );
}

Widget _resultApp(
  VipPurchaseDataSource dataSource,
  VipPaymentGateway gateway, {
  VipPurchaseActionLauncher? customerServiceLauncher,
}) {
  return MaterialApp(
    home: _VipPurchaseResultHost(
      dataSource,
      gateway,
      customerServiceLauncher: customerServiceLauncher,
    ),
  );
}

VipPurchaseSession _session({
  required bool expanded,
  bool withBenefits = false,
  String category = 'joy-ledger',
  String level = '中级会计',
  bool showWechatPay = true,
  bool isLoggedIn = true,
}) {
  return VipPurchaseSession(
    request: const VipPurchaseRequest.mine(),
    category: category,
    level: level,
    subjects: const [
      VipSubject(id: 6, name: '会计实务'),
      VipSubject(id: 7, name: '经济法'),
      VipSubject(id: 8, name: '财务管理'),
    ],
    initialSubjectIndex: 2,
    productTypes: expanded
        ? const [
            VipProductType.svip,
            VipProductType.skill,
            VipProductType.course,
          ]
        : const [VipProductType.skill],
    initialProductType: expanded ? VipProductType.svip : VipProductType.skill,
    isLoggedIn: isLoggedIn,
    showWechatPay: showWechatPay,
    initialPaymentChannel: showWechatPay
        ? VipPaymentChannel.wechat
        : VipPaymentChannel.alipay,
    payPageSourceId: 1020,
    nickname: '迁移用户',
    avatarUrl: '',
    benefitLines: withBenefits
        ? const [
            VipBenefitLine(
              subject: 'all',
              type: 'all',
              expiresOn: '2026-08-01',
              text: '中级会计 全能SVIP 有效期至 2026-08-01',
            ),
            VipBenefitLine(
              subject: '会计实务',
              type: 'answering_skills_vip',
              expiresOn: '2026-08-01',
              text: '会计实务 答题技巧VIP 有效期至 2026-08-01',
            ),
            VipBenefitLine(
              subject: '财务管理',
              type: 'course_video',
              expiresOn: '2026-08-01',
              text: '财务管理 课程VIP 有效期至 2026-08-01',
            ),
          ]
        : const [],
  );
}

VipSkuSelection _selection({String firstName = '月卡', bool emptyCart = false}) {
  return VipSkuSelection(
    products: [
      VipProduct(
        productId: 'product',
        productName: '商品',
        category: 'joy-ledger',
        level: '中级会计',
        subject: '财务管理',
        productType: 'level_member',
        skus: const [
          VipProductSku(
            skuProductId: 1,
            skuName: '月卡',
            benefitsExpiryMinute: 43200,
          ),
          VipProductSku(
            skuProductId: 2,
            skuName: '季卡',
            benefitsExpiryMinute: 129600,
          ),
        ],
      ),
    ],
    skus: [
      VipCommonSku(
        skuName: firstName,
        totalPrice: 29.9,
        shopCart: emptyCart
            ? const []
            : const [VipShopCartItem(productId: 'product', productSkuId: 1)],
      ),
      VipCommonSku(
        skuName: '季卡',
        totalPrice: 59.9,
        shopCart: const [
          VipShopCartItem(productId: 'product', productSkuId: 2),
        ],
      ),
    ],
  );
}

const _wechatCredential = VipWechatCredential(
  appId: 'app-id',
  partnerId: 'partner-id',
  prepayId: 'prepay-id',
  nonceStr: 'nonce',
  timeStamp: '123',
  packageValue: 'Sign=WXPay',
  sign: 'signature',
);

const _wechatOrder = VipPaymentOrder(
  orderId: 'wx-order',
  wechatCredential: _wechatCredential,
);

const _alipayOrder = VipPaymentOrder(
  orderId: 'ali-order',
  alipayOrderInfo: 'signed-order',
);

const _successfulPayment = VipNativePaymentResult(
  status: VipNativePaymentStatus.success,
);

const _cancelledPayment = VipNativePaymentResult(
  status: VipNativePaymentStatus.cancelled,
);

final class _VipPurchaseResultHost extends StatefulWidget {
  const _VipPurchaseResultHost(
    this.dataSource,
    this.gateway, {
    this.customerServiceLauncher,
  });

  final VipPurchaseDataSource dataSource;
  final VipPaymentGateway gateway;
  final VipPurchaseActionLauncher? customerServiceLauncher;

  @override
  State<_VipPurchaseResultHost> createState() => _VipPurchaseResultHostState();
}

final class _VipPurchaseResultHostState extends State<_VipPurchaseResultHost> {
  VipPurchaseResult? _result;

  Future<void> _open() async {
    final result = await Navigator.of(context).push<VipPurchaseResult>(
      MaterialPageRoute(
        builder: (_) => VipPurchasePage(
          request: const VipPurchaseRequest.mine(),
          dataSource: widget.dataSource,
          paymentGateway: widget.gateway,
          customerServiceLauncher: widget.customerServiceLauncher,
        ),
      ),
    );
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('result:${_result?.name ?? 'none'}'),
          FilledButton(
            key: const ValueKey('open-vip-purchase'),
            onPressed: _open,
            child: const Text('open'),
          ),
        ],
      ),
    );
  }
}

final class _SkuRequest {
  const _SkuRequest({required this.type, required this.subjects});

  final VipProductType type;
  final List<VipSubject> subjects;
}

final class _OrderRequest {
  const _OrderRequest({
    required this.session,
    required this.channel,
    required this.shopCart,
  });

  final VipPurchaseSession session;
  final VipPaymentChannel channel;
  final List<VipShopCartItem> shopCart;
}

final class _DataSource implements VipPurchaseDataSource {
  _DataSource({
    VipPurchaseSession? session,
    Future<VipPurchaseSession> Function()? sessionHandler,
    required this.skuHandler,
    this.orderHandler,
    this.confirmHandler,
    this.successSummaryHandler,
  }) : sessionHandler = sessionHandler ?? (() async => session!);

  final Future<VipPurchaseSession> Function() sessionHandler;
  final Future<VipSkuSelection> Function(
    VipProductType type,
    List<VipSubject> subjects,
  )
  skuHandler;
  final Future<VipPaymentOrder> Function(
    VipPurchaseSession session,
    VipPaymentChannel channel,
    List<VipShopCartItem> shopCart,
  )?
  orderHandler;
  final Future<bool> Function()? confirmHandler;
  final Future<VipPurchaseSuccessSummary> Function(VipPurchaseSession session)?
  successSummaryHandler;
  int sessionRequests = 0;
  int confirmRequests = 0;
  int successSummaryRequests = 0;
  final skuRequests = <_SkuRequest>[];
  final orderRequests = <_OrderRequest>[];
  final successSummarySessions = <VipPurchaseSession>[];

  @override
  Future<VipPurchaseSession> loadSession(VipPurchaseRequest request) {
    sessionRequests += 1;
    return sessionHandler();
  }

  @override
  Future<VipPurchaseSuccessSummary> loadSuccessSummary(
    VipPurchaseSession session,
  ) {
    successSummaryRequests += 1;
    successSummarySessions.add(session);
    final handler = successSummaryHandler;
    if (handler == null) {
      return Future.value(const VipPurchaseSuccessSummary.generic());
    }
    return handler(session);
  }

  @override
  Future<VipSkuSelection> loadSkus({
    required VipPurchaseSession session,
    required VipProductType type,
    required List<VipSubject> subjects,
  }) {
    final copy = List<VipSubject>.unmodifiable(subjects);
    skuRequests.add(_SkuRequest(type: type, subjects: copy));
    return skuHandler(type, copy);
  }

  @override
  Future<VipPaymentOrder> createOrder({
    required VipPurchaseSession session,
    required VipPaymentChannel channel,
    required List<VipShopCartItem> shopCart,
  }) {
    final copy = List<VipShopCartItem>.unmodifiable(shopCart);
    orderRequests.add(
      _OrderRequest(session: session, channel: channel, shopCart: copy),
    );
    final handler = orderHandler;
    if (handler == null) throw UnimplementedError();
    return handler(session, channel, copy);
  }

  @override
  Future<bool> confirmWechatPayment() {
    confirmRequests += 1;
    final handler = confirmHandler;
    if (handler == null) throw UnimplementedError();
    return handler();
  }
}

final class _Gateway implements VipPaymentGateway {
  _Gateway({
    bool isWechatInstalled = true,
    this.wechatHandler,
    this.alipayHandler,
  }) : wechatInstalled = isWechatInstalled;

  final bool wechatInstalled;
  final Future<VipNativePaymentResult> Function(VipWechatCredential credential)?
  wechatHandler;
  final Future<VipNativePaymentResult> Function(String orderInfo)?
  alipayHandler;
  int wechatInstalledChecks = 0;
  final wechatCredentials = <VipWechatCredential>[];
  final alipayOrderInfos = <String>[];

  @override
  Future<bool> isWechatInstalled() async {
    wechatInstalledChecks += 1;
    return wechatInstalled;
  }

  @override
  Future<VipNativePaymentResult> payAlipay(String orderInfo) async {
    alipayOrderInfos.add(orderInfo);
    return alipayHandler?.call(orderInfo) ?? _cancelledPayment;
  }

  @override
  Future<VipNativePaymentResult> payWechat(
    VipWechatCredential credential,
  ) async {
    wechatCredentials.add(credential);
    return wechatHandler?.call(credential) ?? _cancelledPayment;
  }
}
