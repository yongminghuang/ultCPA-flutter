import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/network/method_channel_request_context.dart';
import 'package:ultcpa_flutter/src/startup/startup_remote_initializer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(MethodChannelRequestContext.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'calls static config and hardware login then persists session',
    () async {
      final persisted = <String, Object?>{};
      Map<String, Object?>? staticValues;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'buildRequestHeaders':
                return {'X-sign': 'signed'};
              case 'buildDeviceLoginBody':
                return {'params': 'encrypted-device', 'timestamp': '123'};
              case 'persistSession':
                persisted.addAll(
                  Map<String, Object?>.from(call.arguments as Map),
                );
                return null;
              case 'persistStaticConfiguration':
                staticValues = Map<String, Object?>.from(
                  (call.arguments as Map)['values'] as Map,
                );
                return null;
            }
            return null;
          });
      final adapter = _StartupAdapter();
      final dio = Dio()..httpClientAdapter = adapter;

      await StartupRemoteInitializer(
        dio: dio,
        baseUrl: 'https://ult-test.xmzhujing.com',
        requestContext: MethodChannelRequestContext(),
        deviceLoginSuffix: 'request-id/42',
      ).initialize();

      expect(adapter.paths, [
        '/currency/dict/list',
        '/app/device/hardware/request-id/42',
      ]);
      expect(adapter.requests.first.data, {
        'appType': 'social-work',
        'keys': StartupRemoteInitializer.staticInfoKeys,
      });
      expect(adapter.requests.first.headers['X-sign'], 'signed');
      expect(StartupRemoteInitializer.staticInfoKeys, [
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
      ]);
      expect(adapter.requests.last.data, {
        'params': 'encrypted-device',
        'timestamp': '123',
      });
      expect(persisted, {
        'accessToken': 'access-token',
        'userId': '2038529229062426626',
      });
      expect(staticValues, {
        'oss_domain': 'https://img.jx885.com/',
        'collect_book_h5_url': '  https://example.com/collect  ',
        'invite_fission_activity': '1',
      });
    },
  );

  test('refreshes only the anonymous device session', () async {
    final persisted = <String, Object?>{};
    final nativeCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add(call.method);
          switch (call.method) {
            case 'buildDeviceLoginBody':
              return {'params': 'encrypted-device', 'timestamp': '456'};
            case 'persistSession':
              persisted.addAll(
                Map<String, Object?>.from(call.arguments as Map),
              );
              return null;
          }
          fail('Unexpected native call ${call.method}');
        });
    final adapter = _StartupAdapter();

    await DeviceSessionInitializer(
      dio: Dio()..httpClientAdapter = adapter,
      baseUrl: 'https://ult-test.xmzhujing.com/',
      requestContext: MethodChannelRequestContext(),
      deviceLoginSuffix: 'refresh-id/73',
    ).initialize();

    expect(adapter.paths, ['/app/device/hardware/refresh-id/73']);
    expect(adapter.requests.single.data, {
      'params': 'encrypted-device',
      'timestamp': '456',
    });
    expect(nativeCalls, ['buildDeviceLoginBody', 'persistSession']);
    expect(persisted, {
      'accessToken': 'access-token',
      'userId': '2038529229062426626',
    });
  });
}

final class _StartupAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  List<String> get paths =>
      requests.map((request) => Uri.parse(request.path).path).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = options.path.contains('/app/device/hardware/')
        ? {
            'code': 2001,
            'body': {
              'accessToken': 'access-token',
              'user': {'id': '2038529229062426626'},
            },
          }
        : {
            'code': 200,
            'body': [
              {'key': 'oss_domain', 'value': 'https://img.jx885.com/'},
              {
                'key': 'collect_book_h5_url',
                'value': '  https://example.com/collect  ',
              },
              {'key': 'invite_fission_activity', 'value': 1},
              {'key': null, 'value': 'ignored'},
            ],
          };
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
