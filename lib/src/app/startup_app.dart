import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../account_profile/account_profile_data_source.dart';
import '../account_profile/account_profile_models.dart';
import '../account_profile/account_profile_page.dart';
import '../account_profile/account_sign_out_gateway.dart';
import '../account_safety/account_deactivation_gateway.dart';
import '../account_safety/account_deactivation_page.dart';
import '../account_safety/account_safety_data_source.dart';
import '../account_safety/account_safety_models.dart';
import '../account_safety/account_safety_page.dart';
import '../app_update/app_update_dialog.dart';
import '../app_update/app_update_file_transfer.dart';
import '../app_update/app_update_models.dart';
import '../app_update/app_update_repository.dart';
import '../authentication/phone_login_page.dart';
import '../chapter_practice/chapter_practice_page.dart';
import '../chapter_practice/chapter_practice_progress_store.dart';
import '../chapter_practice/chapter_practice_repository.dart';
import '../customer_service/customer_service_data_source.dart';
import '../customer_service/customer_service_launcher.dart';
import '../daily_skill/daily_skill_detail_page.dart';
import '../daily_skill/daily_skill_models.dart';
import '../daily_skill/daily_skill_progress_store.dart';
import '../daily_skill/daily_skill_report_page.dart';
import '../daily_skill/daily_skill_repository.dart';
import '../fast_practice/fast_practice_entry_page.dart';
import '../fast_practice/fast_practice_landing_page.dart';
import '../fast_practice/fast_practice_repository.dart';
import '../exam/exam_models.dart';
import '../exam/exam_page.dart';
import '../exam/exam_repository.dart';
import '../exam/exam_result_page.dart';
import '../learning_materials/learning_materials_feed_page.dart';
import '../learning_materials/learning_materials_home_section.dart';
import '../learning_materials/learning_materials_models.dart';
import '../learning_materials/learning_materials_navigation.dart';
import '../learning_materials/learning_materials_repository.dart';
import '../main_tabs/home_module_route.dart';
import '../main_tabs/main_tabs_models.dart';
import '../main_tabs/main_tabs_page.dart';
import '../main_tabs/main_tabs_repository.dart';
import '../main_tabs/mine_tab_page.dart';
import '../media/html5_video_player.dart';
import '../network/app_api_client.dart';
import '../network/method_channel_request_context.dart';
import '../practice/practice_page.dart';
import '../practice/flat_practice_progress_store.dart';
import '../practice/practice_repository.dart';
import '../practice/practice_settings_store.dart';
import '../past_exams/past_exams_page.dart';
import '../past_exams/past_exams_repository.dart';
import '../pre_exam_six_paper/pre_exam_six_paper_entry_page.dart';
import '../pre_exam_six_paper/pre_exam_six_paper_file_transfer.dart';
import '../pre_exam_six_paper/pre_exam_six_paper_landing_page.dart';
import '../pre_exam_six_paper/pre_exam_six_paper_preview_page.dart';
import '../pre_exam_six_paper/pre_exam_six_paper_repository.dart';
import '../pre_exam_secret_paper/pre_exam_secret_paper_page.dart';
import '../pre_exam_secret_paper/pre_exam_secret_paper_repository.dart';
import '../purchase_history/purchase_history_data_source.dart';
import '../purchase_history/purchase_history_page.dart';
import '../promotion_sharing/promotion_share_gateway.dart';
import '../promotion_sharing/promotion_sharing_page.dart';
import '../promotion_sharing/promotion_sharing_repository.dart';
import '../settings/settings_data_source.dart';
import '../settings/settings_navigation.dart';
import '../settings/settings_page.dart';
import '../startup/method_channel_startup_consent_store.dart';
import '../startup/privacy_consent_dialog.dart';
import '../startup/startup_coordinator.dart';
import '../startup/startup_remote_initializer.dart';
import '../startup/startup_splash_page.dart';
import '../teacher_course/teacher_course_page.dart';
import '../teacher_course/course_video_player_page.dart';
import '../teacher_course/teacher_course_progress_store.dart';
import '../teacher_course/teacher_course_repository.dart';
import '../skill_mnemonics/skill_mnemonics_detail_page.dart';
import '../skill_mnemonics/skill_mnemonics_models.dart';
import '../skill_mnemonics/skill_mnemonics_page.dart';
import '../skill_mnemonics/skill_mnemonics_repository.dart';
import '../smart_card/smart_card_entry_page.dart';
import '../smart_card/smart_card_models.dart';
import '../smart_card/smart_card_page.dart';
import '../smart_card/smart_card_repository.dart';
import '../vip_purchase/vip_difference_upgrade_page.dart';
import '../vip_purchase/vip_difference_upgrade_repository.dart';
import '../vip_purchase/vip_checkout_coordinator.dart';
import '../vip_purchase/vip_pay_sheet.dart';
import '../vip_purchase/vip_payment_gateway.dart';
import '../vip_purchase/vip_purchase_models.dart';
import '../vip_purchase/vip_purchase_page.dart';
import '../vip_purchase/vip_purchase_repository.dart';
import '../vip_purchase/vip_purchase_success_page.dart';
import '../web/agreement_webview_page.dart';
import '../web/legacy_webview_page.dart';

typedef StartupVipPaySheetLauncher =
    Future<VipPurchaseResult?> Function(
      BuildContext context,
      VipPayEntry entry,
    );

final class StartupApp extends StatefulWidget {
  const StartupApp({
    this.consentStore,
    this.initializer,
    this.delay,
    this.lifecycleNowMillis,
    this.secondarySplashDelay,
    this.appUpdateDataSource,
    this.appUpdateFileTransfer,
    this.mainTabsDataSource,
    this.learningMaterialsDataSource,
    this.learningMaterialsHtmlContentBuilder,
    this.learningMaterialsVideoContentBuilder,
    this.learningMaterialsPaymentCallback,
    this.learningMaterialsShareCallback,
    this.learningMaterialsBannerCallback,
    this.promotionSharingDataSource,
    this.promotionShareGateway,
    this.teacherCourseDataSource,
    this.teacherCourseProgressStore,
    this.teacherCourseVideoContentBuilder,
    this.skillMnemonicsDataSource,
    this.chapterPracticeDataSource,
    this.chapterPracticeProgressStore,
    this.customerServiceDataSource,
    this.customerServiceGateway,
    this.dailySkillDataSource,
    this.dailySkillProgressStore,
    this.fastPracticeDataSource,
    this.fastPracticeUnlockLauncher,
    this.flatPracticeProgressStore,
    this.practiceDataSource,
    this.preExamSixPaperDataSource,
    this.preExamSixPaperFileTransfer,
    this.preExamSixPaperContentBuilder,
    this.preExamSixPaperUnlockLauncher,
    this.preExamSecretPaperDataSource,
    this.preExamSecretPaperUnlockLauncher,
    this.smartCardDataSource,
    this.smartCardUnlockLauncher,
    this.pastExamsDataSource,
    this.examDataSource,
    this.pastExamsUnlockLauncher,
    this.examImproveLauncher,
    this.settingsDataSource,
    this.accountProfileDataSource,
    this.mineProfileLauncher,
    this.mineWebContentBuilder,
    this.purchaseHistoryDataSource,
    this.vipPurchaseDataSource,
    this.vipDifferenceUpgradeDataSource,
    this.vipCommodityOrderDataSource,
    this.vipPaymentGateway,
    this.vipPaySheetLauncher,
    this.accountSafetyDataSource,
    this.settingsAccountSafetyLauncher,
    this.agreementContentBuilder,
    this.onOpenDocument,
    this.onExit,
    super.key,
  });

  final StartupConsentStore? consentStore;
  final StartupPostConsentInitializer? initializer;
  final StartupDelay? delay;
  final int Function()? lifecycleNowMillis;
  final StartupDelay? secondarySplashDelay;
  final AppUpdateDataSource? appUpdateDataSource;
  final AppUpdateFileTransfer? appUpdateFileTransfer;
  final MainTabsDataSource? mainTabsDataSource;
  final LearningMaterialsDataSource? learningMaterialsDataSource;
  final LearningMaterialsHtmlContentBuilder?
  learningMaterialsHtmlContentBuilder;
  final LearningMaterialsVideoContentBuilder?
  learningMaterialsVideoContentBuilder;
  final LearningMaterialsPaymentCallback? learningMaterialsPaymentCallback;
  final LearningMaterialsShareCallback? learningMaterialsShareCallback;
  final LearningMaterialsBannerCallback? learningMaterialsBannerCallback;
  final PromotionSharingDataSource? promotionSharingDataSource;
  final PromotionShareGateway? promotionShareGateway;
  final TeacherCourseDataSource? teacherCourseDataSource;
  final TeacherCourseProgressStore? teacherCourseProgressStore;
  final Html5VideoContentBuilder? teacherCourseVideoContentBuilder;
  final SkillMnemonicsDataSource? skillMnemonicsDataSource;
  final ChapterPracticeDataSource? chapterPracticeDataSource;
  final ChapterPracticeProgressStore? chapterPracticeProgressStore;
  final CustomerServiceDataSource? customerServiceDataSource;
  final CustomerServiceMiniProgramGateway? customerServiceGateway;
  final DailySkillDataSource? dailySkillDataSource;
  final DailySkillProgressDataSource? dailySkillProgressStore;
  final FastPracticeDataSource? fastPracticeDataSource;
  final FastPracticeUnlockLauncher? fastPracticeUnlockLauncher;
  final FlatPracticeProgressStore? flatPracticeProgressStore;
  final PracticeDataSource? practiceDataSource;
  final PreExamSixPaperDataSource? preExamSixPaperDataSource;
  final PreExamSixPaperFileTransfer? preExamSixPaperFileTransfer;
  final PreExamSixPaperContentBuilder? preExamSixPaperContentBuilder;
  final PreExamSixPaperUnlockLauncher? preExamSixPaperUnlockLauncher;
  final PreExamSecretPaperDataSource? preExamSecretPaperDataSource;
  final PreExamSecretPaperUnlockLauncher? preExamSecretPaperUnlockLauncher;
  final SmartCardDataSource? smartCardDataSource;
  final SmartCardUnlockLauncher? smartCardUnlockLauncher;
  final PastExamsDataSource? pastExamsDataSource;
  final ExamDataSource? examDataSource;
  final PastExamsUnlockLauncher? pastExamsUnlockLauncher;
  final ExamImproveLauncher? examImproveLauncher;
  final SettingsDataSource? settingsDataSource;
  final AccountProfileDataSource? accountProfileDataSource;
  final MineProfileLauncher? mineProfileLauncher;
  final LegacyWebContentBuilder? mineWebContentBuilder;
  final PurchaseHistoryDataSource? purchaseHistoryDataSource;
  final VipPurchaseDataSource? vipPurchaseDataSource;
  final VipDifferenceUpgradeDataSource? vipDifferenceUpgradeDataSource;
  final VipCommodityOrderDataSource? vipCommodityOrderDataSource;
  final VipPaymentGateway? vipPaymentGateway;
  final StartupVipPaySheetLauncher? vipPaySheetLauncher;
  final AccountSafetyDataSource? accountSafetyDataSource;
  final SettingsAccountSafetyLauncher? settingsAccountSafetyLauncher;
  final AgreementWebContentBuilder? agreementContentBuilder;
  final ValueChanged<AgreementDocument>? onOpenDocument;
  final VoidCallback? onExit;

  @override
  State<StartupApp> createState() => _StartupAppState();
}

final class _StartupAppState extends State<StartupApp>
    with WidgetsBindingObserver {
  static const _secondarySplashThreshold = Duration(seconds: 15);
  static const _secondarySplashDuration = Duration(seconds: 3);

  late final StartupConsentStore _consentStore =
      widget.consentStore ?? MethodChannelStartupConsentStore();
  late final int Function() _lifecycleNowMillis =
      widget.lifecycleNowMillis ?? _currentTimeMillis;
  late final StartupDelay _secondarySplashDelay =
      widget.secondarySplashDelay ?? Future<void>.delayed;
  late final StartupCoordinator _coordinator;
  late final AppUpdateDataSource _appUpdateDataSource;
  late final AppUpdateFileTransfer _appUpdateFileTransfer;
  late final MainTabsDataSource _mainTabsDataSource;
  late final LearningMaterialsDataSource _learningMaterialsDataSource;
  late final PromotionSharingDataSource _promotionSharingDataSource;
  late final PromotionShareGateway _promotionShareGateway;
  late final TeacherCourseDataSource _teacherCourseDataSource;
  late final TeacherCourseProgressStore _teacherCourseProgressStore;
  late final SkillMnemonicsDataSource _skillMnemonicsDataSource;
  late final ChapterPracticeDataSource _chapterPracticeDataSource;
  late final ChapterPracticeProgressStore _chapterPracticeProgressStore;
  late final CustomerServiceCoordinator _customerServiceCoordinator;
  late final DailySkillDataSource _dailySkillDataSource;
  late final DailySkillProgressDataSource _dailySkillProgressStore;
  late final FastPracticeDataSource _fastPracticeDataSource;
  late final FlatPracticeProgressStore _flatPracticeProgressStore;
  late final PracticeDataSource _practiceDataSource;
  late final PracticeSettingsStore _practiceSettingsStore;
  late final PreExamSixPaperDataSource _preExamSixPaperDataSource;
  late final PreExamSixPaperFileTransfer _preExamSixPaperFileTransfer;
  late final PreExamSecretPaperDataSource _preExamSecretPaperDataSource;
  late final SmartCardDataSource _smartCardDataSource;
  late final PastExamsDataSource _pastExamsDataSource;
  late final ExamDataSource _examDataSource;
  late final SettingsDataSource _settingsDataSource;
  late final AccountProfileDataSource _accountProfileDataSource;
  late final PurchaseHistoryDataSource _purchaseHistoryDataSource;
  late final VipPurchaseDataSource _vipPurchaseDataSource;
  late final VipDifferenceUpgradeDataSource _vipDifferenceUpgradeDataSource;
  late final VipCommodityOrderDataSource _vipCommodityOrderDataSource;
  late final VipPaymentGateway _vipPaymentGateway;
  late final AccountSafetyDataSource _accountSafetyDataSource;
  final _navigatorKey = GlobalKey<NavigatorState>();
  int _mainTabsRevision = 0;
  StartupPhase _phase = StartupPhase.checkingConsent;
  Object? _startupError;
  bool _proactiveAppUpdateInFlight = false;
  bool _vipPaymentInFlight = false;
  int? _backgroundedAtMillis;
  bool _showSecondarySplash = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final requestContext = MethodChannelRequestContext();
    _practiceSettingsStore = requestContext;
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    final apiClient = DioAppApiClient(
      dio: dio,
      apiBaseUrl: requestContext.apiBaseUrl,
      headers: requestContext.headers,
    );
    _appUpdateDataSource =
        widget.appUpdateDataSource ??
        AppApiAppUpdateDataSource(
          api: apiClient,
          stateStore: requestContext,
          persistCheckTimestamp: requestContext.persistAppUpdateCheckTimestamp,
        );
    _appUpdateFileTransfer =
        widget.appUpdateFileTransfer ??
        DioAppUpdateFileTransfer(
          dio: dio,
          nativeBridge: MethodChannelAppUpdateNativeBridge(),
        );
    _customerServiceCoordinator = CustomerServiceCoordinator(
      dataSource:
          widget.customerServiceDataSource ??
          AppApiCustomerServiceDataSource(api: apiClient),
      gateway:
          widget.customerServiceGateway ??
          MethodChannelCustomerServiceGateway(),
    );
    _mainTabsDataSource =
        widget.mainTabsDataSource ??
        MainTabsRepository(
          api: apiClient,
          stateStore: requestContext,
          persistMineReferralProfile: requestContext.persistMineReferralProfile,
        );
    _learningMaterialsDataSource =
        widget.learningMaterialsDataSource ??
        LearningMaterialsRepository(api: apiClient, stateStore: requestContext);
    _promotionSharingDataSource =
        widget.promotionSharingDataSource ??
        PromotionSharingRepository(api: apiClient, stateStore: requestContext);
    _promotionShareGateway =
        widget.promotionShareGateway ?? MethodChannelPromotionShareGateway();
    _teacherCourseDataSource =
        widget.teacherCourseDataSource ??
        TeacherCourseRepository(api: apiClient, stateStore: requestContext);
    _teacherCourseProgressStore =
        widget.teacherCourseProgressStore ??
        MethodChannelTeacherCourseProgressStore();
    final defaultVipPurchaseRepository = VipPurchaseRepository(
      api: apiClient,
      stateStore: requestContext,
    );
    _vipPurchaseDataSource =
        widget.vipPurchaseDataSource ?? defaultVipPurchaseRepository;
    _vipCommodityOrderDataSource =
        widget.vipCommodityOrderDataSource ??
        (_vipPurchaseDataSource is VipCommodityOrderDataSource
            ? _vipPurchaseDataSource as VipCommodityOrderDataSource
            : defaultVipPurchaseRepository);
    _vipDifferenceUpgradeDataSource =
        widget.vipDifferenceUpgradeDataSource ??
        VipDifferenceUpgradeRepository(
          api: apiClient,
          purchaseDataSource: _vipPurchaseDataSource,
        );
    _vipPaymentGateway =
        widget.vipPaymentGateway ?? MethodChannelVipPaymentGateway();
    _skillMnemonicsDataSource =
        widget.skillMnemonicsDataSource ??
        SkillMnemonicsRepository(api: apiClient, stateStore: requestContext);
    _chapterPracticeProgressStore =
        widget.chapterPracticeProgressStore ?? requestContext;
    _chapterPracticeDataSource =
        widget.chapterPracticeDataSource ??
        ChapterPracticeRepository(api: apiClient, stateStore: requestContext);
    _dailySkillDataSource =
        widget.dailySkillDataSource ??
        DailySkillRepository(api: apiClient, stateStore: requestContext);
    _dailySkillProgressStore =
        widget.dailySkillProgressStore ??
        DailySkillProgressStore(persistence: requestContext);
    _fastPracticeDataSource =
        widget.fastPracticeDataSource ??
        FastPracticeRepository(api: apiClient, stateStore: requestContext);
    _flatPracticeProgressStore =
        widget.flatPracticeProgressStore ?? requestContext;
    _practiceDataSource =
        widget.practiceDataSource ??
        PracticeRepository(
          api: apiClient,
          stateStore: requestContext,
          reviewStore: requestContext,
          chapterDataSource: _chapterPracticeDataSource,
        );
    _preExamSixPaperDataSource =
        widget.preExamSixPaperDataSource ??
        PreExamSixPaperRepository(api: apiClient, stateStore: requestContext);
    _preExamSixPaperFileTransfer =
        widget.preExamSixPaperFileTransfer ??
        DioPreExamSixPaperFileTransfer(
          dio: dio,
          nativeBridge: MethodChannelPreExamSixPaperNativeBridge(),
        );
    _preExamSecretPaperDataSource =
        widget.preExamSecretPaperDataSource ??
        PreExamSecretPaperRepository(
          api: apiClient,
          stateStore: requestContext,
        );
    _smartCardDataSource =
        widget.smartCardDataSource ??
        SmartCardRepository(api: apiClient, stateStore: requestContext);
    _pastExamsDataSource =
        widget.pastExamsDataSource ??
        PastExamsRepository(api: apiClient, stateStore: requestContext);
    _examDataSource =
        widget.examDataSource ??
        ExamRepository(api: apiClient, stateStore: requestContext);
    _settingsDataSource =
        widget.settingsDataSource ?? MethodChannelSettingsDataSource();
    _accountProfileDataSource =
        widget.accountProfileDataSource ??
        AccountProfileRepository(
          remote: DioAccountSignOutGateway(
            dio: dio,
            apiBaseUrl: requestContext.apiBaseUrl,
            headers: requestContext.headers,
          ),
          nativeStore: MethodChannelAccountProfileNativeStore(),
          refreshDeviceSession: () async {
            await DeviceSessionInitializer(
              dio: dio,
              baseUrl: await requestContext.apiBaseUrl(),
              requestContext: requestContext,
            ).initialize();
          },
        );
    _purchaseHistoryDataSource =
        widget.purchaseHistoryDataSource ??
        DioPurchaseHistoryRepository(
          dio: dio,
          apiBaseUrl: requestContext.apiBaseUrl,
          headers: requestContext.headers,
        );
    _accountSafetyDataSource =
        widget.accountSafetyDataSource ??
        AccountSafetyRepository(
          remote: DioAccountDeactivationGateway(
            dio: dio,
            apiBaseUrl: requestContext.apiBaseUrl,
            headers: requestContext.headers,
          ),
          nativeStore: MethodChannelAccountSafetyNativeStore(),
          refreshDeviceSession: () async {
            await DeviceSessionInitializer(
              dio: dio,
              baseUrl: await requestContext.apiBaseUrl(),
              requestContext: requestContext,
            ).initialize();
          },
        );
    _coordinator = StartupCoordinator(
      consentStore: _consentStore,
      initializer:
          widget.initializer ??
          MethodChannelStartupInitializer(
            dio: dio,
            requestContext: requestContext,
          ),
      delay: widget.delay ?? Future<void>.delayed,
      onPhaseChanged: _handlePhaseChanged,
    );
    unawaited(_run(_coordinator.start));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _backgroundedAtMillis = _lifecycleNowMillis();
      case AppLifecycleState.resumed:
        final backgroundedAt = _backgroundedAtMillis;
        _backgroundedAtMillis = null;
        if (backgroundedAt == null || _phase != StartupPhase.ready) return;
        final elapsed = _lifecycleNowMillis() - backgroundedAt;
        unawaited(
          _checkForProactiveAppUpdate(
            showSecondarySplash:
                elapsed > _secondarySplashThreshold.inMilliseconds,
          ),
        );
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        return;
    }
  }

  void _handlePhaseChanged(StartupPhase phase) {
    if (mounted) {
      setState(() {
        _phase = phase;
        if (phase == StartupPhase.initializing) _startupError = null;
      });
      if (phase == StartupPhase.ready) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _phase == StartupPhase.ready) {
            unawaited(_checkForProactiveAppUpdate());
          }
        });
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _startupError = error);
    }
  }

  void _declinePrivacy() {
    _coordinator.declinePrivacy();
    (widget.onExit ?? SystemNavigator.pop)();
  }

  void _openAgreement(AgreementDocument document) {
    _navigatorKey.currentState?.push<void>(
      MaterialPageRoute(
        builder: (_) => AgreementWebViewPage(
          document: document,
          contentBuilder: widget.agreementContentBuilder,
        ),
      ),
    );
  }

  Future<void> _launchHomeModule(
    BuildContext context,
    HomeModule module,
    HomeModule? bigSkillCircleModule,
  ) async {
    final route = resolveHomeModuleRoute(module.page);
    switch (route) {
      case ReadyHomeModuleRoute(destination: HomeDestination.skillMnemonics):
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SkillMnemonicsPage(
              module: module,
              dataSource: _skillMnemonicsDataSource,
              detailLauncher: _openMnemonicDetail,
            ),
          ),
        );
      case ReadyHomeModuleRoute(destination: HomeDestination.teacherCourse):
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => TeacherCoursePage(
              module: module,
              dataSource: _teacherCourseDataSource,
              progressStore: _teacherCourseProgressStore,
              videoContentBuilder: widget.teacherCourseVideoContentBuilder,
            ),
          ),
        );
      case ReadyHomeModuleRoute(destination: HomeDestination.vipPurchase):
        await _openHomeVipPurchase(context);
      case ReadyHomeModuleRoute(destination: HomeDestination.practice):
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => PracticePage(
              request: ModulePracticeRequest(
                module: module,
                bigSkillCircleModule: bigSkillCircleModule,
              ),
              dataSource: _practiceDataSource,
              settingsStore: _practiceSettingsStore,
              customerServiceLauncher: () => _openCustomerService(context),
              paymentLauncher: _openPracticePayment,
            ),
          ),
        );
      case ReadyHomeModuleRoute(destination: HomeDestination.chapterPractice):
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => ChapterPracticePage(
              module: module,
              dataSource: _chapterPracticeDataSource,
              progressStore: _chapterPracticeProgressStore,
              practiceDataSource: _practiceDataSource,
              settingsStore: _practiceSettingsStore,
              paymentLauncher: _openPracticePayment,
              onUnlock: (unlockContext) async =>
                  await _openPracticePayment(
                    unlockContext,
                    VipPaymentSource.chapterOrPastExamsUnlock,
                  ) ==
                  VipPurchaseResult.paid,
            ),
          ),
        );
      case ReadyHomeModuleRoute(destination: HomeDestination.fastPractice):
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => FastPracticeEntryPage(
              module: module,
              dataSource: _fastPracticeDataSource,
              practiceDataSource: _practiceDataSource,
              flatProgressStore: _flatPracticeProgressStore,
              settingsStore: _practiceSettingsStore,
              paymentLauncher: _openPracticePayment,
              onUnlock:
                  widget.fastPracticeUnlockLauncher ??
                  () => _openVipPaySheet(context, VipPayEntry.fast300),
            ),
          ),
        );
      case ReadyHomeModuleRoute(destination: HomeDestination.dailySkill):
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => DailySkillDetailPage(
              module: module,
              dataSource: _dailySkillDataSource,
              progressStore: _dailySkillProgressStore,
              practiceLauncher: _openDailySkillPractice,
              improveLauncher: _openDailySkillImprove,
            ),
          ),
        );
      case ReadyHomeModuleRoute(destination: HomeDestination.preExamSixPaper):
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => PreExamSixPaperEntryPage(
              module: module,
              dataSource: _preExamSixPaperDataSource,
              fileTransfer: _preExamSixPaperFileTransfer,
              contentBuilder: widget.preExamSixPaperContentBuilder,
              onUnlock:
                  widget.preExamSixPaperUnlockLauncher ??
                  () => _openVipPurchasePage(
                    context,
                    VipPayEntry.preExamSixPaper,
                  ),
            ),
          ),
        );
      case ReadyHomeModuleRoute(
        destination: HomeDestination.preExamSecretPaper,
      ):
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => PreExamSecretPaperPage(
              module: module,
              dataSource: _preExamSecretPaperDataSource,
              examLauncher: _openNormalExam,
              onUnlock:
                  widget.preExamSecretPaperUnlockLauncher ??
                  (source) async {
                    await _openVipPaySheet(context, switch (source) {
                      PreExamSecretPaperUnlockSource.lockedCard =>
                        VipPayEntry.secretPaperList,
                      PreExamSecretPaperUnlockSource.bottomAction =>
                        VipPayEntry.secretPaperBottom,
                    }, defaultProductType: VipProductType.skill);
                  },
            ),
          ),
        );
      case ReadyHomeModuleRoute(destination: HomeDestination.smartCard):
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SmartCardEntryPage(
              request: SmartCardRequest(module: module),
              dataSource: _smartCardDataSource,
              onUnlock:
                  widget.smartCardUnlockLauncher ??
                  () async {
                    await _openVipPaySheet(context, VipPayEntry.smartCard);
                  },
            ),
          ),
        );
      case ReadyHomeModuleRoute(destination: HomeDestination.pastExams):
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => PastExamsPage(
              module: module,
              dataSource: _pastExamsDataSource,
              examLauncher: _openNormalExam,
              onUnlock:
                  widget.pastExamsUnlockLauncher ??
                  () async {
                    await _openVipPaySheet(context, VipPayEntry.pastExams);
                  },
            ),
          ),
        );
      case ReadyHomeModuleRoute(destination: HomeDestination.learningMaterials):
        await _openLearningMaterialsModule(context, module);
      case ReadyHomeModuleRoute(destination: HomeDestination.errorReview):
        await _openHomeErrorReview(context);
      case PendingHomeModuleRoute(:final canonicalPage):
        _showModuleMessage(context, '$canonicalPage功能仍在迁移中');
      case UnsupportedHomeModuleRoute(reason: HomeRouteFailure.empty):
        _showModuleMessage(context, '暂无可跳转页面');
      case UnsupportedHomeModuleRoute(reason: HomeRouteFailure.unknown):
        _showModuleMessage(context, '该入口暂不受支持');
    }
  }

  Future<void> _openCourseMedia(
    BuildContext context,
    CourseMedia media,
    CourseTabData data,
  ) async {
    if (!data.isLoggedIn) {
      final login = await _openVipLogin(context);
      if (!context.mounted || login == null) return;
    }
    if (!media.hasPlayableMedia) {
      if (data.hasVideoAccess) {
        _showModuleMessage(context, '暂无视频');
      } else {
        await _openVipPaySheet(
          context,
          VipPayEntry.courseTrial,
          defaultProductType: VipProductType.course,
        );
      }
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (pageContext) => CourseVideoPlayerPage(
          media: media,
          progressStore: _teacherCourseProgressStore,
          hasVideoAccess: data.hasVideoAccess,
          videoContentBuilder: widget.teacherCourseVideoContentBuilder,
          onPurchase: () async {
            final result = await _openVipPaySheet(
              pageContext,
              VipPayEntry.courseTrial,
              defaultProductType: VipProductType.course,
            );
            return result == VipPurchaseResult.paid;
          },
        ),
      ),
    );
  }

  Future<void> _openNormalExam(BuildContext context, ExamRequest request) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ExamPage(
          request: request,
          dataSource: _examDataSource,
          resultLauncher: _openExamResult,
        ),
      ),
    );
  }

  Future<void> _openLearningMaterialsModule(
    BuildContext context,
    HomeModule module,
  ) async {
    var snapshot = await _learningMaterialsDataSource.readSnapshot();
    final shelves = await _learningMaterialsDataSource.loadShelfTabs(
      moduleId: module.id,
    );
    if (!context.mounted) return;
    if (shelves.isEmpty) {
      _showModuleMessage(context, '暂无学习资料');
      return;
    }
    if (!snapshot.isLoggedIn) {
      final login = await _openVipLogin(context);
      if (!context.mounted || login == null) return;
      snapshot = snapshot.copyWith(isLoggedIn: true);
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LearningMaterialsFeedPage(
          request: LearningMaterialsFeedRequest(
            module: module,
            shelves: shelves,
            initialTabIndex: 0,
            clickedIndex: 0,
            snapshotItems: const [],
            appSnapshot: snapshot,
          ),
          dataSource: _learningMaterialsDataSource,
          htmlContentBuilder: widget.learningMaterialsHtmlContentBuilder,
          videoContentBuilder: widget.learningMaterialsVideoContentBuilder,
          onPayment:
              widget.learningMaterialsPaymentCallback ?? _payLearningMaterials,
          onShare:
              widget.learningMaterialsShareCallback ?? _shareLearningMaterials,
          onBannerTap:
              widget.learningMaterialsBannerCallback ??
              _openLearningMaterialsJump,
        ),
      ),
    );
  }

  Future<void> _openExamResult(
    BuildContext context, {
    required ExamResult result,
    required bool uploadFailed,
  }) {
    return Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (_) => ExamResultPage(
          result: result,
          uploadFailed: uploadFailed,
          onImprove:
              widget.examImproveLauncher ??
              (context) =>
                  _openVipPurchasePage(context, VipPayEntry.circlePaperResult),
          onMnemonics: _openDailySkillImprove,
        ),
      ),
    );
  }

  Future<void> _openDailySkillPractice(
    BuildContext context,
    DailySkillDetail detail,
  ) async {
    final request = DailySkillPracticeRequest(
      module: detail.module,
      skillId: detail.skill.skillId,
      shelfId: detail.effectiveShelfId,
    );
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (_) => PracticePage(
          request: request,
          dataSource: _practiceDataSource,
          dailySkillProgressStore: _dailySkillProgressStore,
          dailySkillReportLauncher: _openDailySkillReport,
          settingsStore: _practiceSettingsStore,
          paymentLauncher: _openPracticePayment,
        ),
      ),
    );
  }

  Future<void> _openDailySkillReport(
    BuildContext context,
    DailySkillPracticeRequest request,
  ) async {
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (_) => DailySkillReportPage(
          request: request,
          dataSource: _dailySkillDataSource,
          progressStore: _dailySkillProgressStore,
          improveLauncher: _openDailySkillImprove,
        ),
      ),
    );
  }

  Future<void> _openDailySkillImprove(BuildContext context) async {
    final home = await _mainTabsDataSource.loadHome();
    HomeModule? mnemonicModule;
    for (final module in home.modules) {
      final route = resolveHomeModuleRoute(module.page);
      if (route case ReadyHomeModuleRoute(
        destination: HomeDestination.skillMnemonics,
      )) {
        mnemonicModule = module;
        break;
      }
    }
    if (mnemonicModule == null) {
      throw StateError('技巧口诀入口尚未就绪');
    }
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SkillMnemonicsPage(
          module: mnemonicModule!,
          dataSource: _skillMnemonicsDataSource,
          detailLauncher: _openMnemonicDetail,
        ),
      ),
    );
  }

  Future<void> _openHomeErrorReview(BuildContext context) async {
    ErrorPracticeAvailability availability;
    try {
      availability = await _practiceDataSource.probeErrorPractice();
    } catch (_) {
      return;
    }
    if (!context.mounted) return;
    if (availability.requiresLogin) {
      await Navigator.of(context).pushNamed(PhoneLoginPage.routeName);
      return;
    }
    if (!availability.hasQuestions) {
      _showModuleMessage(context, '暂无错题');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PracticePage(
          request: const ErrorPracticeRequest(),
          dataSource: _practiceDataSource,
          settingsStore: _practiceSettingsStore,
          paymentLauncher: _openPracticePayment,
        ),
      ),
    );
  }

  Future<void> _openMnemonicDetail(
    BuildContext context,
    SkillMnemonic item,
    int position,
    HomeModule module,
  ) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SkillMnemonicsDetailPage(
          item: item,
          position: position,
          module: module,
          practiceLauncher: _openMnemonicPractice,
        ),
      ),
    );
  }

  Future<void> _openMnemonicPractice(
    BuildContext context,
    SkillMnemonic item,
    int position,
    HomeModule module,
  ) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PracticePage(
          request: SkillPracticeRequest(
            skillId: item.skillId,
            position: position,
            module: module,
          ),
          dataSource: _practiceDataSource,
          settingsStore: _practiceSettingsStore,
          paymentLauncher: _openPracticePayment,
        ),
      ),
    );
  }

  void _showModuleMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      routes: {PhoneLoginPage.routeName: (_) => const PhoneLoginPage()},
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [
          ?child,
          if (_showSecondarySplash)
            const StartupSplashPage(key: ValueKey('secondary-startup-splash')),
        ],
      ),
      home: _phase == StartupPhase.ready
          ? MainTabsPage(
              key: ValueKey('main-tabs-$_mainTabsRevision'),
              dataSource: _mainTabsDataSource,
              moduleLauncher: _launchHomeModule,
              courseMediaLauncher: _openCourseMedia,
              learningMaterialsSectionBuilder: (context, module) =>
                  LearningMaterialsHomeSection(
                    module: module,
                    dataSource: _learningMaterialsDataSource,
                    loginLauncher: _openVipLogin,
                    htmlContentBuilder:
                        widget.learningMaterialsHtmlContentBuilder,
                    videoContentBuilder:
                        widget.learningMaterialsVideoContentBuilder,
                    onPayment:
                        widget.learningMaterialsPaymentCallback ??
                        _payLearningMaterials,
                    onShare:
                        widget.learningMaterialsShareCallback ??
                        _shareLearningMaterials,
                    onBannerTap:
                        widget.learningMaterialsBannerCallback ??
                        _openLearningMaterialsJump,
                  ),
              mineAppUpdateLauncher: _checkForAppUpdate,
              mineCustomerServiceLauncher: _openCustomerService,
              mineReviewLauncher: _openMineReview,
              mineProfileLauncher: _openMineProfile,
              minePurchaseHistoryLauncher: _openPurchaseHistory,
              mineSettingsLauncher: _openMineSettings,
              mineVipPurchaseLauncher: _openMineVipPurchase,
              mineWebLauncher: _openMineWeb,
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                const StartupSplashPage(),
                if (_phase == StartupPhase.awaitingConsent) ...[
                  const ColoredBox(color: Color(0x66000000)),
                  PrivacyConsentDialog(
                    onAccept: () => _run(_coordinator.acceptPrivacy),
                    onExit: _declinePrivacy,
                    onOpenDocument: widget.onOpenDocument ?? _openAgreement,
                  ),
                ],
                if (_phase == StartupPhase.failed) ...[
                  const ColoredBox(color: Color(0x66000000)),
                  _StartupFailurePanel(
                    error: _startupError,
                    onRetry: () => _run(_coordinator.retryInitialization),
                    onExit: widget.onExit ?? SystemNavigator.pop,
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _openMineReview(BuildContext context, MineReviewKind kind) {
    final request = switch (kind) {
      MineReviewKind.errors => const ErrorPracticeRequest(),
      MineReviewKind.collections => const CollectionPracticeRequest(),
    };
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PracticePage(
          request: request,
          dataSource: _practiceDataSource,
          settingsStore: _practiceSettingsStore,
          paymentLauncher: _openPracticePayment,
        ),
      ),
    );
  }

  Future<VipPurchaseResult?> _openMineVipPurchase(BuildContext context) {
    return Navigator.of(context).push<VipPurchaseResult>(
      MaterialPageRoute<VipPurchaseResult>(
        builder: (_) => VipPurchasePage(
          request: const VipPurchaseRequest.mine(),
          dataSource: _vipPurchaseDataSource,
          paymentGateway: _vipPaymentGateway,
          loginLauncher: _openVipLogin,
          customerServiceLauncher: _openCustomerService,
          agreementLauncher: _openVipAgreement,
          differenceUpgradeLauncher: _openVipDifferenceUpgrade,
        ),
      ),
    );
  }

  Future<VipPurchaseResult?> _openHomeVipPurchase(BuildContext context) async {
    if (_vipPaymentInFlight) return null;
    _vipPaymentInFlight = true;
    try {
      final result = await Navigator.of(context).push<VipPurchaseResult>(
        MaterialPageRoute<VipPurchaseResult>(
          builder: (_) => VipPurchasePage(
            request: VipPurchaseRequest.source(source: VipPaymentSource.home),
            dataSource: _vipPurchaseDataSource,
            paymentGateway: _vipPaymentGateway,
            loginLauncher: _openVipLogin,
            customerServiceLauncher: _openCustomerService,
            agreementLauncher: _openVipAgreement,
            differenceUpgradeLauncher: _openVipDifferenceUpgrade,
          ),
        ),
      );
      if (result == VipPurchaseResult.paid && mounted) {
        setState(() => _mainTabsRevision += 1);
      }
      return result;
    } finally {
      _vipPaymentInFlight = false;
    }
  }

  Future<VipPurchaseResult?> _openVipPaySheet(
    BuildContext context,
    VipPayEntry entry, {
    VipProductType? defaultProductType,
  }) async {
    if (_vipPaymentInFlight || !context.mounted) return null;
    _vipPaymentInFlight = true;
    try {
      final launcher = widget.vipPaySheetLauncher;
      final VipPurchaseResult? result;
      if (launcher != null) {
        result = await launcher(context, entry);
      } else {
        result = await showVipPaySheet(
          context,
          request: VipPurchaseRequest.popup(
            entry: entry,
            defaultProductType: defaultProductType,
          ),
          dataSource: _vipPurchaseDataSource,
          paymentGateway: _vipPaymentGateway,
          loginLauncher: _openVipLogin,
          agreementLauncher: _openVipAgreement,
          customerServiceLauncher: _openCustomerService,
          differenceUpgradeLauncher: _openVipDifferenceUpgrade,
        );
      }
      if (result == VipPurchaseResult.paid && mounted) {
        setState(() => _mainTabsRevision += 1);
      }
      return result;
    } finally {
      _vipPaymentInFlight = false;
    }
  }

  Future<VipPurchaseResult?> _openPracticePayment(
    BuildContext context,
    VipPaymentSource source,
  ) async {
    if (_vipPaymentInFlight || !context.mounted) return null;
    _vipPaymentInFlight = true;
    try {
      final request = VipPurchaseRequest.source(
        source: source,
        defaultProductType: VipProductType.skill,
      );
      final VipPurchaseResult? result;
      if (source.presentation == VipPaymentPresentation.sheet) {
        result = await showVipPaySheet(
          context,
          request: request,
          dataSource: _vipPurchaseDataSource,
          paymentGateway: _vipPaymentGateway,
          loginLauncher: _openVipLogin,
          agreementLauncher: _openVipAgreement,
          customerServiceLauncher: _openCustomerService,
          differenceUpgradeLauncher: _openVipDifferenceUpgrade,
        );
      } else {
        result = await Navigator.of(context).push<VipPurchaseResult>(
          MaterialPageRoute<VipPurchaseResult>(
            builder: (_) => VipPurchasePage(
              request: request,
              dataSource: _vipPurchaseDataSource,
              paymentGateway: _vipPaymentGateway,
              loginLauncher: _openVipLogin,
              customerServiceLauncher: _openCustomerService,
              agreementLauncher: _openVipAgreement,
              differenceUpgradeLauncher: _openVipDifferenceUpgrade,
            ),
          ),
        );
      }
      if (result == VipPurchaseResult.paid && mounted) {
        setState(() => _mainTabsRevision += 1);
      }
      return result;
    } finally {
      _vipPaymentInFlight = false;
    }
  }

  Future<VipPurchaseResult?> _openVipPurchasePage(
    BuildContext context,
    VipPayEntry entry,
  ) async {
    if (_vipPaymentInFlight) return null;
    _vipPaymentInFlight = true;
    try {
      final result = await Navigator.of(context).push<VipPurchaseResult>(
        MaterialPageRoute<VipPurchaseResult>(
          builder: (_) => VipPurchasePage(
            request: VipPurchaseRequest.fullScreen(entry: entry),
            dataSource: _vipPurchaseDataSource,
            paymentGateway: _vipPaymentGateway,
            loginLauncher: _openVipLogin,
            customerServiceLauncher: _openCustomerService,
            agreementLauncher: _openVipAgreement,
            differenceUpgradeLauncher: _openVipDifferenceUpgrade,
          ),
        ),
      );
      if (result == VipPurchaseResult.paid && mounted) {
        setState(() => _mainTabsRevision += 1);
      }
      return result;
    } finally {
      _vipPaymentInFlight = false;
    }
  }

  Future<Map<String, dynamic>?> _openVipLogin(BuildContext context) async {
    final result = await Navigator.of(
      context,
    ).pushNamed(PhoneLoginPage.routeName);
    if (result is! Map) return null;
    return Map<String, dynamic>.from(result);
  }

  Future<VipPurchaseResult?> _openVipDifferenceUpgrade(
    BuildContext context,
    VipPurchaseRequest request,
  ) {
    return Navigator.of(context).push<VipPurchaseResult>(
      MaterialPageRoute<VipPurchaseResult>(
        builder: (_) => VipDifferenceUpgradePage(
          request: request,
          dataSource: _vipDifferenceUpgradeDataSource,
          purchaseDataSource: _vipPurchaseDataSource,
          commodityOrderDataSource: _vipCommodityOrderDataSource,
          paymentGateway: _vipPaymentGateway,
          normalPurchaseLauncher: _presentVipPurchaseRequest,
          loginLauncher: _openVipLogin,
          agreementLauncher: _openVipAgreement,
          customerServiceLauncher: _openCustomerService,
        ),
      ),
    );
  }

  Future<VipPurchaseResult?> _presentVipPurchaseRequest(
    BuildContext context,
    VipPurchaseRequest request,
  ) {
    if (request.presentation == VipPaymentPresentation.sheet) {
      return showVipPaySheet(
        context,
        request: request,
        dataSource: _vipPurchaseDataSource,
        paymentGateway: _vipPaymentGateway,
        loginLauncher: _openVipLogin,
        agreementLauncher: _openVipAgreement,
        customerServiceLauncher: _openCustomerService,
        differenceUpgradeLauncher: _openVipDifferenceUpgrade,
      );
    }
    return Navigator.of(context).push<VipPurchaseResult>(
      MaterialPageRoute<VipPurchaseResult>(
        builder: (_) => VipPurchasePage(
          request: request,
          dataSource: _vipPurchaseDataSource,
          paymentGateway: _vipPaymentGateway,
          loginLauncher: _openVipLogin,
          customerServiceLauncher: _openCustomerService,
          agreementLauncher: _openVipAgreement,
          differenceUpgradeLauncher: _openVipDifferenceUpgrade,
        ),
      ),
    );
  }

  Future<void> _openVipAgreement(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LegacyWebViewPage(
          request: _vipAgreementRequest,
          contentBuilder: widget.mineWebContentBuilder,
        ),
      ),
    );
  }

  Future<void> _openCustomerService(BuildContext _) {
    return _customerServiceCoordinator.open();
  }

  Future<void> _checkForAppUpdate(BuildContext context) async {
    final result = await _appUpdateDataSource.checkManual();
    if (!context.mounted) return;
    switch (result) {
      case AppUpdateLatest():
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('当前已是最新版本')));
      case AppUpdateAvailable(:final info):
        await showAppUpdateDialog(
          context: context,
          info: info,
          fileTransfer: _appUpdateFileTransfer,
        );
    }
  }

  Future<void> _checkForProactiveAppUpdate({
    bool showSecondarySplash = false,
  }) async {
    if (_phase != StartupPhase.ready || _proactiveAppUpdateInFlight) return;
    _proactiveAppUpdateInFlight = true;
    var splashVisible = false;
    try {
      if (showSecondarySplash) {
        if (!mounted || _phase != StartupPhase.ready) return;
        setState(() => _showSecondarySplash = true);
        splashVisible = true;
        await _secondarySplashDelay(_secondarySplashDuration);
        if (!mounted || _phase != StartupPhase.ready) return;
        setState(() => _showSecondarySplash = false);
        splashVisible = false;
      }
      final result = await _appUpdateDataSource.checkProactive();
      if (!mounted || result == null) return;
      switch (result) {
        case AppUpdateLatest():
          return;
        case AppUpdateAvailable(:final info):
          final context = _navigatorKey.currentState?.overlay?.context;
          if (context == null || !context.mounted) return;
          await showAppUpdateDialog(
            context: context,
            info: info,
            fileTransfer: _appUpdateFileTransfer,
          );
      }
    } catch (_) {
      // Android keeps proactive version-check failures silent.
    } finally {
      if (splashVisible && mounted) {
        setState(() => _showSecondarySplash = false);
      }
      _proactiveAppUpdateInFlight = false;
    }
  }

  Future<void> _openMineWeb(BuildContext context, LegacyWebRequest request) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LegacyWebViewPage(
          request: request,
          contentBuilder: widget.mineWebContentBuilder,
          onInviteShare: _openPromotionSharing,
        ),
      ),
    );
  }

  Future<void> _openPromotionSharing(
    BuildContext context,
    String inviteContent,
  ) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PromotionSharingPage(
          inviteContent: inviteContent,
          dataSource: _promotionSharingDataSource,
          shareGateway: _promotionShareGateway,
        ),
      ),
    );
  }

  Future<bool> _payLearningMaterials(
    BuildContext context,
    LearningMaterialsItem item,
    LearningMaterialsPaymentChannel channel,
  ) async {
    if (_vipPaymentInFlight) return false;
    final commodityId = item.commodityId.trim();
    if (commodityId.isEmpty) {
      _showModuleMessage(context, '商品信息异常');
      return false;
    }
    _vipPaymentInFlight = true;
    try {
      final request = VipPurchaseRequest.source(
        source: VipPaymentSource.learningMaterials,
        allowDifferenceUpgrade: false,
      );
      var session = await _vipPurchaseDataSource.loadSession(request);
      if (!context.mounted) return false;
      if (!session.isLoggedIn) {
        final login = await _openVipLogin(context);
        if (!context.mounted || login == null) return false;
        session = await _vipPurchaseDataSource.loadSession(request);
      }
      final coordinator = VipCheckoutCoordinator(
        dataSource: _vipPurchaseDataSource,
        paymentGateway: _vipPaymentGateway,
      );
      final outcome = await coordinator.checkoutCommodity(
        session: session,
        channel: channel == LearningMaterialsPaymentChannel.wechat
            ? VipPaymentChannel.wechat
            : VipPaymentChannel.alipay,
        commodityId: commodityId,
        commodityDataSource: _vipCommodityOrderDataSource,
        isActive: () => context.mounted,
      );
      if (!context.mounted) return false;
      switch (outcome.status) {
        case VipCheckoutStatus.cancelled:
          return false;
        case VipCheckoutStatus.failed:
          _showModuleMessage(context, outcome.message);
          return false;
        case VipCheckoutStatus.paid:
          var summary = const VipPurchaseSuccessSummary.generic();
          try {
            summary = await _vipPurchaseDataSource.loadSuccessSummary(session);
          } catch (_) {
            // A confirmed commodity payment still reaches the success page.
          }
          if (!context.mounted) return true;
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (successContext) => VipPurchaseSuccessPage(
                summary: summary,
                onFinished: () => Navigator.of(successContext).pop(),
                customerServiceLauncher: _openCustomerService,
              ),
            ),
          );
          return true;
      }
    } finally {
      _vipPaymentInFlight = false;
    }
  }

  Future<void> _shareLearningMaterials(
    BuildContext context,
    LearningMaterialsShareRequest request,
  ) async {
    final timeline = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              key: const ValueKey('learning-material-share-friend'),
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('微信好友'),
              onTap: () => Navigator.of(sheetContext).pop(false),
            ),
            ListTile(
              key: const ValueKey('learning-material-share-moments'),
              leading: const Icon(Icons.public),
              title: const Text('朋友圈'),
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || timeline == null) return;
    try {
      await _promotionShareGateway.shareWechatWebpage(
        url: request.url,
        title: request.title,
        description: request.description,
        timeline: timeline,
      );
    } catch (error) {
      if (!context.mounted) return;
      final message = error is PlatformException ? error.message : null;
      _showModuleMessage(context, message ?? '分享失败');
    }
  }

  Future<void> _openLearningMaterialsJump(
    BuildContext context,
    String jumpPage,
  ) async {
    final page = jumpPage.trim();
    if (page.isEmpty) {
      _showModuleMessage(context, '暂无可跳转页面');
      return;
    }
    try {
      final home = await _mainTabsDataSource.loadHome();
      if (!context.mounted) return;
      final candidates = <HomeModule>[
        ...home.modules,
        if (home.bigSkillCircleModule != null) home.bigSkillCircleModule!,
        if (home.learningMaterialsModule != null) home.learningMaterialsModule!,
      ];
      HomeModule? target;
      for (final module in candidates) {
        if (module.page.trim() == page || module.name.trim() == page) {
          target = module;
          break;
        }
      }
      final route = resolveHomeModuleRoute(page);
      if (target == null && route is ReadyHomeModuleRoute) {
        for (final module in candidates) {
          if (resolveHomeModuleRoute(module.page) == route) {
            target = module;
            break;
          }
        }
      }
      if (target == null) {
        if (route case ReadyHomeModuleRoute(
          destination: HomeDestination.vipPurchase,
        )) {
          await _openHomeVipPurchase(context);
          return;
        }
        _showModuleMessage(context, '该入口暂不受支持');
        return;
      }
      await _launchHomeModule(context, target, home.bigSkillCircleModule);
    } catch (_) {
      if (context.mounted) _showModuleMessage(context, '页面加载失败，请稍后重试');
    }
  }

  Future<AccountProfileResult?> _openMineProfile(BuildContext context) async {
    final result = await (widget.mineProfileLauncher ?? _pushAccountProfile)(
      context,
    );
    if (!mounted || result != AccountProfileResult.signedOut) return result;
    setState(() => _mainTabsRevision += 1);
    return result;
  }

  Future<AccountProfileResult?> _pushAccountProfile(BuildContext context) {
    return Navigator.of(context).push<AccountProfileResult>(
      MaterialPageRoute<AccountProfileResult>(
        builder: (_) =>
            AccountProfilePage(dataSource: _accountProfileDataSource),
      ),
    );
  }

  Future<void> _openPurchaseHistory(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            PurchaseHistoryPage(dataSource: _purchaseHistoryDataSource),
      ),
    );
  }

  Future<void> _openMineSettings(BuildContext context, bool isLoggedIn) {
    return _pushMineSettings(context, isLoggedIn);
  }

  Future<void> _pushMineSettings(BuildContext context, bool isLoggedIn) async {
    final result = await Navigator.of(context).push<AccountSafetyResult>(
      MaterialPageRoute<AccountSafetyResult>(
        builder: (_) => SettingsPage(
          isLoggedIn: isLoggedIn,
          dataSource: _settingsDataSource,
          agreementLauncher: _openSettingsAgreement,
          accountSafetyLauncher:
              widget.settingsAccountSafetyLauncher ?? _openAccountSafety,
        ),
      ),
    );
    if (!mounted || result != AccountSafetyResult.deactivated) return;
    setState(() => _mainTabsRevision += 1);
  }

  Future<AccountSafetyResult?> _openAccountSafety(BuildContext context) {
    return Navigator.of(context).push<AccountSafetyResult>(
      MaterialPageRoute<AccountSafetyResult>(
        builder: (_) => AccountSafetyPage(
          dataSource: _accountSafetyDataSource,
          deactivationLauncher: _openAccountDeactivation,
        ),
      ),
    );
  }

  Future<AccountSafetyResult?> _openAccountDeactivation(BuildContext context) {
    return Navigator.of(context).push<AccountSafetyResult>(
      MaterialPageRoute<AccountSafetyResult>(
        builder: (_) =>
            AccountDeactivationPage(dataSource: _accountSafetyDataSource),
      ),
    );
  }

  Future<void> _openSettingsAgreement(
    BuildContext context,
    AgreementDocument document,
  ) async {
    final callback = widget.onOpenDocument;
    if (callback != null) {
      callback(document);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AgreementWebViewPage(
          document: document,
          contentBuilder: widget.agreementContentBuilder,
        ),
      ),
    );
  }
}

int _currentTimeMillis() => DateTime.now().millisecondsSinceEpoch;

const _vipAgreementRequest = LegacyWebRequest(
  url: 'https://img.jx885.com/pass-license/html/vip.html',
  title: '会员协议',
);

final class _StartupFailurePanel extends StatelessWidget {
  const _StartupFailurePanel({
    required this.error,
    required this.onRetry,
    required this.onExit,
  });

  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '提示',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('网络错误，请检查网络后重试'),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF828282),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(onPressed: onExit, child: const Text('退出')),
                  const SizedBox(width: 12),
                  FilledButton(onPressed: onRetry, child: const Text('重试')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
