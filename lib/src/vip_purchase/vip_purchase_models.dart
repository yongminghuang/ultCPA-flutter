import 'dart:collection';
import 'dart:convert';

import '../main_tabs/main_tabs_models.dart';
import '../practice/practice_benefit_kind.dart';

enum VipProductType {
  skill(0, '答题技巧VIP', 'skills_feature_package'),
  svip(1, '全能 SVIP', 'level_member'),
  course(2, '课程VIP', 'video_course');

  const VipProductType(this.androidIndex, this.label, this.apiValue);

  final int androidIndex;
  final String label;
  final String apiValue;
}

enum VipPaymentChannel { wechat, alipay }

enum VipPurchaseResult { paid }

enum VipPaymentPresentation { fullScreen, sheet, practicePackage, difference }

enum VipPurchaseSuccessDestination { membership, practicePackage, caller }

enum VipPurchaseReturnPolicy { caller, home }

enum VipPaymentSource {
  home(
    normalPayPageSourceId: 1001,
    differencePayPageSourceId: 2001,
    returnPolicy: VipPurchaseReturnPolicy.home,
  ),
  dazhaoMietiUnlock(
    normalPayPageSourceId: 1002,
    differencePayPageSourceId: 2005,
    presentation: VipPaymentPresentation.practicePackage,
    successDestination: VipPurchaseSuccessDestination.caller,
  ),
  dazhaoMietiVideo(
    normalPayPageSourceId: 1003,
    differencePayPageSourceId: 2005,
  ),
  dazhaoMietiExplainWithCount(
    normalPayPageSourceId: 1004,
    differencePayPageSourceId: 2005,
  ),
  dazhaoMietiExplainNoCount(
    normalPayPageSourceId: 1005,
    differencePayPageSourceId: 2005,
  ),
  dazhaoSuxueUnlock(
    normalPayPageSourceId: 1006,
    differencePayPageSourceId: 2005,
    presentation: VipPaymentPresentation.practicePackage,
    successDestination: VipPurchaseSuccessDestination.caller,
  ),
  dazhaoSuxueVideo(
    normalPayPageSourceId: 1007,
    differencePayPageSourceId: 2005,
  ),
  dazhaoSuxueExplainWithCount(
    normalPayPageSourceId: 1008,
    differencePayPageSourceId: 2005,
  ),
  dazhaoSuxueExplainNoCount(
    normalPayPageSourceId: 1009,
    differencePayPageSourceId: 2005,
  ),
  fast300(
    normalPayPageSourceId: 1010,
    differencePayPageSourceId: 2003,
    presentation: VipPaymentPresentation.sheet,
  ),
  secretPaperList(
    normalPayPageSourceId: 1011,
    presentation: VipPaymentPresentation.sheet,
  ),
  secretPaperBottom(
    normalPayPageSourceId: 1012,
    presentation: VipPaymentPresentation.sheet,
  ),
  smartCard(
    normalPayPageSourceId: 1013,
    differencePayPageSourceId: 2004,
    presentation: VipPaymentPresentation.sheet,
  ),
  preExamSixPaper(normalPayPageSourceId: 1014),
  mnemonicsBottom(normalPayPageSourceId: 1015, differencePayPageSourceId: 2006),
  mnemonicsLockedList(
    normalPayPageSourceId: 1016,
    differencePayPageSourceId: 2006,
  ),
  homeMarketingFloat(
    normalPayPageSourceId: 1017,
    presentation: VipPaymentPresentation.practicePackage,
    successDestination: VipPurchaseSuccessDestination.practicePackage,
    returnPolicy: VipPurchaseReturnPolicy.home,
  ),
  shortVideo(normalPayPageSourceId: 1018, differencePayPageSourceId: 2007),
  courseTrial(normalPayPageSourceId: 1019, differencePayPageSourceId: 2008),
  mine(
    normalPayPageSourceId: 1020,
    differencePayPageSourceId: 2002,
    returnPolicy: VipPurchaseReturnPolicy.home,
  ),
  chapterOrPastExamsUnlock(
    normalPayPageSourceId: 1021,
    presentation: VipPaymentPresentation.sheet,
    successDestination: VipPurchaseSuccessDestination.caller,
  ),
  answerCardUnlock(
    normalPayPageSourceId: 1022,
    presentation: VipPaymentPresentation.practicePackage,
    successDestination: VipPurchaseSuccessDestination.caller,
  ),
  skillExplain(normalPayPageSourceId: 1023),
  homeLiveShortVideo(
    normalPayPageSourceId: 1024,
    differencePayPageSourceId: 2007,
  ),
  homeTopBanner(
    normalPayPageSourceId: 1025,
    differencePayPageSourceId: 2001,
    returnPolicy: VipPurchaseReturnPolicy.home,
  ),
  circlePaperResult(normalPayPageSourceId: 1026),
  retentionPopup(normalPayPageSourceId: 1027),
  homeLiveCourse(normalPayPageSourceId: 1028, differencePayPageSourceId: 2008),
  promotionPracticePay(
    normalPayPageSourceId: 1032,
    differencePayPageSourceId: 2005,
    presentation: VipPaymentPresentation.practicePackage,
    successDestination: VipPurchaseSuccessDestination.caller,
  ),
  promotionPracticeFinish(
    normalPayPageSourceId: 1033,
    differencePayPageSourceId: 2005,
    presentation: VipPaymentPresentation.practicePackage,
    successDestination: VipPurchaseSuccessDestination.caller,
  ),
  learningMaterials(normalPayPageSourceId: 0);

  const VipPaymentSource({
    required this.normalPayPageSourceId,
    int? differencePayPageSourceId,
    this.presentation = VipPaymentPresentation.fullScreen,
    this.successDestination = VipPurchaseSuccessDestination.membership,
    this.returnPolicy = VipPurchaseReturnPolicy.caller,
  }) : differencePayPageSourceId =
           differencePayPageSourceId ?? normalPayPageSourceId;

  final int normalPayPageSourceId;
  final int differencePayPageSourceId;
  final VipPaymentPresentation presentation;
  final VipPurchaseSuccessDestination successDestination;
  final VipPurchaseReturnPolicy returnPolicy;
}

enum VipPayEntry {
  courseTrial(VipPaymentSource.courseTrial),
  fast300(VipPaymentSource.fast300),
  secretPaperList(VipPaymentSource.secretPaperList),
  secretPaperBottom(VipPaymentSource.secretPaperBottom),
  smartCard(VipPaymentSource.smartCard),
  preExamSixPaper(VipPaymentSource.preExamSixPaper),
  pastExams(VipPaymentSource.chapterOrPastExamsUnlock),
  circlePaperResult(VipPaymentSource.circlePaperResult);

  const VipPayEntry(this.source);

  final VipPaymentSource source;

  int get conversionEntryId => source.normalPayPageSourceId;
}

final class VipPurchaseRequest {
  VipPurchaseRequest.source({
    required this.source,
    VipPaymentPresentation? presentation,
    this.defaultProductType,
    this.allowDifferenceUpgrade = true,
  }) : presentation = presentation ?? source.presentation;

  const VipPurchaseRequest.mine({
    this.defaultProductType,
    this.allowDifferenceUpgrade = true,
  }) : source = VipPaymentSource.mine,
       presentation = VipPaymentPresentation.fullScreen;

  const VipPurchaseRequest.home({
    this.defaultProductType,
    this.allowDifferenceUpgrade = true,
  }) : source = VipPaymentSource.home,
       presentation = VipPaymentPresentation.fullScreen;

  const VipPurchaseRequest.topBanner({
    this.defaultProductType,
    this.allowDifferenceUpgrade = true,
  }) : source = VipPaymentSource.homeTopBanner,
       presentation = VipPaymentPresentation.fullScreen;

  VipPurchaseRequest.popup({
    required VipPayEntry entry,
    this.defaultProductType,
    this.allowDifferenceUpgrade = true,
  }) : source = entry.source,
       presentation = VipPaymentPresentation.sheet;

  VipPurchaseRequest.fullScreen({
    required VipPayEntry entry,
    this.defaultProductType,
    this.allowDifferenceUpgrade = true,
  }) : source = entry.source,
       presentation = VipPaymentPresentation.fullScreen;

  final VipPaymentSource source;
  final VipPaymentPresentation presentation;
  final VipProductType? defaultProductType;
  final bool allowDifferenceUpgrade;

  VipPurchaseRequest withoutDifferenceUpgrade() {
    return VipPurchaseRequest.source(
      source: source,
      presentation: presentation,
      defaultProductType: defaultProductType,
      allowDifferenceUpgrade: false,
    );
  }

  int get normalPayPageSourceId => source.normalPayPageSourceId;

  int get differencePayPageSourceId => source.differencePayPageSourceId;

  VipPurchaseSuccessDestination get successDestination =>
      source.successDestination;

  VipPurchaseReturnPolicy get returnPolicy => source.returnPolicy;
}

List<VipProductType> visibleVipProductTypes({required bool expanded}) {
  return expanded
      ? const [VipProductType.svip, VipProductType.skill, VipProductType.course]
      : const [VipProductType.skill];
}

VipProductType defaultVipProductType({
  required bool expanded,
  VipProductType? explicit,
}) {
  final visible = visibleVipProductTypes(expanded: expanded);
  return explicit != null && visible.contains(explicit)
      ? explicit
      : visible.first;
}

String formatVipMoney(double value) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', '必须是有限数字');
  }
  final scaled = value * 100;
  final roundedCents = value >= 0
      ? (scaled + 0.500000001).floor()
      : (scaled - 0.500000001).ceil();
  var fixed = (roundedCents / 100).toStringAsFixed(2);
  while (fixed.contains('.') && fixed.endsWith('0')) {
    fixed = fixed.substring(0, fixed.length - 1);
  }
  return fixed.endsWith('.') ? fixed.substring(0, fixed.length - 1) : fixed;
}

String formatVipDailyPrice({
  required double totalPrice,
  required int subjectCount,
  required int days,
}) {
  if (!totalPrice.isFinite ||
      totalPrice <= 0 ||
      subjectCount <= 0 ||
      days <= 0) {
    return '';
  }
  final value = totalPrice / subjectCount / days;
  return '仅¥${value.toStringAsFixed(2)}/科/天';
}

int resolveVipSkuDays(String skuName, List<VipProductSku> productSkus) {
  for (final sku in productSkus) {
    if (sku.skuName == skuName && sku.benefitsExpiryMinute > 0) {
      return (sku.benefitsExpiryMinute ~/ 1440).clamp(1, 1 << 30);
    }
  }
  if (skuName.contains('月')) return 30;
  if (skuName.contains('季')) return 90;
  if (skuName.contains('年')) return 365;
  return 0;
}

int resolveInitialVipSubjectIndex(
  List<VipSubject> subjects, {
  required int selectedMarketId,
}) {
  if (subjects.isEmpty) return -1;
  final index = subjects.indexWhere(
    (subject) => subject.id == selectedMarketId,
  );
  return index < 0 ? 0 : index;
}

Set<int> toggleVipSubject(Set<int> selected, {required int subjectIndex}) {
  final next = SplayTreeSet<int>.of(selected);
  if (next.contains(subjectIndex)) {
    if (next.length > 1) next.remove(subjectIndex);
  } else if (subjectIndex >= 0) {
    next.add(subjectIndex);
  }
  return Set<int>.unmodifiable(next);
}

Set<int> toggleAllVipSubjects(
  Set<int> selected, {
  required int subjectCount,
  required int fallbackIndex,
}) {
  if (subjectCount <= 0) return const {};
  if (selected.length == subjectCount) {
    final safeFallback = fallbackIndex >= 0 && fallbackIndex < subjectCount
        ? fallbackIndex
        : 0;
    return Set<int>.unmodifiable({safeFallback});
  }
  return Set<int>.unmodifiable(
    List<int>.generate(subjectCount, (index) => index),
  );
}

final class VipSubject {
  const VipSubject({required this.id, required this.name});

  final int id;
  final String name;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VipSubject && other.id == id && other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);
}

final class VipProductSku {
  const VipProductSku({
    this.skuProductId = 0,
    required this.skuName,
    this.benefitsExpiryMinute = 0,
  });

  factory VipProductSku.fromMap(Map<String, dynamic> map) {
    return VipProductSku(
      skuProductId: _optionalInt(map['skuProductId']),
      skuName: _text(map['skuName']),
      benefitsExpiryMinute: _optionalInt(map['benefitsExpiryMinute']),
    );
  }

  final int skuProductId;
  final String skuName;
  final int benefitsExpiryMinute;
}

final class VipProduct {
  VipProduct({
    required this.productId,
    required this.productName,
    required this.category,
    required this.level,
    required this.subject,
    required this.productType,
    required List<VipProductSku> skus,
  }) : skus = List<VipProductSku>.unmodifiable(skus);

  factory VipProduct.fromMap(Map<String, dynamic> map) {
    final productId = _requiredText(map['productId'], 'productId');
    final rawSkus = map['skuList'];
    if (rawSkus != null && rawSkus is! List) {
      throw const FormatException('商品 skuList 不是数组');
    }
    final skus = <VipProductSku>[];
    for (final raw in rawSkus as List? ?? const []) {
      if (raw is! Map) throw const FormatException('商品 SKU 不是对象');
      skus.add(VipProductSku.fromMap(Map<String, dynamic>.from(raw)));
    }
    return VipProduct(
      productId: productId,
      productName: _text(map['productName']),
      category: _text(map['category']),
      level: _text(map['level']),
      subject: _text(map['subject']),
      productType: _text(map['productType']),
      skus: skus,
    );
  }

  final String productId;
  final String productName;
  final String category;
  final String level;
  final String subject;
  final String productType;
  final List<VipProductSku> skus;
}

final class VipShopCartItem {
  const VipShopCartItem({required this.productId, required this.productSkuId});

  factory VipShopCartItem.fromMap(Map<String, dynamic> map) {
    final productId = _requiredText(map['productId'], 'productId');
    final productSkuId = _requiredPositiveInt(
      map['productSkuId'],
      'productSkuId',
    );
    return VipShopCartItem(productId: productId, productSkuId: productSkuId);
  }

  final String productId;
  final int productSkuId;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productSkuId': productSkuId,
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VipShopCartItem &&
            other.productId == productId &&
            other.productSkuId == productSkuId;
  }

  @override
  int get hashCode => Object.hash(productId, productSkuId);
}

final class VipCommonSku {
  VipCommonSku({
    required this.skuName,
    required this.totalPrice,
    required List<VipShopCartItem> shopCart,
  }) : shopCart = List<VipShopCartItem>.unmodifiable(shopCart);

  factory VipCommonSku.fromMap(Map<String, dynamic> map) {
    final skuName = _requiredText(map['skuName'], 'skuName');
    final totalPrice = _finiteDouble(map['totalPrice'], 'totalPrice');
    if (totalPrice < 0) throw const FormatException('SKU totalPrice 不能为负数');
    final rawCart = map['aggProductList'];
    if (rawCart is! List) {
      throw const FormatException('SKU aggProductList 不是数组');
    }
    final shopCart = <VipShopCartItem>[];
    for (final raw in rawCart) {
      if (raw is! Map) throw const FormatException('购物车条目不是对象');
      shopCart.add(VipShopCartItem.fromMap(Map<String, dynamic>.from(raw)));
    }
    return VipCommonSku(
      skuName: skuName,
      totalPrice: totalPrice,
      shopCart: shopCart,
    );
  }

  final String skuName;
  final double totalPrice;
  final List<VipShopCartItem> shopCart;
}

final class VipWechatCredential {
  const VipWechatCredential({
    required this.appId,
    required this.partnerId,
    required this.prepayId,
    required this.nonceStr,
    required this.timeStamp,
    required this.packageValue,
    required this.sign,
  });

  factory VipWechatCredential.fromMap(Map<String, dynamic> map) {
    return VipWechatCredential(
      appId: _requiredText(map['appId'], 'appId'),
      partnerId: _requiredText(map['partnerId'], 'partnerId'),
      prepayId: _requiredText(map['prepayId'], 'prepayId'),
      nonceStr: _requiredText(map['nonceStr'], 'nonceStr'),
      timeStamp: _requiredText(map['timeStamp'], 'timeStamp'),
      packageValue: _requiredText(map['packageValue'], 'packageValue'),
      sign: _requiredText(map['sign'], 'sign'),
    );
  }

  final String appId;
  final String partnerId;
  final String prepayId;
  final String nonceStr;
  final String timeStamp;
  final String packageValue;
  final String sign;

  Map<String, String> toMap() => {
    'appId': appId,
    'partnerId': partnerId,
    'prepayId': prepayId,
    'nonceStr': nonceStr,
    'timeStamp': timeStamp,
    'packageValue': packageValue,
    'sign': sign,
  };
}

final class VipPaymentOrder {
  const VipPaymentOrder({
    required this.orderId,
    this.wechatCredential,
    this.alipayOrderInfo,
  });

  final String orderId;
  final VipWechatCredential? wechatCredential;
  final String? alipayOrderInfo;
}

final class VipSkuSelection {
  VipSkuSelection({
    required List<VipProduct> products,
    required List<VipCommonSku> skus,
  }) : products = List<VipProduct>.unmodifiable(products),
       skus = List<VipCommonSku>.unmodifiable(skus);

  final List<VipProduct> products;
  final List<VipCommonSku> skus;
}

final class VipBenefitLine {
  const VipBenefitLine({
    required this.subject,
    required this.type,
    required this.expiresOn,
    required this.text,
  });

  final String subject;
  final String type;
  final String expiresOn;
  final String text;
}

final class VipBenefitSummary {
  VipBenefitSummary({
    required List<VipBenefitLine> lines,
    required this.isFullMember,
    required this.hasPracticePackage,
    Set<String> ownedPracticeBenefitTypes = const {},
  }) : lines = List<VipBenefitLine>.unmodifiable(lines),
       ownedPracticeBenefitTypes = Set<String>.unmodifiable(
         ownedPracticeBenefitTypes,
       );

  final List<VipBenefitLine> lines;
  final bool isFullMember;
  final bool hasPracticePackage;
  final Set<String> ownedPracticeBenefitTypes;

  List<String> get headerPreview {
    final texts = lines.map((line) => line.text).toList(growable: false);
    if (texts.length <= 2) return texts;
    return List<String>.unmodifiable([...texts.take(2), '查看更多']);
  }

  int payPageSourceId(VipPurchaseRequest request) {
    return request.allowDifferenceUpgrade && !isFullMember && hasPracticePackage
        ? request.differencePayPageSourceId
        : request.normalPayPageSourceId;
  }
}

final class VipPurchaseSuccessSummary {
  const VipPurchaseSuccessSummary({
    required this.title,
    required this.expiresOn,
    required this.hasMemberTier,
  });

  const VipPurchaseSuccessSummary.generic()
    : title = '恭喜！会员开通成功',
      expiresOn = '',
      hasMemberTier = false;

  final String title;
  final String expiresOn;
  final bool hasMemberTier;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VipPurchaseSuccessSummary &&
            other.title == title &&
            other.expiresOn == expiresOn &&
            other.hasMemberTier == hasMemberTier;
  }

  @override
  int get hashCode => Object.hash(title, expiresOn, hasMemberTier);
}

final class BigSkillPracticePurchaseSuccessRequest {
  const BigSkillPracticePurchaseSuccessRequest({
    this.benefitKind = PracticeBenefitKind.regularPractice,
    this.navigateHomeOnBack = true,
    this.cachedPracticeModule,
    this.cachedCircleModule,
  });

  final PracticeBenefitKind benefitKind;
  final bool navigateHomeOnBack;
  final HomeModule? cachedPracticeModule;
  final HomeModule? cachedCircleModule;
}

final class BigSkillPracticePurchaseSuccessSummary {
  const BigSkillPracticePurchaseSuccessSummary({
    required this.kind,
    required this.benefitName,
    required this.expiresOn,
  });

  const BigSkillPracticePurchaseSuccessSummary.generic(this.kind)
    : benefitName = '',
      expiresOn = '';

  final PracticeBenefitKind kind;
  final String benefitName;
  final String expiresOn;

  String get title {
    final name = benefitName.trim().isEmpty
        ? kind.defaultBenefitName
        : benefitName.trim();
    return '恭喜！【$name】开通成功';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BigSkillPracticePurchaseSuccessSummary &&
            other.kind == kind &&
            other.benefitName == benefitName &&
            other.expiresOn == expiresOn;
  }

  @override
  int get hashCode => Object.hash(kind, benefitName, expiresOn);
}

BigSkillPracticePurchaseSuccessSummary
resolveBigSkillPracticePurchaseSuccessSummary(
  Object? rawBenefits, {
  required PracticeBenefitKind kind,
  required String category,
  required String level,
  DateTime Function()? now,
}) {
  final expectedCategory = category.trim();
  final expectedLevel = level.trim();
  final profile = _VipLevelBenefitProfile.resolve(
    expectedCategory,
    expectedLevel,
  );
  final legacyPrefix = profile == null
      ? null
      : _practiceBenefitPrefix(profile, kind);
  final clock = now ?? DateTime.now;
  for (final raw in _decodeBenefitList(rawBenefits)) {
    if (_text(raw['category']).trim() != expectedCategory) continue;
    final expiry = _parseBenefitExpiry(raw['expireTime'], clock());
    if (!expiry.valid) continue;
    final code = _text(raw['benefitsCode']).trim();
    if (code.isEmpty) continue;

    final matches = code.contains(':')
        ? _matchesAbstractPracticeBenefit(
            code,
            kind: kind,
            category: expectedCategory,
            level: expectedLevel,
          )
        : legacyPrefix != null && code.startsWith(legacyPrefix);
    if (!matches) continue;
    return BigSkillPracticePurchaseSuccessSummary(
      kind: kind,
      benefitName: _text(raw['benefitsDesc']).trim(),
      expiresOn: expiry.date,
    );
  }
  return BigSkillPracticePurchaseSuccessSummary.generic(kind);
}

String _practiceBenefitPrefix(
  _VipLevelBenefitProfile profile,
  PracticeBenefitKind kind,
) {
  return switch (kind) {
    PracticeBenefitKind.regularPractice => profile.regular,
    PracticeBenefitKind.fastPractice => profile.speed,
    PracticeBenefitKind.chapterPractice => profile.chapter,
    PracticeBenefitKind.pastExams => profile.pastExams,
  };
}

bool _matchesAbstractPracticeBenefit(
  String code, {
  required PracticeBenefitKind kind,
  required String category,
  required String level,
}) {
  final parts = code.split(':');
  return parts.length >= 4 &&
      _matchesBenefitScope(parts[0], category) &&
      _matchesBenefitScope(parts[1], level) &&
      parts[3].trim().toLowerCase() == kind.benefitType;
}

VipPurchaseSuccessSummary resolveVipPurchaseSuccessSummary(
  Object? rawBenefits, {
  required String category,
  required String level,
  DateTime Function()? now,
}) {
  final expectedCategory = category.trim();
  final expectedLevel = level.trim();
  final profile = _VipLevelBenefitProfile.resolve(
    expectedCategory,
    expectedLevel,
  );
  final clock = now ?? DateTime.now;
  for (final raw in _decodeBenefitList(rawBenefits)) {
    if (_text(raw['category']).trim() != expectedCategory) continue;
    final expiry = _parseBenefitExpiry(raw['expireTime'], clock());
    if (!expiry.valid) continue;
    final code = _text(raw['benefitsCode']).trim();
    if (code.isEmpty) continue;

    final isMemberTier = code.contains(':')
        ? _isAbstractFullMemberCode(
            code,
            category: expectedCategory,
            level: expectedLevel,
          )
        : profile != null && code.startsWith(profile.member);
    if (!isMemberTier) continue;

    final description = _text(raw['benefitsDesc']).trim();
    return VipPurchaseSuccessSummary(
      title: description.isEmpty ? '恭喜！会员开通成功' : '恭喜！【$description】开通成功',
      expiresOn: expiry.date,
      hasMemberTier: true,
    );
  }
  return const VipPurchaseSuccessSummary.generic();
}

bool _isAbstractFullMemberCode(
  String code, {
  required String category,
  required String level,
}) {
  final parts = code.split(':');
  return parts.length >= 4 &&
      _matchesBenefitScope(parts[0], category) &&
      _matchesBenefitScope(parts[1], level) &&
      parts[3].trim().toLowerCase() == 'all';
}

VipBenefitSummary resolveVipBenefitSummary(
  Object? rawBenefits, {
  required String category,
  required String level,
  required String categoryName,
  DateTime Function()? now,
}) {
  final decoded = _decodeBenefitList(rawBenefits);
  final clock = now ?? DateTime.now;
  final profile = _VipLevelBenefitProfile.resolve(
    category.trim(),
    level.trim(),
  );
  final parsed = <_ParsedVipBenefit>[];
  for (final raw in decoded) {
    final itemCategory = _text(raw['category']).trim();
    if (itemCategory != category.trim()) continue;
    final expiry = _parseBenefitExpiry(raw['expireTime'], clock());
    if (!expiry.valid) continue;
    final code = _text(raw['benefitsCode']).trim();
    if (code.isEmpty) continue;
    if (code.contains(':')) {
      final parts = code.split(':');
      if (parts.length < 4 ||
          !_matchesBenefitScope(parts[0], category) ||
          !_matchesBenefitScope(parts[1], level)) {
        continue;
      }
      parsed.add(
        _ParsedVipBenefit(
          subject: parts[2].trim().isEmpty ? 'all' : parts[2].trim(),
          type: parts[3].trim().toLowerCase(),
          expiresOn: expiry.date,
        ),
      );
      continue;
    }
    final legacy = profile?.parse(code, expiry.date);
    if (legacy != null) parsed.add(legacy);
  }

  final grouped = <String, List<_ParsedVipBenefit>>{};
  for (final benefit in parsed) {
    grouped.putIfAbsent(benefit.subject, () => []).add(benefit);
  }
  final visible = <_ParsedVipBenefit>[];
  for (final entry in grouped.entries) {
    final benefits = entry.value;
    _ParsedVipBenefit? allBenefit;
    _ParsedVipBenefit? skillBenefit;
    var hasSpeed = false;
    var hasPastExams = false;
    for (final benefit in benefits) {
      if (benefit.type == 'all' && allBenefit == null) {
        allBenefit = benefit;
      } else if (benefit.type == 'practice_skill' && skillBenefit == null) {
        skillBenefit = benefit;
      } else if (benefit.type == 'practice_speed') {
        hasSpeed = true;
      } else if (benefit.type == 'past_exams') {
        hasPastExams = true;
      }
    }
    if (allBenefit != null) visible.add(allBenefit);
    if (skillBenefit != null && hasSpeed && hasPastExams) {
      visible.add(
        _ParsedVipBenefit(
          subject: entry.key,
          type: 'answering_skills_vip',
          expiresOn: skillBenefit.expiresOn,
        ),
      );
    }
    visible.addAll(benefits.where((benefit) => benefit.type == 'course_video'));
  }
  visible.sort((left, right) {
    final priority = _benefitTypePriority(
      left.type,
    ).compareTo(_benefitTypePriority(right.type));
    return priority != 0 ? priority : left.subject.compareTo(right.subject);
  });
  final lines = visible
      .map((benefit) {
        final typeName = _benefitTypeName(benefit.type);
        final subject = benefit.subject.isEmpty || benefit.subject == 'all'
            ? categoryName.trim()
            : benefit.subject;
        final prefix = subject.isEmpty ? typeName : '$subject $typeName';
        final text = benefit.expiresOn.isEmpty
            ? prefix
            : '$prefix 有效期至 ${benefit.expiresOn}';
        return VipBenefitLine(
          subject: benefit.subject,
          type: benefit.type,
          expiresOn: benefit.expiresOn,
          text: text,
        );
      })
      .toList(growable: false);
  const practiceTypes = {
    'practice_skill',
    'practice_speed',
    'practice_chapter',
    'past_exams',
  };
  return VipBenefitSummary(
    lines: lines,
    isFullMember: parsed.any((benefit) => benefit.type == 'all'),
    hasPracticePackage: parsed.any(
      (benefit) => practiceTypes.contains(benefit.type),
    ),
    ownedPracticeBenefitTypes: parsed
        .map((benefit) => benefit.type)
        .where(practiceTypes.contains)
        .toSet(),
  );
}

final class VipPurchaseSession {
  VipPurchaseSession({
    required this.request,
    required this.category,
    required this.level,
    required List<VipSubject> subjects,
    required this.initialSubjectIndex,
    required List<VipProductType> productTypes,
    required this.initialProductType,
    required this.isLoggedIn,
    required this.showWechatPay,
    required this.initialPaymentChannel,
    required this.payPageSourceId,
    required this.nickname,
    required this.avatarUrl,
    required List<VipBenefitLine> benefitLines,
    this.isFullMember = false,
    this.hasPracticePackage = false,
    Set<String> ownedPracticeBenefitTypes = const {},
  }) : subjects = List<VipSubject>.unmodifiable(subjects),
       productTypes = List<VipProductType>.unmodifiable(productTypes),
       benefitLines = List<VipBenefitLine>.unmodifiable(benefitLines),
       ownedPracticeBenefitTypes = Set<String>.unmodifiable(
         ownedPracticeBenefitTypes,
       );

  final VipPurchaseRequest request;
  final String category;
  final String level;
  final List<VipSubject> subjects;
  final int initialSubjectIndex;
  final List<VipProductType> productTypes;
  final VipProductType initialProductType;
  final bool isLoggedIn;
  final bool showWechatPay;
  final VipPaymentChannel initialPaymentChannel;
  final int payPageSourceId;
  final String nickname;
  final String avatarUrl;
  final List<VipBenefitLine> benefitLines;
  final bool isFullMember;
  final bool hasPracticePackage;
  final Set<String> ownedPracticeBenefitTypes;
}

final class VipPrivilege {
  const VipPrivilege({
    required this.assetName,
    required this.title,
    this.subtitle,
  });

  final String assetName;
  final String title;
  final String? subtitle;
}

const _standardPrivileges = <VipPrivilege>[
  VipPrivilege(assetName: 'ic_vip_privilege_doc.png', title: '速成300题'),
  VipPrivilege(assetName: 'ic_vip_privilege_practice.png', title: '技巧练题+口诀'),
  VipPrivilege(assetName: 'ic_vip_privilege_lock.png', title: '最后密押卷'),
  VipPrivilege(assetName: 'ic_vip_privilege_real.png', title: '历年真题卷'),
  VipPrivilege(assetName: 'ic_vip_privilege_chapter.png', title: '章节练习'),
  VipPrivilege(assetName: 'ic_vip_privilege_card.png', title: '技巧卡片'),
];

const _coursePrivileges = <VipPrivilege>[
  VipPrivilege(
    assetName: 'ic_vip_privilege_video.png',
    title: '名师全科课程',
    subtitle: '直播+回放',
  ),
  VipPrivilege(assetName: 'ic_vip_privilege_folder.png', title: '独家电子资料'),
  VipPrivilege(assetName: 'ic_vip_privilege_expert.png', title: '1V1督学老师'),
];

List<VipPrivilege> vipPrivilegesFor(VipProductType type) {
  return type == VipProductType.course
      ? _coursePrivileges
      : _standardPrivileges;
}

List<VipPrivilege> vipBonusPrivilegesFor(VipProductType type) {
  return type == VipProductType.svip ? _coursePrivileges : const [];
}

final class _ParsedVipBenefit {
  const _ParsedVipBenefit({
    required this.subject,
    required this.type,
    required this.expiresOn,
  });

  final String subject;
  final String type;
  final String expiresOn;
}

final class _BenefitExpiry {
  const _BenefitExpiry({required this.valid, required this.date});

  final bool valid;
  final String date;
}

final class _VipLevelBenefitProfile {
  const _VipLevelBenefitProfile({
    required this.member,
    required this.regular,
    required this.speed,
    required this.chapter,
    required this.pastExams,
  });

  factory _VipLevelBenefitProfile._create(String prefix, String levelSuffix) {
    return _VipLevelBenefitProfile(
      member: '${prefix}_MEMBER_$levelSuffix',
      regular: '${prefix}_PRACTICE_REGULAR_$levelSuffix',
      speed: '${prefix}_PRACTICE_SPEED_$levelSuffix',
      chapter: '${prefix}_PRACTICE_CHAPTER_$levelSuffix',
      pastExams: '${prefix}_PRACTICE_PAST_EXAMS_$levelSuffix',
    );
  }

  static _VipLevelBenefitProfile? resolve(String category, String level) {
    return switch ((category, level)) {
      ('joy-ledger', '初级会计') => _VipLevelBenefitProfile._create('KJ', 'L1'),
      ('joy-ledger', '中级会计') => _VipLevelBenefitProfile._create('KJ', 'L2'),
      ('joy-ledger', '中级经济师') => _VipLevelBenefitProfile._create('KJEC', 'L2'),
      ('joy-ledger', '注册会计师') => _VipLevelBenefitProfile._create('ZCKJ', 'L3'),
      ('joy-ledger', '税务师') => _VipLevelBenefitProfile._create('SWS', 'L3'),
      ('social-work', '初级社工') => _VipLevelBenefitProfile._create('SW', 'L1'),
      ('social-work', '中级社工') => _VipLevelBenefitProfile._create('SW', 'L2'),
      ('cert-edu', '导游资格证') => _VipLevelBenefitProfile._create('DY', 'L1'),
      ('cert-edu', '计算机等级考试(一级)') => _VipLevelBenefitProfile._create(
        'JSJ',
        'L1',
      ),
      ('cert-edu', '计算机等级考试(二级)') => _VipLevelBenefitProfile._create(
        'JSJ',
        'L2',
      ),
      ('cert-edu', '计算机等级考试(三级)') => _VipLevelBenefitProfile._create(
        'JSJ',
        'L3',
      ),
      ('cert-edu', '计算机等级考试(四级)') => _VipLevelBenefitProfile._create(
        'JSJ',
        'L4',
      ),
      ('engineer', '消防工程师(一级)') => _VipLevelBenefitProfile._create('XF', 'L1'),
      ('engineer', '消防工程师(二级)') => _VipLevelBenefitProfile._create('XF', 'L2'),
      ('engineer', '造价工程师(一级)') => _VipLevelBenefitProfile._create('ZJ', 'L1'),
      ('finance', '证券从业资格') => _VipLevelBenefitProfile._create('ZQ', 'L1'),
      _ => null,
    };
  }

  final String member;
  final String regular;
  final String speed;
  final String chapter;
  final String pastExams;

  _ParsedVipBenefit? parse(String code, String expiresOn) {
    final type = switch (code) {
      _ when code.startsWith(member) => 'all',
      _ when code.startsWith(regular) => 'practice_skill',
      _ when code.startsWith(speed) => 'practice_speed',
      _ when code.startsWith(chapter) => 'practice_chapter',
      _ when code.startsWith(pastExams) => 'past_exams',
      _ => null,
    };
    return type == null
        ? null
        : _ParsedVipBenefit(subject: 'all', type: type, expiresOn: expiresOn);
  }
}

List<Map<String, dynamic>> _decodeBenefitList(Object? rawBenefits) {
  Object? decoded = rawBenefits;
  if (rawBenefits is String) {
    if (rawBenefits.trim().isEmpty) return const [];
    try {
      decoded = jsonDecode(rawBenefits);
    } on FormatException {
      return const [];
    }
  }
  if (decoded is! List) return const [];
  return decoded
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

_BenefitExpiry _parseBenefitExpiry(Object? raw, DateTime now) {
  final text = _text(raw).trim();
  if (text.isEmpty) return const _BenefitExpiry(valid: true, date: '');
  final timestamp = int.tryParse(text);
  if (timestamp != null) {
    if (timestamp <= 0) return const _BenefitExpiry(valid: true, date: '');
    final milliseconds = timestamp < 100000000000
        ? timestamp * 1000
        : timestamp;
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return _BenefitExpiry(valid: date.isAfter(now), date: _formatVipDate(date));
  }
  final date = DateTime.tryParse(text.replaceFirst(' ', 'T'));
  if (date == null) return const _BenefitExpiry(valid: false, date: '');
  return _BenefitExpiry(valid: date.isAfter(now), date: _formatVipDate(date));
}

String _formatVipDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

bool _matchesBenefitScope(String rule, String value) {
  final normalized = rule.trim().toLowerCase();
  return normalized == 'all' || normalized == value.trim().toLowerCase();
}

int _benefitTypePriority(String type) => switch (type) {
  'all' => 1,
  'answering_skills_vip' => 2,
  'course_video' => 3,
  _ => 20,
};

String _benefitTypeName(String type) => switch (type) {
  'all' => '全能SVIP',
  'course_video' => '课程VIP',
  'answering_skills_vip' => '答题技巧VIP',
  'practice_skill' => '技巧练题',
  'skill_mnemonic' => '技巧口诀',
  'practice_speed' => '速成练题',
  'practice_chapter' => '章节练习',
  'skill_card' => '技巧卡片',
  'past_exams' => '历年真题卷',
  'final_prediction' => '最后密押卷',
  _ => type,
};

String _text(Object? value) => value?.toString() ?? '';

String _requiredText(Object? value, String name) {
  final text = _text(value).trim();
  if (text.isEmpty) throw FormatException('$name 为空');
  return text;
}

int _optionalInt(Object? value) {
  if (value == null) return 0;
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? 0;
}

int _requiredPositiveInt(Object? value, String name) {
  final parsed = value is int ? value : int.tryParse(value.toString());
  if (parsed == null || parsed <= 0) {
    throw FormatException('$name 不是正整数');
  }
  return parsed;
}

double _finiteDouble(Object? value, String name) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value.toString());
  if (parsed == null || !parsed.isFinite) {
    throw FormatException('$name 不是有限数字');
  }
  return parsed;
}
