import 'dart:convert';

import 'package:dio/dio.dart';

import '../network/app_api_client.dart';
import 'purchase_history_models.dart';

abstract interface class PurchaseHistoryDataSource {
  Future<List<PurchaseHistoryOrder>> loadOrders();
}

final class DioPurchaseHistoryRepository implements PurchaseHistoryDataSource {
  DioPurchaseHistoryRepository({
    required Dio dio,
    required ApiBaseUrlProvider apiBaseUrl,
    required AppHeadersProvider headers,
  }) : _dio = dio,
       _apiBaseUrl = apiBaseUrl,
       _headers = headers;

  static const path = '/app/order/v1/getMyOrder';

  final Dio _dio;
  final ApiBaseUrlProvider _apiBaseUrl;
  final AppHeadersProvider _headers;

  @override
  Future<List<PurchaseHistoryOrder>> loadOrders() async {
    final baseUrl = (await _apiBaseUrl()).replaceFirst(RegExp(r'/$'), '');
    final response = await _dio.get<Object?>(
      '$baseUrl$path',
      options: Options(
        headers: await _headers(),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
    final envelope = _decodeEnvelope(response.data);
    final rawCode = envelope['code'];
    final code = rawCode is int ? rawCode : int.tryParse(rawCode.toString());
    if (code != 0 && code != 200 && code != 2001) {
      throw AppApiException(
        (envelope['msg'] ?? envelope['message'] ?? '请求失败').toString(),
        code: code,
      );
    }
    final rawBody = _decodeOrderBody(envelope['body']);
    if (rawBody == null) return const [];
    if (rawBody is! List) {
      throw const FormatException('订单列表解析失败');
    }
    final orders = <PurchaseHistoryOrder>[];
    for (final rawOrder in rawBody) {
      if (rawOrder == null) continue;
      if (rawOrder is! Map) {
        throw const FormatException('订单列表解析失败');
      }
      try {
        orders.add(
          PurchaseHistoryOrder.fromMap(Map<String, dynamic>.from(rawOrder)),
        );
      } on TypeError {
        throw const FormatException('订单列表解析失败');
      }
    }
    return sortPurchaseOrdersNewestFirst(orders);
  }

  static Map<String, dynamic> _decodeEnvelope(Object? raw) {
    if (raw is String && raw.trim().isEmpty) {
      throw const FormatException('数据为空');
    }
    Object? decoded;
    try {
      decoded = raw is String ? jsonDecode(raw) : raw;
    } on FormatException {
      throw const FormatException('解析失败');
    }
    if (decoded is! Map) throw const FormatException('解析失败');
    try {
      return Map<String, dynamic>.from(decoded);
    } on TypeError {
      throw const FormatException('解析失败');
    }
  }

  static Object? _decodeOrderBody(Object? raw) {
    if (raw is! String) return raw;
    if (raw.trim() == 'null') return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      throw const FormatException('订单列表解析失败');
    }
  }
}
