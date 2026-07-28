import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_models.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_success_page.dart';

void main() {
  testWidgets('renders the Android success copy asset and teacher action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        summary: const VipPurchaseSuccessSummary(
          title: '恭喜！【初级会计畅学卡】开通成功',
          expiresOn: '2026-08-01',
          hasMemberTier: true,
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final image = tester.widget<Image>(
      find.byKey(const ValueKey('vip-success-icon')),
    );

    expect(scaffold.backgroundColor, const Color(0xFFFFFDF5));
    expect(appBar.backgroundColor, const Color(0xFFFFFDF5));
    expect(find.byKey(const ValueKey('vip-success-back')), findsOneWidget);
    expect(image.width, 72);
    expect(image.height, 72);
    expect(
      image.image,
      const AssetImage('assets/images/vip_purchase/icon_open_vip_success.png'),
    );
    expect(find.text('恭喜！【初级会计畅学卡】开通成功'), findsOneWidget);
    expect(find.text('有效期至 2026-08-01'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vip-success-teacher-card')),
      findsOneWidget,
    );
    expect(find.text('专属班主任'), findsOneWidget);
    expect(find.text('官方认证'), findsOneWidget);
    expect(find.text('5年经验 · 3000+学员 · 好评率99%'), findsOneWidget);
    expect(find.text('添加班主任，激活专属权益'), findsOneWidget);
  });

  testWidgets('hides expiry without a matched member tier', (tester) async {
    await tester.pumpWidget(
      _app(summary: const VipPurchaseSuccessSummary.generic()),
    );

    expect(find.text('恭喜！会员开通成功'), findsOneWidget);
    expect(find.textContaining('有效期至'), findsNothing);
  });

  testWidgets('app bar and system back finish only once', (tester) async {
    var appBarFinishes = 0;
    await tester.pumpWidget(
      _app(
        summary: const VipPurchaseSuccessSummary.generic(),
        onFinished: () => appBarFinishes += 1,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('vip-success-back')));
    await tester.tap(find.byKey(const ValueKey('vip-success-back')));
    await tester.pump();
    expect(appBarFinishes, 1);

    var systemFinishes = 0;
    await tester.pumpWidget(
      _app(
        key: const ValueKey('system-back-success-page'),
        summary: const VipPurchaseSuccessSummary.generic(),
        onFinished: () => systemFinishes += 1,
      ),
    );
    await tester.binding.handlePopRoute();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(systemFinishes, 1);
  });

  testWidgets('customer service is single flight and restores on completion', (
    tester,
  ) async {
    final launch = Completer<void>();
    var launchCalls = 0;
    await tester.pumpWidget(
      _app(
        summary: const VipPurchaseSuccessSummary.generic(),
        customerServiceLauncher: (_) {
          launchCalls += 1;
          return launch.future;
        },
      ),
    );

    final action = find.byKey(const ValueKey('vip-success-customer-service'));
    await tester.tap(action);
    await tester.tap(action);
    await tester.pump();

    expect(launchCalls, 1);
    expect(
      find.byKey(const ValueKey('vip-success-customer-service-progress')),
      findsOneWidget,
    );

    launch.complete();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('vip-success-customer-service-progress')),
      findsNothing,
    );
  });

  testWidgets('customer service errors notify and allow retry', (tester) async {
    var launchCalls = 0;
    await tester.pumpWidget(
      _app(
        summary: const VipPurchaseSuccessSummary.generic(),
        customerServiceLauncher: (_) async {
          launchCalls += 1;
          throw StateError('WeChat unavailable');
        },
      ),
    );

    final action = find.byKey(const ValueKey('vip-success-customer-service'));
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(launchCalls, 1);
    expect(find.text('暂时无法打开微信客服，请稍后重试'), findsOneWidget);

    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(launchCalls, 2);
    expect(
      find.byKey(const ValueKey('vip-success-customer-service-progress')),
      findsNothing,
    );
  });

  testWidgets('ignores customer service completion after disposal', (
    tester,
  ) async {
    final launch = Completer<void>();
    await tester.pumpWidget(
      _app(
        summary: const VipPurchaseSuccessSummary.generic(),
        customerServiceLauncher: (_) => launch.future,
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('vip-success-customer-service')),
    );
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    launch.completeError(StateError('late failure'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('fits both compact Android viewports without overflow', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in const [Size(320, 568), Size(360, 640)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        _app(
          key: ValueKey('${size.width}x${size.height}'),
          summary: const VipPurchaseSuccessSummary(
            title: '恭喜！【初级会计全科长期畅学会员】开通成功',
            expiresOn: '2026-08-01',
            hasMemberTier: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '$size');
      expect(
        find.byKey(const ValueKey('vip-success-customer-service')),
        findsOneWidget,
      );
    }
  });
}

Widget _app({
  Key? key,
  required VipPurchaseSuccessSummary summary,
  VoidCallback? onFinished,
  Future<void> Function(BuildContext)? customerServiceLauncher,
}) {
  return MaterialApp(
    key: key,
    home: VipPurchaseSuccessPage(
      summary: summary,
      onFinished: onFinished ?? () {},
      customerServiceLauncher: customerServiceLauncher,
    ),
  );
}
