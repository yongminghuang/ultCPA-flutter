import 'package:flutter/material.dart';

enum AgreementDocument {
  privacyPolicy('隐私政策', 'https://img.jx885.com/pass-license/html/privacy.html'),
  userAgreement('用户协议', 'https://img.jx885.com/pass-license/html/user.html');

  const AgreementDocument(this.label, this.url);

  final String label;
  final String url;

  Uri get uri => Uri.parse(url);
}

final class PrivacyConsentDialog extends StatefulWidget {
  const PrivacyConsentDialog({
    required this.onAccept,
    required this.onExit,
    required this.onOpenDocument,
    super.key,
  });

  final VoidCallback onAccept;
  final VoidCallback onExit;
  final ValueChanged<AgreementDocument> onOpenDocument;

  @override
  State<PrivacyConsentDialog> createState() => _PrivacyConsentDialogState();
}

final class _PrivacyConsentDialogState extends State<PrivacyConsentDialog> {
  bool _showExitWarning = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.8,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
            child: _showExitWarning ? _buildExitWarning() : _buildGuide(),
          ),
        ),
      ),
    );
  }

  Widget _buildGuide() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '个人信息保护指引',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('感谢您信任并使用考有招！我们将通过'),
                    _documentLink(
                      AgreementDocument.privacyPolicy,
                      const Key('privacy-policy-link'),
                    ),
                    const Text('和'),
                    _documentLink(
                      AgreementDocument.userAgreement,
                      const Key('user-agreement-link'),
                    ),
                    const Text(
                      '，帮助您了解我们为您提供的服务，以及我们对您的个人信息的处理方式。\n'
                      '如果您同意隐私协议，请点击“同意”。',
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                const Text(
                  '点击同意，代表您已同意前述协议及以下约定：\n\n'
                  '1、在仅浏览时，我们可能会申请系统设备权限收集国际移动设备识别码，以及手机其他设备信息如网络设备硬件地址、日志信息，用于识别设备，进行题库缓存和安全风控。\n\n'
                  '2、为实现第三方登录、信息分享等功能所必需，我们可能会使用与功能相关的最小必要信息。',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        _primaryButton('同意', widget.onAccept),
        TextButton(
          onPressed: () => setState(() => _showExitWarning = true),
          child: const Text('不同意', style: TextStyle(color: Color(0xFF828282))),
        ),
      ],
    );
  }

  Widget _buildExitWarning() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '温馨提示',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        const Text('需同意《个人信息保护指引》后我们才能继续为你提供服务', textAlign: TextAlign.center),
        const SizedBox(height: 20),
        _primaryButton('同意并继续', widget.onAccept),
        TextButton(
          onPressed: widget.onExit,
          child: const Text('放弃使用', style: TextStyle(color: Color(0xFF828282))),
        ),
      ],
    );
  }

  Widget _documentLink(AgreementDocument document, Key key) {
    return GestureDetector(
      key: key,
      onTap: () => widget.onOpenDocument(document),
      child: Text(
        '《${document.label}》',
        style: const TextStyle(color: Color(0xFFFF6B00)),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B00),
          shape: const RoundedRectangleBorder(),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
