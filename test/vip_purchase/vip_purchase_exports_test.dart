import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/ultcpa_flutter.dart';

void main() {
  test('exports the complete VIP purchase public surface', () {
    expect(VipPurchaseResult.paid.name, 'paid');
    expect(const VipPurchaseRequest.mine().normalPayPageSourceId, 1020);
    expect(
      resolveVipPurchaseSuccessSummary(
        const [],
        category: 'joy-ledger',
        level: '中级会计',
      ),
      const VipPurchaseSuccessSummary.generic(),
    );
    expect(
      const BigSkillPracticePurchaseSuccessSummary.generic(
        PracticeBenefitKind.fastPractice,
      ).title,
      '恭喜！【速成300题功能】开通成功',
    );
    expect(showVipPaySheet, isA<Function>());
    expect(<Type>[
      VipCheckoutStatus,
      VipCheckoutOutcome,
      VipCheckoutCoordinator,
      VipPaySheet,
      VipPurchaseRequest,
      VipPurchaseSession,
      VipSkuSelection,
      VipPaymentOrder,
      VipPurchaseDataSource,
      VipPurchaseRepository,
      VipPaymentGateway,
      MethodChannelVipPaymentGateway,
      VipPurchasePage,
      VipPurchaseSuccessSummary,
      VipPurchaseSuccessPage,
      PracticeBenefitKind,
      BigSkillPracticePurchaseSuccessRequest,
      BigSkillPracticePurchaseSuccessSummary,
      BigSkillPracticeDestination,
      BigSkillPracticePurchaseSuccessDataSource,
      BigSkillPracticePurchaseSuccessRepository,
      BigSkillPracticePurchaseSuccessPage,
    ], hasLength(22));
  });
}
