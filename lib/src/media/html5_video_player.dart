import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../teacher_course/teacher_course_models.dart';

typedef Html5VideoContentBuilder =
    Widget Function(
      BuildContext context,
      TeacherCourseItem item,
      Duration initialPosition,
    );

final class Html5VideoPlayer extends StatefulWidget {
  const Html5VideoPlayer({
    required this.item,
    this.initialPosition = Duration.zero,
    this.onPositionChanged,
    this.onPlaybackError,
    this.contentBuilder,
    super.key,
  });

  final TeacherCourseItem item;
  final Duration initialPosition;
  final ValueChanged<Duration>? onPositionChanged;
  final VoidCallback? onPlaybackError;
  final Html5VideoContentBuilder? contentBuilder;

  @override
  State<Html5VideoPlayer> createState() => _Html5VideoPlayerState();
}

final class _Html5VideoPlayerState extends State<Html5VideoPlayer>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  int _progress = 0;
  bool _playbackError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createController();
  }

  @override
  void didUpdateWidget(Html5VideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item ||
        oldWidget.initialPosition != widget.initialPosition ||
        oldWidget.contentBuilder != widget.contentBuilder) {
      _progress = 0;
      _playbackError = false;
      _createController();
    }
  }

  void _createController() {
    if (widget.contentBuilder != null || !widget.item.hasPlayableMedia) {
      _controller = null;
      return;
    }
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
        ),
      )
      ..addJavaScriptChannel(
        'CourseProgress',
        onMessageReceived: (message) {
          final milliseconds = int.tryParse(message.message);
          if (milliseconds == null || milliseconds < 0) return;
          widget.onPositionChanged?.call(Duration(milliseconds: milliseconds));
        },
      )
      ..addJavaScriptChannel(
        'CourseEvent',
        onMessageReceived: (message) {
          if (message.message != 'error' || !mounted) return;
          setState(() => _playbackError = true);
          widget.onPlaybackError?.call();
        },
      );
    _controller = controller;
    unawaited(controller.loadHtmlString(_videoHtml()));
  }

  String _videoHtml() {
    final escape = const HtmlEscape(HtmlEscapeMode.attribute);
    final media = escape.convert(widget.item.mediaUrl);
    final cover = escape.convert(widget.item.coverUrl);
    final initialSeconds = widget.initialPosition.inMilliseconds / 1000;
    return '''<!doctype html>
<html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<style>html,body{margin:0;width:100%;height:100%;background:#000;overflow:hidden}video{width:100%;height:100%;object-fit:contain;background:#000}</style></head>
<body><video id="player" controls autoplay playsinline webkit-playsinline preload="metadata" poster="$cover" src="$media"></video>
<script>
const player=document.getElementById('player');
let lastReported=-5000;
player.addEventListener('loadedmetadata',()=>{const target=$initialSeconds;if(Number.isFinite(target)&&target>0&&target<player.duration){player.currentTime=target;}player.play().catch(()=>{});});
player.addEventListener('timeupdate',()=>{const ms=Math.floor(player.currentTime*1000);if(ms-lastReported>=5000){lastReported=ms;CourseProgress.postMessage(String(ms));}});
player.addEventListener('pause',()=>CourseProgress.postMessage(String(Math.floor(player.currentTime*1000))));
player.addEventListener('ended',()=>CourseProgress.postMessage('0'));
player.addEventListener('error',()=>CourseEvent.postMessage('error'));
</script></body></html>''';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(
        _controller?.runJavaScript(
          'document.getElementById("player")?.pause();',
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(
      _controller?.runJavaScript('document.getElementById("player")?.pause();'),
    );
    super.dispose();
  }

  Widget _frame(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final height = (width * 9 / 16).clamp(0.0, 320.0);
        return SizedBox(width: double.infinity, height: height, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final builder = widget.contentBuilder;
    if (builder != null) {
      return _frame(builder(context, widget.item, widget.initialPosition));
    }
    if (!widget.item.hasPlayableMedia) {
      return _frame(
        const ColoredBox(
          color: Colors.black,
          child: Center(
            child: Text('视频地址无效', style: TextStyle(color: Colors.white70)),
          ),
        ),
      );
    }
    return _frame(
      Stack(
        fit: StackFit.expand,
        children: [
          WebViewWidget(controller: _controller!),
          if (_progress < 100 && !_playbackError)
            Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(
                value: _progress == 0 ? null : _progress / 100,
                minHeight: 2,
                color: const Color(0xFF237DED),
                backgroundColor: Colors.white24,
              ),
            ),
          if (_playbackError)
            const ColoredBox(
              color: Color(0xCC000000),
              child: Center(
                child: Text('视频加载失败', style: TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
