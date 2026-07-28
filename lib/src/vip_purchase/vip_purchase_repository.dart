import 'dart:convert';

import '../main_tabs/main_tabs_models.dart';
import '../network/app_api_client.dart';
import '../storage/legacy_app_state_store.dart';
import 'vip_purchase_models.dart';

abstract interface class VipPurchaseDataSource {
  Future<VipPurchaseSession> loadSession(VipPurchaseRequest request);

  Future<VipPurchaseSuccessSummary> loadSuccessSummary(
    VipPurchaseSession session,
  );

  Future<VipSkuSelection> loadSkus({
    required VipPurchaseSession session,
    required VipProductType type,
    required List<VipSubject> subjects,
  });

  Future<VipPaymentOrder> createOrder({
    required VipPurchaseSession session,
    required VipPaymentChannel channel,
    required List<VipShopCartItem> shopCart,
  });

  Future<bool> confirmWechatPayment();
}

abstract interface class VipCommodityOrderDataSource {
  Future<VipPaymentOrder> createCommodityOrder({
    required VipPurchaseSession session,
    required VipPaymentChannel channel,
    required String commodityId,
  });
}

final class VipPurchaseRepository
    implements VipPurchaseDataSource, VipCommodityOrderDataSource {
  VipPurchaseRepository({
    required AppApiClient api,
    required LegacyAppStateStore stateStore,
    DateTime Function()? now,
  }) : _api = api,
       _stateStore = stateStore,
       _now = now ?? DateTime.now;

  final AppApiClient _api;
  final LegacyAppStateStore _stateStore;
  final DateTime Function() _now;

  @override
  Future<VipPurchaseSession> loadSession(VipPurchaseRequest request) async {
    final snapshot = _safeSnapshot(await _stateStore.readAppSnapshot());
    final category = _resolveCategory(snapshot);
    final subjects = category.subjects.isEmpty
        ? const [
            VipSubject(id: 6, name: '会计实务'),
            VipSubject(id: 7, name: '经济法基础'),
          ]
        : category.subjects;
    final subjectIndex = resolveInitialVipSubjectIndex(
      subjects,
      selectedMarketId: snapshot.selectedMarketId,
    );
    final selectedSubject = subjectIndex < 0 ? '' : subjects[subjectIndex].name;
    final expanded = await _loadExpandedTypeFlag(
      level: category.level,
      subject: selectedSubject,
    );
    final productTypes = visibleVipProductTypes(expanded: expanded);
    final benefitSummary = await _loadBenefitSummary(
      snapshot,
      level: category.level,
      categoryName: category.name,
    );
    final initialChannel = !snapshot.showWxPay || snapshot.defaultPayType == 2
        ? VipPaymentChannel.alipay
        : VipPaymentChannel.wechat;
    return VipPurchaseSession(
      request: request,
      category: snapshot.category,
      level: category.level,
      subjects: subjects,
      initialSubjectIndex: subjectIndex,
      productTypes: productTypes,
      initialProductType: defaultVipProductType(
        expanded: expanded,
        explicit: request.defaultProductType,
      ),
      isLoggedIn: snapshot.isLoggedIn,
      showWechatPay: snapshot.showWxPay,
      initialPaymentChannel: initialChannel,
      payPageSourceId: benefitSummary.payPageSourceId(request),
      nickname: snapshot.nickname,
      avatarUrl: snapshot.avatar,
      benefitLines: benefitSummary.lines,
      isFullMember: benefitSummary.isFullMember,
      hasPracticePackage: benefitSummary.hasPracticePackage,
      ownedPracticeBenefitTypes: benefitSummary.ownedPracticeBenefitTypes,
    );
  }

  Future<bool> _loadExpandedTypeFlag({
    required String level,
    required String subject,
  }) async {
    if (level.isEmpty || subject.isEmpty) return false;
    try {
      final body = await _api.getBody(
        '/app/tempMedia/countGroupByLevelAndSubject',
      );
      if (body is! List) return false;
      for (final raw in body) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        if (_text(item['level']).trim() == level.trim() &&
            _text(item['subject']).trim() == subject.trim() &&
            _int(item['count']) > 0) {
          return true;
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  @override
  Future<VipPurchaseSuccessSummary> loadSuccessSummary(
    VipPurchaseSession session,
  ) async {
    try {
      final body = await _api.getBody('/app/user/getUserBenefits');
      if (body is! List) {
        return const VipPurchaseSuccessSummary.generic();
      }
      return resolveVipPurchaseSuccessSummary(
        body,
        category: session.category,
        level: session.level,
        now: _now,
      );
    } catch (_) {
      return const VipPurchaseSuccessSummary.generic();
    }
  }

  Future<VipBenefitSummary> _loadBenefitSummary(
    AppSnapshot snapshot, {
    required String level,
    required String categoryName,
  }) async {
    Object? benefits = snapshot.userBenefitsJson;
    if (snapshot.isLoggedIn) {
      try {
        final live = await _api.getBody('/app/user/getUserBenefits');
        if (live is List) benefits = live;
      } catch (_) {
        // Android keeps the last valid benefit cache when refresh fails.
      }
    }
    return resolveVipBenefitSummary(
      benefits,
      category: snapshot.category,
      level: level,
      categoryName: categoryName,
      now: _now,
    );
  }

  @override
  Future<VipSkuSelection> loadSkus({
    required VipPurchaseSession session,
    required VipProductType type,
    required List<VipSubject> subjects,
  }) async {
    final products = <VipProduct>[];
    for (final subject in subjects) {
      final body = await _api.postBody('/app/product/v1/queryProduct', {
        'category': session.category,
        'level': session.level,
        'subject': subject.name,
        'productType': type.apiValue,
        'productId': null,
        'loadSameTypeProducts': true,
      });
      final product = _firstValidProduct(body);
      if (product != null) products.add(product);
    }
    if (products.isEmpty) {
      return VipSkuSelection(products: const [], skus: const []);
    }
    final body = await _api.postBody('/app/product/v1/queryCommonProductSku', {
      'productIds': products.map((product) => product.productId).toList(),
    });
    if (body is! List) {
      throw const FormatException('组合 SKU 响应不是数组');
    }
    final skus = <VipCommonSku>[];
    for (final raw in body) {
      if (raw is! Map) throw const FormatException('组合 SKU 不是对象');
      skus.add(VipCommonSku.fromMap(Map<String, dynamic>.from(raw)));
    }
    return VipSkuSelection(products: products, skus: skus);
  }

  @override
  Future<VipPaymentOrder> createOrder({
    required VipPurchaseSession session,
    required VipPaymentChannel channel,
    required List<VipShopCartItem> shopCart,
  }) async {
    if (shopCart.isEmpty) {
      throw ArgumentError.value(shopCart, 'shopCart', '购物车不能为空');
    }
    final path = switch (channel) {
      VipPaymentChannel.wechat => '/app/order/v1/wxPayOrder',
      VipPaymentChannel.alipay => '/app/order/v1/aliPayOrder',
    };
    final body = await _api.postBody(path, {
      'commodityId': null,
      'payPageSourceId': session.payPageSourceId,
      'shopCart': shopCart.map((item) => item.toJson()).toList(),
    });
    return _paymentOrderFromBody(body, channel: channel);
  }

  @override
  Future<VipPaymentOrder> createCommodityOrder({
    required VipPurchaseSession session,
    required VipPaymentChannel channel,
    required String commodityId,
  }) async {
    final normalizedCommodityId = commodityId.trim();
    if (normalizedCommodityId.isEmpty) {
      throw ArgumentError.value(commodityId, 'commodityId', '商品 ID 不能为空');
    }
    final path = switch (channel) {
      VipPaymentChannel.wechat => '/app/order/v1/wxPayOrder',
      VipPaymentChannel.alipay => '/app/order/v1/aliPayOrder',
    };
    final body = await _api.postBody(path, {
      'commodityId': normalizedCommodityId,
      'payPageSourceId': session.payPageSourceId,
      'shopCart': null,
    });
    return _paymentOrderFromBody(body, channel: channel);
  }

  @override
  Future<bool> confirmWechatPayment() async {
    final body = await _api.getBody('/app/order/v2/getOrderPayStatus');
    return body is String && body == '成功';
  }
}

VipPaymentOrder _paymentOrderFromBody(
  Object? body, {
  required VipPaymentChannel channel,
}) {
  if (body is! Map) throw const FormatException('支付订单响应不是对象');
  final values = Map<String, dynamic>.from(body);
  final orderId = _requiredText(values['orderId'], 'orderId');
  return switch (channel) {
    VipPaymentChannel.wechat => VipPaymentOrder(
      orderId: orderId,
      wechatCredential: _wechatCredential(values['credential']),
    ),
    VipPaymentChannel.alipay => VipPaymentOrder(
      orderId: orderId,
      alipayOrderInfo: _normalizeAlipayCredential(values['credential']),
    ),
  };
}

AppSnapshot _safeSnapshot(Map<String, dynamic> raw) {
  try {
    return AppSnapshot.fromMap(raw);
  } on FormatException {
    return AppSnapshot.fromMap({...raw, 'selectedCategoryJson': ''});
  }
}

_VipCategory _resolveCategory(AppSnapshot snapshot) {
  var raw = snapshot.selectedCategory;
  if (_subjects(raw).isEmpty) {
    raw = _findCategoryInBody(snapshot) ?? const {};
  }
  final level = _text(raw['level']).trim().isNotEmpty
      ? _text(raw['level']).trim()
      : snapshot.selectedLevel.trim();
  final name = _text(raw['name']).trim().isNotEmpty
      ? _text(raw['name']).trim()
      : level;
  return _VipCategory(name: name, level: level, subjects: _subjects(raw));
}

Map<String, dynamic>? _findCategoryInBody(AppSnapshot snapshot) {
  if (snapshot.categoryBodyJson.trim().isEmpty) return null;
  Object? decoded;
  try {
    decoded = jsonDecode(snapshot.categoryBodyJson);
  } on FormatException {
    return null;
  }
  if (decoded is! Map || decoded[snapshot.category] is! List) return null;
  final candidates = (decoded[snapshot.category] as List)
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
  if (candidates.isEmpty) return null;
  final selectedId = _int(snapshot.selectedCategory['id']);
  final keyParts = snapshot.selectedCategoryKey.split('_');
  final keyId = int.tryParse(keyParts.isEmpty ? '' : keyParts.last);
  for (final candidate in candidates) {
    final id = _int(candidate['id']);
    if ((selectedId > 0 && id == selectedId) ||
        (keyId != null && keyId > 0 && id == keyId) ||
        (_text(candidate['level']).trim() == snapshot.selectedLevel.trim() &&
            snapshot.selectedLevel.trim().isNotEmpty)) {
      return candidate;
    }
  }
  return candidates.first;
}

List<VipSubject> _subjects(Map<String, dynamic> category) {
  final rawChildren = category['children'];
  if (rawChildren is! List) return const [];
  final subjects = <VipSubject>[];
  for (final raw in rawChildren) {
    if (raw is! Map) continue;
    final child = Map<String, dynamic>.from(raw);
    final id = _int(child['id']);
    final name = _text(child['name']).trim();
    if (id > 0 && name.isNotEmpty) {
      subjects.add(VipSubject(id: id, name: name));
    }
  }
  return List<VipSubject>.unmodifiable(subjects);
}

final class _VipCategory {
  const _VipCategory({
    required this.name,
    required this.level,
    required this.subjects,
  });

  final String name;
  final String level;
  final List<VipSubject> subjects;
}

String _text(Object? value) => value?.toString() ?? '';

int _int(Object? value) {
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? 0;
}

VipProduct? _firstValidProduct(Object? body) {
  final candidates = body is List ? body : [body];
  for (final raw in candidates) {
    if (raw is! Map) continue;
    try {
      return VipProduct.fromMap(Map<String, dynamic>.from(raw));
    } on FormatException {
      continue;
    }
  }
  return null;
}

String _requiredText(Object? value, String name) {
  final text = _text(value).trim();
  if (text.isEmpty) throw FormatException('$name 为空');
  return text;
}

VipWechatCredential _wechatCredential(Object? raw) {
  if (raw is! Map) throw const FormatException('微信支付凭证不是对象');
  return VipWechatCredential.fromMap(Map<String, dynamic>.from(raw));
}

String _normalizeAlipayCredential(Object? raw) {
  if (raw == null) throw const FormatException('支付宝支付凭证为空');
  var value = raw.toString().trim();
  if (value.startsWith('"') && value.endsWith('"') && value.length > 1) {
    value = value.substring(1, value.length - 1);
  }
  value = value.replaceAll(r'\"', '"').trim();
  if (value.isEmpty) throw const FormatException('支付宝支付凭证为空');
  return value;
}
