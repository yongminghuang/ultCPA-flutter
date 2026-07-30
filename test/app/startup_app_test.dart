import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/account_profile/account_profile_data_source.dart';
import 'package:ultcpa_flutter/src/account_profile/account_profile_models.dart';
import 'package:ultcpa_flutter/src/account_profile/account_profile_page.dart';
import 'package:ultcpa_flutter/src/account_safety/account_deactivation_page.dart';
import 'package:ultcpa_flutter/src/account_safety/account_safety_data_source.dart';
import 'package:ultcpa_flutter/src/account_safety/account_safety_models.dart';
import 'package:ultcpa_flutter/src/account_safety/account_safety_page.dart';
import 'package:ultcpa_flutter/src/app_update/app_update_dialog.dart';
import 'package:ultcpa_flutter/src/app_update/app_update_file_transfer.dart';
import 'package:ultcpa_flutter/src/app_update/app_update_models.dart';
import 'package:ultcpa_flutter/src/app_update/app_update_repository.dart';
import 'package:ultcpa_flutter/src/app/startup_app.dart';
import 'package:ultcpa_flutter/src/authentication/phone_login_page.dart';
import 'package:ultcpa_flutter/src/chapter_practice/chapter_practice_models.dart';
import 'package:ultcpa_flutter/src/chapter_practice/chapter_practice_page.dart';
import 'package:ultcpa_flutter/src/chapter_practice/chapter_practice_progress_store.dart';
import 'package:ultcpa_flutter/src/chapter_practice/chapter_practice_repository.dart';
import 'package:ultcpa_flutter/src/customer_service/customer_service_data_source.dart';
import 'package:ultcpa_flutter/src/customer_service/customer_service_launcher.dart';
import 'package:ultcpa_flutter/src/daily_skill/daily_skill_detail_page.dart';
import 'package:ultcpa_flutter/src/daily_skill/daily_skill_models.dart';
import 'package:ultcpa_flutter/src/daily_skill/daily_skill_progress_store.dart';
import 'package:ultcpa_flutter/src/daily_skill/daily_skill_report_page.dart';
import 'package:ultcpa_flutter/src/daily_skill/daily_skill_repository.dart';
import 'package:ultcpa_flutter/src/fast_practice/fast_practice_catalog_page.dart';
import 'package:ultcpa_flutter/src/fast_practice/fast_practice_entry_page.dart';
import 'package:ultcpa_flutter/src/fast_practice/fast_practice_landing_page.dart';
import 'package:ultcpa_flutter/src/fast_practice/fast_practice_models.dart';
import 'package:ultcpa_flutter/src/fast_practice/fast_practice_repository.dart';
import 'package:ultcpa_flutter/src/exam/exam_models.dart';
import 'package:ultcpa_flutter/src/exam/exam_page.dart';
import 'package:ultcpa_flutter/src/exam/exam_repository.dart';
import 'package:ultcpa_flutter/src/exam/exam_result_page.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_page.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_repository.dart';
import 'package:ultcpa_flutter/src/practice/practice_models.dart';
import 'package:ultcpa_flutter/src/practice/flat_practice_progress_store.dart';
import 'package:ultcpa_flutter/src/practice/practice_page.dart';
import 'package:ultcpa_flutter/src/practice/practice_repository.dart';
import 'package:ultcpa_flutter/src/past_exams/past_exams_models.dart';
import 'package:ultcpa_flutter/src/past_exams/past_exams_page.dart';
import 'package:ultcpa_flutter/src/past_exams/past_exams_repository.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_entry_page.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_file_transfer.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_landing_page.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_models.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_preview_page.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_repository.dart';
import 'package:ultcpa_flutter/src/pre_exam_secret_paper/pre_exam_secret_paper_models.dart';
import 'package:ultcpa_flutter/src/pre_exam_secret_paper/pre_exam_secret_paper_page.dart';
import 'package:ultcpa_flutter/src/pre_exam_secret_paper/pre_exam_secret_paper_repository.dart';
import 'package:ultcpa_flutter/src/purchase_history/purchase_history_data_source.dart';
import 'package:ultcpa_flutter/src/purchase_history/purchase_history_models.dart';
import 'package:ultcpa_flutter/src/purchase_history/purchase_history_page.dart';
import 'package:ultcpa_flutter/src/settings/privacy_settings_page.dart';
import 'package:ultcpa_flutter/src/settings/settings_data_source.dart';
import 'package:ultcpa_flutter/src/settings/settings_models.dart';
import 'package:ultcpa_flutter/src/settings/settings_page.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_detail_page.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_models.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_page.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_repository.dart';
import 'package:ultcpa_flutter/src/smart_card/smart_card_entry_page.dart';
import 'package:ultcpa_flutter/src/smart_card/smart_card_models.dart';
import 'package:ultcpa_flutter/src/smart_card/smart_card_page.dart';
import 'package:ultcpa_flutter/src/smart_card/smart_card_repository.dart';
import 'package:ultcpa_flutter/src/startup/privacy_consent_dialog.dart';
import 'package:ultcpa_flutter/src/startup/startup_coordinator.dart';
import 'package:ultcpa_flutter/src/startup/startup_splash_page.dart';
import 'package:ultcpa_flutter/src/teacher_course/teacher_course_models.dart';
import 'package:ultcpa_flutter/src/teacher_course/course_video_player_page.dart';
import 'package:ultcpa_flutter/src/teacher_course/teacher_course_page.dart';
import 'package:ultcpa_flutter/src/teacher_course/teacher_course_progress_store.dart';
import 'package:ultcpa_flutter/src/teacher_course/teacher_course_repository.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_payment_gateway.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_pay_sheet.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_models.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_page.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_repository.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_success_page.dart';
import 'package:ultcpa_flutter/src/web/agreement_webview_page.dart';
import 'package:ultcpa_flutter/src/web/legacy_webview_page.dart';

void main() {
  testWidgets('starts on the real splash without a debug banner', (
    tester,
  ) async {
    final initializer = _Initializer();
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: initializer,
        delay: (_) async {},
        mainTabsDataSource: _DataSource(),
      ),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.routes, contains(PhoneLoginPage.routeName));
    expect(find.byType(StartupSplashPage), findsNothing);
    expect(find.byType(MainTabsPage), findsOneWidget);
    expect(initializer.calls, 1);
  });

  testWidgets('shows privacy consent over the splash for legacy opt-out', (
    tester,
  ) async {
    final store = _ConsentStore(false);
    final initializer = _Initializer();
    await tester.pumpWidget(
      StartupApp(
        consentStore: store,
        initializer: initializer,
        delay: (_) async {},
        mainTabsDataSource: _DataSource(),
      ),
    );
    await tester.pump();

    expect(find.byType(StartupSplashPage), findsOneWidget);
    expect(find.byType(PrivacyConsentDialog), findsOneWidget);

    await tester.tap(find.text('同意'));
    await tester.pumpAndSettle();

    expect(store.accepted, isTrue);
    expect(initializer.calls, 1);
    expect(find.byType(PrivacyConsentDialog), findsNothing);
  });

  testWidgets('shows a retry action when real startup initialization fails', (
    tester,
  ) async {
    final initializer = _Initializer(failOnce: true);
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: initializer,
        delay: (_) async {},
        mainTabsDataSource: _DataSource(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('网络错误，请检查网络后重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(initializer.calls, 2);
    expect(find.text('网络错误，请检查网络后重试'), findsNothing);
  });

  testWidgets('opens startup agreements inside the app', (tester) async {
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(false),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(),
        agreementContentBuilder: (context, uri) => Text('CONTENT:$uri'),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('privacy-policy-link')));
    await tester.pumpAndSettle();

    expect(find.byType(AgreementWebViewPage), findsOneWidget);
    expect(find.text('隐私政策'), findsOneWidget);
    expect(
      find.text('CONTENT:https://img.jx885.com/pass-license/html/privacy.html'),
      findsOneWidget,
    );
  });

  testWidgets('opens the real mnemonic list and detail from a home module', (
    tester,
  ) async {
    final mnemonicSource = _MnemonicDataSource();
    final practiceSource = _PracticeDataSource();
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(
          _routingHome(
            const HomeModule(id: 42, name: '技巧口诀', page: '技巧口诀', tag: 'hot'),
          ),
        ),
        skillMnemonicsDataSource: mnemonicSource,
        practiceDataSource: practiceSource,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-42')));
    await tester.pumpAndSettle();

    expect(find.byType(SkillMnemonicsPage), findsOneWidget);
    expect(mnemonicSource.modules.single.id, 42);
    expect(find.text('看到必须先排除', findRichText: true), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mnemonic-row-0')));
    await tester.pumpAndSettle();

    expect(find.byType(SkillMnemonicsDetailPage), findsOneWidget);
    expect(find.text('技巧记忆'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mnemonic-practice-action')));
    await tester.pumpAndSettle();

    expect(find.byType(PracticePage), findsOneWidget);
    final request = practiceSource.requests.single as SkillPracticeRequest;
    expect(request.skillId, '11');
    expect(request.position, 0);
    expect(request.module?.id, 42);
  });

  testWidgets(
    'opens the Home free teacher course instead of a migration message',
    (tester) async {
      const module = HomeModule(id: 55, name: '技巧讲解', page: '技巧讲解', tag: '');
      final source = _TeacherCourseDataSource(
        TeacherCourseSession(
          module: module,
          subject: '会计实务',
          items: const [
            TeacherCourseItem(
              id: 901,
              subject: '会计实务',
              courseType: '',
              title: '首页免费技巧课',
              coverUrl: '',
              mediaUrl: 'https://example.com/course.mp4',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        StartupApp(
          consentStore: _ConsentStore(true),
          initializer: _Initializer(),
          delay: (_) async {},
          mainTabsDataSource: _DataSource(_routingHome(module)),
          teacherCourseDataSource: source,
          teacherCourseProgressStore: MemoryTeacherCourseProgressStore(),
          teacherCourseVideoContentBuilder: (_, item, position) => ColoredBox(
            color: Colors.black,
            child: Text('COURSE:${item.id}:${position.inSeconds}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-module-55')));
      await tester.pumpAndSettle();

      expect(find.byType(TeacherCoursePage), findsOneWidget);
      expect(find.text('首页免费技巧课'), findsWidgets);
      expect(find.text('COURSE:901:0'), findsOneWidget);
      expect(find.text('技巧讲解功能仍在迁移中'), findsNothing);
      expect(source.modules, [module]);
    },
  );

  testWidgets('opens a teacher course video from the Course tab', (
    tester,
  ) async {
    final dataSource = _DataSource()
      ..courseData = const CourseTabData(
        categoryLabel: '初级社工',
        subjects: _subjects,
        selectedSubject: CategorySubject(id: 1023, name: '社工实务'),
        courseType: CourseType.intensive,
        items: [
          CourseMedia(
            id: 902,
            subject: '社工实务',
            courseType: '大招精讲',
            title: '名师技巧精讲',
            coverUrl: '',
            mediaUrl: 'https://example.com/course.mp4',
          ),
        ],
        isLoggedIn: true,
        hasVideoAccess: true,
      );
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: dataSource,
        teacherCourseProgressStore: MemoryTeacherCourseProgressStore(),
        teacherCourseVideoContentBuilder: (_, item, position) => ColoredBox(
          color: Colors.black,
          child: Text('COURSE-PLAYER:${item.id}:${position.inSeconds}'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('技巧课程'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('course-media-902')));
    await tester.pumpAndSettle();

    expect(find.byType(CourseVideoPlayerPage), findsOneWidget);
    expect(find.text('名师技巧精讲'), findsOneWidget);
    expect(find.text('COURSE-PLAYER:902:0'), findsOneWidget);
  });

  testWidgets('opens module practice from the ready home destination', (
    tester,
  ) async {
    final practiceSource = _PracticeDataSource();
    const module = HomeModule(
      id: 45,
      name: '技巧练题',
      page: '技巧练题',
      tag: 'hot',
      type: '结构化',
    );
    const circleModule = HomeModule(
      id: 46,
      name: '技巧圈题卷',
      page: '技巧圈题卷',
      tag: '',
      type: '结构化',
    );
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(
          _routingHome(module, bigSkillCircleModule: circleModule),
        ),
        skillMnemonicsDataSource: _MnemonicDataSource(),
        practiceDataSource: practiceSource,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-45')));
    await tester.pumpAndSettle();

    expect(find.byType(PracticePage), findsOneWidget);
    final request = practiceSource.requests.single as ModulePracticeRequest;
    expect(request.module.id, 45);
    expect(request.module.type, '结构化');
    expect(request.bigSkillCircleModule, same(circleModule));
  });

  testWidgets('opens the chapter catalog from its ready home destination', (
    tester,
  ) async {
    final chapterSource = _ChapterDataSource();
    final practiceSource = _PracticeDataSource();
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(
          _routingHome(
            const HomeModule(
              id: 43,
              name: '章节练习',
              page: '章节练习',
              tag: '',
              type: '结构化',
            ),
          ),
        ),
        skillMnemonicsDataSource: _MnemonicDataSource(),
        chapterPracticeDataSource: chapterSource,
        chapterPracticeProgressStore:
            const DisabledChapterPracticeProgressStore(),
        practiceDataSource: practiceSource,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-43')));
    await tester.pumpAndSettle();

    expect(find.byType(ChapterPracticePage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chapter-practice-empty')),
      findsOneWidget,
    );
    expect(chapterSource.modules.single.id, 43);
    expect(chapterSource.modules.single.type, '结构化');
    expect(find.text('章节练习功能仍在迁移中'), findsNothing);
    expect(practiceSource.requests, isEmpty);
  });

  testWidgets('opens fast practice with shared runner and flat progress', (
    tester,
  ) async {
    final fastSource = _FastPracticeDataSource();
    final flatProgress = _FlatProgressStore();
    final practiceSource = _PracticeDataSource(
      catalog: PracticeCatalog(
        items: [
          PracticeQuestionItem(
            PracticeQuestion.fromMap(const {
              'questionId': '101',
              'title': '速成题目',
              'questionType': '单选题',
              'options': {'A': '正确', 'B': '错误'},
              'answer': 'A',
            }),
          ),
        ],
        access: const PracticeAccess(fullAccess: true, freeQuestionCount: 0),
        title: '精选一',
      ),
    );
    const module = HomeModule(
      id: 48,
      name: '速成300题',
      page: '速成300题',
      tag: 'hot',
    );

    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(module)),
        skillMnemonicsDataSource: _MnemonicDataSource(),
        fastPracticeDataSource: fastSource,
        flatPracticeProgressStore: flatProgress,
        practiceDataSource: practiceSource,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-48')));
    await tester.pumpAndSettle();

    expect(find.byType(FastPracticeEntryPage), findsOneWidget);
    expect(find.byType(FastPracticeCatalogPage), findsOneWidget);
    expect(fastSource.resolvedModules, [module]);
    expect(fastSource.loadedModules, [module]);

    await tester.tap(find.byKey(const ValueKey('fast-practice-leaf-111')));
    await tester.pumpAndSettle();

    expect(find.byType(PracticePage), findsOneWidget);
    final request = practiceSource.requests.single as FastPracticeRequest;
    expect(request.module, module);
    expect(request.shelfId, 111);
    expect(request.shelfName, '精选一');
    expect(request.shelfType, '扁平化');
    expect(flatProgress.loadedShelfIds, [111]);
  });

  testWidgets('opens pre-exam six-paper with shared injected dependencies', (
    tester,
  ) async {
    const file = PreExamSixPaperFile(
      name: '考前重点',
      text: '<p>预取内容</p>',
      textUrl: '',
      fileUrl: 'https://cdn.example.com/a.pdf',
      htmlBaseUrl: 'https://cdn.example.com/',
    );
    final source = _PreExamSixPaperDataSource(
      const PreExamSixPaperEntry(
        PreExamSixPaperEntryDestination.preview,
        file: file,
      ),
    );
    final transfer = _PreExamSixPaperTransfer();

    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(_preExamSixPaperModule)),
        skillMnemonicsDataSource: _MnemonicDataSource(),
        preExamSixPaperDataSource: source,
        preExamSixPaperFileTransfer: transfer,
        preExamSixPaperContentBuilder:
            (context, {required url, required html, required baseUrl}) {
              return Text('SIX-PAPER:$baseUrl:${html != null}');
            },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-49')));
    await tester.pumpAndSettle();

    expect(find.byType(PreExamSixPaperEntryPage), findsOneWidget);
    expect(find.byType(PreExamSixPaperPreviewPage), findsOneWidget);
    expect(
      find.text('SIX-PAPER:https://cdn.example.com/:true'),
      findsOneWidget,
    );
    expect(source.resolvedModules, [_preExamSixPaperModule]);
    expect(source.loadedModules, isEmpty);
    final preview = tester.widget<PreExamSixPaperPreviewPage>(
      find.byType(PreExamSixPaperPreviewPage),
    );
    expect(preview.dataSource, same(source));
    expect(preview.fileTransfer, same(transfer));
    expect(preview.initialFile, same(file));
  });

  testWidgets('passes the injected six-paper unlock launcher', (tester) async {
    var unlockCalls = 0;
    final source = _PreExamSixPaperDataSource(
      const PreExamSixPaperEntry(PreExamSixPaperEntryDestination.landing),
    );
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(_preExamSixPaperModule)),
        skillMnemonicsDataSource: _MnemonicDataSource(),
        preExamSixPaperDataSource: source,
        preExamSixPaperFileTransfer: _PreExamSixPaperTransfer(),
        preExamSixPaperUnlockLauncher: () => unlockCalls += 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-49')));
    await tester.pumpAndSettle();
    expect(find.byType(PreExamSixPaperLandingPage), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pre-exam-six-landing-unlock')));
    await tester.pump();
    expect(unlockCalls, 1);
  });

  testWidgets('non-six-paper Home routes never resolve six-paper entry', (
    tester,
  ) async {
    final source = _PreExamSixPaperDataSource(
      const PreExamSixPaperEntry(PreExamSixPaperEntryDestination.empty),
    );
    const module = HomeModule(id: 44, name: '神秘入口', page: 'mystery', tag: '');
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(module)),
        skillMnemonicsDataSource: _MnemonicDataSource(),
        preExamSixPaperDataSource: source,
        preExamSixPaperFileTransfer: _PreExamSixPaperTransfer(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-44')));
    await tester.pump();

    expect(source.resolvedModules, isEmpty);
    expect(source.loadedModules, isEmpty);
    expect(find.byType(PreExamSixPaperEntryPage), findsNothing);
  });

  testWidgets('opens smart cards with clicked module and shared dependencies', (
    tester,
  ) async {
    final catalog = _smartCardCatalog();
    final source = _SmartCardDataSource(
      SmartCardEntry(SmartCardEntryDestination.page, catalog: catalog),
    );
    var unlockCalls = 0;

    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(_smartCardModule)),
        smartCardDataSource: source,
        smartCardUnlockLauncher: () => unlockCalls += 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-51')));
    await tester.pumpAndSettle();

    expect(find.byType(SmartCardEntryPage), findsOneWidget);
    expect(find.byType(SmartCardPage), findsOneWidget);
    expect(source.resolvedRequests, hasLength(1));
    expect(source.resolvedRequests.single.module, same(_smartCardModule));
    expect(source.resolvedRequests.single.shelfId, 0);
    expect(source.loadedRequests, isEmpty);

    final page = tester.widget<SmartCardPage>(find.byType(SmartCardPage));
    expect(page.dataSource, same(source));
    expect(page.request, same(source.resolvedRequests.single));
    expect(page.initialCatalog, same(catalog));

    await tester.tap(find.byKey(const ValueKey('smart-card-unlock')));
    await tester.pump();
    expect(unlockCalls, 1);
  });

  testWidgets('non-card Home routes never resolve a smart-card entry', (
    tester,
  ) async {
    final source = _SmartCardDataSource(
      const SmartCardEntry(SmartCardEntryDestination.empty),
    );
    const module = HomeModule(id: 44, name: '神秘入口', page: 'mystery', tag: '');

    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(module)),
        smartCardDataSource: source,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-44')));
    await tester.pump();

    expect(source.resolvedRequests, isEmpty);
    expect(source.loadedRequests, isEmpty);
    expect(find.byType(SmartCardEntryPage), findsNothing);
  });

  testWidgets('opens a past paper exam and result with shared dependencies', (
    tester,
  ) async {
    final pastSource = _PastExamsDataSource(
      (module) async => PastExamsCatalog(
        module: module,
        hasFullAccess: false,
        papers: const [
          PastExamPaper(id: 901, name: '真题一', type: '扁平化', locked: false),
        ],
      ),
    );
    final examSource = _ExamDataSource();
    var improveCalls = 0;
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(_pastExamsModule)),
        pastExamsDataSource: pastSource,
        examDataSource: examSource,
        examImproveLauncher: (context) => improveCalls += 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-52')));
    await tester.pumpAndSettle();
    expect(find.byType(PastExamsPage), findsOneWidget);
    expect(pastSource.modules, [_pastExamsModule]);
    final pastPage = tester.widget<PastExamsPage>(find.byType(PastExamsPage));
    expect(pastPage.dataSource, same(pastSource));

    await tester.tap(find.byKey(const ValueKey('past-exams-start-0')));
    await tester.pumpAndSettle();
    expect(find.byType(ExamPage), findsOneWidget);
    expect(examSource.loadRequests, hasLength(1));
    final examPage = tester.widget<ExamPage>(find.byType(ExamPage));
    expect(examPage.dataSource, same(examSource));
    expect(examPage.request, same(examSource.loadRequests.single));
    expect(examPage.request.module, same(_pastExamsModule));
    expect(examPage.request.shelfId, 901);
    expect(examPage.request.title, '真题一');

    await tester.tap(find.byKey(const ValueKey('exam-option-A')));
    await tester.tap(find.byKey(const ValueKey('exam-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('exam-confirm-submit')));
    await tester.pumpAndSettle();

    expect(find.byType(ExamResultPage), findsOneWidget);
    expect(examSource.submittedResults, hasLength(1));
    expect(examSource.submittedResults.single.rightCount, 1);
    await tester.tap(find.byKey(const ValueKey('exam-result-improve')));
    await tester.pump();
    expect(improveCalls, 1);
  });

  testWidgets('passes the past-exams unlock callback and reloads access', (
    tester,
  ) async {
    var catalogLoads = 0;
    final pastSource = _PastExamsDataSource((module) async {
      final fullAccess = catalogLoads++ > 0;
      return PastExamsCatalog(
        module: module,
        hasFullAccess: fullAccess,
        papers: [
          for (var index = 0; index < 3; index += 1)
            PastExamPaper(
              id: 901 + index,
              name: '真题 ${index + 1}',
              type: '扁平化',
              locked: !fullAccess && index >= 2,
            ),
        ],
      );
    });
    var unlockCalls = 0;
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(_pastExamsModule)),
        pastExamsDataSource: pastSource,
        examDataSource: _ExamDataSource(),
        pastExamsUnlockLauncher: () => unlockCalls += 1,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-module-52')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('past-exams-unlock-2')));
    await tester.pumpAndSettle();

    expect(unlockCalls, 1);
    expect(pastSource.modules, [_pastExamsModule, _pastExamsModule]);
    expect(find.byKey(const ValueKey('past-exams-start-2')), findsOneWidget);
  });

  testWidgets('opens a secret paper with the shared exam and result path', (
    tester,
  ) async {
    final secretSource = _SecretPaperDataSource(
      (module) async => PreExamSecretPaperCatalog(
        module: module,
        isVip: true,
        papers: const [PreExamSecretPaper(id: 1001, name: '考前终极密卷')],
      ),
    );
    final examSource = _ExamDataSource();
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(_secretPaperModule)),
        preExamSecretPaperDataSource: secretSource,
        examDataSource: examSource,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-53')));
    await tester.pumpAndSettle();
    expect(find.byType(PreExamSecretPaperPage), findsOneWidget);
    expect(secretSource.modules, [_secretPaperModule]);
    final landing = tester.widget<PreExamSecretPaperPage>(
      find.byType(PreExamSecretPaperPage),
    );
    expect(landing.dataSource, same(secretSource));

    final card = find.byKey(const ValueKey('secret-paper-card-0'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(ExamPage), findsOneWidget);
    final examPage = tester.widget<ExamPage>(find.byType(ExamPage));
    expect(examPage.dataSource, same(examSource));
    expect(examPage.request.module, same(_secretPaperModule));
    expect(examPage.request.shelfId, 1001);
    expect(examPage.request.title, '考前终极密卷');

    await tester.tap(find.byKey(const ValueKey('exam-option-A')));
    await tester.tap(find.byKey(const ValueKey('exam-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('exam-confirm-submit')));
    await tester.pumpAndSettle();

    expect(find.byType(ExamResultPage), findsOneWidget);
    expect(examSource.submittedResults, hasLength(1));
    expect(examSource.submittedResults.single.rightCount, 1);
  });

  testWidgets('passes the secret-paper unlock callback and reloads VIP', (
    tester,
  ) async {
    var catalogLoads = 0;
    final secretSource = _SecretPaperDataSource((module) async {
      return PreExamSecretPaperCatalog(
        module: module,
        isVip: catalogLoads++ > 0,
        papers: const [PreExamSecretPaper(id: 1001, name: '考前终极密卷')],
      );
    });
    var unlockCalls = 0;
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(_secretPaperModule)),
        preExamSecretPaperDataSource: secretSource,
        examDataSource: _ExamDataSource(),
        preExamSecretPaperUnlockLauncher: (_) => unlockCalls += 1,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-module-53')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('secret-paper-bottom-unlock')));
    await tester.pumpAndSettle();

    expect(unlockCalls, 1);
    expect(secretSource.modules, [_secretPaperModule, _secretPaperModule]);
    expect(
      find.byKey(const ValueKey('secret-paper-bottom-unlock')),
      findsNothing,
    );
  });

  testWidgets('default popup surfaces preserve Android source IDs', (
    tester,
  ) async {
    final entries = <VipPayEntry>[];
    Future<VipPurchaseResult?> present(
      BuildContext context,
      VipPayEntry entry,
    ) async {
      entries.add(entry);
      return null;
    }

    const fastModule = HomeModule(
      id: 48,
      name: '速成300题',
      page: '速成300题',
      tag: '',
    );
    await tester.pumpWidget(
      StartupApp(
        key: UniqueKey(),
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(_mnemonicModule)),
        skillMnemonicsDataSource: _LockedMnemonicDataSource(),
        vipPaySheetLauncher: present,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-module-42')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mnemonic-row-0')));
    await tester.pumpAndSettle();
    expect(entries, [VipPayEntry.mnemonicsLockedList]);

    await tester.pumpWidget(
      StartupApp(
        key: UniqueKey(),
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(fastModule)),
        fastPracticeDataSource: _FastPracticeDataSource(
          destination: FastPracticeEntryDestination.landing,
        ),
        vipPaySheetLauncher: present,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-module-48')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fast-practice-unlock')));
    await tester.pump();
    expect(entries, [VipPayEntry.fast300]);

    final secretSource = _SecretPaperDataSource(
      (module) async => PreExamSecretPaperCatalog(
        module: module,
        isVip: false,
        papers: const [PreExamSecretPaper(id: 1001, name: '密押卷')],
      ),
    );
    await tester.pumpWidget(
      StartupApp(
        key: UniqueKey(),
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(_secretPaperModule)),
        preExamSecretPaperDataSource: secretSource,
        examDataSource: _ExamDataSource(),
        vipPaySheetLauncher: present,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-module-53')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('secret-paper-bottom-unlock')));
    await tester.pumpAndSettle();
    expect(entries.last, VipPayEntry.secretPaperBottom);
    final secretCard = find.byKey(const ValueKey('secret-paper-card-0'));
    await tester.ensureVisible(secretCard);
    await tester.tap(secretCard);
    await tester.pumpAndSettle();
    expect(entries.last, VipPayEntry.secretPaperList);

    final smartSource = _SmartCardDataSource(
      SmartCardEntry(
        SmartCardEntryDestination.page,
        catalog: _smartCardCatalog(),
      ),
    );
    await tester.pumpWidget(
      StartupApp(
        key: UniqueKey(),
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(_smartCardModule)),
        smartCardDataSource: smartSource,
        vipPaySheetLauncher: present,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-module-51')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('smart-card-unlock')));
    await tester.pumpAndSettle();
    expect(entries.last, VipPayEntry.smartCard);

    final pastSource = _PastExamsDataSource(
      (module) async => PastExamsCatalog(
        module: module,
        hasFullAccess: false,
        papers: const [
          PastExamPaper(id: 1, name: '一', type: '扁平化', locked: false),
          PastExamPaper(id: 2, name: '二', type: '扁平化', locked: false),
          PastExamPaper(id: 3, name: '三', type: '扁平化', locked: true),
        ],
      ),
    );
    await tester.pumpWidget(
      StartupApp(
        key: UniqueKey(),
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(_pastExamsModule)),
        pastExamsDataSource: pastSource,
        examDataSource: _ExamDataSource(),
        vipPaySheetLauncher: present,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-module-52')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('past-exams-unlock-2')));
    await tester.pumpAndSettle();
    expect(entries.last, VipPayEntry.pastExams);

    expect(entries, [
      VipPayEntry.mnemonicsLockedList,
      VipPayEntry.fast300,
      VipPayEntry.secretPaperBottom,
      VipPayEntry.secretPaperList,
      VipPayEntry.smartCard,
      VipPayEntry.pastExams,
    ]);
  });

  testWidgets('six-paper opens attributed full-screen VIP purchase', (
    tester,
  ) async {
    final vipSource = _VipPurchaseDataSource(
      _vipSession(isLoggedIn: true, showWechatPay: false),
    );
    var popupCalls = 0;
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(_preExamSixPaperModule)),
        preExamSixPaperDataSource: _PreExamSixPaperDataSource(
          const PreExamSixPaperEntry(PreExamSixPaperEntryDestination.landing),
        ),
        preExamSixPaperFileTransfer: _PreExamSixPaperTransfer(),
        vipPurchaseDataSource: vipSource,
        vipPaymentGateway: _VipPaymentGateway(),
        vipPaySheetLauncher: (_, _) async {
          popupCalls += 1;
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-module-49')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pre-exam-six-landing-unlock')));
    await tester.pumpAndSettle();

    expect(find.byType(VipPurchasePage), findsOneWidget);
    expect(find.byType(VipPaySheet), findsNothing);
    expect(popupCalls, 0);
    expect(vipSource.requests, hasLength(1));
    expect(vipSource.requests.single.normalPayPageSourceId, 1014);
    expect(vipSource.requests.single.differencePayPageSourceId, 1014);
    expect(vipSource.requests.single.defaultProductType, isNull);
  });

  testWidgets('secret-paper popup requests default to the skill product', (
    tester,
  ) async {
    final secretSource = _SecretPaperDataSource(
      (module) async => PreExamSecretPaperCatalog(
        module: module,
        isVip: false,
        papers: const [PreExamSecretPaper(id: 1001, name: '密押卷')],
      ),
    );
    final vipSource = _VipPurchaseDataSource(
      _vipSession(isLoggedIn: true, showWechatPay: false),
    );
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(_secretPaperModule)),
        preExamSecretPaperDataSource: secretSource,
        examDataSource: _ExamDataSource(),
        vipPurchaseDataSource: vipSource,
        vipPaymentGateway: _VipPaymentGateway(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-module-53')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('secret-paper-bottom-unlock')));
    await tester.pumpAndSettle();
    expect(vipSource.requests.single.normalPayPageSourceId, 1012);
    expect(vipSource.requests.single.defaultProductType, VipProductType.skill);
    await tester.tap(find.byKey(const ValueKey('vip-pay-sheet-close')));
    await tester.pumpAndSettle();

    final secretCard = find.byKey(const ValueKey('secret-paper-card-0'));
    await tester.ensureVisible(secretCard);
    await tester.tap(secretCard);
    await tester.pumpAndSettle();
    expect(vipSource.requests, hasLength(2));
    expect(vipSource.requests.last.normalPayPageSourceId, 1011);
    expect(vipSource.requests.last.defaultProductType, VipProductType.skill);
  });

  testWidgets('confirmed fast payment resolves the catalog after success', (
    tester,
  ) async {
    const fastModule = HomeModule(
      id: 48,
      name: '速成300题',
      page: '速成300题',
      tag: '',
    );
    final mainSource = _DataSource(_routingHome(fastModule));
    final fastSource = _FastPracticeDataSource(
      destination: FastPracticeEntryDestination.landing,
      destinationAfterFirstResolve: FastPracticeEntryDestination.catalog,
    );
    final vipSource = _VipPurchaseDataSource(
      _vipSession(isLoggedIn: true, showWechatPay: false),
    );
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: mainSource,
        fastPracticeDataSource: fastSource,
        vipPurchaseDataSource: vipSource,
        vipPaymentGateway: _VipPaymentGateway(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-module-48')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fast-practice-unlock')));
    await tester.pumpAndSettle();

    expect(find.byType(VipPaySheet), findsOneWidget);
    expect(find.byType(FastPracticeLandingPage), findsOneWidget);
    expect(fastSource.resolvedModules, [fastModule]);

    await tester.tap(find.byKey(const ValueKey('vip-pay-sheet-checkout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vip-success-back')));
    await tester.pumpAndSettle();

    expect(find.byType(FastPracticeCatalogPage), findsOneWidget);
    expect(fastSource.resolvedModules, [fastModule, fastModule]);
    expect(fastSource.loadedModules, [fastModule]);
    expect(mainSource.homeLoadCalls, 2);
  });

  testWidgets('confirmed popup payment refreshes the active feature and tabs', (
    tester,
  ) async {
    final mainSource = _DataSource(_routingHome(_pastExamsModule));
    var catalogLoads = 0;
    final pastSource = _PastExamsDataSource((module) async {
      final unlocked = catalogLoads++ > 0;
      return PastExamsCatalog(
        module: module,
        hasFullAccess: unlocked,
        papers: [
          const PastExamPaper(id: 1, name: '一', type: '扁平化', locked: false),
          const PastExamPaper(id: 2, name: '二', type: '扁平化', locked: false),
          PastExamPaper(id: 3, name: '三', type: '扁平化', locked: !unlocked),
        ],
      );
    });
    final vipSource = _VipPurchaseDataSource(
      _vipSession(isLoggedIn: true, showWechatPay: false),
    );

    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: mainSource,
        pastExamsDataSource: pastSource,
        examDataSource: _ExamDataSource(),
        vipPurchaseDataSource: vipSource,
        vipPaymentGateway: _VipPaymentGateway(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-module-52')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('past-exams-unlock-2')));
    await tester.pumpAndSettle();

    expect(find.byType(VipPaySheet), findsOneWidget);
    expect(vipSource.requests.single.normalPayPageSourceId, 1021);
    await tester.tap(find.byKey(const ValueKey('vip-pay-sheet-checkout')));
    await tester.pumpAndSettle();
    expect(find.byType(VipPurchaseSuccessPage), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('vip-success-back')));
    await tester.pumpAndSettle();

    expect(find.byType(PastExamsPage), findsOneWidget);
    expect(find.byKey(const ValueKey('past-exams-unlock-2')), findsNothing);
    expect(find.byKey(const ValueKey('past-exams-start-2')), findsOneWidget);
    expect(pastSource.modules, [_pastExamsModule, _pastExamsModule]);
    expect(mainSource.homeLoadCalls, 2);
  });

  testWidgets('non-exam routes never touch paper or exam sources', (
    tester,
  ) async {
    final pastSource = _PastExamsDataSource(
      (module) => throw StateError('unexpected past-exams load'),
    );
    final examSource = _ExamDataSource();
    final secretSource = _SecretPaperDataSource(
      (module) => throw StateError('unexpected secret-paper load'),
    );
    const module = HomeModule(id: 44, name: '神秘入口', page: 'mystery', tag: '');
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(module)),
        pastExamsDataSource: pastSource,
        preExamSecretPaperDataSource: secretSource,
        examDataSource: examSource,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-44')));
    await tester.pump();

    expect(pastSource.modules, isEmpty);
    expect(secretSource.modules, isEmpty);
    expect(examSource.loadRequests, isEmpty);
    expect(examSource.submittedResults, isEmpty);
    expect(find.byType(PastExamsPage), findsNothing);
  });

  testWidgets(
    'opens daily detail practice report and resolves mnemonic improvement',
    (tester) async {
      final mainSource = _DataSource(
        _routingHomeModules(const [_dailyModule, _mnemonicModule]),
      );
      final dailySource = _DailyDataSource();
      final dailyProgress = _DailyProgressStore();
      final mnemonicSource = _MnemonicDataSource();
      final practiceSource = _PracticeDataSource(
        catalog: PracticeCatalog(
          items: [PracticeQuestionItem(_dailyQuestion())],
          access: const PracticeAccess(fullAccess: true, freeQuestionCount: 0),
          title: '每日一招',
        ),
      );
      await tester.pumpWidget(
        StartupApp(
          consentStore: _ConsentStore(true),
          initializer: _Initializer(),
          delay: (_) async {},
          mainTabsDataSource: mainSource,
          skillMnemonicsDataSource: mnemonicSource,
          dailySkillDataSource: dailySource,
          dailySkillProgressStore: dailyProgress,
          practiceDataSource: practiceSource,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-module-46')));
      await tester.pumpAndSettle();

      expect(find.byType(DailySkillDetailPage), findsOneWidget);
      expect(dailySource.detailModules, [_dailyModule]);
      expect(dailyProgress.ensureRequests.single.skillId, '11');
      expect(dailyProgress.ensureRequests.single.moduleId, 46);
      expect(dailyProgress.ensureRequests.single.shelfId, 111);

      await tester.tap(find.byKey(const ValueKey('daily-skill-practice')));
      await tester.pumpAndSettle();

      expect(find.byType(PracticePage), findsOneWidget);
      final request = practiceSource.requests.single;
      expect(request, isA<DailySkillPracticeRequest>());
      final dailyRequest = request as DailySkillPracticeRequest;
      expect(dailyRequest.module, _dailyModule);
      expect(dailyRequest.skillId, '11');
      expect(dailyRequest.shelfId, 111);

      await tester.tap(find.byKey(const ValueKey('practice-option-A')));
      await tester.pumpAndSettle();
      expect(dailyProgress.records.single.questionId, 101);
      expect(dailyProgress.records.single.choose, 'A');

      await tester.tap(find.byKey(const ValueKey('practice-next')));
      await tester.pumpAndSettle();

      expect(find.byType(DailySkillReportPage), findsOneWidget);
      expect(dailyProgress.finishedValues, [true]);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('已打卡1天'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('daily-skill-report-improve')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SkillMnemonicsPage), findsOneWidget);
      expect(mainSource.homeLoadCalls, 2);
      expect(mnemonicSource.modules.last, _mnemonicModule);
    },
  );

  testWidgets('daily improvement reports a missing mnemonic module', (
    tester,
  ) async {
    final mainSource = _DataSource(_routingHome(_dailyModule));
    final dailyProgress = _DailyProgressStore(finished: true);
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: mainSource,
        skillMnemonicsDataSource: _MnemonicDataSource(),
        dailySkillDataSource: _DailyDataSource(),
        dailySkillProgressStore: dailyProgress,
        practiceDataSource: _PracticeDataSource(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-46')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('daily-skill-finished')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('daily-skill-improve')));
    await tester.pumpAndSettle();

    expect(find.text('入口数据加载中，请稍后重试'), findsOneWidget);
    expect(find.byType(SkillMnemonicsPage), findsNothing);
    expect(mainSource.homeLoadCalls, 2);
  });

  testWidgets('reports an unsupported home destination separately', (
    tester,
  ) async {
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(
          _routingHome(
            const HomeModule(id: 44, name: '神秘入口', page: 'mystery', tag: ''),
          ),
        ),
        skillMnemonicsDataSource: _MnemonicDataSource(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-44')));
    await tester.pump();

    expect(find.text('该入口暂不受支持'), findsOneWidget);
    expect(find.byType(SkillMnemonicsPage), findsNothing);
  });

  testWidgets('Home wrong review opens login without probing questions', (
    tester,
  ) async {
    final practiceSource = _PracticeDataSource(
      availability: const ErrorPracticeAvailability(requiresLogin: true),
    );
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(_wrongReviewModule)),
        skillMnemonicsDataSource: _MnemonicDataSource(),
        practiceDataSource: practiceSource,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-47')));
    await tester.pumpAndSettle();

    expect(practiceSource.probeCalls, 1);
    expect(practiceSource.requests, isEmpty);
    expect(find.byType(PhoneLoginPage), findsOneWidget);
  });

  testWidgets('Mine review opens the default phone-login route safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(),
        skillMnemonicsDataSource: _MnemonicDataSource(),
        practiceDataSource: _PracticeDataSource(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mine-review-errors')));
    await tester.pumpAndSettle();

    expect(find.byType(PhoneLoginPage), findsOneWidget);
  });

  testWidgets('Home wrong review reports an empty authenticated probe', (
    tester,
  ) async {
    final practiceSource = _PracticeDataSource(
      availability: const ErrorPracticeAvailability(
        requiresLogin: false,
        total: 0,
      ),
    );
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(_wrongReviewModule)),
        skillMnemonicsDataSource: _MnemonicDataSource(),
        practiceDataSource: practiceSource,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-47')));
    await tester.pumpAndSettle();

    expect(find.text('暂无错题'), findsOneWidget);
    expect(find.byType(PracticePage), findsNothing);
  });

  testWidgets('Home wrong review opens error practice after a positive probe', (
    tester,
  ) async {
    final practiceSource = _PracticeDataSource(
      availability: const ErrorPracticeAvailability(
        requiresLogin: false,
        total: 2,
      ),
    );
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(_wrongReviewModule)),
        skillMnemonicsDataSource: _MnemonicDataSource(),
        practiceDataSource: practiceSource,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-47')));
    await tester.pumpAndSettle();

    expect(find.byType(PracticePage), findsOneWidget);
    expect(practiceSource.requests.single, isA<ErrorPracticeRequest>());
  });

  testWidgets('Home wrong review leaves probe failures silent', (tester) async {
    final practiceSource = _PracticeDataSource(
      probeError: StateError('offline'),
    );
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_routingHome(_wrongReviewModule)),
        skillMnemonicsDataSource: _MnemonicDataSource(),
        practiceDataSource: practiceSource,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-47')));
    await tester.pumpAndSettle();

    expect(find.byType(PracticePage), findsNothing);
    expect(find.byType(PhoneLoginPage), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('opens both Mine review modes with exact practice requests', (
    tester,
  ) async {
    final practiceSource = _PracticeDataSource();
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_homeData, _mineReviewData),
        skillMnemonicsDataSource: _MnemonicDataSource(),
        practiceDataSource: practiceSource,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mine-review-errors')));
    await tester.pumpAndSettle();
    expect(find.byType(PracticePage), findsOneWidget);
    expect(practiceSource.requests.single, isA<ErrorPracticeRequest>());

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mine-review-collections')));
    await tester.pumpAndSettle();
    expect(find.byType(PracticePage), findsOneWidget);
    expect(practiceSource.requests.last, isA<CollectionPracticeRequest>());
  });

  testWidgets('opens Mine settings and reuses the agreement web surface', (
    tester,
  ) async {
    final settingsSource = _SettingsDataSource();
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_homeData, _mineReviewData),
        settingsDataSource: settingsSource,
        agreementContentBuilder: (context, uri) => Text('SETTINGS:$uri'),
      ),
    );
    await tester.pumpAndSettle();
    expect(settingsSource.loadCalls, 0);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    final settingsRow = find.byKey(const ValueKey('mine-settings'));
    await tester.ensureVisible(settingsRow);
    await tester.pumpAndSettle();
    await tester.tap(settingsRow);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    final settings = tester.widget<SettingsPage>(find.byType(SettingsPage));
    expect(settings.dataSource, same(settingsSource));
    expect(settings.isLoggedIn, isTrue);
    expect(settingsSource.loadCalls, 1);

    await tester.tap(find.byKey(const ValueKey('settings-privacy')));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacySettingsPage), findsOneWidget);
    expect(settingsSource.loadCalls, 2);

    await tester.tap(find.byKey(const ValueKey('privacy-policy')));
    await tester.pumpAndSettle();
    expect(find.byType(AgreementWebViewPage), findsOneWidget);
    expect(
      find.text(
        'SETTINGS:https://img.jx885.com/pass-license/html/privacy.html',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'opens real account safety and rebuilds tabs after deactivation',
    (tester) async {
      final mainSource = _DataSource(_homeData, _mineReviewData);
      final accountSource = _AccountSafetyDataSource();
      await tester.pumpWidget(
        StartupApp(
          consentStore: _ConsentStore(true),
          initializer: _Initializer(),
          delay: (_) async {},
          mainTabsDataSource: mainSource,
          settingsDataSource: _SettingsDataSource(),
          accountSafetyDataSource: accountSource,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('main-tabs-0')), findsOneWidget);

      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      final settingsRow = find.byKey(const ValueKey('mine-settings'));
      await tester.ensureVisible(settingsRow);
      await tester.pumpAndSettle();
      await tester.tap(settingsRow);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-account-safety')));
      await tester.pumpAndSettle();

      expect(find.byType(AccountSafetyPage), findsOneWidget);
      expect(
        tester
            .widget<AccountSafetyPage>(find.byType(AccountSafetyPage))
            .dataSource,
        same(accountSource),
      );
      await tester.tap(find.byKey(const ValueKey('account-safety-deactivate')));
      await tester.pumpAndSettle();
      expect(find.byType(AccountDeactivationPage), findsOneWidget);
      Navigator.of(
        tester.element(find.byType(AccountDeactivationPage)),
      ).pop(AccountSafetyResult.deactivated);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsNothing);
      expect(find.byKey(const ValueKey('main-tabs-1')), findsOneWidget);
    },
  );

  testWidgets(
    'opens the real profile and rebuilds tabs only after normal sign out',
    (tester) async {
      final mainSource = _DataSource(_homeData, _mineReviewData);
      final profileSource = _AccountProfileDataSource();
      await tester.pumpWidget(
        StartupApp(
          consentStore: _ConsentStore(true),
          initializer: _Initializer(),
          delay: (_) async {},
          mainTabsDataSource: mainSource,
          accountProfileDataSource: profileSource,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('main-tabs-0')), findsOneWidget);

      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mine-profile')));
      await tester.pumpAndSettle();

      expect(find.byType(AccountProfilePage), findsOneWidget);
      expect(
        tester
            .widget<AccountProfilePage>(find.byType(AccountProfilePage))
            .dataSource,
        same(profileSource),
      );
      expect(profileSource.loadCalls, 1);

      await tester.tap(find.byKey(const ValueKey('account-profile-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('main-tabs-0')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('mine-profile')));
      await tester.pumpAndSettle();
      Navigator.of(
        tester.element(find.byType(AccountProfilePage)),
      ).pop(AccountProfileResult.signedOut);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('main-tabs-1')), findsOneWidget);
    },
  );

  testWidgets('keeps an injected Mine profile launcher supported', (
    tester,
  ) async {
    var launchCalls = 0;
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_homeData, _mineReviewData),
        mineProfileLauncher: (_) async {
          launchCalls += 1;
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mine-profile')));
    await tester.pump();

    expect(launchCalls, 1);
    expect(find.byType(AccountProfilePage), findsNothing);
    expect(find.byKey(const ValueKey('main-tabs-0')), findsOneWidget);
  });

  testWidgets('opens real purchase history without rebuilding MainTabs', (
    tester,
  ) async {
    final purchaseSource = _PurchaseHistoryDataSource();
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_homeData, _mineReviewData),
        purchaseHistoryDataSource: purchaseSource,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-tabs-0')), findsOneWidget);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('mine-purchase-history'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.byType(PurchaseHistoryPage), findsOneWidget);
    expect(
      tester
          .widget<PurchaseHistoryPage>(find.byType(PurchaseHistoryPage))
          .dataSource,
      same(purchaseSource),
    );
    expect(purchaseSource.loadCalls, 1);

    await tester.tap(find.byKey(const ValueKey('purchase-history-back')));
    await tester.pumpAndSettle();
    expect(find.byType(PurchaseHistoryPage), findsNothing);
    expect(find.byKey(const ValueKey('main-tabs-0')), findsOneWidget);
  });

  testWidgets('opens both real Mine web routes without rebuilding MainTabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(_homeData, _mineReviewData),
        mineWebContentBuilder: (context, uri) => Text('MINE-WEB:$uri'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('驾考学习指南'), findsNothing);

    final collect = find.byKey(const ValueKey('mine-collect-book'));
    await tester.ensureVisible(collect);
    await tester.pumpAndSettle();
    await tester.tap(collect);
    await tester.pumpAndSettle();
    expect(find.byType(LegacyWebViewPage), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('领取书籍'), findsOneWidget);
    expect(
      find.text('MINE-WEB:https://example.com/collect-book'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('legacy-web-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-tabs-0')), findsOneWidget);

    final invite = find.byKey(const ValueKey('mine-invite-friends'));
    await tester.ensureVisible(invite);
    await tester.pumpAndSettle();
    await tester.tap(invite);
    await tester.pumpAndSettle();
    expect(find.byType(LegacyWebViewPage), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('邀请好友'), findsNothing);
    expect(
      find.text('MINE-WEB:https://example.com/invite?t=token&env=prod'),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-tabs-0')), findsOneWidget);
  });

  testWidgets('opens Mine customer service without rebuilding MainTabs', (
    tester,
  ) async {
    final customerSource = _CustomerServiceDataSource(
      url: 'https://service.example/customer?a=1&b=2',
    );
    final customerGateway = _CustomerServiceGateway();
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(),
        customerServiceDataSource: customerSource,
        customerServiceGateway: customerGateway,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('mine-customer-service'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(customerSource.loadCalls, 1);
    expect(customerGateway.urls, ['https://service.example/customer?a=1&b=2']);
    expect(find.byKey(const ValueKey('main-tabs-0')), findsOneWidget);
  });

  testWidgets('proactive update waits for privacy and the first ready frame', (
    tester,
  ) async {
    final updateSource = _AppUpdateDataSource(
      const AppUpdateLatest(),
      proactiveResult: const AppUpdateLatest(),
    );
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(false),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(),
        appUpdateDataSource: updateSource,
        appUpdateFileTransfer: _AppUpdateTransfer(),
      ),
    );
    await tester.pump();

    expect(find.byType(PrivacyConsentDialog), findsOneWidget);
    expect(updateSource.proactiveCalls, 0);

    await tester.tap(find.text('同意'));
    await tester.pumpAndSettle();

    expect(find.byType(MainTabsPage), findsOneWidget);
    expect(updateSource.proactiveCalls, 1);
  });

  testWidgets('proactive throttled result stays silent', (tester) async {
    final updateSource = _AppUpdateDataSource(const AppUpdateLatest());
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(),
        appUpdateDataSource: updateSource,
        appUpdateFileTransfer: _AppUpdateTransfer(),
      ),
    );
    await tester.pumpAndSettle();

    expect(updateSource.proactiveCalls, 1);
    expect(find.byType(AppUpdateDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('proactive latest result stays silent', (tester) async {
    final updateSource = _AppUpdateDataSource(
      const AppUpdateLatest(),
      proactiveResult: const AppUpdateLatest(),
    );
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(),
        appUpdateDataSource: updateSource,
        appUpdateFileTransfer: _AppUpdateTransfer(),
      ),
    );
    await tester.pumpAndSettle();

    expect(updateSource.proactiveCalls, 1);
    expect(find.byType(AppUpdateDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('proactive failure stays silent', (tester) async {
    final updateSource = _AppUpdateDataSource(
      const AppUpdateLatest(),
      proactiveError: StateError('offline'),
    );
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(),
        appUpdateDataSource: updateSource,
        appUpdateFileTransfer: _AppUpdateTransfer(),
      ),
    );
    await tester.pumpAndSettle();

    expect(updateSource.proactiveCalls, 1);
    expect(find.byType(AppUpdateDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('proactive available result opens the real update dialog', (
    tester,
  ) async {
    final updateSource = _AppUpdateDataSource(
      const AppUpdateLatest(),
      proactiveResult: const AppUpdateAvailable(_availableUpdate),
    );
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(),
        appUpdateDataSource: updateSource,
        appUpdateFileTransfer: _AppUpdateTransfer(),
      ),
    );
    await tester.pumpAndSettle();

    expect(updateSource.proactiveCalls, 1);
    expect(find.byType(AppUpdateDialog), findsOneWidget);
    expect(find.text('v2.0.0'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-update-close')));
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsNothing);
  });

  testWidgets('proactive short resume checks immediately without a splash', (
    tester,
  ) async {
    var now = 1000000;
    final delays = <Duration>[];
    final updateSource = _AppUpdateDataSource(
      const AppUpdateLatest(),
      proactiveResult: const AppUpdateLatest(),
    );
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        lifecycleNowMillis: () => now,
        secondarySplashDelay: (duration) async => delays.add(duration),
        mainTabsDataSource: _DataSource(),
        appUpdateDataSource: updateSource,
        appUpdateFileTransfer: _AppUpdateTransfer(),
      ),
    );
    await tester.pumpAndSettle();
    expect(updateSource.proactiveCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now += const Duration(seconds: 10).inMilliseconds;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(updateSource.proactiveCalls, 2);
    expect(delays, isEmpty);
    expect(find.byType(StartupSplashPage), findsNothing);
  });

  testWidgets('proactive resume at exactly fifteen seconds stays immediate', (
    tester,
  ) async {
    var now = 1000000;
    final delays = <Duration>[];
    final updateSource = _AppUpdateDataSource(
      const AppUpdateLatest(),
      proactiveResult: const AppUpdateLatest(),
    );
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        lifecycleNowMillis: () => now,
        secondarySplashDelay: (duration) async => delays.add(duration),
        mainTabsDataSource: _DataSource(),
        appUpdateDataSource: updateSource,
        appUpdateFileTransfer: _AppUpdateTransfer(),
      ),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now += const Duration(seconds: 15).inMilliseconds;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(updateSource.proactiveCalls, 2);
    expect(delays, isEmpty);
    expect(find.byType(StartupSplashPage), findsNothing);
  });

  testWidgets(
    'proactive long resume shows three second splash before a throttled check',
    (tester) async {
      var now = 1000000;
      final delays = <Duration>[];
      final splashDelay = Completer<void>();
      final updateSource = _AppUpdateDataSource(const AppUpdateLatest());
      await tester.pumpWidget(
        StartupApp(
          consentStore: _ConsentStore(true),
          initializer: _Initializer(),
          delay: (_) async {},
          lifecycleNowMillis: () => now,
          secondarySplashDelay: (duration) {
            delays.add(duration);
            return splashDelay.future;
          },
          mainTabsDataSource: _DataSource(),
          appUpdateDataSource: updateSource,
          appUpdateFileTransfer: _AppUpdateTransfer(),
        ),
      );
      await tester.pumpAndSettle();
      expect(updateSource.proactiveCalls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now += const Duration(seconds: 15).inMilliseconds + 1;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(delays, [const Duration(seconds: 3)]);
      expect(find.byType(StartupSplashPage), findsOneWidget);
      expect(updateSource.proactiveCalls, 1);

      splashDelay.complete();
      await tester.pumpAndSettle();

      expect(find.byType(StartupSplashPage), findsNothing);
      expect(updateSource.proactiveCalls, 2);
      expect(find.byType(AppUpdateDialog), findsNothing);
    },
  );

  testWidgets('proactive resume before ready is ignored', (tester) async {
    var now = 1000000;
    final delays = <Duration>[];
    final updateSource = _AppUpdateDataSource(
      const AppUpdateLatest(),
      proactiveResult: const AppUpdateLatest(),
    );
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(false),
        initializer: _Initializer(),
        delay: (_) async {},
        lifecycleNowMillis: () => now,
        secondarySplashDelay: (duration) async => delays.add(duration),
        mainTabsDataSource: _DataSource(),
        appUpdateDataSource: updateSource,
        appUpdateFileTransfer: _AppUpdateTransfer(),
      ),
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now += const Duration(minutes: 1).inMilliseconds;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(updateSource.proactiveCalls, 0);
    expect(delays, isEmpty);
    expect(find.byType(PrivacyConsentDialog), findsOneWidget);
    expect(find.byType(StartupSplashPage), findsOneWidget);
  });

  testWidgets('proactive pending request ignores a foreground trigger', (
    tester,
  ) async {
    var now = 1000000;
    final pending = Completer<AppUpdateCheckResult?>();
    final updateSource = _AppUpdateDataSource(
      const AppUpdateLatest(),
      proactiveCompleter: pending,
    );
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        lifecycleNowMillis: () => now,
        secondarySplashDelay: (_) async {},
        mainTabsDataSource: _DataSource(),
        appUpdateDataSource: updateSource,
        appUpdateFileTransfer: _AppUpdateTransfer(),
      ),
    );
    await tester.pumpAndSettle();
    expect(updateSource.proactiveCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now += const Duration(seconds: 1).inMilliseconds;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(updateSource.proactiveCalls, 1);
    pending.complete(const AppUpdateLatest());
    await tester.pumpAndSettle();
  });

  testWidgets('proactive pending splash ignores another long resume', (
    tester,
  ) async {
    var now = 1000000;
    final delays = <Duration>[];
    final splashDelay = Completer<void>();
    final updateSource = _AppUpdateDataSource(
      const AppUpdateLatest(),
      proactiveResult: const AppUpdateLatest(),
    );
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        lifecycleNowMillis: () => now,
        secondarySplashDelay: (duration) {
          delays.add(duration);
          return splashDelay.future;
        },
        mainTabsDataSource: _DataSource(),
        appUpdateDataSource: updateSource,
        appUpdateFileTransfer: _AppUpdateTransfer(),
      ),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now += const Duration(seconds: 16).inMilliseconds;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(delays, [const Duration(seconds: 3)]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now += const Duration(seconds: 16).inMilliseconds;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(delays, [const Duration(seconds: 3)]);
    expect(updateSource.proactiveCalls, 1);
    splashDelay.complete();
    await tester.pumpAndSettle();
    expect(updateSource.proactiveCalls, 2);
  });

  testWidgets('manual update reports latest without rebuilding MainTabs', (
    tester,
  ) async {
    final updateSource = _AppUpdateDataSource(const AppUpdateLatest());
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(),
        appUpdateDataSource: updateSource,
        appUpdateFileTransfer: _AppUpdateTransfer(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('mine-check-update'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();

    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(updateSource.calls, 1);
    expect(find.text('当前已是最新版本'), findsOneWidget);
    expect(find.byKey(const ValueKey('main-tabs-0')), findsOneWidget);
  });

  testWidgets('manual update opens the real dialog over preserved MainTabs', (
    tester,
  ) async {
    final updateSource = _AppUpdateDataSource(
      const AppUpdateAvailable(_availableUpdate),
    );
    final transfer = _AppUpdateTransfer();
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(),
        appUpdateDataSource: updateSource,
        appUpdateFileTransfer: transfer,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('mine-check-update'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();

    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(updateSource.calls, 1);
    expect(find.byType(AppUpdateDialog), findsOneWidget);
    expect(find.text('v2.0.0'), findsOneWidget);
    expect(find.byKey(const ValueKey('main-tabs-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-update-close')));
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsNothing);
    expect(find.byKey(const ValueKey('main-tabs-0')), findsOneWidget);
  });

  testWidgets('manual update failures remain silent and allow a retry', (
    tester,
  ) async {
    final updateSource = _AppUpdateDataSource(
      const AppUpdateLatest(),
      error: StateError('offline'),
    );
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(),
        appUpdateDataSource: updateSource,
        appUpdateFileTransfer: _AppUpdateTransfer(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('mine-check-update'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('当前已是最新版本'), findsNothing);
    expect(find.byType(AppUpdateDialog), findsNothing);

    updateSource.error = null;
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(updateSource.calls, 2);
    expect(find.text('当前已是最新版本'), findsOneWidget);
  });

  testWidgets('Startup customer service silently uses the fixed fallback', (
    tester,
  ) async {
    final customerSource = _CustomerServiceDataSource(
      error: StateError('offline'),
    );
    final customerGateway = _CustomerServiceGateway();
    await tester.pumpWidget(
      StartupApp(
        consentStore: _ConsentStore(true),
        initializer: _Initializer(),
        delay: (_) async {},
        mainTabsDataSource: _DataSource(),
        customerServiceDataSource: customerSource,
        customerServiceGateway: customerGateway,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('mine-customer-service'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(customerSource.loadCalls, 1);
    expect(customerGateway.urls, [customerServiceFallbackUrl]);
    expect(find.text('暂时无法打开微信客服，请稍后重试'), findsNothing);
    expect(find.byKey(const ValueKey('main-tabs-0')), findsOneWidget);
  });

  testWidgets(
    'opens the real VIP page with shared login service and agreement',
    (tester) async {
      final mainSource = _DataSource();
      final vipSource = _VipPurchaseDataSource(_vipSession(isLoggedIn: false));
      final paymentGateway = _VipPaymentGateway();
      final customerSource = _CustomerServiceDataSource(
        url: 'https://service.example/vip',
      );
      final customerGateway = _CustomerServiceGateway();

      await tester.pumpWidget(
        StartupApp(
          consentStore: _ConsentStore(true),
          initializer: _Initializer(),
          delay: (_) async {},
          mainTabsDataSource: mainSource,
          vipPurchaseDataSource: vipSource,
          vipPaymentGateway: paymentGateway,
          customerServiceDataSource: customerSource,
          customerServiceGateway: customerGateway,
          mineWebContentBuilder: (_, uri) => Text('VIP-WEB:$uri'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mine-vip-purchase')));
      await tester.pumpAndSettle();

      final page = tester.widget<VipPurchasePage>(find.byType(VipPurchasePage));
      expect(page.dataSource, same(vipSource));
      expect(page.paymentGateway, same(paymentGateway));

      await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
      await tester.pumpAndSettle();
      expect(find.byType(PhoneLoginPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('vip-customer-service')));
      await tester.pumpAndSettle();
      expect(customerSource.loadCalls, 1);
      expect(customerGateway.urls, ['https://service.example/vip']);

      await tester.tap(find.byKey(const ValueKey('vip-agreement')));
      await tester.pumpAndSettle();
      final agreement = tester.widget<LegacyWebViewPage>(
        find.byType(LegacyWebViewPage),
      );
      expect(
        agreement.request.url,
        'https://img.jx885.com/pass-license/html/vip.html',
      );
      expect(agreement.request.title, '会员协议');
      expect(
        find.text('VIP-WEB:https://img.jx885.com/pass-license/html/vip.html'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('legacy-web-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('vip-purchase-back')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('main-tabs-0')), findsOneWidget);
      expect(mainSource.homeLoadCalls, 1);
      expect(mainSource.mineLoadCalls, 1);
    },
  );

  testWidgets(
    'confirmed VIP payment shows success then returns Home and reloads Mine',
    (tester) async {
      final mainSource = _DataSource(_homeData, _mineReviewData);
      final vipSource = _VipPurchaseDataSource(
        _vipSession(isLoggedIn: true, showWechatPay: false),
        successSummary: const VipPurchaseSuccessSummary(
          title: '恭喜！【初级社工畅学卡】开通成功',
          expiresOn: '2026-08-01',
          hasMemberTier: true,
        ),
      );
      final paymentGateway = _VipPaymentGateway();
      final customerSource = _CustomerServiceDataSource(
        url: 'https://service.example/vip-success',
      );
      final customerGateway = _CustomerServiceGateway();

      await tester.pumpWidget(
        StartupApp(
          consentStore: _ConsentStore(true),
          initializer: _Initializer(),
          delay: (_) async {},
          mainTabsDataSource: mainSource,
          vipPurchaseDataSource: vipSource,
          vipPaymentGateway: paymentGateway,
          customerServiceDataSource: customerSource,
          customerServiceGateway: customerGateway,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      expect(mainSource.mineLoadCalls, 1);

      await tester.tap(find.byKey(const ValueKey('mine-vip-purchase')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('vip-checkout-button')));
      await tester.pumpAndSettle();

      expect(find.byType(VipPurchasePage), findsOneWidget);
      expect(find.byType(VipPurchaseSuccessPage), findsOneWidget);
      expect(find.text('恭喜！【初级社工畅学卡】开通成功'), findsOneWidget);
      expect(vipSource.successSummaryCalls, 1);
      expect(mainSource.homeLoadCalls, 1);
      expect(mainSource.mineLoadCalls, 1);
      expect(vipSource.orderCalls, 1);
      expect(paymentGateway.alipayOrderInfos, ['signed-order']);

      await tester.tap(
        find.byKey(const ValueKey('vip-success-customer-service')),
      );
      await tester.pumpAndSettle();
      expect(customerSource.loadCalls, 1);
      expect(customerGateway.urls, ['https://service.example/vip-success']);
      expect(mainSource.mineLoadCalls, 1);

      await tester.tap(find.byKey(const ValueKey('vip-success-back')));
      await tester.pumpAndSettle();

      expect(find.byType(VipPurchasePage), findsNothing);
      expect(find.byKey(const ValueKey('main-tabs-0')), findsOneWidget);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        0,
      );
      expect(mainSource.homeLoadCalls, 1);
      expect(mainSource.mineLoadCalls, 2);
    },
  );
}

final class _ConsentStore implements StartupConsentStore {
  _ConsentStore(this.accepted);

  bool accepted;

  @override
  Future<void> acceptPrivacy() async => accepted = true;

  @override
  Future<bool> hasAcceptedPrivacy() async => accepted;
}

final class _Initializer implements StartupPostConsentInitializer {
  _Initializer({this.failOnce = false});

  final bool failOnce;
  int calls = 0;

  @override
  Future<void> initialize() async {
    calls += 1;
    if (failOnce && calls == 1) throw StateError('network unavailable');
  }
}

final class _DataSource implements MainTabsDataSource {
  _DataSource([this.homeData = _homeData, this.mineData = _mineData]);

  final HomeTabData homeData;
  final MineTabData mineData;
  int homeLoadCalls = 0;
  int mineLoadCalls = 0;
  CourseTabData? courseData;

  @override
  Future<HomeTabData> loadHome({
    String? preferredCategoryKey,
    int? preferredSubjectId,
  }) async {
    homeLoadCalls += 1;
    return homeData;
  }

  @override
  Future<CourseTabData> loadCourses({
    required CourseType courseType,
    String? subject,
  }) async {
    return courseData ??
        CourseTabData(
          categoryLabel: '初级社工',
          subjects: _subjects,
          selectedSubject: _subjects.first,
          courseType: courseType,
          items: const [],
        );
  }

  @override
  Future<MineTabData> loadMine() async {
    mineLoadCalls += 1;
    return mineData;
  }
}

final class _TeacherCourseDataSource implements TeacherCourseDataSource {
  _TeacherCourseDataSource(this.session);

  final TeacherCourseSession session;
  final modules = <HomeModule>[];

  @override
  Future<TeacherCourseSession> load(HomeModule module) async {
    modules.add(module);
    return session;
  }
}

final class _VipPurchaseDataSource implements VipPurchaseDataSource {
  _VipPurchaseDataSource(
    this.session, {
    this.successSummary = const VipPurchaseSuccessSummary.generic(),
  });

  final VipPurchaseSession session;
  final VipPurchaseSuccessSummary successSummary;
  final requests = <VipPurchaseRequest>[];
  int sessionCalls = 0;
  int orderCalls = 0;
  int confirmCalls = 0;
  int successSummaryCalls = 0;

  @override
  Future<VipPurchaseSession> loadSession(VipPurchaseRequest request) async {
    sessionCalls += 1;
    requests.add(request);
    return session;
  }

  @override
  Future<VipPurchaseSuccessSummary> loadSuccessSummary(
    VipPurchaseSession session,
  ) async {
    successSummaryCalls += 1;
    return successSummary;
  }

  @override
  Future<VipSkuSelection> loadSkus({
    required VipPurchaseSession session,
    required VipProductType type,
    required List<VipSubject> subjects,
  }) async {
    return VipSkuSelection(
      products: const [],
      skus: [
        VipCommonSku(
          skuName: '月卡',
          totalPrice: 29.9,
          shopCart: const [
            VipShopCartItem(productId: 'product', productSkuId: 1),
          ],
        ),
      ],
    );
  }

  @override
  Future<VipPaymentOrder> createOrder({
    required VipPurchaseSession session,
    required VipPaymentChannel channel,
    required List<VipShopCartItem> shopCart,
  }) async {
    orderCalls += 1;
    return switch (channel) {
      VipPaymentChannel.wechat => const VipPaymentOrder(
        orderId: 'wx-order',
        wechatCredential: VipWechatCredential(
          appId: 'app-id',
          partnerId: 'partner-id',
          prepayId: 'prepay-id',
          nonceStr: 'nonce',
          timeStamp: '123',
          packageValue: 'Sign=WXPay',
          sign: 'signature',
        ),
      ),
      VipPaymentChannel.alipay => const VipPaymentOrder(
        orderId: 'ali-order',
        alipayOrderInfo: 'signed-order',
      ),
    };
  }

  @override
  Future<bool> confirmWechatPayment() async {
    confirmCalls += 1;
    return true;
  }
}

final class _VipPaymentGateway implements VipPaymentGateway {
  final alipayOrderInfos = <String>[];
  final wechatCredentials = <VipWechatCredential>[];

  @override
  Future<bool> isWechatInstalled() async => true;

  @override
  Future<VipNativePaymentResult> payAlipay(String orderInfo) async {
    alipayOrderInfos.add(orderInfo);
    return const VipNativePaymentResult(status: VipNativePaymentStatus.success);
  }

  @override
  Future<VipNativePaymentResult> payWechat(
    VipWechatCredential credential,
  ) async {
    wechatCredentials.add(credential);
    return const VipNativePaymentResult(status: VipNativePaymentStatus.success);
  }
}

VipPurchaseSession _vipSession({
  required bool isLoggedIn,
  bool showWechatPay = true,
}) {
  return VipPurchaseSession(
    request: const VipPurchaseRequest.mine(),
    category: 'social-work',
    level: '初级社工',
    subjects: const [VipSubject(id: 1023, name: '社工实务')],
    initialSubjectIndex: 0,
    productTypes: const [VipProductType.skill],
    initialProductType: VipProductType.skill,
    isLoggedIn: isLoggedIn,
    showWechatPay: showWechatPay,
    initialPaymentChannel: showWechatPay
        ? VipPaymentChannel.wechat
        : VipPaymentChannel.alipay,
    payPageSourceId: 1020,
    nickname: isLoggedIn ? '考友' : '',
    avatarUrl: '',
    benefitLines: const [],
  );
}

final class _AppUpdateDataSource implements AppUpdateDataSource {
  _AppUpdateDataSource(
    this.result, {
    this.error,
    this.proactiveResult,
    this.proactiveError,
    this.proactiveCompleter,
  });

  final AppUpdateCheckResult result;
  final AppUpdateCheckResult? proactiveResult;
  final Completer<AppUpdateCheckResult?>? proactiveCompleter;
  Object? error;
  Object? proactiveError;
  int calls = 0;
  int proactiveCalls = 0;

  @override
  Future<AppUpdateCheckResult> checkManual() async {
    calls += 1;
    final failure = error;
    if (failure != null) throw failure;
    return result;
  }

  @override
  Future<AppUpdateCheckResult?> checkProactive() async {
    proactiveCalls += 1;
    final failure = proactiveError;
    if (failure != null) throw failure;
    final completer = proactiveCompleter;
    if (completer != null) return completer.future;
    return proactiveResult;
  }
}

final class _AppUpdateTransfer implements AppUpdateFileTransfer {
  final List<String> downloadUrls = [];
  final List<String> installs = [];
  final List<String> externalUrls = [];
  int marketCalls = 0;

  @override
  Future<String> download({
    required String url,
    required void Function(int received, int total) onProgress,
  }) async {
    downloadUrls.add(url);
    onProgress(1, 1);
    return '/external/update/app.apk';
  }

  @override
  Future<void> install(String path) async => installs.add(path);

  @override
  Future<void> openExternal(String url) async => externalUrls.add(url);

  @override
  Future<void> openMarket() async => marketCalls += 1;
}

final class _MnemonicDataSource implements SkillMnemonicsDataSource {
  final List<HomeModule> modules = [];

  @override
  Future<SkillMnemonicsCatalog> load(HomeModule module) async {
    modules.add(module);
    return SkillMnemonicsCatalog.fromBody(const {
      'records': [
        {
          'skillId': '11',
          'text': '看到必须先排除',
          'keyword': '必须',
          'note': '结合题干排除绝对表述',
          'questionCount': 7,
        },
      ],
    }, freeCount: 3);
  }
}

final class _LockedMnemonicDataSource implements SkillMnemonicsDataSource {
  @override
  Future<SkillMnemonicsCatalog> load(HomeModule module) async {
    return SkillMnemonicsCatalog.fromBody(const {
      'records': [
        {
          'skillId': '11',
          'text': '看到必须先排除',
          'keyword': '必须',
          'note': '结合题干排除绝对表述',
          'questionCount': 7,
        },
      ],
    }, freeCount: 0);
  }
}

final class _DailyDataSource implements DailySkillDataSource {
  final List<HomeModule> detailModules = [];
  final List<String> questionSkillIds = [];

  @override
  Future<DailySkillDetail> loadDetail(HomeModule module) async {
    detailModules.add(module);
    return DailySkillDetail(
      module: module,
      skill: SkillMnemonic.fromMap(const {
        'skillId': '11',
        'shelfId': '111',
        'text': '看到必须先排除',
        'keyword': '必须',
        'note': '结合题干排除绝对表述',
        'questionCount': 1,
      }),
      effectiveShelfId: 111,
      imageUrl: '',
    );
  }

  @override
  Future<List<PracticeQuestion>> loadQuestions(String skillId) async {
    questionSkillIds.add(skillId);
    return [_dailyQuestion()];
  }
}

final class _DailyProgressStore implements DailySkillProgressDataSource {
  _DailyProgressStore({bool finished = false})
    : _progress = DailySkillProgress.empty(
        date: '2026-07-16',
        skillId: '11',
        moduleId: 46,
        shelfId: 111,
      ).copyWith(isFinished: finished),
      _completedDays = finished ? 1 : 0;

  DailySkillProgress _progress;
  int _completedDays;
  final List<({String skillId, int moduleId, int shelfId})> ensureRequests = [];
  final List<
    ({
      int questionId,
      String choose,
      bool isRight,
      int currentIndex,
      List<int> questionOrder,
    })
  >
  records = [];
  final List<bool> finishedValues = [];

  @override
  Future<DailySkillProgress?> loadToday() async => _progress;

  @override
  Future<DailySkillProgress> ensureToday({
    required String skillId,
    required int moduleId,
    required int shelfId,
  }) async {
    ensureRequests.add((
      skillId: skillId,
      moduleId: moduleId,
      shelfId: shelfId,
    ));
    _progress = _progress.copyWith(
      skillId: skillId,
      moduleId: moduleId,
      shelfId: shelfId,
    );
    return _progress;
  }

  @override
  Future<void> persistQuestionOrder(List<int> questionOrder) async {
    _progress = _progress.copyWith(questionOrder: questionOrder);
  }

  @override
  Future<void> recordAnswer({
    required int questionId,
    required String choose,
    required bool isRight,
    required int currentIndex,
    required List<int> questionOrder,
  }) async {
    records.add((
      questionId: questionId,
      choose: choose,
      isRight: isRight,
      currentIndex: currentIndex,
      questionOrder: List<int>.of(questionOrder),
    ));
    final answers = Map<int, DailySkillAnswer>.from(_progress.answers);
    answers[questionId] = DailySkillAnswer.fromChoose(
      questionId: questionId,
      choose: choose,
      isRight: isRight,
      timestamp: 10,
    );
    final right = <int>[
      ..._progress.rightQuestionIds.where((id) => id != questionId),
    ];
    final wrong = <int>[
      ..._progress.wrongQuestionIds.where((id) => id != questionId),
    ];
    (isRight ? right : wrong).add(questionId);
    _progress = _progress.copyWith(
      currentIndex: currentIndex,
      questionOrder: questionOrder,
      rightQuestionIds: right,
      wrongQuestionIds: wrong,
      answers: answers,
    );
  }

  @override
  Future<void> markFinished(bool finished) async {
    finishedValues.add(finished);
    _progress = _progress.copyWith(isFinished: finished);
    if (finished) _completedDays = 1;
  }

  @override
  Future<int> completedDaysCount() async => _completedDays;

  @override
  Future<void> clear() async {
    _progress = DailySkillProgress.empty(
      date: '2026-07-16',
      skillId: _progress.skillId,
      moduleId: _progress.moduleId,
      shelfId: _progress.shelfId,
    );
  }
}

final class _ChapterDataSource implements ChapterPracticeDataSource {
  final List<HomeModule> modules = [];

  @override
  Future<ChapterPracticeCatalog> load(HomeModule module) async {
    modules.add(module);
    return ChapterPracticeCatalog.empty(module);
  }
}

final class _FastPracticeDataSource implements FastPracticeDataSource {
  _FastPracticeDataSource({
    this.destination = FastPracticeEntryDestination.catalog,
    this.destinationAfterFirstResolve,
  });

  final FastPracticeEntryDestination destination;
  final FastPracticeEntryDestination? destinationAfterFirstResolve;
  final List<HomeModule> resolvedModules = [];
  final List<HomeModule> loadedModules = [];

  @override
  Future<FastPracticeEntryDestination> resolveEntry(HomeModule module) async {
    resolvedModules.add(module);
    if (resolvedModules.length > 1 && destinationAfterFirstResolve != null) {
      return destinationAfterFirstResolve!;
    }
    return destination;
  }

  @override
  Future<FastPracticeCatalog> loadCatalog(HomeModule module) async {
    loadedModules.add(module);
    return FastPracticeCatalog(
      module: module,
      leaves: const [FastPracticeLeaf(id: 111, name: '精选一', type: '扁平化')],
    );
  }
}

final class _PreExamSixPaperDataSource implements PreExamSixPaperDataSource {
  _PreExamSixPaperDataSource(this.entry);

  final PreExamSixPaperEntry entry;
  final List<HomeModule> resolvedModules = [];
  final List<HomeModule> loadedModules = [];

  @override
  Future<PreExamSixPaperEntry> resolveEntry(HomeModule module) async {
    resolvedModules.add(module);
    return entry;
  }

  @override
  Future<PreExamSixPaperFile> loadFile(HomeModule module) {
    loadedModules.add(module);
    throw StateError('unexpected preview load');
  }
}

final class _PreExamSixPaperTransfer implements PreExamSixPaperFileTransfer {
  @override
  Future<String> download({
    required String url,
    required String fileName,
    required void Function(int received, int total) onProgress,
  }) {
    throw StateError('unexpected download');
  }

  @override
  Future<void> share({required String path, required String mimeType}) {
    throw StateError('unexpected share');
  }

  @override
  void cancel() {}
}

final class _SmartCardDataSource implements SmartCardDataSource {
  _SmartCardDataSource(this.entry);

  final SmartCardEntry entry;
  final List<SmartCardRequest> resolvedRequests = [];
  final List<({SmartCardRequest request, bool isVip})> loadedRequests = [];

  @override
  Future<SmartCardEntry> resolveEntry(SmartCardRequest request) async {
    resolvedRequests.add(request);
    return entry;
  }

  @override
  Future<SkillMnemonicsCatalog> loadCatalog(
    SmartCardRequest request, {
    required bool isVip,
  }) {
    loadedRequests.add((request: request, isVip: isVip));
    throw StateError('unexpected smart-card load');
  }
}

typedef _PastExamsLoader = Future<PastExamsCatalog> Function(HomeModule module);

final class _PastExamsDataSource implements PastExamsDataSource {
  _PastExamsDataSource(this.loader);

  final _PastExamsLoader loader;
  final List<HomeModule> modules = [];

  @override
  Future<PastExamsCatalog> loadCatalog(HomeModule module) {
    modules.add(module);
    return loader(module);
  }
}

typedef _SecretPaperLoader =
    Future<PreExamSecretPaperCatalog> Function(HomeModule module);

final class _SecretPaperDataSource implements PreExamSecretPaperDataSource {
  _SecretPaperDataSource(this.loader);

  final _SecretPaperLoader loader;
  final List<HomeModule> modules = [];

  @override
  Future<PreExamSecretPaperCatalog> loadCatalog(HomeModule module) {
    modules.add(module);
    return loader(module);
  }
}

final class _ExamDataSource implements ExamDataSource {
  final List<ExamRequest> loadRequests = [];
  final List<ExamResult> submittedResults = [];

  @override
  Future<ExamCatalog> load(ExamRequest request) async {
    loadRequests.add(request);
    return ExamCatalog(
      request: request,
      questions: [
        PracticeQuestion.fromMap(const {
          'questionId': '101',
          'title': '真题题目',
          'questionType': '单选题',
          'options': {'A': '正确', 'B': '错误'},
          'answer': 'A',
          'analysis': '真题解析',
        }),
      ],
    );
  }

  @override
  Future<void> submit(ExamResult result) async {
    submittedResults.add(result);
  }
}

final class _SettingsDataSource implements SettingsDataSource {
  int loadCalls = 0;

  @override
  Future<SettingsSnapshot> load() async {
    loadCalls += 1;
    return const SettingsSnapshot(
      notificationEnabled: true,
      personalizedRecommendations: true,
    );
  }

  @override
  Future<void> clearCaches() async {}

  @override
  Future<void> openExternalUrl(Uri url) async {}

  @override
  Future<void> openStoreRating() async {}

  @override
  Future<void> setNotificationEnabled(bool enabled) async {}

  @override
  Future<void> setPersonalizedRecommendations(bool enabled) async {}
}

final class _AccountSafetyDataSource implements AccountSafetyDataSource {
  int loadCalls = 0;
  int deactivateCalls = 0;

  @override
  Future<void> deactivateAccount() async {
    deactivateCalls += 1;
  }

  @override
  Future<AccountSafetySnapshot> load() async {
    loadCalls += 1;
    return const AccountSafetySnapshot(isLoggedIn: true, phone: '13800138000');
  }
}

final class _AccountProfileDataSource implements AccountProfileDataSource {
  int loadCalls = 0;
  int signOutCalls = 0;

  @override
  Future<AccountProfileSnapshot> load() async {
    loadCalls += 1;
    return const AccountProfileSnapshot(
      isLoggedIn: true,
      userId: '2038529229062426626',
      nickname: '考友',
      avatar: '',
    );
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }
}

final class _PurchaseHistoryDataSource implements PurchaseHistoryDataSource {
  int loadCalls = 0;

  @override
  Future<List<PurchaseHistoryOrder>> loadOrders() async {
    loadCalls += 1;
    return const [];
  }
}

final class _CustomerServiceDataSource implements CustomerServiceDataSource {
  _CustomerServiceDataSource({this.url, this.error});

  final String? url;
  final Object? error;
  int loadCalls = 0;

  @override
  Future<String?> loadUrl() async {
    loadCalls += 1;
    if (error != null) throw error!;
    return url;
  }
}

final class _CustomerServiceGateway
    implements CustomerServiceMiniProgramGateway {
  final List<String> urls = [];

  @override
  Future<void> launch(String h5Url) async => urls.add(h5Url);
}

final class _FlatProgressStore implements FlatPracticeProgressStore {
  final List<int> loadedShelfIds = [];

  @override
  Future<int> loadFlatQuestionPosition({required int shelfId}) async {
    loadedShelfIds.add(shelfId);
    return 0;
  }

  @override
  Future<void> saveFlatQuestionPosition({
    required int shelfId,
    required int position,
  }) async {}
}

final class _PracticeDataSource implements PracticeDataSource {
  _PracticeDataSource({
    this.availability = const ErrorPracticeAvailability(
      requiresLogin: false,
      total: 1,
    ),
    this.probeError,
    this.catalog,
  });

  final ErrorPracticeAvailability availability;
  final Object? probeError;
  final PracticeCatalog? catalog;
  final List<PracticeRequest> requests = [];
  int probeCalls = 0;

  @override
  Future<PracticeCatalog> load(PracticeRequest request) async {
    requests.add(request);
    return catalog ??
        const PracticeCatalog(
          items: [],
          access: PracticeAccess(fullAccess: true, freeQuestionCount: 5),
          title: '技巧练题',
        );
  }

  @override
  Future<void> saveAnswer(
    PracticeQuestion question,
    PracticeAnswer answer,
  ) async {}

  @override
  Future<void> setCollected(PracticeQuestion question, bool collected) async {}

  @override
  Future<void> removeWrongQuestion(PracticeQuestion question) async {}

  @override
  Future<ErrorPracticeAvailability> probeErrorPractice() async {
    probeCalls += 1;
    if (probeError != null) throw probeError!;
    return availability;
  }

  @override
  Future<int> loadWrongRemovalThreshold() async => -1;

  @override
  Future<void> saveWrongRemovalThreshold(int threshold) async {}

  @override
  Future<bool> recordWrongQuestionCorrect(PracticeQuestion question) async {
    return false;
  }
}

HomeTabData _routingHome(
  HomeModule module, {
  HomeModule? bigSkillCircleModule,
  HomeModule? learningMaterialsModule,
}) {
  return _routingHomeModules(
    [module],
    bigSkillCircleModule: bigSkillCircleModule,
    learningMaterialsModule: learningMaterialsModule,
  );
}

HomeTabData _routingHomeModules(
  List<HomeModule> modules, {
  HomeModule? bigSkillCircleModule,
  HomeModule? learningMaterialsModule,
}) {
  return HomeTabData(
    categoryGroups: const [
      CategoryGroup(label: '社工', options: [_categoryOption]),
    ],
    selection: _selection,
    modules: modules,
    bannerUrl: null,
    examCountdownDays: null,
    bigSkillCircleModule: bigSkillCircleModule,
    learningMaterialsModule: learningMaterialsModule,
  );
}

SkillMnemonicsCatalog _smartCardCatalog() {
  return SkillMnemonicsCatalog.fromBody(
    const {
      'records': [
        {'skillId': '51', 'text': '看到题干先排除', 'keyword': '题干', 'note': '结合题干判断'},
      ],
      'total': 1,
      'pages': 1,
      'current': 1,
      'size': 200,
    },
    freeCount: 3,
    isVip: false,
  );
}

PracticeQuestion _dailyQuestion() {
  return PracticeQuestion.fromMap(const {
    'questionId': '101',
    'title': '每日题目',
    'questionType': '单选题',
    'options': {'A': '正确', 'B': '错误'},
    'answer': 'A',
    'subject': '社工实务',
    'level': '初级社工',
  });
}

const _dailyModule = HomeModule(id: 46, name: '每日一招', page: '每日一招', tag: '');

const _preExamSixPaperModule = HomeModule(
  id: 49,
  name: '考前6页纸',
  page: '考前6页纸',
  tag: '',
);

const _smartCardModule = HomeModule(
  id: 51,
  name: '技巧卡片',
  page: '技巧卡片',
  tag: '',
);

const _pastExamsModule = HomeModule(
  id: 52,
  name: '历年真题卷',
  page: '历年真题卷',
  tag: '',
  type: '嵌套化',
);

const _secretPaperModule = HomeModule(
  id: 53,
  name: '最后密押卷',
  page: '最后密押卷',
  tag: '',
);

const _mnemonicModule = HomeModule(id: 42, name: '技巧口诀', page: '技巧口诀', tag: '');

const _wrongReviewModule = HomeModule(
  id: 47,
  name: '错题巩固',
  page: '错题巩固',
  tag: '',
);

const _subjects = [CategorySubject(id: 1023, name: '社工实务')];

const _categoryOption = CategoryOption(
  key: 'social-work_1016',
  appType: 'social-work',
  id: 1016,
  label: '初级社工',
  subjects: _subjects,
  raw: {'id': 1016, 'appType': 'social-work', 'level': '初级社工'},
);

const _selection = MainTabsSelection(
  category: _categoryOption,
  subject: CategorySubject(id: 1023, name: '社工实务'),
);

const _homeData = HomeTabData(
  categoryGroups: [
    CategoryGroup(label: '社工', options: [_categoryOption]),
  ],
  selection: _selection,
  modules: [],
  bannerUrl: null,
  examCountdownDays: null,
);

const _mineData = MineTabData(
  isLoggedIn: false,
  profile: MineProfile(
    userId: '',
    nickname: '',
    phone: '',
    avatar: '',
    userRole: '',
  ),
  errorCount: 0,
  collectionCount: 0,
  collectBookRequest: null,
  inviteFriendsRequest: null,
);

const _availableUpdate = AppUpdateInfo(
  latestVersion: '2.0.0',
  description: '修复练题记录',
  isForceUpdate: false,
  rawUrl: 'https://cdn.example.com/app.apk',
  ossDomain: '',
);

const _mineReviewData = MineTabData(
  isLoggedIn: true,
  profile: MineProfile(
    userId: '2038529229062426626',
    nickname: '考友',
    phone: '13800138000',
    avatar: '',
    userRole: 'student',
  ),
  errorCount: 2,
  collectionCount: 3,
  collectBookRequest: _collectBookRequest,
  inviteFriendsRequest: _inviteFriendsRequest,
);

const _collectBookRequest = LegacyWebRequest(
  url: 'https://example.com/collect-book',
  title: '领取书籍',
);

const _inviteFriendsRequest = LegacyWebRequest(
  url: 'https://example.com/invite?t=token&env=prod',
  title: '邀请好友',
  hideTitleBar: true,
);
