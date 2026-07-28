import 'dart:async';

import 'package:flutter/material.dart';

import '../account_safety/account_safety_models.dart';
import 'about_page.dart';
import 'privacy_settings_page.dart';
import 'settings_data_source.dart';
import 'settings_models.dart';
import 'settings_navigation.dart';

final class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.isLoggedIn,
    required this.dataSource,
    required this.agreementLauncher,
    this.accountSafetyLauncher,
    super.key,
  });

  final bool isLoggedIn;
  final SettingsDataSource dataSource;
  final SettingsAgreementLauncher agreementLauncher;
  final SettingsAccountSafetyLauncher? accountSafetyLauncher;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

final class _SettingsPageState extends State<SettingsPage> {
  SettingsSnapshot? _snapshot;
  Object? _error;
  bool _loading = true;
  bool _savingNotification = false;
  bool _clearingCache = false;
  bool _openingAccount = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    super.dispose();
  }

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
          key: const ValueKey('settings-back'),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: const Text(
          '我的设置',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        key: ValueKey('settings-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null || _snapshot == null) {
      return Center(
        key: const ValueKey('settings-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('设置加载失败'),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('settings-retry'),
              onPressed: _retry,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    return ListView(
      key: const ValueKey('settings-list'),
      padding: const EdgeInsets.only(top: 12),
      children: [
        ColoredBox(
          color: Colors.white,
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '通知开关',
                      style: TextStyle(color: Color(0xFF333333), fontSize: 14),
                    ),
                  ),
                  Switch(
                    key: const ValueKey('settings-notification-switch'),
                    value: _snapshot!.notificationEnabled,
                    onChanged: _savingNotification ? null : _setNotification,
                  ),
                ],
              ),
            ),
          ),
        ),
        _SettingsRow(
          rowKey: const ValueKey('settings-clear-cache'),
          actionKey: const ValueKey('settings-clear-cache-action'),
          label: '清理缓存',
          onTap: _clearingCache ? null : _clearCaches,
        ),
        _SettingsRow(
          rowKey: const ValueKey('settings-about'),
          label: '关于我们',
          onTap: _openAbout,
        ),
        _SettingsRow(
          rowKey: const ValueKey('settings-privacy'),
          label: '隐私设置',
          onTap: _openPrivacy,
        ),
        _SettingsRow(
          rowKey: const ValueKey('settings-account-safety'),
          label: '账号与安全',
          showDivider: false,
          onTap: _openingAccount ? null : _openAccountSafety,
        ),
      ],
    );
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final snapshot = await widget.dataSource.load();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _snapshot = null;
        _error = error;
        _loading = false;
      });
    }
  }

  void _retry() {
    if (_loading) return;
    setState(() {
      _snapshot = null;
      _error = null;
      _loading = true;
    });
    unawaited(_load());
  }

  Future<void> _setNotification(bool enabled) async {
    if (_savingNotification || _snapshot == null) return;
    final previous = _snapshot!;
    setState(() {
      _savingNotification = true;
      _snapshot = SettingsSnapshot(
        notificationEnabled: enabled,
        personalizedRecommendations: previous.personalizedRecommendations,
      );
    });
    try {
      await widget.dataSource.setNotificationEnabled(enabled);
    } catch (_) {
      if (mounted) {
        setState(() => _snapshot = previous);
        _showMessage('设置保存失败，请重试');
      }
    } finally {
      if (mounted) setState(() => _savingNotification = false);
    }
  }

  Future<void> _clearCaches() async {
    if (_clearingCache) return;
    setState(() => _clearingCache = true);
    try {
      await widget.dataSource.clearCaches();
      if (mounted) _showMessage('清理成功');
    } catch (_) {
      if (mounted) _showMessage('清理失败，请重试');
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  Future<void> _openAbout() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AboutPage(
          dataSource: widget.dataSource,
          agreementLauncher: widget.agreementLauncher,
        ),
      ),
    );
  }

  Future<void> _openPrivacy() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PrivacySettingsPage(
          dataSource: widget.dataSource,
          agreementLauncher: widget.agreementLauncher,
        ),
      ),
    );
  }

  Future<void> _openAccountSafety() async {
    if (_openingAccount) return;
    if (!widget.isLoggedIn) {
      _showMessage('请先登录');
      return;
    }
    final launcher = widget.accountSafetyLauncher;
    if (launcher == null) {
      _showMessage('账号与安全功能仍在迁移中');
      return;
    }
    setState(() => _openingAccount = true);
    AccountSafetyResult? result;
    try {
      result = await launcher(context);
    } catch (_) {
      if (mounted) _showMessage('账号与安全入口打开失败，请重试');
    } finally {
      if (mounted) setState(() => _openingAccount = false);
    }
    if (!mounted || result != AccountSafetyResult.deactivated) return;
    Navigator.of(context).pop(result);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.rowKey,
    required this.label,
    required this.onTap,
    this.actionKey,
    this.showDivider = true,
  });

  final Key rowKey;
  final Key? actionKey;
  final String label;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: rowKey,
      color: Colors.white,
      child: InkWell(
        key: actionKey,
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 52,
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      border: showDivider
                          ? const Border(
                              bottom: BorderSide(
                                color: Color(0xFFF3F3F3),
                                width: 0.5,
                              ),
                            )
                          : null,
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 14,
                      ),
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
