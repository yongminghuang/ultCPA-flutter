import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../teacher_course/teacher_course_models.dart';

typedef Html5VideoContentBuilder =
    Widget Function(
      BuildContext context,
      TeacherCourseItem item,
      Duration initialPosition,
    );

final class Html5VideoController extends ChangeNotifier {
  Html5VideoController({Duration initialPosition = Duration.zero})
    : _position = initialPosition;

  Duration _position;
  Duration _duration = Duration.zero;
  bool _isPlaying = true;
  bool _isMuted = false;
  double _playbackSpeed = 1;
  Future<void> Function(String script)? _runJavaScript;

  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;
  double get playbackSpeed => _playbackSpeed;

  Future<void> play() async {
    if (_runJavaScript == null) {
      _update(isPlaying: true);
      return;
    }
    await _run(
      '(()=>{const p=document.getElementById("player");'
      'if(!p){return;}p.play().then(()=>window.courseEmit?.())'
      '.catch(()=>window.courseEmit?.());})();',
    );
  }

  Future<void> pause() async {
    _update(isPlaying: false);
    await _run(
      '(()=>{const p=document.getElementById("player");'
      'if(p){p.pause();window.courseEmit?.();}})();',
    );
  }

  Future<void> togglePlayback() => isPlaying ? pause() : play();

  Future<void> seekTo(Duration position) async {
    final maxMilliseconds = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds
        : position.inMilliseconds;
    final milliseconds = position.inMilliseconds
        .clamp(0, maxMilliseconds)
        .toInt();
    _update(position: Duration(milliseconds: milliseconds));
    await _run(
      '(()=>{const p=document.getElementById("player");'
      'if(p){p.currentTime=${milliseconds / 1000};}})();',
    );
  }

  Future<void> setMuted(bool muted) async {
    _update(isMuted: muted);
    await _run(
      '(()=>{const p=document.getElementById("player");'
      'if(p){p.muted=${muted ? 'true' : 'false'};}})();',
    );
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final safeSpeed = speed.clamp(0.5, 2.0).toDouble();
    _update(playbackSpeed: safeSpeed);
    await _run(
      '(()=>{const p=document.getElementById("player");'
      'if(p){p.playbackRate=$safeSpeed;}})();',
    );
  }

  void _attach(Future<void> Function(String script) runJavaScript) {
    _runJavaScript = runJavaScript;
  }

  void _detach(Future<void> Function(String script) runJavaScript) {
    if (_runJavaScript == runJavaScript) _runJavaScript = null;
  }

  Future<void> _run(String script) async {
    await _runJavaScript?.call(script);
  }

  void _update({
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    bool? isMuted,
    double? playbackSpeed,
  }) {
    final nextPosition = position ?? _position;
    final nextDuration = duration ?? _duration;
    final nextPlaying = isPlaying ?? _isPlaying;
    final nextMuted = isMuted ?? _isMuted;
    final nextSpeed = playbackSpeed ?? _playbackSpeed;
    if (nextPosition == _position &&
        nextDuration == _duration &&
        nextPlaying == _isPlaying &&
        nextMuted == _isMuted &&
        nextSpeed == _playbackSpeed) {
      return;
    }
    _position = nextPosition;
    _duration = nextDuration;
    _isPlaying = nextPlaying;
    _isMuted = nextMuted;
    _playbackSpeed = nextSpeed;
    notifyListeners();
  }

  @override
  void dispose() {
    _runJavaScript = null;
    super.dispose();
  }
}

final class Html5VideoPlayer extends StatefulWidget {
  const Html5VideoPlayer({
    required this.item,
    this.initialPosition = Duration.zero,
    this.onPositionChanged,
    this.onPlaybackError,
    this.contentBuilder,
    this.controller,
    this.showNativeControls = true,
    this.fillAvailableSpace = false,
    super.key,
  });

  final TeacherCourseItem item;
  final Duration initialPosition;
  final ValueChanged<Duration>? onPositionChanged;
  final VoidCallback? onPlaybackError;
  final Html5VideoContentBuilder? contentBuilder;
  final Html5VideoController? controller;
  final bool showNativeControls;
  final bool fillAvailableSpace;

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
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(_runVideoJavaScript);
      widget.controller?._attach(_runVideoJavaScript);
    }
    if (oldWidget.item != widget.item ||
        oldWidget.initialPosition != widget.initialPosition ||
        oldWidget.contentBuilder != widget.contentBuilder ||
        oldWidget.showNativeControls != widget.showNativeControls) {
      _progress = 0;
      _playbackError = false;
      _createController();
    }
  }

  void _createController() {
    widget.controller?._attach(_runVideoJavaScript);
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
      )
      ..addJavaScriptChannel(
        'CourseState',
        onMessageReceived: (message) {
          final Object? decoded;
          try {
            decoded = jsonDecode(message.message);
          } on FormatException {
            return;
          }
          if (decoded is! Map) return;
          final map = Map<String, dynamic>.from(decoded);
          final position = _durationFromJson(map['positionMs']);
          final duration = _durationFromJson(map['durationMs']);
          final playing = map['playing'];
          final muted = map['muted'];
          final speed = map['speed'];
          widget.controller?._update(
            position: position,
            duration: duration,
            isPlaying: playing is bool ? playing : null,
            isMuted: muted is bool ? muted : null,
            playbackSpeed: speed is num ? speed.toDouble() : null,
          );
        },
      );
    _controller = controller;
    unawaited(_configureAndLoad(controller));
  }

  Future<void> _configureAndLoad(WebViewController controller) async {
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      // The visible play button lives in Flutter, not inside the WebView. An
      // Android WebView therefore does not treat that tap as a media gesture.
      // Allow the subsequent JavaScript play() call to start the video.
      await platform.setMediaPlaybackRequiresUserGesture(false);
    }
    await controller.loadHtmlString(_videoHtml());
  }

  String _videoHtml() {
    final escape = const HtmlEscape(HtmlEscapeMode.attribute);
    final media = escape.convert(widget.item.mediaUrl);
    final cover = escape.convert(widget.item.coverUrl);
    final initialSeconds = widget.initialPosition.inMilliseconds / 1000;
    final controls = widget.showNativeControls ? ' controls' : '';
    return '''<!doctype html>
<html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<style>html,body{margin:0;width:100%;height:100%;background:#000;overflow:hidden}video{width:100%;height:100%;object-fit:contain;background:#000}</style></head>
<body><video id="player"$controls autoplay playsinline webkit-playsinline preload="metadata" poster="$cover" src="$media"></video>
<script>
const player=document.getElementById('player');
let lastReported=-5000;
const emit=()=>CourseState.postMessage(JSON.stringify({positionMs:Math.floor((player.currentTime||0)*1000),durationMs:Number.isFinite(player.duration)?Math.floor(player.duration*1000):0,playing:!player.paused&&!player.ended,muted:player.muted,speed:player.playbackRate||1}));
window.courseEmit=emit;
player.addEventListener('loadedmetadata',()=>{const target=$initialSeconds;if(Number.isFinite(target)&&target>0&&target<player.duration){player.currentTime=target;}emit();player.play().then(emit).catch(emit);});
player.addEventListener('timeupdate',()=>{const ms=Math.floor(player.currentTime*1000);emit();if(ms-lastReported>=5000){lastReported=ms;CourseProgress.postMessage(String(ms));}});
player.addEventListener('play',emit);
player.addEventListener('playing',emit);
player.addEventListener('canplay',emit);
player.addEventListener('waiting',emit);
player.addEventListener('stalled',emit);
player.addEventListener('pause',()=>{emit();CourseProgress.postMessage(String(Math.floor(player.currentTime*1000)));});
player.addEventListener('ratechange',emit);
player.addEventListener('volumechange',emit);
player.addEventListener('ended',()=>{emit();CourseProgress.postMessage('0');});
player.addEventListener('error',()=>CourseEvent.postMessage('error'));
</script></body></html>''';
  }

  Future<void> _runVideoJavaScript(String script) async {
    await _controller?.runJavaScript(script);
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
    widget.controller?._detach(_runVideoJavaScript);
    unawaited(
      _controller?.runJavaScript('document.getElementById("player")?.pause();'),
    );
    super.dispose();
  }

  Widget _frame(Widget child) {
    if (widget.fillAvailableSpace) {
      return SizedBox.expand(child: child);
    }
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

Duration? _durationFromJson(Object? value) {
  if (value is! num || !value.isFinite || value < 0) return null;
  return Duration(milliseconds: value.toInt());
}
