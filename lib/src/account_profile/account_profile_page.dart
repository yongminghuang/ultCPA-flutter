import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'account_profile_data_source.dart';
import 'account_profile_models.dart';

final class AccountProfilePage extends StatefulWidget {
  const AccountProfilePage({required this.dataSource, super.key});

  final AccountProfileDataSource dataSource;

  @override
  State<AccountProfilePage> createState() => _AccountProfilePageState();
}

final class _AccountProfilePageState extends State<AccountProfilePage> {
  AccountProfileSnapshot? _snapshot;
  Object? _error;
  bool _loading = true;
  bool _confirming = false;
  bool _submitting = false;
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
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F3F3),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          surfaceTintColor: Colors.white,
          leading: IconButton(
            key: const ValueKey('account-profile-back'),
            tooltip: '返回',
            onPressed: _submitting
                ? null
                : () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          title: const Text(
            '我的资料',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            AbsorbPointer(absorbing: _submitting, child: _buildBody()),
            if (_submitting) ...[
              const ModalBarrier(dismissible: false, color: Color(0x33000000)),
              const Center(
                child: CircularProgressIndicator(
                  key: ValueKey('account-profile-progress'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        key: ValueKey('account-profile-loading'),
        child: CircularProgressIndicator(),
      );
    }
    final snapshot = _snapshot;
    if (_error != null || snapshot == null) {
      return Center(
        key: const ValueKey('account-profile-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('账号资料加载失败'),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('account-profile-retry'),
              onPressed: _retry,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    return ListView(
      key: const ValueKey('account-profile-list'),
      padding: const EdgeInsets.only(top: 16),
      children: [
        _ProfileRow(
          rowKey: const ValueKey('account-profile-avatar'),
          label: '头像',
          height: 70,
          trailing: _ProfileAvatar(url: snapshot.avatar),
        ),
        const _ProfileDivider(),
        _ProfileRow(
          rowKey: const ValueKey('account-profile-nickname'),
          label: '用户名',
          description: snapshot.nickname,
        ),
        const _ProfileDivider(),
        _ProfileRow(
          rowKey: const ValueKey('account-profile-user-id'),
          label: '账号ID',
          description: snapshot.userId,
          onTap: snapshot.userId.trim().isEmpty ? null : _copyUserId,
        ),
        const SizedBox(height: 16),
        Material(
          key: const ValueKey('account-profile-sign-out'),
          color: Colors.white,
          child: InkWell(
            onTap: _submitting ? null : _confirmSignOut,
            child: const SizedBox(
              height: 48,
              child: Center(
                child: Text(
                  '退出登录',
                  style: TextStyle(color: Color(0xFFE53935), fontSize: 14),
                ),
              ),
            ),
          ),
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

  Future<void> _copyUserId() async {
    final userId = _snapshot?.userId.trim() ?? '';
    if (userId.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: userId));
    if (mounted) _showMessage('已复制userId');
  }

  Future<void> _confirmSignOut() async {
    if (_confirming || _submitting) return;
    if (_snapshot?.isLoggedIn != true) {
      _showMessage('当前未登录');
      return;
    }
    _confirming = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('account-profile-dialog'),
          title: const Text(
            '提示',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          content: const Text(
            '退出登录您可能会丢失做题记录，是否确定退出？',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              key: const ValueKey('account-profile-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              key: const ValueKey('account-profile-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE53935),
              ),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      await _signOut();
    } finally {
      _confirming = false;
    }
  }

  Future<void> _signOut() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.dataSource.signOut();
      if (!mounted) return;
      Navigator.of(context).pop(AccountProfileResult.signedOut);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showMessage('退出登录失败，请重试');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.rowKey,
    required this.label,
    this.description,
    this.trailing,
    this.onTap,
    this.height = 56,
  });

  final Key rowKey;
  final String label;
  final String? description;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: rowKey,
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: trailing != null
                      ? Align(alignment: Alignment.centerRight, child: trailing)
                      : Text(
                          description ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 14,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _ProfileDivider extends StatelessWidget {
  const _ProfileDivider();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.only(left: 16),
        child: Divider(height: 1, thickness: 0.5),
      ),
    );
  }
}

final class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final fallback = const ColoredBox(
      color: Color(0xFFEFF4FA),
      child: Center(
        child: Icon(Icons.person, color: Color(0xFF94A3B8), size: 32),
      ),
    );
    return ClipOval(
      child: SizedBox(
        width: 54,
        height: 54,
        child: url.trim().isEmpty
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
