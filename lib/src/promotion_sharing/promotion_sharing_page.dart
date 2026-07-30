import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'promotion_share_gateway.dart';
import 'promotion_sharing_models.dart';
import 'promotion_sharing_repository.dart';

const _promotionOrange = Color(0xFFFFAF24);
const _promotionBlue = Color(0xFF237DED);
const _promotionDivider = Color(0xFFF3F7F9);
const _promotionPageBackground = Color(0xFFF7F8FA);
const _promotionAssetRoot = 'assets/images/promotion_sharing';

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
  PromotionPoster? _selectedPoster;
  Uint8List? _qrBytes;
  Object? _error;
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
      final loadedSession = await widget.dataSource.load(widget.inviteContent);
      var profile = loadedSession.profile;
      PromotionPosterPreference? preference;
      try {
        profile = await widget.shareGateway.readProfile(profile);
        preference = await widget.shareGateway.readSelectedPoster();
      } catch (_) {
        // The Android account snapshot and first server poster remain usable.
      }

      final posters = loadedSession.posters.toList(growable: true);
      var selected = _preferredPoster(posters, preference);
      if (selected == null &&
          preference != null &&
          _isRemoteUrl(preference.templateUrl)) {
        selected = PromotionPoster(
          id: preference.posterId,
          templateUrl: preference.templateUrl,
          sampleUrl: preference.templateUrl,
          showStatus: true,
        );
        posters.insert(0, selected);
      }
      selected ??= posters.firstOrNull;
      if (preference == null && selected != null) {
        try {
          await widget.shareGateway.saveSelectedPoster(selected);
        } catch (_) {
          // The current poster can still be used for this session.
        }
      }

      final qr = await widget.shareGateway.createQrCode(
        loadedSession.inviteUrl,
      );
      if (!mounted) return;
      setState(() {
        _session = PromotionSharingSession(
          inviteUrl: loadedSession.inviteUrl,
          profile: loadedSession.profile,
          posters: posters,
        );
        _profile = profile;
        _selectedPoster = selected;
        _qrBytes = qr;
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

  PromotionPoster? _preferredPoster(
    List<PromotionPoster> posters,
    PromotionPosterPreference? preference,
  ) {
    if (preference == null) return null;
    for (final poster in posters) {
      if (poster.id == preference.posterId) return poster;
    }
    for (final poster in posters) {
      if (poster.templateUrl == preference.templateUrl) return poster;
    }
    return null;
  }

  Future<void> _editProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _PromotionProfilePage(
          initialProfile: _profile,
          shareGateway: widget.shareGateway,
          onChanged: (profile) {
            if (mounted) setState(() => _profile = profile);
          },
        ),
      ),
    );
  }

  Future<void> _choosePoster() async {
    final selected = await Navigator.of(context).push<PromotionPoster>(
      MaterialPageRoute(
        builder: (_) => _PromotionPosterPage(
          dataSource: widget.dataSource,
          initialPosters: _session?.posters ?? const <PromotionPoster>[],
          selectedPosterId: _selectedPoster?.id,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _selectedPoster = selected);
    try {
      await widget.shareGateway.saveSelectedPoster(selected);
    } catch (error) {
      if (mounted) _showMessage(_messageFor(error));
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _promotionOrange,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text('VIP推广赚钱'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_session == null) {
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
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(flex: 7, child: _buildPosterArea()),
          Expanded(flex: 1, child: _buildChangeActions()),
          Expanded(flex: 2, child: _buildShareActions()),
        ],
      ),
    );
  }

  Widget _buildPosterArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.max(0.0, constraints.maxWidth - 36);
        final maxHeight = math.max(0.0, constraints.maxHeight - 36);
        final width = math.min(maxWidth, maxHeight * 3 / 4);
        return Center(
          child: SizedBox(
            width: width,
            height: width * 4 / 3,
            child: RepaintBoundary(
              key: _posterKey,
              child: _PosterCanvas(
                poster: _selectedPoster,
                profile: _profile,
                qrBytes: _qrBytes,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChangeActions() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: ColoredBox(
            color: _promotionDivider,
            child: SizedBox(height: 4, width: double.infinity),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PromotionOutlineButton(
                key: const ValueKey('promotion-edit-profile'),
                label: '修改招生信息',
                onPressed: _editProfile,
              ),
              const SizedBox(width: 16),
              _PromotionOutlineButton(
                key: const ValueKey('promotion-change-poster'),
                label: '更换推广图片',
                onPressed: _choosePoster,
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: ColoredBox(
            color: _promotionDivider,
            child: SizedBox(height: 8, width: double.infinity),
          ),
        ),
      ],
    );
  }

  Widget _buildShareActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _PromotionAction(
          key: const ValueKey('promotion-share-friend'),
          assetName: '$_promotionAssetRoot/ic_tools_wx.png',
          label: '分享微信好友',
          onTap: _actionInFlight ? null : () => _shareImage(false),
        ),
        _PromotionAction(
          key: const ValueKey('promotion-share-moments'),
          assetName: '$_promotionAssetRoot/ic_tools_pyq.png',
          label: '朋友圈',
          onTap: _actionInFlight ? null : () => _shareImage(true),
        ),
        _PromotionAction(
          key: const ValueKey('promotion-save-image'),
          assetName: '$_promotionAssetRoot/icon_share_download.png',
          label: '保存图片',
          onTap: _actionInFlight ? null : _saveImage,
        ),
        _PromotionAction(
          key: const ValueKey('promotion-send-link'),
          assetName: '$_promotionAssetRoot/send_link.png',
          label: '发送链接',
          onTap: _actionInFlight ? null : _sendLink,
        ),
      ],
    );
  }
}

final class _PromotionOutlineButton extends StatelessWidget {
  const _PromotionOutlineButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: Colors.white,
        side: const BorderSide(color: _promotionBlue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: Text(label),
    );
  }
}

final class _PromotionProfilePage extends StatefulWidget {
  const _PromotionProfilePage({
    required this.initialProfile,
    required this.shareGateway,
    required this.onChanged,
  });

  final PromotionProfile initialProfile;
  final PromotionShareGateway shareGateway;
  final ValueChanged<PromotionProfile> onChanged;

  @override
  State<_PromotionProfilePage> createState() => _PromotionProfilePageState();
}

final class _PromotionProfilePageState extends State<_PromotionProfilePage> {
  late PromotionProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
  }

  Future<void> _editName() async {
    final value = await _showEditor(
      title: '请输入昵称',
      description: '留空则推广海报不显示昵称，限10个字以内',
      initialValue: _profile.name,
      maxLength: 10,
    );
    if (value == null || value == _profile.name) return;
    await _save(PromotionProfile(name: value, phone: _profile.phone));
  }

  Future<void> _editPhone() async {
    final value = await _showEditor(
      title: '请输入手机号',
      description: '留空则推广海报不显示手机号，限11个字符',
      initialValue: _profile.phone,
      maxLength: 11,
      phone: true,
    );
    if (value == null || value == _profile.phone) return;
    await _save(PromotionProfile(name: _profile.name, phone: value));
  }

  Future<String?> _showEditor({
    required String title,
    required String description,
    required String initialValue,
    required int maxLength,
    bool phone = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _PromotionTextEditorDialog(
        title: title,
        description: description,
        initialValue: initialValue,
        maxLength: maxLength,
        phone: phone,
      ),
    );
  }

  Future<void> _save(PromotionProfile profile) async {
    try {
      await widget.shareGateway.saveProfile(profile);
      if (!mounted) return;
      setState(() => _profile = profile);
      widget.onChanged(profile);
      _showMessage('修改成功');
    } catch (error) {
      if (mounted) _showMessage(_messageFor(error));
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _promotionPageBackground,
      appBar: AppBar(
        backgroundColor: _promotionBlue,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text('修改招生信息'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PromotionProfileRow(
              key: const ValueKey('promotion-name-row'),
              title: '昵称',
              value: _profile.name,
              onTap: _editName,
            ),
            const SizedBox(height: 8),
            _PromotionProfileRow(
              key: const ValueKey('promotion-phone-row'),
              title: '手机号码',
              value: _profile.phone,
              onTap: _editPhone,
            ),
            const SizedBox(height: 20),
            const Text(
              '注:仅用于二维码海报的显示，不会修改你的资料',
              style: TextStyle(fontSize: 12, color: Color(0xFF212121)),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PromotionTextEditorDialog extends StatefulWidget {
  const _PromotionTextEditorDialog({
    required this.title,
    required this.description,
    required this.initialValue,
    required this.maxLength,
    required this.phone,
  });

  final String title;
  final String description;
  final String initialValue;
  final int maxLength;
  final bool phone;

  @override
  State<_PromotionTextEditorDialog> createState() =>
      _PromotionTextEditorDialogState();
}

final class _PromotionTextEditorDialogState
    extends State<_PromotionTextEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.description,
            style: const TextStyle(color: Color(0xFF727272), fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            key: ValueKey(
              widget.phone ? 'promotion-phone-input' : 'promotion-name-input',
            ),
            controller: _controller,
            autofocus: true,
            maxLength: widget.maxLength,
            keyboardType: widget.phone
                ? TextInputType.phone
                : TextInputType.text,
            inputFormatters: widget.phone
                ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
                : null,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('promotion-profile-save'),
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

final class _PromotionProfileRow extends StatelessWidget {
  const _PromotionProfileRow({
    required this.title,
    required this.value,
    required this.onTap,
    super.key,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 49,
          decoration: const BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: _promotionDivider, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.only(left: 16, right: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF3C3C3C),
                    fontSize: 16,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF737373),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF999999),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _PromotionPosterPage extends StatefulWidget {
  const _PromotionPosterPage({
    required this.dataSource,
    required this.initialPosters,
    required this.selectedPosterId,
  });

  final PromotionSharingDataSource dataSource;
  final List<PromotionPoster> initialPosters;
  final String? selectedPosterId;

  @override
  State<_PromotionPosterPage> createState() => _PromotionPosterPageState();
}

final class _PromotionPosterPageState extends State<_PromotionPosterPage> {
  late List<PromotionPoster> _posters;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _posters = widget.initialPosters;
    _loading = _posters.isEmpty;
    unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final posters = await widget.dataSource.loadPosters();
      if (!mounted) return;
      setState(() {
        _posters = posters;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _posters = const [];
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _promotionDivider,
      appBar: AppBar(
        backgroundColor: _promotionOrange,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text('推广图片'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_posters.isEmpty) {
      return Center(
        child: InkWell(
          onTap: _reload,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error == null ? '暂无推广图片模板' : '获取海报失败，点击重试'),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: GridView.builder(
        key: const ValueKey('promotion-poster-selector'),
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3 / 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _posters.length,
        itemBuilder: (context, index) {
          final poster = _posters[index];
          return InkWell(
            key: ValueKey('promotion-poster-$index'),
            onTap: () => Navigator.of(context).pop(poster),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: poster.id == widget.selectedPosterId
                    ? Border.all(color: _promotionOrange, width: 2)
                    : null,
              ),
              child: Image.network(
                poster.previewUrl,
                fit: BoxFit.fill,
                errorBuilder: (_, _, _) => const _PosterFallback(),
              ),
            ),
          );
        },
      ),
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
    return Stack(
      fit: StackFit.expand,
      children: [
        if (poster == null)
          const _PosterFallback()
        else
          Image.network(
            poster!.templateUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _PosterFallback(),
          ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 10,
          child: AspectRatio(
            aspectRatio: 280 / 82,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (profile.name.isNotEmpty)
                          Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _promotionDivider,
                              fontSize: 22,
                              height: 1.05,
                            ),
                          ),
                        if (profile.phone.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Image.asset(
                                '$_promotionAssetRoot/ic_left_poster_phone.png',
                                width: 16,
                                height: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  profile.phone,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xCCFFFFFF),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0x22000000),
                            width: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(1),
                          child: qrBytes == null
                              ? const SizedBox.expand()
                              : Image.memory(qrBytes!, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      '$_promotionAssetRoot/share_stu_empty.jpg',
      fit: BoxFit.cover,
    );
  }
}

final class _PromotionAction extends StatelessWidget {
  const _PromotionAction({
    required this.assetName,
    required this.label,
    required this.onTap,
    super.key,
  });

  final String assetName;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 88,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.45 : 1,
          child: Column(
            children: [
              Image.asset(assetName, width: 40, height: 40),
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isRemoteUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

String _messageFor(Object error) {
  if (error case PlatformException(:final message)) {
    return message?.trim().isNotEmpty == true ? message!.trim() : '操作失败';
  }
  final value = error.toString().replaceFirst('Exception: ', '').trim();
  return value.isEmpty ? '操作失败' : value;
}

extension on List<PromotionPoster> {
  PromotionPoster? get firstOrNull => isEmpty ? null : first;
}
