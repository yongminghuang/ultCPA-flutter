import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/teacher_course/course_video_player_page.dart';
import 'package:ultcpa_flutter/src/teacher_course/teacher_course_progress_store.dart';

void main() {
  testWidgets('restores progress and exposes Android-style portrait controls', (
    tester,
  ) async {
    await _usePortraitSurface(tester);
    final store = MemoryTeacherCourseProgressStore();
    await store.writeMediaPosition(7, const Duration(seconds: 18));

    await tester.pumpWidget(_app(store: store));
    await tester.pumpAndSettle();

    expect(find.text('名师技巧课'), findsOneWidget);
    expect(find.text('player:7:18'), findsOneWidget);
    expect(find.text('试看5分钟，购买会员即可观看所有视频'), findsOneWidget);
    expect(find.text('横屏'), findsOneWidget);
    expect(find.text('暂停'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('course-video-play-pause')));
    await tester.pump();
    expect(find.text('播放'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'uses the landscape control variant and hides the trial CTA for VIP',
    (tester) async {
      await _useLandscapeSurface(tester);

      await tester.pumpWidget(
        _app(store: MemoryTeacherCourseProgressStore(), hasVideoAccess: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('竖屏'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('course-video-trial-tip')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('shows the five-minute stop overlay and unlocks after purchase', (
    tester,
  ) async {
    await _usePortraitSurface(tester);
    final store = MemoryTeacherCourseProgressStore();
    await store.writeMediaPosition(7, const Duration(minutes: 5));
    var purchaseCalls = 0;

    await tester.pumpWidget(
      _app(
        store: store,
        onPurchase: () async {
          purchaseCalls += 1;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('course-video-trial-ended')),
      findsOneWidget,
    );
    expect(find.textContaining('试看结束了'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('course-video-unlock')));
    await tester.pumpAndSettle();

    expect(purchaseCalls, 1);
    expect(
      find.byKey(const ValueKey('course-video-trial-ended')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('course-video-trial-tip')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _usePortraitSurface(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 800);
  addTearDown(tester.view.reset);
}

Future<void> _useLandscapeSurface(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 500);
  addTearDown(tester.view.reset);
}

Widget _app({
  required TeacherCourseProgressStore store,
  bool hasVideoAccess = false,
  CourseVideoPurchaseLauncher? onPurchase,
}) {
  return MaterialApp(
    home: CourseVideoPlayerPage(
      media: _media,
      progressStore: store,
      hasVideoAccess: hasVideoAccess,
      onPurchase: onPurchase,
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

const _media = CourseMedia(
  id: 7,
  subject: '会计实务',
  courseType: '大招精讲',
  title: '名师技巧课',
  coverUrl: '',
  mediaUrl: 'https://example.com/teacher.mp4',
);
