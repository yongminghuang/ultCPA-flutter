import 'package:flutter/material.dart';

import '../network/app_api_client.dart';
import 'account_safety_data_source.dart';
import 'account_safety_models.dart';

final class AccountDeactivationPage extends StatefulWidget {
  const AccountDeactivationPage({required this.dataSource, super.key});

  final AccountSafetyDataSource dataSource;

  @override
  State<AccountDeactivationPage> createState() =>
      _AccountDeactivationPageState();
}

final class _AccountDeactivationPageState
    extends State<AccountDeactivationPage> {
  bool _confirming = false;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          key: const ValueKey('account-deactivation-back'),
          tooltip: '返回',
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: const Text(
          '注销账号',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AbsorbPointer(
            absorbing: _submitting,
            child: SingleChildScrollView(
              key: const ValueKey('account-deactivation-content'),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '注销须知',
                        style: TextStyle(
                          color: Color(0xFF333333),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '在提交注销申请前，请仔细阅读以下通知\n\n'
                        '1、注销账号后，使用此手机和微信号将无法登录考有招系统。\n\n'
                        '2、注销账号后，账号内的个人账号（包括昵称、头像等无法找回）。\n\n'
                        '3、注销账号后，账户内的虚拟资产（VIP会员）和增值服务'
                        '（VIP课程都将无法继续使用，建议谨慎注销，避免损失。',
                        style: TextStyle(
                          color: Color(0xFF333333),
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: FilledButton(
                          key: const ValueKey('account-deactivation-start'),
                          onPressed: _submitting ? null : _showConfirmations,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1D8AF2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(23),
                            ),
                          ),
                          child: const Text('注销账号'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_submitting) ...[
            const ModalBarrier(dismissible: false, color: Color(0x33000000)),
            const Center(
              child: CircularProgressIndicator(
                key: ValueKey('account-deactivation-progress'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showConfirmations() async {
    if (_confirming || _submitting) return;
    _confirming = true;
    try {
      final firstConfirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('account-deactivation-first-dialog'),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 8, 0),
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  '确认要注销账号吗？',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                key: const ValueKey('account-deactivation-first-close'),
                tooltip: '关闭',
                onPressed: () => Navigator.of(dialogContext).pop(false),
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          content: const Text(
            '注销账户后,使用此手机号或微信号将无法登录考有招',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF333333)),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              key: const ValueKey('account-deactivation-first-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确定注销'),
            ),
            FilledButton(
              key: const ValueKey('account-deactivation-first-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消注销'),
            ),
          ],
        ),
      );
      if (!mounted || firstConfirmed != true) return;
      final typedConfirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const _TypedDeactivationDialog(),
      );
      if (!mounted || typedConfirmed != true) return;
      await _deactivate();
    } finally {
      _confirming = false;
    }
  }

  Future<void> _deactivate() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.dataSource.deactivateAccount();
      if (!mounted) return;
      Navigator.of(context).pop(AccountSafetyResult.deactivated);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showMessage(_errorMessage(error));
    }
  }

  String _errorMessage(Object error) {
    if (error is AppApiException && error.message.isNotEmpty) {
      return error.message;
    }
    return '账号注销失败，请重试';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _TypedDeactivationDialog extends StatefulWidget {
  const _TypedDeactivationDialog();

  @override
  State<_TypedDeactivationDialog> createState() =>
      _TypedDeactivationDialogState();
}

final class _TypedDeactivationDialogState
    extends State<_TypedDeactivationDialog> {
  final _controller = TextEditingController();
  String _input = '';

  bool get _isCorrect => _input.trim() == '确认注销';
  bool get _showError => _input.trim().isNotEmpty && !_isCorrect;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('account-deactivation-typed-dialog'),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 8, 0),
      title: Row(
        children: [
          const Expanded(
            child: Text(
              '请再次确认注销操作',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            key: const ValueKey('account-deactivation-typed-close'),
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '请在下方输入“确认注销”',
              style: TextStyle(color: Color(0xFF666666), fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('account-deactivation-input'),
              controller: _controller,
              maxLength: 10,
              maxLines: 1,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '请输入“确认注销”',
                counterText: '',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _input = value),
            ),
            if (_showError) ...[
              const SizedBox(height: 4),
              const Text(
                '输入错误',
                style: TextStyle(color: Color(0xFFFF4444), fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          key: const ValueKey('account-deactivation-typed-confirm'),
          onPressed: _isCorrect ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF666666),
          ),
          child: const Text('确定注销'),
        ),
        FilledButton(
          key: const ValueKey('account-deactivation-typed-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1D8AF2),
          ),
          child: const Text('取消注销'),
        ),
      ],
    );
  }
}
