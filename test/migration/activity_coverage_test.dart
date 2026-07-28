import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/migration/activity_coverage.dart';

void main() {
  test(
    'parses relative and absolute activities and ignores valid comments',
    () {
      const xml = '''
      <manifest package="com.jx885.lrjk"
          xmlns:android="http://schemas.android.com/apk/res/android">
        <application>
          <!-- <activity android:name=".DeletedCommentActivity" /> -->
          <activity android:name=".cg.ui.MainActivity" />
          <activity android:name="com.xmzj.ult.agg.wxapi.WXEntryActivity" />
        </application>
      </manifest>
    ''';

      final rows = parseActivityRegistrations(source: 'main.xml', xml: xml);

      expect(rows.map((row) => row.activityName), <String>[
        'com.jx885.lrjk.cg.ui.MainActivity',
        'com.xmzj.ult.agg.wxapi.WXEntryActivity',
      ]);
      expect(rows.first.disposition, ActivityDisposition.flutterPage);
      expect(rows.first.progress.status, ActivityMigrationStatus.partial);
      expect(rows.first.progress.flutterSurface, 'MainTabsPage');
      expect(rows.last.disposition, ActivityDisposition.pluginCallback);
      expect(rows.last.progress.status, ActivityMigrationStatus.external);
    },
  );

  test('classifies approved PDF removals and SDK-owned login pages', () {
    expect(
      classifyActivity(
        'com.jx885.lrjk.cg.ui.activity.BigSkillPaperPdfListActivity',
      ),
      ActivityDisposition.removed,
    );
    expect(
      classifyActivity('com.mobile.auth.gatewayauth.LoginAuthActivity'),
      ActivityDisposition.sdkManaged,
    );
  });

  test('keeps ownership classification separate from reviewed progress', () {
    expect(
      migrationProgressFor(
        'com.example.PendingActivity',
        ActivityDisposition.flutterPage,
      ),
      const ActivityMigrationProgress(status: ActivityMigrationStatus.pending),
    );
    expect(
      migrationProgressFor(
        'com.jx885.lrjk.cg.ui.SplashActivity',
        ActivityDisposition.flutterPage,
      ),
      const ActivityMigrationProgress(
        status: ActivityMigrationStatus.complete,
        flutterSurface: 'StartupApp / StartupSplashPage',
        evidence: 'startup coordinator and splash widget tests',
      ),
    );
    expect(
      migrationProgressFor(
        'com.mobile.auth.gatewayauth.LoginAuthActivity',
        ActivityDisposition.sdkManaged,
      ).status,
      ActivityMigrationStatus.external,
    );
    expect(
      migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.BigSkillPaperPdfListActivity',
        ActivityDisposition.removed,
      ).status,
      ActivityMigrationStatus.removed,
    );
  });

  test('records Mine H5 routes without overstating generic web work', () {
    final main = migrationProgressFor(
      'com.jx885.lrjk.cg.ui.MainActivity',
      ActivityDisposition.flutterPage,
    );
    final mineWeb = migrationProgressFor(
      'com.jx885.lrjk.ui.web.WebActivity',
      ActivityDisposition.flutterPage,
    );
    final agreementWeb = migrationProgressFor(
      'com.jx885.lrjk.cg.ui.activity.WebViewActivity',
      ActivityDisposition.flutterPage,
    );
    final purchasePayment = migrationProgressFor(
      'com.jx885.lrjk.cg.ui.activity.OpenVipMultiPayActivity',
      ActivityDisposition.flutterPage,
    );
    final purchaseSuccess = migrationProgressFor(
      'com.jx885.lrjk.cg.ui.activity.VipPurchaseSuccessActivity',
      ActivityDisposition.flutterPage,
    );
    final practicePurchaseSuccess = migrationProgressFor(
      'com.jx885.lrjk.cg.ui.activity.BigSkillPracticePurchaseSuccessActivity',
      ActivityDisposition.flutterPage,
    );

    expect(main.status, ActivityMigrationStatus.partial);
    expect(main.flutterSurface, 'MainTabsPage');
    expect(main.evidence, contains('Mine collect-book H5 route migrated'));
    expect(main.evidence, contains('Mine invite-friends H5 route migrated'));
    expect(main.evidence, contains('hidden learning-guide row preserved'));
    expect(
      main.evidence,
      contains('manual Mine app-version check and update handoff migrated'),
    );
    expect(
      main.evidence,
      contains(
        'privacy-gated cold-ready and foreground proactive app-version '
        'checks migrated',
      ),
    );
    expect(main.evidence, contains('shared 30-minute throttle'));
    expect(main.evidence, contains('15-second/3-second secondary splash'));
    expect(
      main.evidence,
      isNot(contains('proactive app-version checks pending')),
    );
    expect(main.evidence, contains('Mine VIP CTA and paid-result refresh'));
    expect(main.evidence, contains('other shared payment launchers pending'));

    expect(mineWeb.status, ActivityMigrationStatus.partial);
    expect(mineWeb.flutterSurface, 'LegacyWebViewPage');
    expect(mineWeb.evidence, contains('Mine collect-book route migrated'));
    expect(mineWeb.evidence, contains('Mine invite-friends route migrated'));
    expect(mineWeb.evidence, contains('generic payment pending'));
    expect(mineWeb.evidence, contains('file chooser pending'));
    expect(mineWeb.evidence, contains('media pending'));
    expect(mineWeb.evidence, contains('share pending'));
    expect(mineWeb.evidence, contains('JavaScript callbacks pending'));

    expect(
      agreementWeb,
      const ActivityMigrationProgress(
        status: ActivityMigrationStatus.partial,
        flutterSurface: 'AgreementWebViewPage',
        evidence: 'agreement web content migrated; generic web routes pending',
      ),
    );
    expect(purchasePayment.status, ActivityMigrationStatus.partial);
    expect(purchasePayment.flutterSurface, 'VipPurchasePage');
    expect(purchasePayment.evidence, contains('Mine full-screen selection'));
    expect(purchasePayment.evidence, contains('product/SKU requests'));
    expect(purchasePayment.evidence, contains('WeChat/Alipay checkout'));
    expect(purchasePayment.evidence, contains('VipPaySheet popup'));
    expect(purchasePayment.evidence, contains('six-paper full-screen entry'));
    expect(purchasePayment.evidence, isNot(contains('VipPayPopup pending')));
    expect(
      purchasePayment.evidence,
      isNot(contains('VipPurchaseSuccessActivity pending')),
    );
    expect(purchaseSuccess.status, ActivityMigrationStatus.partial);
    expect(purchaseSuccess.flutterSurface, 'VipPurchaseSuccessPage');
    expect(purchaseSuccess.evidence, contains('normal success copy'));
    expect(purchaseSuccess.evidence, contains('post-payment benefit refresh'));
    expect(
      purchaseSuccess.evidence,
      contains('teacher customer-service action'),
    );
    expect(purchaseSuccess.evidence, contains('Mine-to-Home'));
    expect(
      purchaseSuccess.evidence,
      contains('source-specific fast/six/secret destinations'),
    );
    expect(
      purchaseSuccess.evidence,
      contains('unmigrated payment launchers pending'),
    );
    expect(practicePurchaseSuccess.status, ActivityMigrationStatus.partial);
    expect(
      practicePurchaseSuccess.flutterSurface,
      'BigSkillPracticePurchaseSuccessPage',
    );
    expect(practicePurchaseSuccess.evidence, contains('four benefit kinds'));
    expect(
      practicePurchaseSuccess.evidence,
      contains('post-payment benefit refresh'),
    );
    expect(practicePurchaseSuccess.evidence, contains('module fallback'));
    expect(
      practicePurchaseSuccess.evidence,
      contains('typed practice handoff'),
    );
    expect(practicePurchaseSuccess.evidence, contains('Home back intent'));
    expect(
      practicePurchaseSuccess.evidence,
      contains('Home marketing float payment entry pending'),
    );
    expect(
      practicePurchaseSuccess.evidence,
      contains('QuestionPackagePayDialog pending'),
    );
    expect(
      practicePurchaseSuccess.evidence,
      contains('circle-paper destination pending'),
    );
  });

  test('keeps excluded VIP payment surfaces pending', () {
    final purchasePayment = migrationProgressFor(
      'com.jx885.lrjk.cg.ui.activity.OpenVipMultiPayActivity',
      ActivityDisposition.flutterPage,
    );
    for (final activity in const [
      'com.jx885.lrjk.cg.ui.activity.OpenVipDaZhaoActivity',
      'com.jx885.lrjk.cg.ui.activity.VipDifferenceUpgradeActivity',
    ]) {
      final progress = migrationProgressFor(
        activity,
        ActivityDisposition.flutterPage,
      );
      expect(progress.status, ActivityMigrationStatus.pending);
      expect(progress.flutterSurface, isEmpty);
    }
    expect(purchasePayment.evidence, isNot(contains('VipPayPopup pending')));
    expect(purchasePayment.evidence, contains('OpenVipDaZhaoActivity pending'));
    expect(
      purchasePayment.evidence,
      contains('VipDifferenceUpgradeActivity pending'),
    );
  });

  test(
    'records the migrated practice modes without overstating the runner',
    () {
      final list = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.SkillMnemonicsActivity',
        ActivityDisposition.flutterPage,
      );
      final detail = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.SkillMnemonicsDetailActivity',
        ActivityDisposition.flutterPage,
      );
      final runner = migrationProgressFor(
        'com.jx885.lrjk.cg.learn.LearnActivity',
        ActivityDisposition.flutterPage,
      );
      final chapterCatalog = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.ChapterPracticeListActivity',
        ActivityDisposition.flutterPage,
      );
      final fastCatalog = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.Crash200QuestionListActivity',
        ActivityDisposition.flutterPage,
      );
      final fastLanding = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.FastLearnLandingActivity',
        ActivityDisposition.flutterPage,
      );
      final dailyDetail = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.DailySkillDetailActivity',
        ActivityDisposition.flutterPage,
      );
      final dailyReport = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.DailySkillReportActivity',
        ActivityDisposition.flutterPage,
      );
      final sixPaperLanding = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.PreExamSixPaperLandingActivity',
        ActivityDisposition.flutterPage,
      );
      final sixPaperPreview = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.PreExamSixPaperPreviewActivity',
        ActivityDisposition.flutterPage,
      );
      final smartCard = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.SmartCardActivity',
        ActivityDisposition.flutterPage,
      );
      final pastExams = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.PastExamsPaperListActivity',
        ActivityDisposition.flutterPage,
      );
      final secretPaperLanding = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.PreExamSecretPaperLandingActivity2',
        ActivityDisposition.flutterPage,
      );
      final settings = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.setting.SettingActivity',
        ActivityDisposition.flutterPage,
      );
      final privacySettings = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.setting.PrivacySettingActivity',
        ActivityDisposition.flutterPage,
      );
      final accountSettings = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.setting.AccountSettingActivity',
        ActivityDisposition.flutterPage,
      );
      final accountDeactivation = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.setting.AccountUnbindSettingActivity',
        ActivityDisposition.flutterPage,
      );
      final accountProfile = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.AccountActivityNew',
        ActivityDisposition.flutterPage,
      );
      final purchaseHistory = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.PurchaseHistoryActivity',
        ActivityDisposition.flutterPage,
      );
      final purchasePayment = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.OpenVipMultiPayActivity',
        ActivityDisposition.flutterPage,
      );
      final purchaseSuccess = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.VipPurchaseSuccessActivity',
        ActivityDisposition.flutterPage,
      );
      final practicePurchaseSuccess = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.BigSkillPracticePurchaseSuccessActivity',
        ActivityDisposition.flutterPage,
      );
      final dormantAccountDetails = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.setting.AccountDetailsSettingActivity',
        ActivityDisposition.flutterPage,
      );
      final dormantChangePhone = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.ChangePhoneActivity',
        ActivityDisposition.flutterPage,
      );
      final dormantSafeCheck = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.SafeCheckActivity',
        ActivityDisposition.flutterPage,
      );
      final dormantUnbind = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.UnbindActivity',
        ActivityDisposition.flutterPage,
      );
      final about = migrationProgressFor(
        'com.jx885.lrjk.ui.FrameLayoutActivity',
        ActivityDisposition.flutterPage,
      );
      final normalExam = migrationProgressFor(
        'com.jx885.lrjk.cg.learn.LearnActivityExam',
        ActivityDisposition.flutterPage,
      );
      final examResult = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.activity.BigSkillCircleResultActivity',
        ActivityDisposition.flutterPage,
      );
      final main = migrationProgressFor(
        'com.jx885.lrjk.cg.ui.MainActivity',
        ActivityDisposition.flutterPage,
      );

      expect(list.status, ActivityMigrationStatus.complete);
      expect(list.flutterSurface, 'SkillMnemonicsPage');
      expect(list.evidence, contains('repository and widget tests'));
      expect(detail.status, ActivityMigrationStatus.complete);
      expect(detail.flutterSurface, 'SkillMnemonicsDetailPage');
      expect(detail.evidence, contains('practice CTA'));
      expect(runner.status, ActivityMigrationStatus.partial);
      expect(runner.flutterSurface, 'PracticePage / PracticeResultPage');
      expect(runner.evidence, contains('normal mixed practice'));
      expect(runner.evidence, contains('skill-related questions'));
      expect(
        runner.evidence,
        contains('Mine error/collection review migrated'),
      );
      expect(runner.evidence, contains('collection editing migrated'));
      expect(runner.evidence, contains('wrong-question removal settings'));
      expect(runner.evidence, contains('Home error-review entry'));
      expect(runner.evidence, contains('chapter selection and resume'));
      expect(runner.evidence, contains('chapter-only redo'));
      expect(runner.evidence, contains('automatic next chapter'));
      expect(runner.evidence, contains('speed-practice leaf loading'));
      expect(runner.evidence, contains('flat position persistence'));
      expect(runner.evidence, contains('daily local restore'));
      expect(runner.evidence, contains('daily answer persistence'));
      expect(runner.evidence, contains('daily report routing'));
      expect(runner.evidence, isNot(contains('removal thresholds pending')));
      expect(runner.evidence, contains('exams'));
      expect(runner.evidence, contains('course'));
      expect(runner.evidence, isNot(contains('daily report, promotion')));
      expect(runner.evidence, contains('promotion/payment'));
      expect(runner.evidence, contains('audio'));
      expect(runner.evidence, contains('correction'));
      expect(chapterCatalog.status, ActivityMigrationStatus.complete);
      expect(chapterCatalog.flutterSurface, 'ChapterPracticePage');
      expect(chapterCatalog.evidence, contains('tree and record chunking'));
      expect(chapterCatalog.evidence, contains('preview locks'));
      expect(chapterCatalog.evidence, contains('completed chapter choices'));
      expect(fastCatalog.status, ActivityMigrationStatus.complete);
      expect(fastCatalog.flutterSurface, 'FastPracticeCatalogPage');
      expect(fastCatalog.evidence, contains('recursive leaf list'));
      expect(fastCatalog.evidence, contains('selected-leaf runner'));
      expect(fastLanding.status, ActivityMigrationStatus.partial);
      expect(fastLanding.flutterSurface, 'FastPracticeLandingPage');
      expect(fastLanding.evidence, contains('asset-backed landing'));
      expect(fastLanding.evidence, contains('popup source 1010'));
      expect(
        fastLanding.evidence,
        contains('confirmed-payment catalog transition'),
      );
      expect(fastLanding.evidence, isNot(contains('payment pending')));
      expect(dailyDetail.status, ActivityMigrationStatus.complete);
      expect(dailyDetail.flutterSurface, 'DailySkillDetailPage');
      expect(dailyDetail.evidence, contains('same-day progress'));
      expect(dailyReport.status, ActivityMigrationStatus.complete);
      expect(dailyReport.flutterSurface, 'DailySkillReportPage');
      expect(dailyReport.evidence, contains('six-column answer card'));
      expect(dailyReport.evidence, contains('read-only analysis'));
      expect(sixPaperLanding.status, ActivityMigrationStatus.partial);
      expect(sixPaperLanding.flutterSurface, 'PreExamSixPaperLandingPage');
      expect(sixPaperLanding.evidence, contains('asset-backed landing'));
      expect(sixPaperLanding.evidence, contains('full-screen source 1014'));
      expect(sixPaperLanding.evidence, contains('preview transition'));
      expect(sixPaperLanding.evidence, isNot(contains('payment pending')));
      expect(sixPaperPreview.status, ActivityMigrationStatus.complete);
      expect(sixPaperPreview.flutterSurface, 'PreExamSixPaperPreviewPage');
      expect(sixPaperPreview.evidence, contains('rich preview'));
      expect(sixPaperPreview.evidence, contains('download'));
      expect(sixPaperPreview.evidence, contains('Android system share'));
      expect(smartCard.status, ActivityMigrationStatus.partial);
      expect(smartCard.flutterSurface, 'SmartCardPage');
      expect(smartCard.evidence, contains('authoritative Android assets'));
      expect(smartCard.evidence, contains('three-card trial'));
      expect(smartCard.evidence, contains('locks'));
      expect(smartCard.evidence, contains('popup source 1013'));
      expect(smartCard.evidence, contains('post-payment entitlement refresh'));
      expect(smartCard.evidence, isNot(contains('payment pending')));
      expect(pastExams.status, ActivityMigrationStatus.partial);
      expect(pastExams.flutterSurface, 'PastExamsPage');
      expect(pastExams.evidence, contains('top-level flat catalog'));
      expect(pastExams.evidence, contains('two-paper free boundary'));
      expect(pastExams.evidence, contains('entitlement refresh'));
      expect(pastExams.evidence, contains('normal exam launch'));
      expect(pastExams.evidence, contains('popup source 1021'));
      expect(pastExams.evidence, isNot(contains('payment pending')));
      expect(secretPaperLanding.status, ActivityMigrationStatus.partial);
      expect(secretPaperLanding.flutterSurface, 'PreExamSecretPaperPage');
      expect(secretPaperLanding.evidence, contains('recursive leaf catalog'));
      expect(secretPaperLanding.evidence, contains('three-card landing'));
      expect(secretPaperLanding.evidence, contains('VIP gate'));
      expect(secretPaperLanding.evidence, contains('unlock refresh'));
      expect(secretPaperLanding.evidence, contains('normal exam launch'));
      expect(secretPaperLanding.evidence, contains('popup sources 1011/1012'));
      expect(secretPaperLanding.evidence, contains('skill default'));
      expect(secretPaperLanding.evidence, isNot(contains('payment pending')));
      expect(settings.status, ActivityMigrationStatus.partial);
      expect(settings.flutterSurface, 'SettingsPage');
      expect(settings.evidence, contains('notification preference'));
      expect(settings.evidence, contains('cache clearing'));
      expect(settings.evidence, contains('privacy and about routing'));
      expect(settings.evidence, contains('account safety and deactivation'));
      expect(settings.evidence, isNot(contains('account safety pending')));
      expect(settings.evidence, contains('JPush runtime pending'));
      expect(privacySettings.status, ActivityMigrationStatus.complete);
      expect(privacySettings.flutterSurface, 'PrivacySettingsPage');
      expect(privacySettings.evidence, contains('personalization preference'));
      expect(privacySettings.evidence, contains('privacy policy'));
      expect(accountSettings.status, ActivityMigrationStatus.complete);
      expect(accountSettings.flutterSurface, 'AccountSafetyPage');
      expect(accountSettings.evidence, contains('read-only masked phone'));
      expect(accountSettings.evidence, contains('hidden WeChat'));
      expect(accountDeactivation.status, ActivityMigrationStatus.complete);
      expect(accountDeactivation.flutterSurface, 'AccountDeactivationPage');
      expect(accountDeactivation.evidence, contains('typed confirmation'));
      expect(accountDeactivation.evidence, contains('legacy session cleanup'));
      expect(accountProfile.status, ActivityMigrationStatus.complete);
      expect(accountProfile.flutterSurface, 'AccountProfilePage');
      expect(accountProfile.evidence, contains('read-only avatar'));
      expect(accountProfile.evidence, contains('account ID copy'));
      expect(accountProfile.evidence, contains('fire-and-forget logout'));
      expect(accountProfile.evidence, contains('anonymous session refresh'));
      expect(purchaseHistory.status, ActivityMigrationStatus.complete);
      expect(purchaseHistory.flutterSurface, 'PurchaseHistoryPage');
      expect(purchaseHistory.evidence, contains('getMyOrder'));
      expect(purchaseHistory.evidence, contains('stable newest-first'));
      expect(purchaseHistory.evidence, contains('order ID copy'));
      expect(purchaseHistory.evidence, contains('pull refresh'));
      expect(purchasePayment.status, ActivityMigrationStatus.partial);
      expect(purchasePayment.flutterSurface, 'VipPurchasePage');
      expect(purchasePayment.evidence, contains('Mine full-screen selection'));
      expect(purchasePayment.evidence, contains('product/SKU requests'));
      expect(purchasePayment.evidence, contains('WeChat/Alipay checkout'));
      expect(purchaseSuccess.status, ActivityMigrationStatus.partial);
      expect(purchaseSuccess.flutterSurface, 'VipPurchaseSuccessPage');
      expect(purchaseSuccess.evidence, contains('normal success copy'));
      expect(
        purchaseSuccess.evidence,
        contains('post-payment benefit refresh'),
      );
      expect(
        purchaseSuccess.evidence,
        contains('teacher customer-service action'),
      );
      expect(purchaseSuccess.evidence, contains('Mine-to-Home'));
      expect(
        purchaseSuccess.evidence,
        contains('source-specific fast/six/secret destinations'),
      );
      expect(
        purchaseSuccess.evidence,
        contains('unmigrated payment launchers pending'),
      );
      expect(practicePurchaseSuccess.status, ActivityMigrationStatus.partial);
      expect(
        practicePurchaseSuccess.flutterSurface,
        'BigSkillPracticePurchaseSuccessPage',
      );
      expect(practicePurchaseSuccess.evidence, contains('four benefit kinds'));
      expect(practicePurchaseSuccess.evidence, contains('module fallback'));
      expect(
        practicePurchaseSuccess.evidence,
        contains('typed practice handoff'),
      );
      expect(
        practicePurchaseSuccess.evidence,
        contains('QuestionPackagePayDialog pending'),
      );
      expect(dormantAccountDetails.status, ActivityMigrationStatus.pending);
      expect(dormantAccountDetails.flutterSurface, isEmpty);
      expect(dormantChangePhone.status, ActivityMigrationStatus.pending);
      expect(dormantSafeCheck.status, ActivityMigrationStatus.pending);
      expect(dormantUnbind.status, ActivityMigrationStatus.pending);
      expect(about.status, ActivityMigrationStatus.partial);
      expect(about.flutterSurface, 'AboutPage');
      expect(about.evidence, contains('app identity'));
      expect(about.evidence, contains('agreement'));
      expect(about.evidence, contains('store rating'));
      expect(about.evidence, contains('mock-exam modes pending'));
      expect(normalExam.status, ActivityMigrationStatus.partial);
      expect(normalExam.flutterSurface, 'ExamPage / ExamReviewPage');
      expect(normalExam.evidence, contains('past-exam pageGoodsData'));
      expect(normalExam.evidence, contains('selection-only 135-minute timer'));
      expect(normalExam.evidence, contains('batch answer upload'));
      expect(normalExam.evidence, contains('secret-paper normal exam'));
      expect(normalExam.evidence, contains('other exam modes pending'));
      expect(examResult.status, ActivityMigrationStatus.partial);
      expect(examResult.flutterSurface, 'ExamResultPage');
      expect(examResult.evidence, contains('floored accuracy'));
      expect(examResult.evidence, contains('grouped six-column answer card'));
      expect(examResult.evidence, contains('all/wrong review'));
      expect(examResult.evidence, contains('prediction and payment pending'));
      expect(main.status, ActivityMigrationStatus.partial);
      expect(main.evidence, contains('daily skill destination'));
      expect(main.evidence, contains('pre-exam six-paper destination'));
      expect(main.evidence, contains('smart-card destination'));
      expect(main.evidence, contains('past-exams destination'));
      expect(main.evidence, contains('secret-paper destination'));
      expect(main.evidence, contains('Mine settings destination'));
      expect(main.evidence, contains('Mine profile and normal sign-out'));
      expect(main.evidence, contains('Mine purchase-history destination'));
      expect(main.evidence, contains('Mine customer-service action'));
      expect(main.evidence, contains('getWxCustomerUrl'));
      expect(main.evidence, contains('WeChat mini-program'));
      expect(main.evidence, contains('account-safety destination'));
      expect(main.evidence, contains('session refresh'));
      expect(main.evidence, contains('Mine VIP CTA and paid-result refresh'));
      expect(main.evidence, contains('other shared payment launchers pending'));
    },
  );

  test('escapes CSV values', () {
    const row = ActivityRegistration(
      source: 'a,b.xml',
      activityName: 'com.example.Activity',
      disposition: ActivityDisposition.flutterPage,
      progress: ActivityMigrationProgress(
        status: ActivityMigrationStatus.pending,
      ),
    );
    expect(row.toCsv(), '"a,b.xml",com.example.Activity,flutterPage,pending,,');
  });
}
