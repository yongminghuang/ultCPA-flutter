import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../startup/privacy_consent_dialog.dart';
import 'settings_data_source.dart';
import 'settings_navigation.dart';

final class AboutPage extends StatefulWidget {
  const AboutPage({
    required this.dataSource,
    required this.agreementLauncher,
    super.key,
  });

  final SettingsDataSource dataSource;
  final SettingsAgreementLauncher agreementLauncher;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

final class _AboutPageState extends State<AboutPage> {
  bool _openingStore = false;
  bool _openingExternal = false;

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
          key: const ValueKey('about-back'),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: const Text(
          '关于',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        key: const ValueKey('about-scroll'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/settings/app_icon.png',
                  key: const ValueKey('about-app-icon'),
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '考有招',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF333333),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              'v${AppIdentity.versionName}\n(build:${AppIdentity.versionCode})',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF888888), fontSize: 14),
            ),
            const SizedBox(height: 40),
            _AboutRow(
              rowKey: const ValueKey('about-user-agreement'),
              label: '用户协议',
              onTap: () => _openAgreement(AgreementDocument.userAgreement),
            ),
            _AboutRow(
              rowKey: const ValueKey('about-privacy-policy'),
              label: '隐私政策',
              onTap: () => _openAgreement(AgreementDocument.privacyPolicy),
            ),
            _AboutRow(
              rowKey: const ValueKey('about-rate-app'),
              label: '给我好评',
              onTap: _openingStore ? null : _openStore,
            ),
            _AboutRow(
              rowKey: const ValueKey('about-report-error'),
              label: '上报软件错误',
              onTap: () => _showMessage('错误信息已上报成功，感谢反馈。'),
            ),
            const SizedBox(height: 28),
            const Text(
              '考有招',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF237DED), fontSize: 12),
            ),
            TextButton(
              key: const ValueKey('about-icp'),
              onPressed: _openingExternal ? null : _confirmIcp,
              child: const Text(
                '闽ICP备2026009152号 >',
                style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
              ),
            ),
            const Text(
              '厦门铸径信息科技有限公司',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
            ),
            const SizedBox(height: 6),
            const Text(
              'Copyright© 2026 All Rights Reserved',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _openAgreement(AgreementDocument document) async {
    try {
      await widget.agreementLauncher(context, document);
    } catch (_) {
      if (mounted) _showMessage('页面打开失败，请重试');
    }
  }

  Future<void> _openStore() async {
    if (_openingStore) return;
    setState(() => _openingStore = true);
    try {
      await widget.dataSource.openStoreRating();
    } catch (_) {
      if (mounted) _showMessage('应用商店打开失败，请重试');
    } finally {
      if (mounted) setState(() => _openingStore = false);
    }
  }

  Future<void> _confirmIcp() async {
    if (_openingExternal) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('提示'),
        content: const Text('是否跳转到手机浏览器打开 ICP 备案号查询官网'),
        actions: [
          TextButton(
            key: const ValueKey('about-icp-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const ValueKey('about-icp-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _openingExternal = true);
    try {
      await widget.dataSource.openExternalUrl(
        Uri.parse('https://beian.miit.gov.cn'),
      );
    } catch (_) {
      if (mounted) _showMessage('备案网站打开失败，请重试');
    } finally {
      if (mounted) setState(() => _openingExternal = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.rowKey, required this.label, this.onTap});

  final Key rowKey;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        key: rowKey,
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 14,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFAAAAAA),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
