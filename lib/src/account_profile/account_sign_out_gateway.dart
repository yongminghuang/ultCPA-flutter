import 'dart:async';

import 'package:dio/dio.dart';

import '../network/app_api_client.dart';

abstract interface class AccountSignOutGateway {
  Future<void> dispatch();
}

final class DioAccountSignOutGateway implements AccountSignOutGateway {
  DioAccountSignOutGateway({
    required Dio dio,
    required ApiBaseUrlProvider apiBaseUrl,
    required AppHeadersProvider headers,
  }) : _dio = dio,
       _apiBaseUrl = apiBaseUrl,
       _headers = headers;

  static const path = '/app/user/v1/logout';

  final Dio _dio;
  final ApiBaseUrlProvider _apiBaseUrl;
  final AppHeadersProvider _headers;

  @override
  Future<void> dispatch() async {
    final baseUrl = (await _apiBaseUrl()).replaceFirst(RegExp(r'/$'), '');
    final signedHeaders = await _headers();
    final request = _dio.post<Object?>(
      '$baseUrl$path',
      data: '',
      options: Options(
        headers: signedHeaders,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
    unawaited(request.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
  }
}
