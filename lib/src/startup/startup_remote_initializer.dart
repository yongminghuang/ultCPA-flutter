import 'dart:math';

import 'package:dio/dio.dart';

import '../network/method_channel_request_context.dart';
import 'startup_coordinator.dart';

final class StartupRemoteInitializer implements StartupPostConsentInitializer {
  StartupRemoteInitializer({
    required Dio dio,
    required String baseUrl,
    required MethodChannelRequestContext requestContext,
    String? deviceLoginSuffix,
  }) : _dio = dio,
       _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
       _requestContext = requestContext,
       _deviceLoginSuffix = deviceLoginSuffix ?? _newDeviceLoginSuffix();

  static const staticInfoKeys = <String>[
    'oss_domain',
    'add_teacher_h5_url',
    'collect_book_h5_url',
    'floating_window_url',
    'skill_question_free_count',
    'skill_formula_free_question_count',
    'chapter_question_free_count',
    'home_top_banner',
    'default_category',
    'exam_time',
    'app_category_name_mapping',
    'invite_fission_activity',
  ];

  final Dio _dio;
  final String _baseUrl;
  final MethodChannelRequestContext _requestContext;
  final String _deviceLoginSuffix;

  @override
  Future<void> initialize() async {
    final headers = await _requestContext.headers();
    final category = headers['X-category'] ?? 'social-work';
    final staticResponse = await _post('/currency/dict/list', {
      'appType': category,
      'keys': staticInfoKeys,
    }, headers: headers);
    _requireSuccess(staticResponse);
    await _requestContext.persistStaticConfiguration(
      _staticConfigurationValues(staticResponse['body']),
    );

    await DeviceSessionInitializer(
      dio: _dio,
      baseUrl: _baseUrl,
      requestContext: _requestContext,
      deviceLoginSuffix: _deviceLoginSuffix,
    ).initialize();
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final response = await _dio.post<Object?>(
      '$_baseUrl$path',
      data: body,
      options: Options(
        headers: headers,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
    return _asMap(response.data, '接口响应不是 JSON 对象');
  }

  static Map<String, dynamic> _asMap(Object? value, String message) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw FormatException(message);
  }

  static void _requireSuccess(Map<String, dynamic> response) {
    final rawCode = response['code'];
    final code = rawCode is int ? rawCode : int.tryParse(rawCode.toString());
    if (code != 200 && code != 2001) {
      throw StateError(response['msg']?.toString() ?? '请求失败');
    }
  }

  static Map<String, String> _staticConfigurationValues(Object? body) {
    if (body is! List) {
      throw const FormatException('静态配置响应 body 不是数组');
    }
    final values = <String, String>{};
    for (final item in body) {
      if (item is! Map) continue;
      final key = item['key']?.toString() ?? '';
      if (key.isEmpty) continue;
      values[key] = item['value']?.toString() ?? '';
    }
    return values;
  }

  static String _newDeviceLoginSuffix() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final value = bytes.map(hex).join();
    final uuid =
        '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
    final randomLong = random.nextInt(0x7fffffff) - random.nextInt(0x7fffffff);
    return '$uuid/$randomLong';
  }
}

final class DeviceSessionInitializer implements StartupPostConsentInitializer {
  DeviceSessionInitializer({
    required Dio dio,
    required String baseUrl,
    required MethodChannelRequestContext requestContext,
    String? deviceLoginSuffix,
  }) : _dio = dio,
       _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
       _requestContext = requestContext,
       _deviceLoginSuffix =
           deviceLoginSuffix ??
           StartupRemoteInitializer._newDeviceLoginSuffix();

  final Dio _dio;
  final String _baseUrl;
  final MethodChannelRequestContext _requestContext;
  final String _deviceLoginSuffix;

  @override
  Future<void> initialize() async {
    final response = await _dio.post<Object?>(
      '$_baseUrl/app/device/hardware/$_deviceLoginSuffix',
      data: await _requestContext.deviceLoginBody(),
      options: Options(
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
    final envelope = StartupRemoteInitializer._asMap(
      response.data,
      '硬件登录响应不是 JSON 对象',
    );
    StartupRemoteInitializer._requireSuccess(envelope);
    final body = StartupRemoteInitializer._asMap(
      envelope['body'],
      '硬件登录响应 body 为空',
    );
    final user = StartupRemoteInitializer._asMap(body['user'], '硬件登录用户为空');
    final accessToken = body['accessToken']?.toString() ?? '';
    final userId = user['id']?.toString() ?? '';
    if (accessToken.isEmpty || userId.isEmpty) {
      throw const FormatException('硬件登录缺少 accessToken 或 user.id');
    }
    await _requestContext.persistSession(
      accessToken: accessToken,
      userId: userId,
    );
  }
}

final class MethodChannelStartupInitializer
    implements StartupPostConsentInitializer {
  MethodChannelStartupInitializer({
    required Dio dio,
    required MethodChannelRequestContext requestContext,
  }) : _dio = dio,
       _requestContext = requestContext;

  final Dio _dio;
  final MethodChannelRequestContext _requestContext;

  @override
  Future<void> initialize() async {
    await StartupRemoteInitializer(
      dio: _dio,
      baseUrl: await _requestContext.apiBaseUrl(),
      requestContext: _requestContext,
    ).initialize();
  }
}
