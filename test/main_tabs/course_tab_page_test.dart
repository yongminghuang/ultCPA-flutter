import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/course_tab_page.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_repository.dart';

void main() {
  testWidgets('初级课程默认技巧密押，并可切换课程类型', (tester) async {
    final dataSource = _DataSource();

    await tester.pumpWidget(
      MaterialApp(home: CourseTabPage(dataSource: dataSource)),
    );
    await tester.pumpAndSettle();

    expect(find.text('跟名师学习'), findsOneWidget);
    expect(find.text('技巧精讲'), findsOneWidget);
    expect(find.text('技巧密押'), findsOneWidget);
    expect(find.text('技巧急救'), findsOneWidget);
    expect(find.text('技巧密押课程'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('course-type-selected-secret')),
      findsOneWidget,
    );
    expect(dataSource.requestedTypes, [CourseType.secret]);

    await tester.tap(find.text('技巧精讲'));
    await tester.pumpAndSettle();

    expect(find.text('技巧精讲课程'), findsOneWidget);
    expect(dataSource.requestedTypes, [
      CourseType.secret,
      CourseType.intensive,
    ]);
  });

  testWidgets('中级课程默认技巧精讲，并锁定技巧急救', (tester) async {
    final dataSource = _DataSource(categoryLabel: '中级会计');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CourseTabPage(dataSource: dataSource)),
      ),
    );
    await tester.pumpAndSettle();

    expect(dataSource.requestedTypes, [
      CourseType.secret,
      CourseType.intensive,
    ]);
    expect(find.text('技巧精讲课程'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('course-type-lock-emergency')),
      findsOneWidget,
    );

    await tester.tap(find.text('技巧急救'));
    await tester.pump();

    expect(find.text('课程未开始'), findsOneWidget);
    expect(dataSource.requestedTypes, [
      CourseType.secret,
      CourseType.intensive,
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
    await tester.tap(find.text('技巧精讲'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTabPage(dataSource: dataSource, selectionRevision: 1),
      ),
    );
    await tester.pumpAndSettle();

    expect(dataSource.requestedTypes, [
      CourseType.secret,
      CourseType.intensive,
      CourseType.intensive,
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

  testWidgets('课程卡片复刻 Android 尺寸与进入学习按钮', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CourseTabPage(dataSource: _DataSource())),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('course-cover-1'))),
      const Size(130, 85),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('course-enter-study-1'))).height,
      28,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('course-media-1'))).height,
      109,
    );
    expect(find.text('进入学习'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
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

    await tester.tap(find.byKey(const ValueKey('course-enter-study-1')));
    await tester.pump();

    expect(launchedMedia?.title, '技巧密押课程');
    expect(launchedData?.courseType, CourseType.secret);
  });

  testWidgets('直播日历只显示今天及未来场次', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CourseTabPage(
          dataSource: _DataSource(),
          now: () => DateTime(2026, 4, 14),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('直播日历'), findsOneWidget);
    expect(find.text('04.15'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTabPage(
          dataSource: _DataSource(),
          now: () => DateTime(2026, 7, 30),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('直播日历'), findsNothing);
  });
}

final class _DataSource implements MainTabsDataSource {
  _DataSource({this.categoryLabel = '初级会计'});

  final String categoryLabel;
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
      categoryLabel: categoryLabel,
      subjects: _subjects,
      selectedSubject: _subjects.first,
      courseType: courseType,
      items: [
        CourseMedia(
          id: 1,
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
  CategorySubject(id: 1023, name: '会计实务'),
  CategorySubject(id: 1024, name: '经济法基础'),
];
