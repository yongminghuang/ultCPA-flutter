import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';
import 'package:ultcpa_flutter/src/storage/legacy_app_state_store.dart';
import 'package:ultcpa_flutter/src/teacher_course/teacher_course_repository.dart';

void main() {
  const module = HomeModule(id: 23, name: '技巧讲解', page: '技巧讲解', tag: '');

  test('loads the Android Home free-play course contract', () async {
    final api = _Api([
      {
        'id': 7,
        'subject': '经济法基础',
        'courseType': '大招精讲',
        'title': '票据法快速记忆',
        'coverUrl': '/covers/7.jpg',
        'mediaUrl': '/videos/7.m3u8',
      },
      {
        'id': '8',
        'courseTitle': '默认标题字段',
        'videoCoverUrl': 'https://cdn.example.com/8.jpg',
        'videoUrl': 'https://cdn.example.com/8.mp4',
      },
    ]);
    final repository = TeacherCourseRepository(
      api: api,
      stateStore: _Store({
        'selectedSubject': '经济法基础',
        'selectedLevel': '初级会计',
        'selectedCategory': {'level': '初级会计'},
        'ossDomain': 'https://oss.example.com/',
      }),
    );

    final session = await repository.load(module);

    expect(api.paths, ['/app/tempMedia/query']);
    expect(api.bodies.single, {
      'subject': '经济法基础',
      'level': '初级会计',
      'showOnHome': '1',
    });
    expect(api.bodies.single, isNot(contains('courseType')));
    expect(session.module, same(module));
    expect(session.subject, '经济法基础');
    expect(session.items, hasLength(2));
    expect(
      session.items.first.mediaUrl,
      'https://oss.example.com/videos/7.m3u8',
    );
    expect(
      session.items.first.coverUrl,
      'https://oss.example.com/covers/7.jpg',
    );
    expect(session.items.last.title, '默认标题字段');
    expect(session.items.last.mediaUrl, 'https://cdn.example.com/8.mp4');
  });

  test(
    'uses Android subject and level fallbacks and rejects non-list data',
    () async {
      final api = _Api({'id': 1});
      final repository = TeacherCourseRepository(
        api: api,
        stateStore: _Store(const {}),
      );

      await expectLater(repository.load(module), throwsFormatException);
      expect(api.bodies.single, {
        'subject': '会计实务',
        'level': '1',
        'showOnHome': '1',
      });
    },
  );
}

final class _Api implements AppApiClient {
  _Api(this.response);

  final Object? response;
  final paths = <String>[];
  final bodies = <Map<String, dynamic>>[];

  @override
  Future<Object?> getBody(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) => throw UnimplementedError();

  @override
  Future<Object?> postBody(String path, Map<String, dynamic> body) async {
    paths.add(path);
    bodies.add(Map<String, dynamic>.from(body));
    return response;
  }
}

final class _Store implements LegacyAppStateStore {
  _Store(this.snapshot);

  final Map<String, dynamic> snapshot;

  @override
  Future<Map<String, dynamic>> readAppSnapshot() async => snapshot;

  @override
  Future<void> persistCategorySelection({
    required String categoryBodyJson,
    required String category,
    required Map<String, dynamic> selectedCategory,
    required String selectedCategoryKey,
    required int marketId,
    required String subject,
  }) => throw UnimplementedError();
}
