import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum PracticeMediaKind { audio, video }

String resolvePracticeMediaUrl(String? raw, {String ossDomain = ''}) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty || value.toLowerCase() == 'null') return '';
  final uri = Uri.tryParse(value);
  if (uri?.hasScheme == true) {
    return uri!.scheme == 'http' || uri.scheme == 'https' ? value : '';
  }
  final domain = ossDomain.trim().isEmpty
      ? 'https://file.xmzhujing.com/'
      : ossDomain.trim();
  return '${domain.replaceFirst(RegExp(r'/$'), '')}/'
      '${value.replaceFirst(RegExp(r'^/'), '')}';
}

final class PracticeMediaPlayer extends StatefulWidget {
  const PracticeMediaPlayer({
    required this.rawUrl,
    required this.kind,
    this.coverUrl,
    this.ossDomain = '',
    this.autoplay = false,
    super.key,
  });

  final String? rawUrl;
  final PracticeMediaKind kind;
  final String? coverUrl;
  final String ossDomain;
  final bool autoplay;

  @override
  State<PracticeMediaPlayer> createState() => _PracticeMediaPlayerState();
}

final class _PracticeMediaPlayerState extends State<PracticeMediaPlayer>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  bool _failed = false;

  String get _url =>
      resolvePracticeMediaUrl(widget.rawUrl, ossDomain: widget.ossDomain);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createController();
  }

  @override
  void didUpdateWidget(PracticeMediaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawUrl != widget.rawUrl ||
        oldWidget.coverUrl != widget.coverUrl ||
        oldWidget.ossDomain != widget.ossDomain ||
        oldWidget.kind != widget.kind ||
        oldWidget.autoplay != widget.autoplay) {
      _failed = false;
      _createController();
    }
  }

  void _createController() {
    if (_url.isEmpty) {
      _controller = null;
      return;
    }
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(
        widget.kind == PracticeMediaKind.video
            ? Colors.black
            : const Color(0xFFF7F8FA),
      )
      ..addJavaScriptChannel(
        'PracticeMediaEvent',
        onMessageReceived: (message) {
          if (message.message == 'error' && mounted) {
            setState(() => _failed = true);
          }
        },
      );
    _controller = controller;
    unawaited(controller.loadHtmlString(_html()));
  }

  String _html() {
    final escape = const HtmlEscape(HtmlEscapeMode.attribute);
    final media = escape.convert(_url);
    final cover = escape.convert(
      resolvePracticeMediaUrl(widget.coverUrl, ossDomain: widget.ossDomain),
    );
    final autoplay = widget.autoplay ? ' autoplay' : '';
    if (widget.kind == PracticeMediaKind.audio) {
      return '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"><style>html,body{margin:0;width:100%;height:100%;background:#f7f8fa;overflow:hidden}body{display:flex;align-items:center}audio{width:100%;height:54px}</style></head><body><audio id="player" controls$autoplay preload="metadata" src="$media"></audio><script>const p=document.getElementById('player');p.addEventListener('error',()=>PracticeMediaEvent.postMessage('error'));${widget.autoplay ? "p.play().catch(()=>{});" : ''}</script></body></html>''';
    }
    return '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"><style>html,body{margin:0;width:100%;height:100%;background:#000;overflow:hidden}video{width:100%;height:100%;object-fit:contain;background:#000}</style></head><body><video id="player" controls$autoplay playsinline webkit-playsinline preload="metadata" poster="$cover" src="$media"></video><script>const p=document.getElementById('player');p.addEventListener('error',()=>PracticeMediaEvent.postMessage('error'));${widget.autoplay ? "p.play().catch(()=>{});" : ''}</script></body></html>''';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_pause());
    }
  }

  Future<void> _pause() async {
    try {
      await _controller?.runJavaScript(
        'document.getElementById("player")?.pause();',
      );
    } catch (_) {
      // A disposed platform view may reject its final pause command.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_pause());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.kind == PracticeMediaKind.audio ? 58.0 : 210.0;
    if (_url.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('暂无讲解音视频')),
      );
    }
    return SizedBox(
      height: height,
      child: _failed
          ? const ColoredBox(
              color: Color(0xFFF7F8FA),
              child: Center(child: Text('讲解加载失败，请稍后重试')),
            )
          : WebViewWidget(controller: _controller!),
    );
  }
}
