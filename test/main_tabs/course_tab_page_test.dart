import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/course_tab_page.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_repository.dart';

void main() {
  testWidgets('reloads real course data when the Android course type changes', (
    tester,
  ) async {
    final dataSource = _DataSource();

    await tester.pumpWidget(
      MaterialApp(home: CourseTabPage(dataSource: dataSource)),
    );
    await tester.pumpAndSettle();

    expect(find.text('跟名师学习'), findsOneWidget);
    expect(find.text('技巧精讲'), findsOneWidget);
    expect(find.text('技巧密押'), findsOneWidget);
    expect(find.text('技巧急救'), findsOneWidget);
    expect(find.text('技巧精讲课程'), findsOneWidget);
    expect(dataSource.requestedTypes, [CourseType.intensive]);

    await tester.tap(find.text('技巧密押'));
    await tester.pumpAndSettle();

    expect(find.text('技巧密押课程'), findsOneWidget);
    expect(dataSource.requestedTypes, [
      CourseType.intensive,
      CourseType.secret,
    ]);
  });

  testWidgets('selection revision reloads while preserving course type', (
    tester,
  ) async {
    final dataSource = _DataSource();

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTabPage(dataSource: dataSource, selectionRevision: 0),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('技巧密押'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTabPage(dataSource: dataSource, selectionRevision: 1),
      ),
    );
    await tester.pumpAndSettle();

    expect(dataSource.requestedTypes, [
      CourseType.intensive,
      CourseType.secret,
      CourseType.secret,
    ]);
    expect(dataSource.requestedSubjects.last, isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTabPage(dataSource: dataSource, selectionRevision: 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(dataSource.requestedTypes, hasLength(3));
  });

  testWidgets('opens the tapped teacher course in the media launcher', (
    tester,
  ) async {
    CourseMedia? launchedMedia;
    CourseTabData? launchedData;
    await tester.pumpWidget(
      MaterialApp(
        home: CourseTabPage(
          dataSource: _DataSource(),
          mediaLauncher: (context, media, data) async {
            launchedMedia = media;
            launchedData = data;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('course-media-1')));
    await tester.pump();

    expect(launchedMedia?.title, '技巧精讲课程');
    expect(launchedData?.courseType, CourseType.intensive);
  });
}

final class _DataSource implements MainTabsDataSource {
  final List<CourseType> requestedTypes = [];
  final List<String?> requestedSubjects = [];

  @override
  Future<CourseTabData> loadCourses({
    required CourseType courseType,
    String? subject,
  }) async {
    requestedTypes.add(courseType);
    requestedSubjects.add(subject);
    return CourseTabData(
      categoryLabel: '初级社工',
      subjects: _subjects,
      selectedSubject: _subjects.first,
      courseType: courseType,
      items: [
        CourseMedia(
          id: requestedTypes.length,
          subject: _subjects.first.name,
          courseType: courseType.apiValue,
          title: '${courseType.label}课程',
          coverUrl: '',
          mediaUrl: '',
        ),
      ],
    );
  }

  @override
  Future<HomeTabData> loadHome({
    String? preferredCategoryKey,
    int? preferredSubjectId,
  }) => throw UnimplementedError();

  @override
  Future<MineTabData> loadMine() => throw UnimplementedError();
}

const _subjects = [
  CategorySubject(id: 1023, name: '社工实务'),
  CategorySubject(id: 1024, name: '综合能力'),
];
