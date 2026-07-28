import 'dart:convert';

import 'package:dio/dio.dart';

import 'phone_captcha_client.dart';

typedef RequestHeadersProvider = Future<Map<String, String>> Function();

final class DioCaptchaTransport implements CaptchaTransport {
  DioCaptchaTransport({
    required Dio dio,
    required String baseUrl,
    required RequestHeadersProvider headers,
  }) : _dio = dio,
       _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
       _headers = headers;

  final Dio _dio;
  final String _baseUrl;
  final RequestHeadersProvider _headers;

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.post<Object?>(
      '$_baseUrl$path',
      data: body,
      options: Options(
        headers: await _headers(),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
    final data = response.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    throw const FormatException('Expected a JSON object response.');
  }
}
