import 'vip_purchase_models.dart';

enum VipCommodityType {
  levelMember('level_member', '畅学卡'),
  regular('capability_practice_regular', '技巧练题'),
  speed('capability_practice_speed', '速成300题'),
  chapter('capability_practice_chapter', '章节刷题包'),
  pastExams('capability_practice_past_exams', '历年真题卷');

  const VipCommodityType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static VipCommodityType? fromApiValue(String value) {
    for (final type in values) {
      if (type.apiValue == value.trim()) return type;
    }
    return null;
  }
}

final class VipCommodity {
  const VipCommodity({
    required this.commodityId,
    required this.name,
    required this.type,
    required this.price,
    required this.originalPrice,
    required this.description,
  });

  factory VipCommodity.fromMap(Map<String, dynamic> map) {
    final commodityId = _firstText(map, const ['commodityId', 'id']);
    if (commodityId.isEmpty) throw const FormatException('商品 ID 为空');
    final type = VipCommodityType.fromApiValue(_text(map['commodityType']));
    if (type == null) throw const FormatException('未知商品类型');
    final price = _firstMoney(map, const ['price', 'money']);
    final originalPrice = _firstMoney(
      map,
      const ['originalPrice', 'originalMoney'],
      fallback: price,
    );
    return VipCommodity(
      commodityId: commodityId,
      name: _firstText(map, const ['commodityName', 'name']),
      type: type,
      price: price,
      originalPrice: originalPrice,
      description: _text(map['desc']).trim(),
    );
  }

  final String commodityId;
  final String name;
  final VipCommodityType type;
  final double price;
  final double originalPrice;
  final String description;
}

final class VipCommodityBundle {
  VipCommodityBundle(List<VipCommodity> commodities)
    : _commodities = {
        for (final commodity in commodities) commodity.type: commodity,
      };

  final Map<VipCommodityType, VipCommodity> _commodities;

  VipCommodity? operator [](VipCommodityType type) => _commodities[type];

  VipCommodity get levelMember {
    final value = _commodities[VipCommodityType.levelMember];
    if (value == null) throw const FormatException('暂无法获取畅学卡商品');
    return value;
  }
}

final class VipCommodityDeduction {
  const VipCommodityDeduction({
    required this.commodityId,
    required this.price,
    required this.payAmount,
    required this.description,
    required this.isDeduction,
  });

  factory VipCommodityDeduction.fromMap(Map<String, dynamic> map) {
    return VipCommodityDeduction(
      commodityId: _text(map['commodityId']).trim(),
      price: _money(map['price']),
      payAmount: _money(map['payAmount']),
      description: _text(map['deductionDesc']).trim(),
      isDeduction: _bool(map['isDeduction']),
    );
  }

  final String commodityId;
  final double price;
  final double payAmount;
  final String description;
  final bool isDeduction;
}

final class VipDifferenceUpgradeSession {
  const VipDifferenceUpgradeSession({
    required this.purchaseSession,
    required this.commodities,
    required this.deduction,
    required this.deductionRequestSucceeded,
  });

  final VipPurchaseSession purchaseSession;
  final VipCommodityBundle commodities;
  final VipCommodityDeduction? deduction;
  final bool deductionRequestSucceeded;

  bool get shouldOpenNormalPurchase {
    if (purchaseSession.isFullMember || !purchaseSession.hasPracticePackage) {
      return true;
    }
    final value = deduction;
    return deductionRequestSucceeded && value != null && !value.isDeduction;
  }

  double get payAmount {
    final value = deduction;
    if (deductionRequestSucceeded && value != null && value.isDeduction) {
      return value.payAmount;
    }
    return calculateVipDifference(
      levelMemberPrice: commodities.levelMember.price,
      regularPrice: commodities[VipCommodityType.regular]?.price ?? 0,
      speedPrice: commodities[VipCommodityType.speed]?.price ?? 0,
      chapterPrice: commodities[VipCommodityType.chapter]?.price ?? 0,
      pastExamsPrice: commodities[VipCommodityType.pastExams]?.price ?? 0,
      ownedBenefitTypes: purchaseSession.ownedPracticeBenefitTypes,
    );
  }

  String get formulaText {
    final value = deduction;
    if (deductionRequestSucceeded &&
        value != null &&
        value.isDeduction &&
        value.description.isNotEmpty) {
      return value.description;
    }
    final terms = <String>[];
    void add(VipCommodityType type, String benefitType) {
      if (!purchaseSession.ownedPracticeBenefitTypes.contains(benefitType)) {
        return;
      }
      final commodity = commodities[type];
      if (commodity != null) {
        terms.add('-${type.label}${formatVipMoney(commodity.price)}元');
      }
    }

    add(VipCommodityType.regular, 'practice_skill');
    add(VipCommodityType.speed, 'practice_speed');
    add(VipCommodityType.chapter, 'practice_chapter');
    add(VipCommodityType.pastExams, 'past_exams');
    return '${formatVipMoney(payAmount)}元=(畅学卡${formatVipMoney(commodities.levelMember.price)}元${terms.join()})';
  }
}

double calculateVipDifference({
  required double levelMemberPrice,
  required double regularPrice,
  required double speedPrice,
  required double chapterPrice,
  required double pastExamsPrice,
  required Set<String> ownedBenefitTypes,
}) {
  var value = levelMemberPrice;
  if (ownedBenefitTypes.contains('practice_skill')) value -= regularPrice;
  if (ownedBenefitTypes.contains('practice_speed')) value -= speedPrice;
  if (ownedBenefitTypes.contains('practice_chapter')) value -= chapterPrice;
  if (ownedBenefitTypes.contains('past_exams')) value -= pastExamsPrice;
  if (value <= 0) return 0;
  return (value * 100).round() / 100;
}

String _firstText(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = _text(map[key]).trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

double _firstMoney(
  Map<String, dynamic> map,
  List<String> keys, {
  double fallback = 0,
}) {
  for (final key in keys) {
    final value = _money(map[key], fallback: double.nan);
    if (value.isFinite && value >= 0) return value;
  }
  return fallback;
}

double _money(Object? value, {double fallback = 0}) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  return parsed != null && parsed.isFinite ? parsed : fallback;
}

bool _bool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return value?.toString().toLowerCase() == 'true';
}

String _text(Object? value) => value?.toString() ?? '';
