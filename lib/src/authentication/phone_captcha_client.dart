import 'dart:convert';

import 'package:encrypt/encrypt.dart';

abstract interface class CaptchaTransport {
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body);
}

final class CaptchaChallenge {
  const CaptchaChallenge({
    required this.secretKey,
    required this.originalImageBase64,
    required this.jigsawImageBase64,
    required this.token,
  });

  factory CaptchaChallenge.fromJson(Map<String, dynamic> json) {
    return CaptchaChallenge(
      secretKey: json['secretKey'] as String? ?? '',
      originalImageBase64: json['originalImageBase64'] as String? ?? '',
      jigsawImageBase64: json['jigsawImageBase64'] as String? ?? '',
      token: json['token'] as String? ?? '',
    );
  }

  final String secretKey;
  final String originalImageBase64;
  final String jigsawImageBase64;
  final String token;
}

final class CaptchaProtocolException implements Exception {
  const CaptchaProtocolException(this.message);

  final String message;

  @override
  String toString() => 'CaptchaProtocolException: $message';
}

abstract interface class PhoneVerificationGateway {
  Future<CaptchaChallenge> loadChallenge();

  Future<String> verifyDrag(CaptchaChallenge challenge, double sliderX);

  Future<Map<String, dynamic>> sendSmsCode(
    String phone,
    String captchaVerification,
  );

  Future<Map<String, dynamic>> loginByPhone(String phone, String code);
}

final class PhoneCaptchaClient implements PhoneVerificationGateway {
  const PhoneCaptchaClient(this._transport);

  final CaptchaTransport _transport;

  @override
  Future<CaptchaChallenge> loadChallenge() async {
    final response = await _transport.post('/app/captcha/aj/get', {
      'captchaType': 'blockPuzzle',
    });
    _requireCaptchaSuccess(response);
    final data = response['repData'];
    if (data is! Map) {
      throw const CaptchaProtocolException('验证码数据为空');
    }
    return CaptchaChallenge.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<String> verifyDrag(CaptchaChallenge challenge, double sliderX) async {
    final pointJson = jsonEncode({'x': sliderX, 'y': 5.0});
    final response = await _transport.post('/app/captcha/aj/check', {
      'captchaType': 'blockPuzzle',
      'token': challenge.token,
      'pointJson': _aesEncode(pointJson, challenge.secretKey),
    });
    _requireCaptchaSuccess(response);
    return _aesEncode('${challenge.token}---$pointJson', challenge.secretKey);
  }

  @override
  Future<Map<String, dynamic>> sendSmsCode(
    String phone,
    String captchaVerification,
  ) async {
    final response = await _transport.post('/app/captcha/sendVerifyCode', {
      'phone': phone,
      'captchaData': {'captchaVerification': captchaVerification},
    });
    _requireAppSuccess(response);
    return response;
  }

  @override
  Future<Map<String, dynamic>> loginByPhone(String phone, String code) async {
    final response = await _transport.post('/app/user/v1/loginByPhone', {
      'phone': phone,
      'verifyCode': code,
    });
    _requireAppSuccess(response);
    return response;
  }

  static String _aesEncode(String content, String key) {
    if (content.isEmpty || key.isEmpty) {
      return content;
    }
    final encrypter = Encrypter(
      AES(Key.fromUtf8(key), mode: AESMode.ecb, padding: 'PKCS7'),
    );
    return encrypter.encrypt(content, iv: IV.fromLength(16)).base64;
  }

  static void _requireCaptchaSuccess(Map<String, dynamic> response) {
    if (response['repCode'] != '0000') {
      throw CaptchaProtocolException(
        response['repMsg'] as String? ?? '验证失败，请重试',
      );
    }
  }

  static void _requireAppSuccess(Map<String, dynamic> response) {
    final rawCode = response['code'];
    final code = rawCode is int ? rawCode : int.tryParse(rawCode.toString());
    if (code != 200 && code != 2001) {
      throw CaptchaProtocolException(
        (response['msg'] ?? response['message'] ?? '请求失败').toString(),
      );
    }
  }
}
