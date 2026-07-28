final class PurchaseHistoryItem {
  const PurchaseHistoryItem({required this.productName});

  final String? productName;

  factory PurchaseHistoryItem.fromMap(Map<String, dynamic> values) {
    return PurchaseHistoryItem(
      productName: _nullableString(values['productName']),
    );
  }
}

final class PurchaseHistoryOrder {
  const PurchaseHistoryOrder({
    required this.orderId,
    required this.commodityName,
    required this.orderAmount,
    required this.payTime,
    required this.orderStatus,
    required this.benefitsExpireTime,
    required this.items,
  });

  final String orderId;
  final String? commodityName;
  final double? orderAmount;
  final String? payTime;
  final String? orderStatus;
  final String? benefitsExpireTime;
  final List<PurchaseHistoryItem> items;

  factory PurchaseHistoryOrder.fromMap(Map<String, dynamic> values) {
    final rawItems = values['items'];
    if (rawItems != null && rawItems is! List) {
      throw const FormatException('订单商品列表格式无效');
    }
    final items = <PurchaseHistoryItem>[];
    if (rawItems is List) {
      for (final rawItem in rawItems) {
        if (rawItem == null) continue;
        if (rawItem is! Map) {
          throw const FormatException('订单商品格式无效');
        }
        try {
          items.add(
            PurchaseHistoryItem.fromMap(Map<String, dynamic>.from(rawItem)),
          );
        } on TypeError {
          throw const FormatException('订单商品格式无效');
        }
      }
    }
    return PurchaseHistoryOrder(
      orderId: _nullableString(values['orderId']) ?? '',
      commodityName: _nullableString(values['commodityName']),
      orderAmount: _nullableDouble(values['orderAmount']),
      payTime: _nullableString(values['payTime']),
      orderStatus: _nullableString(values['orderStatus']),
      benefitsExpireTime: _nullableString(values['benefitsExpireTime']),
      items: List.unmodifiable(items),
    );
  }

  String get displayTitle {
    final title = commodityName;
    if (title != null && title.trim().isNotEmpty) return title;
    final names = items
        .map((item) => item.productName)
        .whereType<String>()
        .where((name) => name.trim().isNotEmpty)
        .toList(growable: false);
    return names.isEmpty ? '--' : names.join('\n');
  }
}

String formatPurchaseAmount(num? amount) {
  final value = amount?.toDouble();
  if (value == null || !value.isFinite || value == 0) return '¥0';
  final plain = _expandScientific(value.toString());
  return '¥${_stripDecimalZeros(plain)}';
}

int parsePurchaseTimeMillis(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 0;
  final parsedDate = DateTime.tryParse(text);
  if (parsedDate != null) return parsedDate.millisecondsSinceEpoch;
  return int.tryParse(text) ?? 0;
}

List<PurchaseHistoryOrder> sortPurchaseOrdersNewestFirst(
  Iterable<PurchaseHistoryOrder> orders,
) {
  final indexed = orders.toList(growable: false).indexed.toList();
  indexed.sort((left, right) {
    final byTime = parsePurchaseTimeMillis(
      right.$2.payTime,
    ).compareTo(parsePurchaseTimeMillis(left.$2.payTime));
    return byTime != 0 ? byTime : left.$1.compareTo(right.$1);
  });
  return List.unmodifiable(indexed.map((entry) => entry.$2));
}

String? _nullableString(Object? value) {
  return value?.toString();
}

double? _nullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final parsed = double.tryParse(value.toString().trim());
  if (parsed == null) throw const FormatException('订单金额格式无效');
  return parsed;
}

String _stripDecimalZeros(String value) {
  if (!value.contains('.')) return value;
  var end = value.length;
  while (end > 0 && value.codeUnitAt(end - 1) == 0x30) {
    end -= 1;
  }
  if (end > 0 && value.codeUnitAt(end - 1) == 0x2E) end -= 1;
  final stripped = value.substring(0, end);
  return stripped == '-0' ? '0' : stripped;
}

String _expandScientific(String value) {
  final marker = value.indexOf(RegExp('[eE]'));
  if (marker < 0) return value;
  final exponent = int.parse(value.substring(marker + 1));
  var coefficient = value.substring(0, marker);
  final negative = coefficient.startsWith('-');
  if (negative || coefficient.startsWith('+')) {
    coefficient = coefficient.substring(1);
  }
  final dot = coefficient.indexOf('.');
  final decimalIndex = dot < 0 ? coefficient.length : dot;
  final digits = coefficient.replaceFirst('.', '');
  final shiftedIndex = decimalIndex + exponent;
  final expanded = switch (shiftedIndex) {
    <= 0 => '0.${'0' * -shiftedIndex}$digits',
    final index when index >= digits.length =>
      '$digits${'0' * (index - digits.length)}',
    final index => '${digits.substring(0, index)}.${digits.substring(index)}',
  };
  return negative ? '-$expanded' : expanded;
}
