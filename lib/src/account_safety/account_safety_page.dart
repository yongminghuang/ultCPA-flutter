import 'dart:async';

import 'package:flutter/material.dart';

import 'account_safety_data_source.dart';
import 'account_safety_models.dart';

typedef AccountDeactivationLauncher =
    Future<AccountSafetyResult?> Function(BuildContext context);

final class AccountSafetyPage extends StatefulWidget {
  const AccountSafetyPage({
    required this.dataSource,
    required this.deactivationLauncher,
    super.key,
  });

  final AccountSafetyDataSource dataSource;
  final AccountDeactivationLauncher deactivationLauncher;

  @override
  State<AccountSafetyPage> createState() => _AccountSafetyPageState();
}

final class _AccountSafetyPageState extends State<AccountSafetyPage> {
  AccountSafetySnapshot? _snapshot;
  Object? _error;
  bool _loading = true;
  bool _openingDeactivation = false;
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
          key: const ValueKey('account-safety-back'),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: const Text(
          '账号与安全',
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
        key: ValueKey('account-safety-loading'),
        child: CircularProgressIndicator(),
      );
    }
    final snapshot = _snapshot;
    if (_error != null || snapshot == null) {
      return Center(
        key: const ValueKey('account-safety-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('账号信息加载失败'),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('account-safety-retry'),
              onPressed: _retry,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    return ListView(
      key: const ValueKey('account-safety-list'),
      padding: const EdgeInsets.only(top: 12),
      children: [
        _AccountSafetyRow(
          rowKey: const ValueKey('account-safety-phone'),
          label: '手机号',
          description: maskAccountPhone(snapshot.phone),
        ),
        const SizedBox(height: 4),
        _AccountSafetyRow(
          rowKey: const ValueKey('account-safety-deactivate'),
          label: '注销账号',
          description: '请注意！注销后将无法恢复',
          descriptionColor: const Color(0xFFE53935),
          onTap: _openingDeactivation ? null : _openDeactivation,
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

  Future<void> _openDeactivation() async {
    if (_openingDeactivation) return;
    if (_snapshot?.isLoggedIn != true) {
      _showMessage('请先登录');
      return;
    }
    setState(() => _openingDeactivation = true);
    try {
      final result = await widget.deactivationLauncher(context);
      if (!mounted || result != AccountSafetyResult.deactivated) return;
      Navigator.of(context).pop(result);
    } catch (_) {
      if (mounted) _showMessage('注销页面打开失败，请重试');
    } finally {
      if (mounted) setState(() => _openingDeactivation = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

String maskAccountPhone(String phone) {
  final value = phone.trim();
  if (value.isEmpty) return '点击绑定';
  if (value.length <= 7) return value;
  return '${value.substring(0, 3)}'
      '${'*' * (value.length - 7)}'
      '${value.substring(value.length - 4)}';
}

final class _AccountSafetyRow extends StatelessWidget {
  const _AccountSafetyRow({
    required this.rowKey,
    required this.label,
    required this.description,
    this.descriptionColor = const Color(0xFF999999),
    this.onTap,
  });

  final Key rowKey;
  final String label;
  final String description;
  final Color descriptionColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: rowKey,
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(color: descriptionColor, fontSize: 13),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFAAAAAA),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
