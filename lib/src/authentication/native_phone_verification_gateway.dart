import 'package:dio/dio.dart';

import '../network/method_channel_request_context.dart';
import 'dio_captcha_transport.dart';
import 'phone_captcha_client.dart';

final class NativePhoneVerificationGateway implements PhoneVerificationGateway {
  NativePhoneVerificationGateway({
    required Dio dio,
    required MethodChannelRequestContext requestContext,
  }) : _dio = dio,
       _requestContext = requestContext;

  final Dio _dio;
  final MethodChannelRequestContext _requestContext;

  Future<PhoneCaptchaClient> _client() async {
    return PhoneCaptchaClient(
      DioCaptchaTransport(
        dio: _dio,
        baseUrl: await _requestContext.apiBaseUrl(),
        headers: _requestContext.headers,
      ),
    );
  }

  @override
  Future<CaptchaChallenge> loadChallenge() async {
    return (await _client()).loadChallenge();
  }

  @override
  Future<String> verifyDrag(CaptchaChallenge challenge, double sliderX) async {
    return (await _client()).verifyDrag(challenge, sliderX);
  }

  @override
  Future<Map<String, dynamic>> sendSmsCode(
    String phone,
    String captchaVerification,
  ) async {
    return (await _client()).sendSmsCode(phone, captchaVerification);
  }

  @override
  Future<Map<String, dynamic>> loginByPhone(String phone, String code) async {
    return (await _client()).loginByPhone(phone, code);
  }
}
