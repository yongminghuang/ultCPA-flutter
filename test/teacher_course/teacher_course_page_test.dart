import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/teacher_course/teacher_course_models.dart';
import 'package:ultcpa_flutter/src/teacher_course/teacher_course_page.dart';
import 'package:ultcpa_flutter/src/teacher_course/teacher_course_progress_store.dart';
import 'package:ultcpa_flutter/src/teacher_course/teacher_course_repository.dart';

void main() {
  testWidgets('restores the selected course and switches without a pay CTA', (
    tester,
  ) async {
    final store = MemoryTeacherCourseProgressStore();
    await store.writeCourseIndex('会计实务', 1);
    await store.writeMediaPosition(2, const Duration(seconds: 18));
    final source = _Source(_session(_items));

    await tester.pumpWidget(_app(source: source, store: store));
    await tester.pumpAndSettle();

    expect(find.text('首页免费课程'), findsOneWidget);
    expect(find.text('第二课'), findsWidgets);
    expect(
      find.byKey(const ValueKey('teacher-course-current-title')),
      findsOneWidget,
    );
    expect(find.textContaining('开通'), findsNothing);
    expect(find.textContaining('付费'), findsNothing);
    expect(find.text('player:2:18'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('teacher-course-item-1')));
    await tester.pumpAndSettle();

    expect(find.text('player:1:0'), findsOneWidget);
    expect(await store.readCourseIndex('会计实务'), 0);
  });

  testWidgets('shows empty and retry states', (tester) async {
    final source = _Source(_session(const []));
    await tester.pumpWidget(
      _app(source: source, store: MemoryTeacherCourseProgressStore()),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无视频'), findsOneWidget);
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();
    expect(source.calls, 2);
  });

  testWidgets('shows load failures and retries', (tester) async {
    final source = _Source(_session(const []), error: StateError('offline'));
    await tester.pumpWidget(
      _app(source: source, store: MemoryTeacherCourseProgressStore()),
    );
    await tester.pumpAndSettle();

    expect(find.text('课程数据加载失败'), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);
  });
}

const _module = HomeModule(id: 23, name: '技巧讲解', page: '技巧讲解', tag: '');

const _items = [
  TeacherCourseItem(
    id: 1,
    subject: '会计实务',
    courseType: '',
    title: '第一课',
    coverUrl: '',
    mediaUrl: 'https://example.com/1.mp4',
  ),
  TeacherCourseItem(
    id: 2,
    subject: '会计实务',
    courseType: '',
    title: '第二课',
    coverUrl: '',
    mediaUrl: 'https://example.com/2.m3u8',
  ),
];

TeacherCourseSession _session(List<TeacherCourseItem> items) {
  return TeacherCourseSession(module: _module, subject: '会计实务', items: items);
}

Widget _app({
  required TeacherCourseDataSource source,
  required TeacherCourseProgressStore store,
}) {
  return MaterialApp(
    home: TeacherCoursePage(
      module: _module,
      dataSource: source,
      progressStore: store,
      videoContentBuilder: (context, item, position) => ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'player:${item.id}:${position.inSeconds}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    ),
  );
}

final class _Source implements TeacherCourseDataSource {
  _Source(this.session, {this.error});

  final TeacherCourseSession session;
  final Object? error;
  int calls = 0;

  @override
  Future<TeacherCourseSession> load(HomeModule module) async {
    calls += 1;
    if (error case final Object value) throw value;
    return session;
  }
}
