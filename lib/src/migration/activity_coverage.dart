enum ActivityDisposition { flutterPage, pluginCallback, sdkManaged, removed }

enum ActivityMigrationStatus { complete, partial, pending, external, removed }

final class ActivityMigrationProgress {
  const ActivityMigrationProgress({
    required this.status,
    this.flutterSurface = '',
    this.evidence = '',
  });

  final ActivityMigrationStatus status;
  final String flutterSurface;
  final String evidence;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ActivityMigrationProgress &&
            other.status == status &&
            other.flutterSurface == flutterSurface &&
            other.evidence == evidence;
  }

  @override
  int get hashCode => Object.hash(status, flutterSurface, evidence);
}

final class ActivityRegistration {
  const ActivityRegistration({
    required this.source,
    required this.activityName,
    required this.disposition,
    required this.progress,
  });

  final String source;
  final String activityName;
  final ActivityDisposition disposition;
  final ActivityMigrationProgress progress;

  String toCsv() => <String>[
    _csv(source),
    _csv(activityName),
    disposition.name,
    progress.status.name,
    _csv(progress.flutterSurface),
    _csv(progress.evidence),
  ].join(',');
}

const _removed = <String>{
  'com.jx885.lrjk.cg.ui.activity.BigSkillPaperPdfListActivity',
  'com.jx885.lrjk.cg.ui.activity.BigSkillPaperPdfListEntryActivity',
};

const _pluginCallbacks = <String>{
  'com.jx885.lrjk.cg.ui.BackFromAlipayActivity',
  'com.xmzj.ult.agg.wxapi.WXEntryActivity',
  'com.xmzj.ult.agg.wxapi.WXPayEntryActivity',
};

const _sdkManaged = <String>{
  'com.mobile.auth.gatewayauth.LoginAuthActivity',
  'com.mobile.auth.gatewayauth.activity.AuthWebVeiwActivity',
  'com.cmic.sso.sdk.activity.LoginAuthActivity',
};

const _reviewedProgress = <String, ActivityMigrationProgress>{
  'com.jx885.lrjk.cg.ui.SplashActivity': ActivityMigrationProgress(
    status: ActivityMigrationStatus.complete,
    flutterSurface: 'StartupApp / StartupSplashPage',
    evidence: 'startup coordinator and splash widget tests',
  ),
  'com.jx885.lrjk.cg.ui.MainActivity': ActivityMigrationProgress(
    status: ActivityMigrationStatus.partial,
    flutterSurface: 'MainTabsPage',
    evidence:
        'three-tab shell and daily skill destination migrated; pre-exam '
        'six-paper destination migrated; smart-card destination migrated; '
        'past-exams destination migrated; secret-paper destination migrated; '
        'Mine settings destination migrated; Mine profile and normal sign-out '
        'migrated; Mine purchase-history destination migrated; account-safety '
        'destination and deactivation session refresh migrated; Mine '
        'customer-service action migrated with signed getWxCustomerUrl '
        'fallback and WeChat mini-program bridge; Mine collect-book H5 route '
        'migrated; Mine invite-friends H5 route migrated; hidden '
        'learning-guide row preserved; manual Mine app-version check and '
        'update handoff migrated; privacy-gated cold-ready and foreground '
        'proactive app-version checks migrated with shared 30-minute '
        'throttle and 15-second/3-second secondary splash; Mine VIP CTA and '
        'paid-result refresh migrated; learning-material commodity payment, '
        'document WeChat share, and pay-jump routing migrated; invite H5 '
        'promotion poster sharing migrated; remaining business destinations and '
        'other shared payment launchers pending',
  ),
  'com.jx885.lrjk.cg.ui.activity.AgreeDialogActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.complete,
        flutterSurface: 'PrivacyConsentDialog',
        evidence: 'privacy consent widget and startup flow tests',
      ),
  'com.jx885.lrjk.cg.ui.activity.LoginActivity': ActivityMigrationProgress(
    status: ActivityMigrationStatus.partial,
    flutterSurface: 'PhoneLoginPage',
    evidence: 'phone captcha login migrated; alternate login modes pending',
  ),
  'com.jx885.lrjk.cg.ui.activity.CustomOnekeyLoginActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.partial,
        flutterSurface: 'PhoneLoginPage',
        evidence: 'phone captcha login migrated; carrier one-key flow pending',
      ),
  'com.jx885.lrjk.cg.ui.activity.AccountActivityNew': ActivityMigrationProgress(
    status: ActivityMigrationStatus.complete,
    flutterSurface: 'AccountProfilePage',
    evidence:
        'read-only avatar and username, account ID copy, exact '
        'fire-and-forget logout, hardened legacy session cleanup, and '
        'anonymous session refresh covered by tests',
  ),
  'com.jx885.lrjk.cg.ui.activity.PurchaseHistoryActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.complete,
        flutterSurface: 'PurchaseHistoryPage',
        evidence:
            'signed getMyOrder request and endpoint success codes, stable '
            'newest-first order cards, empty and error states, pull refresh, '
            'and order ID copy covered by tests',
      ),
  'com.jx885.lrjk.cg.ui.activity.BigSkillPracticePurchaseSuccessActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.partial,
        flutterSurface: 'BigSkillPracticePurchaseSuccessPage',
        evidence:
            'four benefit kinds, post-payment benefit refresh, Android success '
            'copy and asset, selected-market module fallback, typed practice '
            'handoff with benefit kind and circle module, and Home back intent '
            'covered by tests; Home marketing float payment entry pending; '
            'QuestionPackagePayDialog pending; circle-paper destination '
            'pending',
      ),
  'com.jx885.lrjk.cg.ui.activity.OpenVipMultiPayActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.partial,
        flutterSurface: 'VipPurchasePage',
        evidence:
            'Mine full-screen selection, six-paper full-screen entry, '
            'VipPaySheet popup, product/SKU requests, visible privileges and '
            'marketing, login gate, and native WeChat/Alipay checkout '
            'migrated; shared checkout coordination, WeChat server-status '
            'confirmation, post-payment success routes, and paid-result '
            'entitlement refresh covered by tests; difference-upgrade '
            'eligibility, deduction checkout, normal-purchase fallback, and '
            'source IDs 2001-2008 migrated; OpenVipDaZhaoActivity pending; '
            'other locked-feature payment launchers pending',
      ),
  'com.jx885.lrjk.cg.ui.activity.VipDifferenceUpgradeActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.complete,
        flutterSurface: 'VipDifferenceUpgradePage',
        evidence:
            'practice-package eligibility, commodity query, server/local '
            'deduction, native checkout, paid success, and non-recursive '
            'normal purchase fallback covered by tests',
      ),
  'com.jx885.lrjk.cg.ui.activity.VipPurchaseSuccessActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.partial,
        flutterSurface: 'VipPurchaseSuccessPage',
        evidence:
            'normal success copy, post-payment benefit refresh, authoritative '
            'success asset, teacher customer-service action, Mine-to-Home '
            'completion, and source-specific fast/six/secret destinations '
            'covered by tests; other source behavior for unmigrated payment '
            'launchers pending',
      ),
  'com.jx885.lrjk.cg.ui.activity.WebViewActivity': ActivityMigrationProgress(
    status: ActivityMigrationStatus.partial,
    flutterSurface: 'AgreementWebViewPage',
    evidence: 'agreement web content migrated; generic web routes pending',
  ),
  'com.jx885.lrjk.ui.web.WebActivity': ActivityMigrationProgress(
    status: ActivityMigrationStatus.partial,
    flutterSurface: 'LegacyWebViewPage',
    evidence:
        'Mine collect-book route migrated; Mine invite-friends route migrated; '
        'invite openInviteShare JavaScript callback and promotion route '
        'migrated; generic payment pending; file chooser pending; media '
        'pending; other share and JavaScript callbacks pending',
  ),
  'com.jx885.lrjk.cg.ui.recommend.RecommendActivity': ActivityMigrationProgress(
    status: ActivityMigrationStatus.complete,
    flutterSurface: 'PromotionSharingPage',
    evidence:
        'poster API, invite URL normalization, profile overlay, native QR, '
        'WeChat friend/moments image share, gallery save, and link share '
        'covered by tests and Android compilation',
  ),
  'com.jx885.lrjk.cg.ui.recommend.ChangedRecommendActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.complete,
        flutterSurface: 'PromotionSharingPage profile editor',
        evidence: 'name and phone editing, limits, and native persistence',
      ),
  'com.jx885.lrjk.cg.ui.recommend.ChangePosterActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.complete,
        flutterSurface: 'PromotionSharingPage poster selector',
        evidence: 'visible remote poster templates and selection grid',
      ),
  'com.jx885.lrjk.cg.ui.activity.LearningMaterialsFeedActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.complete,
        flutterSurface: 'LearningMaterialsFeedPage',
        evidence:
            'shelves, pagination, document/video cards, direct commodity '
            'checkout, post-payment state, and pay-jump routing covered by tests',
      ),
  'com.jx885.lrjk.cg.ui.activity.DocumentDetailActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.complete,
        flutterSurface: 'LearningMaterialsDocumentDetailPage',
        evidence:
            'rich content, banner routing, Android-compatible share URL, and '
            'WeChat friend/moments share',
      ),
  'com.jx885.lrjk.cg.ui.activity.LearningVideoDetailActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.complete,
        flutterSurface: 'LearningMaterialsVideoDetailPage',
        evidence: 'video, cover, metadata, and rich-content detail surface',
      ),
  'com.jx885.lrjk.cg.learn.LearnActivity': ActivityMigrationProgress(
    status: ActivityMigrationStatus.partial,
    flutterSurface: 'PracticePage / PracticeResultPage',
    evidence:
        'normal mixed practice and skill-related questions migrated; Mine '
        'error/collection review migrated; collection editing migrated; '
        'wrong-question removal settings and Home error-review entry migrated; '
        'chapter selection and resume, chapter-only redo, and automatic next '
        'chapter migrated; speed-practice leaf loading and flat position '
        'persistence migrated; daily local restore, daily answer persistence, '
        'completion, and daily report routing migrated; exams, course, '
        'promotion practice UI/payment, media explanation playback, and text '
        'correction migrated; exams, course, and correction image attachments '
        'pending',
  ),
  'com.jx885.lrjk.cg.learn.LearnActivityExam': ActivityMigrationProgress(
    status: ActivityMigrationStatus.partial,
    flutterSurface: 'ExamPage / ExamReviewPage',
    evidence:
        'past-exam pageGoodsData request and secret-paper normal exam migrated; '
        'selection-only 135-minute timer, answer card, hand-in, batch answer '
        'upload, and read-only review migrated; driving, course, and other '
        'exam modes pending',
  ),
  'com.jx885.lrjk.cg.ui.activity.ChapterPracticeListActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.complete,
        flutterSurface: 'ChapterPracticePage',
        evidence:
            'tree and record chunking, progress and preview locks, persisted '
            'expansion, and completed chapter choices covered by repository '
            'and widget tests',
      ),
  'com.jx885.lrjk.cg.ui.activity.BigSkillCircleResultActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.partial,
        flutterSurface: 'ExamResultPage',
        evidence:
            'floored accuracy, elapsed time, grouped six-column answer card, '
            'and all/wrong review migrated; prediction and payment pending',
      ),
  'com.jx885.lrjk.cg.ui.activity.Crash200QuestionListActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.complete,
        flutterSurface: 'FastPracticeCatalogPage',
        evidence:
            'entitlement split, recursive leaf list, selected-leaf runner, '
            'records, and position tests',
      ),
  'com.jx885.lrjk.cg.ui.activity.FastLearnLandingActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.partial,
        flutterSurface: 'FastPracticeLandingPage',
        evidence:
            'asset-backed landing, popup source 1010, injectable unlock '
            'override, and confirmed-payment catalog transition covered by '
            'tests',
      ),
  'com.jx885.lrjk.cg.ui.activity.DailySkillDetailActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.complete,
        flutterSurface: 'DailySkillDetailPage',
        evidence:
            'detail repository, same-day progress, completed state, retry, and '
            'practice replacement covered by tests',
      ),
  'com.jx885.lrjk.cg.ui.activity.DailySkillReportActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.complete,
        flutterSurface: 'DailySkillReportPage',
        evidence:
            'statistics, six-column answer card, read-only analysis, and '
            'improvement routing covered by tests',
      ),
  'com.jx885.lrjk.cg.ui.activity.PreExamSixPaperLandingActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.partial,
        flutterSurface: 'PreExamSixPaperLandingPage',
        evidence:
            'asset-backed landing, attributed VIP full-screen source 1014, '
            'injectable unlock override, and confirmed-payment preview '
            'transition covered by tests',
      ),
  'com.jx885.lrjk.cg.ui.activity.PreExamSecretPaperLandingActivity2':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.partial,
        flutterSurface: 'PreExamSecretPaperPage',
        evidence:
            'recursive leaf catalog, authoritative bitmap three-card landing, '
            'VIP gate, popup sources 1011/1012 with skill default, unlock '
            'refresh, and normal exam launch covered by tests',
      ),
  'com.jx885.lrjk.cg.ui.activity.PreExamSixPaperPreviewActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.complete,
        flutterSurface: 'PreExamSixPaperPreviewPage',
        evidence:
            'prefetched and on-demand rich preview, cache download, and '
            'Android system share covered by tests',
      ),
  'com.jx885.lrjk.cg.ui.activity.PastExamsPaperListActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.partial,
        flutterSurface: 'PastExamsPage',
        evidence:
            'top-level flat catalog, past-exams entitlement, two-paper free '
            'boundary, post-purchase entitlement refresh, and normal exam '
            'launch migrated; popup source 1021 and in-place post-payment '
            'refresh covered by tests',
      ),
  'com.jx885.lrjk.cg.ui.activity.SmartCardActivity': ActivityMigrationProgress(
    status: ActivityMigrationStatus.partial,
    flutterSurface: 'SmartCardPage',
    evidence:
        'authoritative Android assets, page-goods cards, three-card trial '
        'boundary, locks, and injectable unlock boundary migrated; popup '
        'source 1013 and post-payment entitlement refresh covered by tests',
  ),
  'com.jx885.lrjk.cg.ui.setting.SettingActivity': ActivityMigrationProgress(
    status: ActivityMigrationStatus.partial,
    flutterSurface: 'SettingsPage',
    evidence:
        'notification preference, cache clearing, and privacy and about routing '
        'migrated; account safety and deactivation migrated; hidden logout row '
        'preserved; JPush runtime pending',
  ),
  'com.jx885.lrjk.cg.ui.setting.AccountSettingActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.complete,
        flutterSurface: 'AccountSafetyPage',
        evidence:
            'read-only masked phone and deactivation entry migrated; hidden '
            'WeChat and disabled phone actions preserved',
      ),
  'com.jx885.lrjk.cg.ui.setting.AccountUnbindSettingActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.complete,
        flutterSurface: 'AccountDeactivationPage',
        evidence:
            'notice, two-stage typed confirmation, exact remote deactivation, '
            'legacy session cleanup, and anonymous session refresh covered by '
            'tests',
      ),
  'com.jx885.lrjk.cg.ui.setting.PrivacySettingActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.complete,
        flutterSurface: 'PrivacySettingsPage',
        evidence:
            'personalization preference persistence and privacy policy routing '
            'covered by tests',
      ),
  'com.jx885.lrjk.ui.FrameLayoutActivity': ActivityMigrationProgress(
    status: ActivityMigrationStatus.partial,
    flutterSurface: 'AboutPage',
    evidence:
        'app identity, agreement links, store rating, error feedback, and ICP '
        'handoff migrated; mock-exam modes pending',
  ),
  'com.jx885.lrjk.cg.ui.activity.SkillMnemonicsActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.complete,
        flutterSurface: 'SkillMnemonicsPage',
        evidence: 'page-goods repository and widget tests',
      ),
  'com.jx885.lrjk.cg.ui.activity.SkillMnemonicsDetailActivity':
      ActivityMigrationProgress(
        status: ActivityMigrationStatus.complete,
        flutterSurface: 'SkillMnemonicsDetailPage',
        evidence: 'detail, countdown, and practice CTA navigation tests',
      ),
};

ActivityDisposition classifyActivity(String activityName) {
  if (_removed.contains(activityName)) return ActivityDisposition.removed;
  if (_pluginCallbacks.contains(activityName)) {
    return ActivityDisposition.pluginCallback;
  }
  if (_sdkManaged.contains(activityName)) {
    return ActivityDisposition.sdkManaged;
  }
  return ActivityDisposition.flutterPage;
}

ActivityMigrationProgress migrationProgressFor(
  String activityName,
  ActivityDisposition disposition,
) {
  if (disposition == ActivityDisposition.removed) {
    return const ActivityMigrationProgress(
      status: ActivityMigrationStatus.removed,
      evidence: 'approved removal',
    );
  }
  if (disposition == ActivityDisposition.pluginCallback ||
      disposition == ActivityDisposition.sdkManaged) {
    return const ActivityMigrationProgress(
      status: ActivityMigrationStatus.external,
      evidence: 'owned by Android plugin or SDK',
    );
  }
  return _reviewedProgress[activityName] ??
      const ActivityMigrationProgress(status: ActivityMigrationStatus.pending);
}

List<ActivityRegistration> parseActivityRegistrations({
  required String source,
  required String xml,
}) {
  final withoutValidComments = xml.replaceAll(
    RegExp(r'<!--[\s\S]*?-->', multiLine: true),
    '',
  );
  final packageMatch = RegExp(
    r'package\s*=\s*"([^"]+)"',
  ).firstMatch(withoutValidComments);
  final packageName = packageMatch?.group(1) ?? '';
  final activityPattern = RegExp(
    r'<activity(?=\s)[\s\S]*?android:name\s*=\s*"([^"]+)"',
    multiLine: true,
  );

  return activityPattern
      .allMatches(withoutValidComments)
      .map((match) {
        final rawName = match.group(1)!;
        final fullName = switch (rawName) {
          final name when name.startsWith('.') => '$packageName$name',
          final name when name.contains('.') => name,
          final name => '$packageName.$name',
        };
        final disposition = classifyActivity(fullName);
        return ActivityRegistration(
          source: source,
          activityName: fullName,
          disposition: disposition,
          progress: migrationProgressFor(fullName, disposition),
        );
      })
      .toList(growable: false);
}

String _csv(String value) {
  if (!value.contains(RegExp('[,"\\n\\r]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}
