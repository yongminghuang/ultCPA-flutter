import '../main_tabs/main_tabs_models.dart';
import '../network/app_api_client.dart';
import '../storage/legacy_app_state_store.dart';
import 'teacher_course_models.dart';

abstract interface class TeacherCourseDataSource {
  Future<TeacherCourseSession> load(HomeModule module);
}

final class TeacherCourseRepository implements TeacherCourseDataSource {
  const TeacherCourseRepository({
    required AppApiClient api,
    required LegacyAppStateStore stateStore,
  }) : _api = api,
       _stateStore = stateStore;

  final AppApiClient _api;
  final LegacyAppStateStore _stateStore;

  @override
  Future<TeacherCourseSession> load(HomeModule module) async {
    final snapshot = await _stateStore.readAppSnapshot();
    final subject = _text(snapshot['selectedSubject']).trim().isEmpty
        ? '会计实务'
        : _text(snapshot['selectedSubject']).trim();
    final selectedCategory = snapshot['selectedCategory'];
    final selectedLevel = selectedCategory is Map
        ? _text(selectedCategory['level']).trim()
        : '';
    final level = selectedLevel.isNotEmpty
        ? selectedLevel
        : _text(snapshot['selectedLevel']).trim().isEmpty
        ? '1'
        : _text(snapshot['selectedLevel']).trim();
    final ossDomain = _text(snapshot['ossDomain']).trim();
    final body = await _api.postBody('/app/tempMedia/query', {
      'subject': subject,
      'level': level,
      'showOnHome': '1',
    });
    if (body is! List) throw const FormatException('课程响应不是数组');
    final items = <TeacherCourseItem>[];
    for (var index = 0; index < body.length; index++) {
      final raw = body[index];
      if (raw is! Map) throw const FormatException('课程条目不是对象');
      final map = Map<String, dynamic>.from(raw);
      final id = _int(map['id']);
      final mediaUrl = _resolveUrl(
        _firstText(map, const ['mediaUrl', 'videoUrl', 'url']),
        ossDomain,
      );
      items.add(
        TeacherCourseItem(
          id: id > 0 ? id : index + 1,
          subject: _text(map['subject']).trim().isEmpty
              ? subject
              : _text(map['subject']).trim(),
          courseType: _text(map['courseType']).trim(),
          title: _firstText(map, const ['title', 'courseTitle']).trim().isEmpty
              ? '课程${index + 1}'
              : _firstText(map, const ['title', 'courseTitle']).trim(),
          coverUrl: _resolveUrl(
            _firstText(map, const ['coverUrl', 'videoCoverUrl', 'cover']),
            ossDomain,
          ),
          mediaUrl: mediaUrl,
        ),
      );
    }
    return TeacherCourseSession(module: module, subject: subject, items: items);
  }
}

String _firstText(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = _text(map[key]).trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _resolveUrl(String value, String domain) {
  final text = value.trim();
  if (text.isEmpty) return '';
  final uri = Uri.tryParse(text);
  if (uri?.hasScheme == true) return text;
  if (domain.isEmpty) return text;
  return '${domain.replaceFirst(RegExp(r'/$'), '')}/${text.replaceFirst(RegExp(r'^/'), '')}';
}

String _text(Object? value) => value?.toString() ?? '';

int _int(Object? value) {
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? 0;
}
