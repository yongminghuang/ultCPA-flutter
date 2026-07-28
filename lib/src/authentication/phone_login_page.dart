import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../network/method_channel_request_context.dart';
import '../startup/privacy_consent_dialog.dart';
import '../web/agreement_webview_page.dart';
import 'block_puzzle_captcha_dialog.dart';
import 'native_phone_verification_gateway.dart';
import 'phone_captcha_client.dart';

typedef CaptchaPresenter =
    Future<String?> Function(
      BuildContext context,
      PhoneVerificationGateway gateway,
    );

typedef PhoneSessionPersister =
    Future<void> Function({
      required String accessToken,
      required Map<String, dynamic> user,
    });

final class PhoneLoginPage extends StatefulWidget {
  static const routeName = '/phone-login';

  const PhoneLoginPage({
    this.gateway,
    this.captchaPresenter,
    this.persistSession,
    this.agreementContentBuilder,
    this.onOpenDocument,
    this.onLoggedIn,
    this.countdownSeconds = 60,
    super.key,
  });

  final PhoneVerificationGateway? gateway;
  final CaptchaPresenter? captchaPresenter;
  final PhoneSessionPersister? persistSession;
  final AgreementWebContentBuilder? agreementContentBuilder;
  final ValueChanged<AgreementDocument>? onOpenDocument;
  final ValueChanged<Map<String, dynamic>>? onLoggedIn;
  final int countdownSeconds;

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

final class _PhoneLoginPageState extends State<PhoneLoginPage> {
  static const _accent = Color(0xFFFF6B00);

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  late final MethodChannelRequestContext _requestContext =
      MethodChannelRequestContext();
  late final PhoneVerificationGateway _gateway =
      widget.gateway ??
      NativePhoneVerificationGateway(
        dio: Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ),
        ),
        requestContext: _requestContext,
      );

  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  bool _sendingCode = false;
  bool _loggingIn = false;
  bool _agreed = false;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (!_isValidPhone(phone)) {
      _showMessage('请输入正确的手机号码');
      return;
    }
    if (_sendingCode || _secondsRemaining > 0) return;
    final presenter = widget.captchaPresenter ?? showBlockPuzzleCaptchaDialog;
    final verification = await presenter(context, _gateway);
    if (!mounted || verification == null) return;
    setState(() => _sendingCode = true);
    try {
      await _gateway.sendSmsCode(phone, verification);
      if (!mounted) return;
      _showMessage('发送成功');
      _startCountdown();
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (!_isValidPhone(phone)) {
      _showMessage('请输入正确的手机号码');
      return;
    }
    if (code.isEmpty) {
      _showMessage('请输入验证码');
      return;
    }
    if (!_agreed) {
      _showMessage('请先阅读并同意用户协议和隐私政策');
      return;
    }
    if (_loggingIn) return;
    setState(() => _loggingIn = true);
    try {
      final response = await _gateway.loginByPhone(phone, code);
      final body = _mapOf(response['body'], '登录响应为空');
      final user = _mapOf(body['user'], '登录用户为空');
      final accessToken = body['accessToken']?.toString() ?? '';
      if (accessToken.isEmpty || user['id']?.toString().isEmpty != false) {
        throw const CaptchaProtocolException('登录响应缺少用户信息');
      }
      await (widget.persistSession ?? _requestContext.persistPhoneSession)(
        accessToken: accessToken,
        user: user,
      );
      if (!mounted) return;
      final onLoggedIn = widget.onLoggedIn;
      if (onLoggedIn != null) {
        _showMessage('登录成功');
        onLoggedIn(body);
      } else {
        Navigator.of(context).pop(body);
      }
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    if (widget.countdownSeconds <= 0) return;
    setState(() => _secondsRemaining = widget.countdownSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _secondsRemaining <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsRemaining = 0);
        return;
      }
      setState(() => _secondsRemaining -= 1);
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openDocument(AgreementDocument document) {
    final onOpenDocument = widget.onOpenDocument;
    if (onOpenDocument != null) {
      onOpenDocument(document);
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AgreementWebViewPage(
          document: document,
          contentBuilder: widget.agreementContentBuilder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('返回'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '登录/注册',
                style: TextStyle(
                  color: Color(0xFF222222),
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                '未注册手机号验证后即可完成登录',
                style: TextStyle(color: Color(0xFF828282), fontSize: 15),
              ),
              const SizedBox(height: 30),
              TextField(
                key: const Key('phone-input'),
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                decoration: const InputDecoration(
                  labelText: '手机号码',
                  hintText: '请输入手机号码',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('sms-code-input'),
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        labelText: '验证码',
                        hintText: '请输入验证码',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    key: const Key('send-sms-button'),
                    onPressed: _sendingCode || _secondsRemaining > 0
                        ? null
                        : _sendCode,
                    child: Text(
                      _sendingCode
                          ? '发送中…'
                          : _secondsRemaining > 0
                          ? '${_secondsRemaining}s'
                          : '发送验证码',
                      style: const TextStyle(color: _accent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  key: const Key('phone-login-button'),
                  onPressed: _loggingIn ? null : _login,
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(_loggingIn ? '登录中…' : '登录'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Checkbox(
                    key: const Key('agreement-checkbox'),
                    value: _agreed,
                    activeColor: _accent,
                    onChanged: (value) =>
                        setState(() => _agreed = value ?? false),
                  ),
                  const Text(
                    '阅读并同意',
                    style: TextStyle(color: Color(0xFF828282), fontSize: 13),
                  ),
                  _agreementLink(AgreementDocument.userAgreement),
                  const Text('、', style: TextStyle(color: Color(0xFF828282))),
                  _agreementLink(AgreementDocument.privacyPolicy),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _agreementLink(AgreementDocument document) {
    return GestureDetector(
      onTap: () => _openDocument(document),
      child: Text(
        '《${document.label}》',
        style: const TextStyle(color: _accent, fontSize: 13),
      ),
    );
  }

  static bool _isValidPhone(String value) {
    return value.length == 11 && int.tryParse(value) != null;
  }

  static Map<String, dynamic> _mapOf(Object? value, String message) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw CaptchaProtocolException(message);
  }

  static String _errorMessage(Object error) {
    return switch (error) {
      CaptchaProtocolException exception => exception.message,
      _ => '网络错误，请稍后重试',
    };
  }
}
