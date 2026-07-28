import 'dart:convert';

import 'package:dio/dio.dart';

import '../network/app_api_client.dart';

abstract interface class AccountDeactivationGateway {
  Future<void> deactivate();
}

final class DioAccountDeactivationGateway
    implements AccountDeactivationGateway {
  DioAccountDeactivationGateway({
    required Dio dio,
    required ApiBaseUrlProvider apiBaseUrl,
    required AppHeadersProvider headers,
  }) : _dio = dio,
       _apiBaseUrl = apiBaseUrl,
       _headers = headers;

  static const path = '/app/user/deactivate';

  final Dio _dio;
  final ApiBaseUrlProvider _apiBaseUrl;
  final AppHeadersProvider _headers;

  @override
  Future<void> deactivate() async {
    final baseUrl = (await _apiBaseUrl()).replaceFirst(RegExp(r'/$'), '');
    final response = await _dio.post<Object?>(
      '$baseUrl$path',
      data: '',
      options: Options(
        headers: await _headers(),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
    final raw = response.data;
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map) {
      throw const FormatException('账号注销响应不是 JSON 对象');
    }
    final envelope = Map<String, dynamic>.from(decoded);
    final rawCode = envelope['code'];
    final code = rawCode is int ? rawCode : int.tryParse(rawCode.toString());
    if (code != 200 && code != 2001) {
      throw AppApiException(
        (envelope['msg'] ?? envelope['message'] ?? '账号注销失败').toString(),
        code: code,
      );
    }
  }
}
