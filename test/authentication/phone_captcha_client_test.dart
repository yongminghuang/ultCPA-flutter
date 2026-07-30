import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/authentication/phone_captcha_client.dart';

void main() {
  test('loads the Android blockPuzzle challenge', () async {
    final transport = _RecordingTransport([
      {
        'code': 200,
        'msg': '操作成功',
        'body': {
          'repCode': '0000',
          'repData': {
            'secretKey': '0123456789abcdef',
            'originalImageBase64': 'base-image',
            'jigsawImageBase64': 'jigsaw-image',
            'token': 'token-123',
          },
        },
      },
    ]);

    final challenge = await PhoneCaptchaClient(transport).loadChallenge();

    expect(transport.requests.single.path, '/app/captcha/aj/get');
    expect(transport.requests.single.body, {'captchaType': 'blockPuzzle'});
    expect(challenge.token, 'token-123');
    expect(challenge.originalImageBase64, 'base-image');
    expect(challenge.jigsawImageBase64, 'jigsaw-image');
  });

  test(
    'checks the drag point and creates the encrypted verification',
    () async {
      final transport = _RecordingTransport([
        {
          'code': 200,
          'msg': '操作成功',
          'body': {
            'repCode': '0000',
            'repData': {'result': true},
          },
        },
      ]);
      final challenge = CaptchaChallenge(
        secretKey: '0123456789abcdef',
        originalImageBase64: 'base-image',
        jigsawImageBase64: 'jigsaw-image',
        token: 'token-123',
      );

      final verification = await PhoneCaptchaClient(
        transport,
      ).verifyDrag(challenge, 42.5);

      expect(transport.requests.single.path, '/app/captcha/aj/check');
      expect(transport.requests.single.body, {
        'captchaType': 'blockPuzzle',
        'token': 'token-123',
        'pointJson': 'FxsF4Vt3mSBPaKJ2pMP2Lg4Jh037bnc5eTHZdaMjumQ=',
      });
      expect(verification, 'wqUEv21kInO06NJdNEUeIlDDvZRcWfVjYmp74EF58uE=');
    },
  );

  test(
    'accepts the boolean check response used by the Android endpoint',
    () async {
      final client = PhoneCaptchaClient(
        _RecordingTransport([
          {'repCode': '0000', 'repData': true},
        ]),
      );

      final result = await client.verifyDrag(
        const CaptchaChallenge(
          secretKey: '',
          originalImageBase64: 'base-image',
          jigsawImageBase64: 'jigsaw-image',
          token: 'token-123',
        ),
        42.5,
      );

      expect(result, 'token-123---{"x":42.5,"y":5.0}');
    },
  );

  test('rejects a check response whose result is false', () async {
    final client = PhoneCaptchaClient(
      _RecordingTransport([
        {
          'repCode': '0000',
          'repData': {'result': false},
        },
      ]),
    );

    await expectLater(
      client.verifyDrag(
        const CaptchaChallenge(
          secretKey: '',
          originalImageBase64: 'base-image',
          jigsawImageBase64: 'jigsaw-image',
          token: 'token-123',
        ),
        42.5,
      ),
      throwsA(
        isA<CaptchaProtocolException>().having(
          (error) => error.message,
          'message',
          '拼图位置不正确，请重试',
        ),
      ),
    );
  });

  test('rejects an incomplete challenge response', () async {
    final client = PhoneCaptchaClient(
      _RecordingTransport([
        {
          'repCode': '0000',
          'repData': {
            'secretKey': '0123456789abcdef',
            'originalImageBase64': '',
            'jigsawImageBase64': 'jigsaw-image',
            'token': 'token-123',
          },
        },
      ]),
    );

    await expectLater(
      client.loadChallenge(),
      throwsA(
        isA<CaptchaProtocolException>().having(
          (error) => error.message,
          'message',
          '验证码数据不完整',
        ),
      ),
    );
  });

  test('uses the real SMS and phone login request shapes', () async {
    final transport = _RecordingTransport([
      {'code': 200, 'body': true},
      {
        'code': 2001,
        'body': {'accessToken': 'access-token'},
      },
    ]);
    final client = PhoneCaptchaClient(transport);

    await client.sendSmsCode('13800138000', 'captcha-verification');
    await client.loginByPhone('13800138000', '123456');

    expect(transport.requests[0].path, '/app/captcha/sendVerifyCode');
    expect(transport.requests[0].body, {
      'phone': '13800138000',
      'captchaData': {'captchaVerification': 'captcha-verification'},
    });
    expect(transport.requests[1].path, '/app/user/v1/loginByPhone');
    expect(transport.requests[1].body, {
      'phone': '13800138000',
      'verifyCode': '123456',
    });
  });

  test('rejects a failed SMS response using the server message', () async {
    final client = PhoneCaptchaClient(
      _RecordingTransport([
        {'code': 400, 'msg': '手机号格式错误'},
      ]),
    );

    await expectLater(
      client.sendSmsCode('123', 'captcha-verification'),
      throwsA(
        isA<CaptchaProtocolException>().having(
          (error) => error.message,
          'message',
          '手机号格式错误',
        ),
      ),
    );
  });

  test(
    'surfaces the app envelope message from a rejected captcha request',
    () async {
      final client = PhoneCaptchaClient(
        _RecordingTransport([
          {'code': 401, 'msg': '登录已失效，请重新登录'},
        ]),
      );

      await expectLater(
        client.loadChallenge(),
        throwsA(
          isA<CaptchaProtocolException>().having(
            (error) => error.message,
            'message',
            '登录已失效，请重新登录',
          ),
        ),
      );
    },
  );
}

final class _RecordingTransport implements CaptchaTransport {
  _RecordingTransport(this.responses);

  final List<Map<String, dynamic>> responses;
  final List<({String path, Map<String, dynamic> body})> requests = [];

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    requests.add((path: path, body: body));
    return responses.removeAt(0);
  }
}
