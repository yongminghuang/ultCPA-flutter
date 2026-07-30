import 'dart:async';
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
  static const _accent = Color(0xFF237DED);
  static const _success = Color(0xFF2E9B55);
  static const _failure = Color(0xFFD94B45);
  static const _handleSize = 52.0;

  CaptchaChallenge? _challenge;
  Uint8List? _coverBytes;
  Uint8List? _blockBytes;
  _ImageMetrics? _coverMetrics;
  _ImageMetrics? _blockMetrics;
  double _progress = 0;
  _CaptchaState _state = _CaptchaState.loading;
  String? _error;
  Timer? _reloadTimer;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadChallenge());
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChallenge() async {
    _reloadTimer?.cancel();
    final generation = ++_loadGeneration;
    setState(() {
      _state = _CaptchaState.loading;
      _challenge = null;
      _coverBytes = null;
      _blockBytes = null;
      _coverMetrics = null;
      _blockMetrics = null;
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
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _challenge = challenge;
        _coverBytes = coverBytes;
        _blockBytes = blockBytes;
        _coverMetrics = dimensions[0];
        _blockMetrics = dimensions[1];
        _state = _CaptchaState.ready;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _state = _CaptchaState.loadError;
        _error = _messageOf(error);
      });
    }
  }

  Future<void> _verify() async {
    final challenge = _challenge;
    final coverMetrics = _coverMetrics;
    final blockMetrics = _blockMetrics;
    if (challenge == null ||
        coverMetrics == null ||
        blockMetrics == null ||
        _state != _CaptchaState.ready) {
      return;
    }
    final sliderX =
        (coverMetrics.width - blockMetrics.width)
            .clamp(0.0, double.infinity)
            .toDouble() *
        _progress;
    setState(() {
      _state = _CaptchaState.verifying;
      _error = null;
    });
    try {
      final verification = await widget.gateway.verifyDrag(challenge, sliderX);
      if (!mounted) return;
      setState(() => _state = _CaptchaState.success);
      final onVerified = widget.onVerified;
      if (onVerified != null) {
        onVerified(verification);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted && _state == _CaptchaState.success) {
        Navigator.of(context).pop(verification);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = _CaptchaState.failed;
        _error = _messageOf(error);
      });
      _reloadTimer = Timer(const Duration(milliseconds: 1000), () {
        if (mounted && _state == _CaptchaState.failed) {
          unawaited(_loadChallenge());
        }
      });
    }
  }

  void _updateDrag(DragUpdateDetails details, double travel) {
    if (_state != _CaptchaState.ready || travel <= 0) return;
    setState(() {
      _progress = (_progress + details.delta.dx / travel)
          .clamp(0.0, 1.0)
          .toDouble();
    });
  }

  void _adjustProgress(double delta) {
    if (_state != _CaptchaState.ready) return;
    setState(() {
      _progress = (_progress + delta).clamp(0.0, 1.0).toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 350),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 50,
      child: Padding(
        padding: const EdgeInsets.only(left: 14, right: 4),
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
            IconButton(
              key: const Key('captcha-close'),
              tooltip: '关闭',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.highlight_off, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_state == _CaptchaState.loading) {
      return const SizedBox(
        height: 230,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_state == _CaptchaState.loadError ||
        _coverBytes == null ||
        _blockBytes == null ||
        _coverMetrics == null ||
        _blockMetrics == null) {
      return SizedBox(
        height: 230,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error ?? '验证码加载失败'),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const Key('captcha-retry'),
              onPressed: () => unawaited(_loadChallenge()),
              icon: const Icon(Icons.refresh),
              label: const Text('重新加载'),
            ),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPuzzleImage(),
        const SizedBox(height: 12),
        _buildDragTrack(),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Text(
            _statusMessage,
            key: ValueKey((_state, _error)),
            textAlign: TextAlign.center,
            style: TextStyle(color: _statusColor, fontSize: 14),
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
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: width,
            height: height,
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
                if (_state == _CaptchaState.verifying)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x33000000),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_state == _CaptchaState.success ||
                    _state == _CaptchaState.failed)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 38,
                      color:
                          (_state == _CaptchaState.success
                                  ? _success
                                  : _failure)
                              .withValues(alpha: 0.82),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _state == _CaptchaState.success
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _state == _CaptchaState.success ? '验证成功' : '验证失败',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: Material(
                    color: const Color(0x66000000),
                    shape: const CircleBorder(),
                    child: IconButton(
                      key: const Key('captcha-refresh'),
                      tooltip: '刷新验证码',
                      onPressed:
                          _state == _CaptchaState.verifying ||
                              _state == _CaptchaState.success
                          ? null
                          : () => unawaited(_loadChallenge()),
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      iconSize: 23,
                      constraints: const BoxConstraints.tightFor(
                        width: 42,
                        height: 42,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDragTrack() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final travel = (constraints.maxWidth - _handleSize)
            .clamp(0.0, double.infinity)
            .toDouble();
        final enabled = _state == _CaptchaState.ready;
        final handleColor = switch (_state) {
          _CaptchaState.success => _success,
          _CaptchaState.failed => _failure,
          _ => _progress > 0 ? _accent : Colors.white,
        };
        final handleIcon = switch (_state) {
          _CaptchaState.verifying => Icons.more_horiz,
          _CaptchaState.success => Icons.check,
          _CaptchaState.failed => Icons.close,
          _ => Icons.arrow_forward,
        };
        return Semantics(
          label: '向右拖动滑块填充拼图',
          value: '${(_progress * 100).round()}%',
          increasedValue:
              '${((_progress + 0.1).clamp(0.0, 1.0) * 100).round()}%',
          decreasedValue:
              '${((_progress - 0.1).clamp(0.0, 1.0) * 100).round()}%',
          enabled: enabled,
          onIncrease: enabled ? () => _adjustProgress(0.1) : null,
          onDecrease: enabled ? () => _adjustProgress(-0.1) : null,
          child: GestureDetector(
            key: const Key('captcha-slider'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: enabled
                ? (details) => _updateDrag(details, travel)
                : null,
            onHorizontalDragEnd: enabled ? (_) => unawaited(_verify()) : null,
            child: SizedBox(
              height: _handleSize,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FB),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 1,
                    bottom: 1,
                    width: _handleSize / 2 + travel * _progress,
                    child: ColoredBox(
                      color: switch (_state) {
                        _CaptchaState.success => const Color(0xFFE8F6ED),
                        _CaptchaState.failed => const Color(0xFFFDECEA),
                        _ => const Color(0xFFF3FEF1),
                      },
                    ),
                  ),
                  if (_progress < 0.2 && enabled)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(left: 40),
                            child: Text(
                              '向右拖动滑块填充拼图',
                              style: TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  AnimatedPositioned(
                    duration: enabled
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    left: travel * _progress,
                    top: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _handleSize,
                      height: _handleSize,
                      decoration: BoxDecoration(
                        color: handleColor,
                        border: Border.all(
                          color: _state == _CaptchaState.failed
                              ? _failure
                              : _state == _CaptchaState.success
                              ? _success
                              : const Color(0xFFD8D8D8),
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        handleIcon,
                        color:
                            _progress > 0 ||
                                _state == _CaptchaState.success ||
                                _state == _CaptchaState.failed
                            ? Colors.white
                            : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String get _statusMessage => switch (_state) {
    _CaptchaState.verifying => '正在验证…',
    _CaptchaState.success => '拼图验证成功',
    _CaptchaState.failed => '${_error ?? '拼图位置不正确'}，正在刷新…',
    _ => '拖动滑块完成拼图',
  };

  Color get _statusColor => switch (_state) {
    _CaptchaState.success => _success,
    _CaptchaState.failed => _failure,
    _ => const Color(0xFF666666),
  };

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

enum _CaptchaState { loading, ready, verifying, success, failed, loadError }

final class _ImageMetrics {
  const _ImageMetrics({required this.width, required this.height});

  final double width;
  final double height;
}
