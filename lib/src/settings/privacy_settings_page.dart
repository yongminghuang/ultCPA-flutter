import 'dart:async';

import 'package:flutter/material.dart';

import '../startup/privacy_consent_dialog.dart';
import 'settings_data_source.dart';
import 'settings_models.dart';
import 'settings_navigation.dart';

final class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({
    required this.dataSource,
    required this.agreementLauncher,
    super.key,
  });

  final SettingsDataSource dataSource;
  final SettingsAgreementLauncher agreementLauncher;

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

final class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  SettingsSnapshot? _snapshot;
  Object? _error;
  bool _loading = true;
  bool _saving = false;
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
          key: const ValueKey('privacy-back'),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: const Text(
          '隐私设置',
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
        key: ValueKey('privacy-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null || _snapshot == null) {
      return Center(
        key: const ValueKey('privacy-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('隐私设置加载失败'),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('privacy-retry'),
              onPressed: _retry,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    return ListView(
      key: const ValueKey('privacy-content'),
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
                      '个性化推荐',
                      style: TextStyle(color: Color(0xFF333333), fontSize: 14),
                    ),
                  ),
                  Switch(
                    key: const ValueKey('privacy-personalized-switch'),
                    value: _snapshot!.personalizedRecommendations,
                    onChanged: _saving ? null : _setPersonalized,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Material(
          color: Colors.white,
          child: InkWell(
            key: const ValueKey('privacy-policy'),
            onTap: () => widget.agreementLauncher(
              context,
              AgreementDocument.privacyPolicy,
            ),
            child: const SizedBox(
              height: 52,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '隐私政策',
                        style: TextStyle(
                          color: Color(0xFF333333),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Color(0xFFAAAAAA)),
                  ],
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

  Future<void> _setPersonalized(bool enabled) async {
    if (_saving || _snapshot == null) return;
    final previous = _snapshot!;
    setState(() {
      _saving = true;
      _snapshot = SettingsSnapshot(
        notificationEnabled: previous.notificationEnabled,
        personalizedRecommendations: enabled,
      );
    });
    try {
      await widget.dataSource.setPersonalizedRecommendations(enabled);
    } catch (_) {
      if (mounted) {
        setState(() => _snapshot = previous);
        _showMessage('设置保存失败，请重试');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
