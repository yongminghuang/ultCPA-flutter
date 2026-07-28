import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'phone_captcha_client.dart';

Future<String?> showBlockPuzzleCaptchaDialog(
  BuildContext context,
  PhoneVerificationGateway gateway,
) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlockPuzzleCaptchaDialog(gateway: gateway),
  );
}

final class BlockPuzzleCaptchaDialog extends StatefulWidget {
  const BlockPuzzleCaptchaDialog({
    required this.gateway,
    this.onVerified,
    super.key,
  });

  final PhoneVerificationGateway gateway;
  final ValueChanged<String>? onVerified;

  @override
  State<BlockPuzzleCaptchaDialog> createState() =>
      _BlockPuzzleCaptchaDialogState();
}

final class _BlockPuzzleCaptchaDialogState
    extends State<BlockPuzzleCaptchaDialog> {
  CaptchaChallenge? _challenge;
  Uint8List? _coverBytes;
  Uint8List? _blockBytes;
  _ImageMetrics? _coverMetrics;
  _ImageMetrics? _blockMetrics;
  double _progress = 0;
  bool _loading = true;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChallenge();
  }

  Future<void> _loadChallenge() async {
    setState(() {
      _loading = true;
      _verifying = false;
      _progress = 0;
      _error = null;
    });
    try {
      final challenge = await widget.gateway.loadChallenge();
      final coverBytes = _decodeBase64Image(challenge.originalImageBase64);
      final blockBytes = _decodeBase64Image(challenge.jigsawImageBase64);
      final dimensions = await Future.wait([
        _readImageMetrics(coverBytes),
        _readImageMetrics(blockBytes),
      ]);
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _coverBytes = coverBytes;
        _blockBytes = blockBytes;
        _coverMetrics = dimensions[0];
        _blockMetrics = dimensions[1];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _messageOf(error);
      });
    }
  }

  Future<void> _verify(double progress) async {
    final challenge = _challenge;
    final coverMetrics = _coverMetrics;
    final blockMetrics = _blockMetrics;
    if (challenge == null ||
        coverMetrics == null ||
        blockMetrics == null ||
        _verifying) {
      return;
    }
    final sliderX =
        (coverMetrics.width - blockMetrics.width)
            .clamp(0.0, double.infinity)
            .toDouble() *
        progress;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final verification = await widget.gateway.verifyDrag(challenge, sliderX);
      if (!mounted) return;
      widget.onVerified?.call(verification);
      if (widget.onVerified == null) {
        Navigator.of(context).pop(verification);
      } else {
        setState(() => _verifying = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _progress = 0;
        _error = '${_messageOf(error)}，请刷新后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '请完成安全验证',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('captcha-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.all(10), child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const SizedBox(
        height: 210,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_coverBytes == null ||
        _blockBytes == null ||
        _coverMetrics == null ||
        _blockMetrics == null) {
      return SizedBox(
        height: 210,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error ?? '验证码加载失败'),
            const SizedBox(height: 8),
            FilledButton(onPressed: _loadChallenge, child: const Text('重新加载')),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            _buildPuzzleImage(),
            Positioned(
              right: 2,
              top: 2,
              child: FilledButton.tonal(
                key: const Key('captcha-refresh'),
                onPressed: _verifying ? null : _loadChallenge,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(42, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('刷新'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          key: const Key('captcha-slider'),
          value: _progress,
          onChanged: _verifying
              ? null
              : (value) => setState(() => _progress = value),
          onChangeEnd: _verifying ? null : _verify,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Text(
            _verifying ? '正在验证…' : (_error ?? '拖动滑块完成拼图'),
            key: ValueKey((_verifying, _error)),
            style: TextStyle(
              color: _error == null
                  ? const Color(0xFF666666)
                  : const Color(0xFFD93025),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPuzzleImage() {
    final coverMetrics = _coverMetrics!;
    final blockMetrics = _blockMetrics!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width * coverMetrics.height / coverMetrics.width;
        final blockWidth = width * blockMetrics.width / coverMetrics.width;
        final blockHeight = width * blockMetrics.height / coverMetrics.width;
        return SizedBox(
          width: width,
          height: height,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.memory(
                    _coverBytes!,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),
                Positioned(
                  left:
                      (width - blockWidth)
                          .clamp(0.0, double.infinity)
                          .toDouble() *
                      _progress,
                  top: 0,
                  width: blockWidth,
                  height: blockHeight,
                  child: Image.memory(
                    _blockBytes!,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Uint8List _decodeBase64Image(String value) {
    final encoded = value.contains(',') ? value.split(',').last : value;
    return base64Decode(base64.normalize(encoded));
  }

  static Future<_ImageMetrics> _readImageMetrics(Uint8List bytes) async {
    if (bytes.length >= 24 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      final data = ByteData.sublistView(bytes);
      return _ImageMetrics(
        width: data.getUint32(16).toDouble(),
        height: data.getUint32(20).toDouble(),
      );
    }
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        return _ImageMetrics(
          width: frame.image.width.toDouble(),
          height: frame.image.height.toDouble(),
        );
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  static String _messageOf(Object error) {
    return switch (error) {
      CaptchaProtocolException exception => exception.message,
      _ => '验证码加载或校验失败',
    };
  }
}

final class _ImageMetrics {
  const _ImageMetrics({required this.width, required this.height});

  final double width;
  final double height;
}
