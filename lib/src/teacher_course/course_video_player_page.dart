import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main_tabs/main_tabs_models.dart';
import '../media/html5_video_player.dart';
import 'teacher_course_models.dart';
import 'teacher_course_progress_store.dart';

typedef CourseVideoPurchaseLauncher = Future<bool> Function();

final class CourseVideoPlayerPage extends StatefulWidget {
  const CourseVideoPlayerPage({
    required this.media,
    required this.progressStore,
    this.hasVideoAccess = false,
    this.onPurchase,
    this.videoContentBuilder,
    this.trialDuration = const Duration(minutes: 5),
    super.key,
  });

  final CourseMedia media;
  final TeacherCourseProgressStore progressStore;
  final bool hasVideoAccess;
  final CourseVideoPurchaseLauncher? onPurchase;
  final Html5VideoContentBuilder? videoContentBuilder;
  final Duration trialDuration;

  @override
  State<CourseVideoPlayerPage> createState() => _CourseVideoPlayerPageState();
}

final class _CourseVideoPlayerPageState extends State<CourseVideoPlayerPage> {
  Html5VideoController? _playbackController;
  Timer? _hideControlsTimer;
  Duration _initialPosition = Duration.zero;
  Duration? _dragPosition;
  bool _loading = true;
  bool _controlsVisible = true;
  bool _trialEnded = false;
  bool _purchasing = false;
  late bool _hasVideoAccess;
  Orientation? _systemUiOrientation;

  TeacherCourseItem get _playerItem => TeacherCourseItem(
    id: widget.media.id,
    subject: widget.media.subject,
    courseType: widget.media.courseType,
    title: widget.media.title,
    coverUrl: widget.media.coverUrl,
    mediaUrl: widget.media.mediaUrl,
  );

  @override
  void initState() {
    super.initState();
    _hasVideoAccess = widget.hasVideoAccess;
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    unawaited(_loadProgress());
  }

  @override
  void didUpdateWidget(CourseVideoPlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.hasVideoAccess && widget.hasVideoAccess) {
      setState(() {
        _hasVideoAccess = true;
        _trialEnded = false;
      });
    }
  }

  Future<void> _loadProgress() async {
    var position = await widget.progressStore.readMediaPosition(
      widget.media.id,
    );
    if (!_hasVideoAccess && position >= widget.trialDuration) {
      position = widget.trialDuration;
      _trialEnded = true;
    }
    if (!mounted) return;
    final controller = Html5VideoController(initialPosition: position);
    controller.addListener(_handlePlaybackChanged);
    setState(() {
      _initialPosition = position;
      _playbackController = controller;
      _loading = false;
    });
    _scheduleControlsAutoHide();
  }

  void _handlePlaybackChanged() {
    final controller = _playbackController;
    if (controller == null || !mounted) return;
    if (!_hasVideoAccess &&
        !_trialEnded &&
        controller.position >= widget.trialDuration) {
      setState(() {
        _trialEnded = true;
        _controlsVisible = false;
      });
      _hideControlsTimer?.cancel();
      unawaited(controller.pause());
      unawaited(
        widget.progressStore.writeMediaPosition(
          widget.media.id,
          widget.trialDuration,
        ),
      );
      return;
    }
    if (!controller.isPlaying) _hideControlsTimer?.cancel();
    setState(() {});
  }

  void _savePosition(Duration position) {
    final safePosition = !_hasVideoAccess && position > widget.trialDuration
        ? widget.trialDuration
        : position;
    unawaited(
      widget.progressStore.writeMediaPosition(widget.media.id, safePosition),
    );
  }

  void _syncSystemUi(Orientation orientation) {
    if (_systemUiOrientation == orientation) return;
    _systemUiOrientation = orientation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        SystemChrome.setEnabledSystemUIMode(
          orientation == Orientation.landscape
              ? SystemUiMode.immersiveSticky
              : SystemUiMode.edgeToEdge,
        ),
      );
    });
  }

  Future<void> _requestOrientation(Orientation orientation) async {
    _hideControlsTimer?.cancel();
    if (orientation == Orientation.landscape) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    }
    _showControls();
  }

  Future<void> _handleBack(Orientation orientation) async {
    if (orientation == Orientation.landscape) {
      await _requestOrientation(Orientation.portrait);
      return;
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  void _showControls() {
    if (!mounted || _trialEnded) return;
    setState(() => _controlsVisible = true);
    _scheduleControlsAutoHide();
  }

  void _scheduleControlsAutoHide() {
    _hideControlsTimer?.cancel();
    final controller = _playbackController;
    if (controller == null || !controller.isPlaying || _trialEnded) return;
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  Future<void> _togglePlayback() async {
    final controller = _playbackController;
    if (controller == null) return;
    await controller.togglePlayback();
    _showControls();
  }

  Future<void> _showSpeedPicker() async {
    _hideControlsTimer?.cancel();
    const speeds = <double>[0.5, 0.75, 1, 1.25, 1.5, 2];
    final selected = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '选择倍率',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            for (final speed in speeds)
              ListTile(
                key: ValueKey('course-video-speed-$speed'),
                title: Center(child: Text('${_formatSpeed(speed)}x')),
                trailing: _playbackController?.playbackSpeed == speed
                    ? const Icon(Icons.check_rounded, color: Color(0xFF237DED))
                    : const SizedBox(width: 24),
                onTap: () => Navigator.of(context).pop(speed),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await _playbackController?.setPlaybackSpeed(selected);
    }
    _showControls();
  }

  Future<void> _purchase() async {
    final launcher = widget.onPurchase;
    if (launcher == null || _purchasing || _hasVideoAccess) return;
    if (MediaQuery.orientationOf(context) == Orientation.landscape) {
      await _requestOrientation(Orientation.portrait);
      await Future<void>.delayed(const Duration(milliseconds: 260));
    }
    if (!mounted) return;
    setState(() => _purchasing = true);
    try {
      final unlocked = await launcher();
      if (!mounted || !unlocked) return;
      setState(() {
        _hasVideoAccess = true;
        _trialEnded = false;
        _controlsVisible = true;
      });
      await _playbackController?.play();
      _scheduleControlsAutoHide();
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restartTrial() async {
    final controller = _playbackController;
    if (controller == null) return;
    setState(() {
      _trialEnded = false;
      _controlsVisible = true;
    });
    await controller.seekTo(Duration.zero);
    await controller.play();
    _scheduleControlsAutoHide();
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        _syncSystemUi(orientation);
        final landscape = orientation == Orientation.landscape;
        return PopScope(
          canPop: !landscape,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) unawaited(_handleBack(orientation));
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                if (_playbackController case final controller?)
                  Html5VideoPlayer(
                    key: ValueKey('course-video-player-${widget.media.id}'),
                    item: _playerItem,
                    initialPosition: _initialPosition,
                    controller: controller,
                    showNativeControls: false,
                    fillAvailableSpace: true,
                    contentBuilder: widget.videoContentBuilder,
                    onPositionChanged: _savePosition,
                  )
                else
                  const ColoredBox(color: Colors.black),
                if (!_loading && !_trialEnded)
                  Positioned.fill(
                    top: landscape
                        ? 48.0
                        : MediaQuery.paddingOf(context).top + 48,
                    child: GestureDetector(
                      key: const ValueKey('course-video-touch-layer'),
                      behavior: HitTestBehavior.translucent,
                      onTap: _showControls,
                    ),
                  ),
                _TopBar(
                  title: widget.media.title,
                  landscape: landscape,
                  onBack: () => unawaited(_handleBack(orientation)),
                ),
                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                if (!_loading && _playbackController != null)
                  _buildControls(orientation),
                if (_trialEnded) _buildTrialEndedOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls(Orientation orientation) {
    final bottomPadding = orientation == Orientation.landscape
        ? 12.0
        : math.max(12.0, MediaQuery.paddingOf(context).bottom + 4);
    return Positioned(
      left: 10,
      right: 10,
      bottom: bottomPadding,
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: AnimatedOpacity(
          key: const ValueKey('course-video-controls'),
          opacity: _controlsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_hasVideoAccess) ...[
                _TrialTipBar(onTap: _purchase, purchasing: _purchasing),
                const SizedBox(height: 8),
              ],
              _buildControlBar(orientation),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlBar(Orientation orientation) {
    final controller = _playbackController!;
    final position = _dragPosition ?? controller.position;
    final fullDuration = controller.duration;
    final limit = _hasVideoAccess ? fullDuration : widget.trialDuration;
    final maxMilliseconds = math.max(
      1,
      limit.inMilliseconds > 0 ? limit.inMilliseconds : position.inMilliseconds,
    );
    final value = position.inMilliseconds.clamp(0, maxMilliseconds).toDouble();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _ControlButton(
            key: const ValueKey('course-video-play-pause'),
            icon: controller.isPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            label: controller.isPlaying ? '暂停' : '播放',
            onTap: _togglePlayback,
          ),
          _TimeText(_formatDuration(position)),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                activeTrackColor: const Color(0xFFF1C04E),
                inactiveTrackColor: Colors.white38,
                thumbColor: const Color(0xFFF1C04E),
                overlayColor: const Color(0x33F1C04E),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                key: const ValueKey('course-video-progress'),
                min: 0,
                max: maxMilliseconds.toDouble(),
                value: value,
                onChangeStart: (_) => _hideControlsTimer?.cancel(),
                onChanged: (next) => setState(
                  () => _dragPosition = Duration(milliseconds: next.toInt()),
                ),
                onChangeEnd: (next) async {
                  final target = Duration(milliseconds: next.toInt());
                  setState(() => _dragPosition = null);
                  await controller.seekTo(target);
                  _savePosition(target);
                  _scheduleControlsAutoHide();
                },
              ),
            ),
          ),
          _TimeText(
            _formatDuration(
              fullDuration > Duration.zero ? fullDuration : limit,
            ),
          ),
          _ControlButton(
            key: const ValueKey('course-video-mute'),
            icon: controller.isMuted
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
            label: controller.isMuted ? '静音' : '有声',
            onTap: () async {
              await controller.setMuted(!controller.isMuted);
              _showControls();
            },
          ),
          _ControlButton(
            key: const ValueKey('course-video-speed'),
            icon: Icons.speed_rounded,
            label: controller.playbackSpeed == 1
                ? '倍率'
                : '${_formatSpeed(controller.playbackSpeed)}x',
            onTap: _showSpeedPicker,
          ),
          _ControlButton(
            key: const ValueKey('course-video-orientation'),
            icon: orientation == Orientation.landscape
                ? Icons.stay_current_portrait_rounded
                : Icons.stay_current_landscape_rounded,
            label: orientation == Orientation.landscape ? '竖屏' : '横屏',
            onTap: () => _requestOrientation(
              orientation == Orientation.landscape
                  ? Orientation.portrait
                  : Orientation.landscape,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialEndedOverlay() {
    return ColoredBox(
      key: const ValueKey('course-video-trial-ended'),
      color: const Color(0xCC000000),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '试看结束了\n\n开通会员可永久免费观看',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('course-video-restart-trial'),
                  onPressed: _restartTrial,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重新试看'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                ),
                const SizedBox(width: 20),
                FilledButton(
                  key: const ValueKey('course-video-unlock'),
                  onPressed: _purchasing ? null : _purchase,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF1C04E),
                    foregroundColor: const Color(0xFF222222),
                  ),
                  child: Text(_purchasing ? '处理中…' : '开通会员解锁'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _playbackController?.removeListener(_handlePlaybackChanged);
    _playbackController?.dispose();
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    super.dispose();
  }
}

final class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.landscape,
    required this.onBack,
  });

  final String title;
  final bool landscape;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: landscape ? 0 : MediaQuery.paddingOf(context).top,
      right: 0,
      height: 52,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xB3000000), Color(0x00000000)],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('course-video-back'),
              onPressed: onBack,
              color: Colors.white,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            ),
            Expanded(
              child: Text(
                title,
                key: const ValueKey('course-video-title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

final class _TrialTipBar extends StatelessWidget {
  const _TrialTipBar({required this.onTap, required this.purchasing});

  final VoidCallback onTap;
  final bool purchasing;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('course-video-trial-tip'),
      color: const Color(0xCC000000),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: purchasing ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '试看5分钟，购买会员即可观看所有视频',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 30),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1C04E),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  purchasing ? '处理中…' : '立即购买',
                  style: const TextStyle(
                    color: Color(0xFF222222),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

final class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final FutureOr<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: SizedBox(
        width: 36,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: Colors.white),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              style: const TextStyle(color: Colors.white, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

final class _TimeText extends StatelessWidget {
  const _TimeText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final seconds = math.max(0, duration.inSeconds);
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${remainder.toString().padLeft(2, '0')}';
}

String _formatSpeed(double speed) {
  final fixed = speed.toStringAsFixed(2);
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
