import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'promotion_share_gateway.dart';
import 'promotion_sharing_models.dart';
import 'promotion_sharing_repository.dart';

final class PromotionSharingPage extends StatefulWidget {
  const PromotionSharingPage({
    required this.inviteContent,
    required this.dataSource,
    required this.shareGateway,
    super.key,
  });

  final String inviteContent;
  final PromotionSharingDataSource dataSource;
  final PromotionShareGateway shareGateway;

  @override
  State<PromotionSharingPage> createState() => _PromotionSharingPageState();
}

final class _PromotionSharingPageState extends State<PromotionSharingPage> {
  final _posterKey = GlobalKey();
  PromotionSharingSession? _session;
  PromotionProfile _profile = const PromotionProfile(name: '', phone: '');
  Uint8List? _qrBytes;
  Object? _error;
  int _selectedPoster = 0;
  bool _loading = true;
  bool _actionInFlight = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await widget.dataSource.load(widget.inviteContent);
      var profile = session.profile;
      try {
        profile = await widget.shareGateway.readProfile(profile);
      } catch (_) {
        // Account snapshot remains the profile fallback.
      }
      final qr = await widget.shareGateway.createQrCode(session.inviteUrl);
      if (!mounted) return;
      setState(() {
        _session = session;
        _profile = profile;
        _qrBytes = qr;
        _selectedPoster = 0;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _editProfile() async {
    final profile = await showDialog<PromotionProfile>(
      context: context,
      builder: (_) => _PromotionProfileDialog(initialProfile: _profile),
    );
    if (!mounted || profile == null) return;
    setState(() => _profile = profile);
    try {
      await widget.shareGateway.saveProfile(profile);
    } catch (error) {
      if (mounted) _showMessage(_messageFor(error));
    }
  }

  Future<void> _choosePoster() async {
    final posters = _session?.posters ?? const <PromotionPoster>[];
    if (posters.length < 2) {
      _showMessage(posters.isEmpty ? '暂无可用海报' : '当前只有一张海报');
      return;
    }
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: GridView.builder(
          key: const ValueKey('promotion-poster-selector'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.62,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: posters.length,
          itemBuilder: (_, index) => InkWell(
            key: ValueKey('promotion-poster-$index'),
            onTap: () => Navigator.of(sheetContext).pop(index),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: index == _selectedPoster
                      ? const Color(0xFFFF8A00)
                      : const Color(0xFFE5E7EB),
                  width: index == _selectedPoster ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  posters[index].previewUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xFFF3F4F6),
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted && selected != null) {
      setState(() => _selectedPoster = selected);
    }
  }

  Future<Uint8List> _capturePoster() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _posterKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError('海报尚未准备好');
    }
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('海报生成失败');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_actionInFlight) return;
    setState(() => _actionInFlight = true);
    try {
      await action();
    } catch (error) {
      if (mounted) _showMessage(_messageFor(error));
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _shareImage(bool timeline) {
    return _runAction(() async {
      final bytes = await _capturePoster();
      await widget.shareGateway.shareWechatImage(bytes, timeline: timeline);
    });
  }

  Future<void> _saveImage() {
    return _runAction(() async {
      final bytes = await _capturePoster();
      await widget.shareGateway.saveImage(bytes);
      if (mounted) _showMessage('保存成功');
    });
  }

  Future<void> _sendLink() {
    final url = _session?.inviteUrl ?? '';
    return _runAction(
      () => widget.shareGateway.shareWechatWebpage(
        url: url,
        title: '高效学习，从选择开始！',
        description: '考有招，答题有技巧，轻松上岸！',
        timeline: false,
      ),
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFAF24),
        foregroundColor: const Color(0xFF332200),
        surfaceTintColor: Colors.transparent,
        title: const Text('推广分享'),
        actions: [
          IconButton(
            key: const ValueKey('promotion-edit-profile'),
            tooltip: '修改信息',
            onPressed: _loading ? null : _editProfile,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            key: const ValueKey('promotion-change-poster'),
            tooltip: '更换海报',
            onPressed: _loading ? null : _choosePoster,
            icon: const Icon(Icons.collections_outlined),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _session == null ? null : _buildActions(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final session = _session;
    if (session == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('推广信息加载失败'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_messageFor(_error!)),
              ),
            OutlinedButton(onPressed: _load, child: const Text('重新加载')),
          ],
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: AspectRatio(
            aspectRatio: 750 / 1334,
            child: RepaintBoundary(
              key: _posterKey,
              child: _PosterCanvas(
                poster: session.posters.isEmpty
                    ? null
                    : session.posters[_selectedPoster],
                profile: _profile,
                qrBytes: _qrBytes,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Material(
      color: Colors.white,
      elevation: 10,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Row(
            children: [
              _PromotionAction(
                key: const ValueKey('promotion-share-friend'),
                icon: Icons.chat_bubble_outline,
                label: '微信好友',
                onTap: _actionInFlight ? null : () => _shareImage(false),
              ),
              _PromotionAction(
                key: const ValueKey('promotion-share-moments'),
                icon: Icons.public,
                label: '朋友圈',
                onTap: _actionInFlight ? null : () => _shareImage(true),
              ),
              _PromotionAction(
                key: const ValueKey('promotion-save-image'),
                icon: Icons.download_outlined,
                label: '保存图片',
                onTap: _actionInFlight ? null : _saveImage,
              ),
              _PromotionAction(
                key: const ValueKey('promotion-send-link'),
                icon: Icons.link,
                label: '发送链接',
                onTap: _actionInFlight ? null : _sendLink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _PromotionProfileDialog extends StatefulWidget {
  const _PromotionProfileDialog({required this.initialProfile});

  final PromotionProfile initialProfile;

  @override
  State<_PromotionProfileDialog> createState() =>
      _PromotionProfileDialogState();
}

final class _PromotionProfileDialogState
    extends State<_PromotionProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile.name);
    _phoneController = TextEditingController(text: widget.initialProfile.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改推广信息'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('promotion-name-input'),
              controller: _nameController,
              maxLength: 10,
              decoration: const InputDecoration(labelText: '姓名'),
            ),
            TextField(
              key: const ValueKey('promotion-phone-input'),
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 11,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '联系电话'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('promotion-profile-save'),
          onPressed: () => Navigator.of(context).pop(
            PromotionProfile(
              name: _nameController.text.trim(),
              phone: _phoneController.text.trim(),
            ),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

final class _PosterCanvas extends StatelessWidget {
  const _PosterCanvas({
    required this.poster,
    required this.profile,
    required this.qrBytes,
  });

  final PromotionPoster? poster;
  final PromotionProfile profile;
  final Uint8List? qrBytes;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (poster == null)
            const ColoredBox(color: Color(0xFFFFAF24))
          else
            Image.network(
              poster!.templateUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFFFFAF24),
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xF7FFFFFF),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Color(0x22000000), blurRadius: 10),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (profile.name.isNotEmpty)
                            Text(
                              profile.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (profile.phone.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(Icons.phone_outlined, size: 15),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    profile.phone,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          const Text(
                            '扫码了解课程详情',
                            style: TextStyle(color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox.square(
                      dimension: 92,
                      child: qrBytes == null
                          ? const ColoredBox(color: Color(0xFFF3F4F6))
                          : Image.memory(qrBytes!, fit: BoxFit.contain),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _PromotionAction extends StatelessWidget {
  const _PromotionAction({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFFFF8A00)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

String _messageFor(Object error) {
  if (error case PlatformException(:final message)) {
    return message?.trim().isNotEmpty == true ? message!.trim() : '操作失败';
  }
  final value = error.toString().replaceFirst('Exception: ', '').trim();
  return value.isEmpty ? '操作失败' : value;
}
