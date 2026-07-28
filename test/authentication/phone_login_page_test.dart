import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/authentication/phone_captcha_client.dart';
import 'package:ultcpa_flutter/src/authentication/phone_login_page.dart';
import 'package:ultcpa_flutter/src/web/agreement_webview_page.dart';

void main() {
  testWidgets('completes captcha, SMS sending, login, and legacy persistence', (
    tester,
  ) async {
    final gateway = _Gateway();
    final persisted = <String, Object?>{};
    final loggedIn = <Map<String, dynamic>>[];
    var captchaCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneLoginPage(
          gateway: gateway,
          countdownSeconds: 0,
          captchaPresenter: (context, gateway) async {
            captchaCalls += 1;
            return 'captcha-verification';
          },
          persistSession: ({required accessToken, required user}) async {
            persisted['accessToken'] = accessToken;
            persisted['user'] = user;
          },
          onLoggedIn: loggedIn.add,
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('phone-input')), '13800138000');
    await tester.tap(find.byKey(const Key('send-sms-button')));
    await tester.pump();
    await tester.pump();

    expect(captchaCalls, 1);
    expect(gateway.smsRequest, ('13800138000', 'captcha-verification'));
    expect(find.text('发送成功'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('sms-code-input')), '123456');
    await tester.tap(find.byKey(const Key('agreement-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('phone-login-button')));
    await tester.pump();
    await tester.pump();

    expect(gateway.loginRequest, ('13800138000', '123456'));
    expect(persisted['accessToken'], 'phone-token');
    expect(
      (persisted['user'] as Map<String, dynamic>)['id'],
      '2038529229062426626',
    );
    expect(loggedIn, hasLength(1));
    expect(find.text('登录成功'), findsOneWidget);
  });

  testWidgets('does not open captcha for an invalid phone number', (
    tester,
  ) async {
    var captchaCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneLoginPage(
          gateway: _Gateway(),
          captchaPresenter: (context, gateway) async {
            captchaCalls += 1;
            return 'captcha-verification';
          },
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('phone-input')), '123');
    await tester.tap(find.byKey(const Key('send-sms-button')));
    await tester.pump();

    expect(captchaCalls, 0);
    expect(find.text('请输入正确的手机号码'), findsOneWidget);
  });

  testWidgets('returns the login body when no callback is supplied', (
    tester,
  ) async {
    Map<String, dynamic>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<Map<String, dynamic>>(
                  MaterialPageRoute(
                    builder: (_) => PhoneLoginPage(
                      gateway: _Gateway(),
                      countdownSeconds: 0,
                      persistSession:
                          ({required accessToken, required user}) async {},
                    ),
                  ),
                );
              },
              child: const Text('打开登录'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开登录'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('phone-input')), '13800138000');
    await tester.enterText(find.byKey(const Key('sms-code-input')), '123456');
    await tester.tap(find.byKey(const Key('agreement-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('phone-login-button')));
    await tester.pumpAndSettle();

    expect(find.text('打开登录'), findsOneWidget);
    expect(result?['accessToken'], 'phone-token');
    expect(
      (result?['user'] as Map<String, dynamic>)['id'],
      '2038529229062426626',
    );
  });

  testWidgets('opens login agreements inside the app', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneLoginPage(
          gateway: _Gateway(),
          agreementContentBuilder: (context, uri) => Text('CONTENT:$uri'),
        ),
      ),
    );

    final agreement = find.text('《用户协议》');
    await tester.ensureVisible(agreement);
    await tester.tap(agreement);
    await tester.pumpAndSettle();

    expect(find.byType(AgreementWebViewPage), findsOneWidget);
    expect(find.text('用户协议'), findsOneWidget);
    expect(
      find.text('CONTENT:https://img.jx885.com/pass-license/html/user.html'),
      findsOneWidget,
    );
  });
}

final class _Gateway implements PhoneVerificationGateway {
  (String, String)? smsRequest;
  (String, String)? loginRequest;

  @override
  Future<Map<String, dynamic>> sendSmsCode(
    String phone,
    String captchaVerification,
  ) async {
    smsRequest = (phone, captchaVerification);
    return {'code': 200, 'body': true};
  }

  @override
  Future<Map<String, dynamic>> loginByPhone(String phone, String code) async {
    loginRequest = (phone, code);
    return {
      'code': 2001,
      'body': {
        'accessToken': 'phone-token',
        'user': {
          'id': '2038529229062426626',
          'phone': phone,
          'nickName': '考友',
          'userRole': 'student',
          'avatar': '',
          'tempStatus': 0,
        },
      },
    };
  }

  @override
  Future<CaptchaChallenge> loadChallenge() {
    throw UnimplementedError();
  }

  @override
  Future<String> verifyDrag(CaptchaChallenge challenge, double sliderX) {
    throw UnimplementedError();
  }
}
