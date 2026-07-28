import 'dart:convert';

import 'package:dio/dio.dart';

typedef ApiBaseUrlProvider = Future<String> Function();
typedef AppHeadersProvider = Future<Map<String, String>> Function();

abstract interface class AppApiClient {
  Future<Object?> getBody(String path, {Map<String, dynamic>? queryParameters});

  Future<Object?> postBody(String path, Map<String, dynamic> body);
}

final class AppApiException implements Exception {
  const AppApiException(this.message, {this.code});

  final String message;
  final int? code;

  @override
  String toString() => 'AppApiException($code): $message';
}

final class DioAppApiClient implements AppApiClient {
  DioAppApiClient({
    required Dio dio,
    required ApiBaseUrlProvider apiBaseUrl,
    required AppHeadersProvider headers,
  }) : _dio = dio,
       _apiBaseUrl = apiBaseUrl,
       _headers = headers;

  final Dio _dio;
  final ApiBaseUrlProvider _apiBaseUrl;
  final AppHeadersProvider _headers;

  @override
  Future<Object?> getBody(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get<Object?>(
      '${await _normalizedBaseUrl()}$path',
      queryParameters: queryParameters,
      options: _options(await _headers()),
    );
    return _resolveBody(response.data);
  }

  @override
  Future<Object?> postBody(String path, Map<String, dynamic> body) async {
    final response = await _dio.post<Object?>(
      '${await _normalizedBaseUrl()}$path',
      data: body,
      options: _options(await _headers()),
    );
    return _resolveBody(response.data);
  }

  Future<String> _normalizedBaseUrl() async {
    return (await _apiBaseUrl()).replaceFirst(RegExp(r'/$'), '');
  }

  static Options _options(Map<String, String> headers) {
    return Options(
      headers: headers,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    );
  }

  static Object? _resolveBody(Object? raw) {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map) {
      throw const FormatException('接口响应不是 JSON 对象');
    }
    final response = Map<String, dynamic>.from(decoded);
    final rawCode = response['code'];
    final code = rawCode is int ? rawCode : int.tryParse(rawCode.toString());
    if (code != 200 && code != 2001) {
      throw AppApiException(
        (response['msg'] ?? response['message'] ?? '请求失败').toString(),
        code: code,
      );
    }
    return response['body'];
  }
}
