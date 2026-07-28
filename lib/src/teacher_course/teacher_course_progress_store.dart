import 'package:flutter/services.dart';

abstract interface class TeacherCourseProgressStore {
  Future<int> readCourseIndex(String subject);

  Future<void> writeCourseIndex(String subject, int index);

  Future<Duration> readMediaPosition(int mediaId);

  Future<void> writeMediaPosition(int mediaId, Duration position);
}

final class MethodChannelTeacherCourseProgressStore
    implements TeacherCourseProgressStore {
  MethodChannelTeacherCourseProgressStore({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.xmzj.ult.agg/legacy_startup');

  final MethodChannel _channel;

  @override
  Future<int> readCourseIndex(String subject) async {
    try {
      return await _channel.invokeMethod<int>('readTeacherCourseIndex', {
            'subject': subject,
          }) ??
          0;
    } on PlatformException {
      return 0;
    } on MissingPluginException {
      return 0;
    }
  }

  @override
  Future<void> writeCourseIndex(String subject, int index) async {
    try {
      await _channel.invokeMethod<void>('writeTeacherCourseIndex', {
        'subject': subject,
        'index': index,
      });
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  @override
  Future<Duration> readMediaPosition(int mediaId) async {
    try {
      final milliseconds =
          await _channel.invokeMethod<int>('readTeacherCoursePosition', {
            'mediaId': mediaId,
          }) ??
          0;
      return Duration(milliseconds: milliseconds.clamp(0, 1 << 31).toInt());
    } on PlatformException {
      return Duration.zero;
    } on MissingPluginException {
      return Duration.zero;
    }
  }

  @override
  Future<void> writeMediaPosition(int mediaId, Duration position) async {
    try {
      await _channel.invokeMethod<void>('writeTeacherCoursePosition', {
        'mediaId': mediaId,
        'milliseconds': position.inMilliseconds.clamp(0, 1 << 31).toInt(),
      });
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}

final class MemoryTeacherCourseProgressStore
    implements TeacherCourseProgressStore {
  final Map<String, int> _indices = {};
  final Map<int, Duration> _positions = {};

  @override
  Future<int> readCourseIndex(String subject) async => _indices[subject] ?? 0;

  @override
  Future<void> writeCourseIndex(String subject, int index) async {
    _indices[subject] = index;
  }

  @override
  Future<Duration> readMediaPosition(int mediaId) async {
    return _positions[mediaId] ?? Duration.zero;
  }

  @override
  Future<void> writeMediaPosition(int mediaId, Duration position) async {
    _positions[mediaId] = position;
  }
}
