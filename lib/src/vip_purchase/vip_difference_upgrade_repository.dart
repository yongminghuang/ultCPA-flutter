import '../network/app_api_client.dart';
import 'vip_difference_upgrade_models.dart';
import 'vip_purchase_models.dart';
import 'vip_purchase_repository.dart';

abstract interface class VipDifferenceUpgradeDataSource {
  Future<VipDifferenceUpgradeSession> load(VipPurchaseRequest request);
}

final class VipDifferenceUpgradeRepository
    implements VipDifferenceUpgradeDataSource {
  const VipDifferenceUpgradeRepository({
    required AppApiClient api,
    required VipPurchaseDataSource purchaseDataSource,
  }) : _api = api,
       _purchaseDataSource = purchaseDataSource;

  final AppApiClient _api;
  final VipPurchaseDataSource _purchaseDataSource;

  @override
  Future<VipDifferenceUpgradeSession> load(VipPurchaseRequest request) async {
    final purchaseSession = await _purchaseDataSource.loadSession(request);
    final body = await _api.postBody('/app/commodity/v1/queryCommodity', {
      'category': purchaseSession.category,
      'levels': [purchaseSession.level],
      'commodityType': VipCommodityType.values
          .map((type) => type.apiValue)
          .toList(growable: false),
    });
    if (body is! List) throw const FormatException('商品列表响应不是数组');
    final commodities = <VipCommodity>[];
    for (final raw in body) {
      if (raw is! Map) throw const FormatException('商品条目不是对象');
      final map = Map<String, dynamic>.from(raw);
      final type = VipCommodityType.fromApiValue(
        map['commodityType']?.toString() ?? '',
      );
      if (type == null) continue;
      commodities.add(VipCommodity.fromMap(map));
    }
    final bundle = VipCommodityBundle(commodities);
    final levelMember = bundle.levelMember;
    VipCommodityDeduction? deduction;
    var deductionRequestSucceeded = false;
    if (purchaseSession.hasPracticePackage && !purchaseSession.isFullMember) {
      try {
        final deductionBody = await _api.getBody(
          '/app/commodity/v1/calculateCommodityPriceAfterDeduction',
          queryParameters: {'commodityId': levelMember.commodityId},
        );
        if (deductionBody is! Map) {
          throw const FormatException('抵扣响应不是对象');
        }
        deduction = VipCommodityDeduction.fromMap(
          Map<String, dynamic>.from(deductionBody),
        );
        deductionRequestSucceeded = true;
      } catch (_) {
        deduction = null;
        deductionRequestSucceeded = false;
      }
    }
    return VipDifferenceUpgradeSession(
      purchaseSession: purchaseSession,
      commodities: bundle,
      deduction: deduction,
      deductionRequestSucceeded: deductionRequestSucceeded,
    );
  }
}
