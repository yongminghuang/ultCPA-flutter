import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/authentication/block_puzzle_captcha_dialog.dart';
import 'package:ultcpa_flutter/src/authentication/phone_captcha_client.dart';

void main() {
  testWidgets('maps the displayed drag back to the AJ-Captcha image pixels', (
    tester,
  ) async {
    final gateway = _Gateway(cover: _coverPng, block: _blockPng);
    final verified = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: BlockPuzzleCaptchaDialog(
          gateway: gateway,
          onVerified: verified.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('captcha-slider')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();

    expect(gateway.sliderX, closeTo(250, 0.01));
    expect(verified, ['captcha-verification']);
  });

  testWidgets('refresh obtains a fresh blockPuzzle challenge', (tester) async {
    final gateway = _Gateway(cover: _smallPng, block: _smallPng);
    await tester.pumpWidget(
      MaterialApp(
        home: BlockPuzzleCaptchaDialog(gateway: gateway, onVerified: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('captcha-refresh')));
    await tester.pumpAndSettle();

    expect(gateway.loadCalls, 2);
  });

  testWidgets('returns the verification after showing success feedback', (
    tester,
  ) async {
    final gateway = _Gateway(cover: _coverPng, block: _blockPng);
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showBlockPuzzleCaptchaDialog(context, gateway);
            },
            child: const Text('打开验证码'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开验证码'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('captcha-slider')),
      const Offset(500, 0),
    );
    await tester.pump();

    expect(find.text('验证成功'), findsOneWidget);
    expect(result, isNull);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(result, 'captcha-verification');
    expect(find.text('打开验证码'), findsOneWidget);
  });

  testWidgets('failed verification shows feedback and refreshes the puzzle', (
    tester,
  ) async {
    final gateway = _Gateway(
      cover: _coverPng,
      block: _blockPng,
      verificationFailures: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlockPuzzleCaptchaDialog(gateway: gateway, onVerified: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('captcha-slider')),
      const Offset(180, 0),
    );
    await tester.pump();

    expect(find.text('验证失败'), findsOneWidget);
    expect(find.textContaining('正在刷新'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(gateway.loadCalls, 2);
    expect(find.text('拖动滑块完成拼图'), findsOneWidget);
  });
}

const _coverPng =
    'iVBORw0KGgoAAAANSUhEUgAAATYAAACbCAYAAADoSbctAAACF0lEQVR4nO3UsQkAMAzAsPzb/+f0iULBaNDuybNnFqBkfgcAvGZsQI6xATnGBuQYG5BjbECOsQE5xgbkGBuQY2xAjrEBOcYG5BgbkGNsQI6xATnGBuQYG5BjbECOsQE5xgbkGBuQY2xAjrEBOcYG5BgbkGNsQI6xATnGBuQYG5BjbECOsQE5xgbkGBuQY2xAjrEBOcYG5BgbkGNsQI6xATnGBuQYG5BjbECOsQE5xgbkGBuQY2xAjrEBOcYG5BgbkGNsQI6xATnGBuQYG5BjbECOsQE5xgbkGBuQY2xAjrEBOcYG5BgbkGNsQI6xATnGBuQYG5BjbECOsQE5xgbkGBuQY2xAjrEBOcYG5BgbkGNsQI6xATnGBuQYG5BjbECOsQE5xgbkGBuQY2xAjrEBOcYG5BgbkGNsQI6xATnGBuQYG5BjbECOsQE5xgbkGBuQY2xAjrEBOcYG5BgbkGNsQI6xATnGBuQYG5BjbECOsQE5xgbkGBuQY2xAjrEBOcYG5BgbkGNsQI6xATnGBuQYG5BjbECOsQE5xgbkGBuQY2xAjrEBOcYG5BgbkGNsQI6xATnGBuQYG5BjbECOsQE5xgbkGBuQY2xAjrEBOcYG5BgbkGNsQI6xATnGBuQYG5BjbECOsQE5xgbkGBuQY2xAzgU0+3p/j25qeQAAAABJRU5ErkJggg==';
const _blockPng =
    'iVBORw0KGgoAAAANSUhEUgAAADwAAACbCAYAAAA+5fgkAAAAxUlEQVR4nO3PsQ0AIAzAsP7L/zOcgZR6yB7PPXM3Nb8HgIGBgYGBgfcEXA+4HnA94HrA9YDrAdcDrgdcD7gecD3gesD1gOsB1wOuB1wPuB5wPeB6wPWA6wHXA64HXA+4HnA94HrA9YDrAdcDrgdcD7gecD3gesD1gOsB1wOuB1wPuB5wPeB6wPWA6wHXA64HXA+4HnA94HrA9YDrAdcDrgdcD7gecD3gesD1gOsB1wOuB1wPuB5wPeB6wPWA6wHXA663DvwASJGTjjeGFqkAAAAASUVORK5CYII=';
const _smallPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFElEQVR4nGP4n83wnxjMMKqQvgoBIgPxBbXDc/EAAAAASUVORK5CYII=';

final class _Gateway implements PhoneVerificationGateway {
  _Gateway({
    required this.cover,
    required this.block,
    this.verificationFailures = 0,
  });

  final String cover;
  final String block;
  final int verificationFailures;
  int loadCalls = 0;
  int verifyCalls = 0;
  double? sliderX;

  @override
  Future<CaptchaChallenge> loadChallenge() async {
    loadCalls += 1;
    return CaptchaChallenge(
      secretKey: '0123456789abcdef',
      originalImageBase64: cover,
      jigsawImageBase64: block,
      token: 'token-$loadCalls',
    );
  }

  @override
  Future<String> verifyDrag(CaptchaChallenge challenge, double sliderX) async {
    verifyCalls += 1;
    this.sliderX = sliderX;
    if (verifyCalls <= verificationFailures) {
      throw const CaptchaProtocolException('拼图位置不正确');
    }
    return 'captcha-verification';
  }

  @override
  Future<Map<String, dynamic>> loginByPhone(String phone, String code) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> sendSmsCode(
    String phone,
    String captchaVerification,
  ) {
    throw UnimplementedError();
  }
}
