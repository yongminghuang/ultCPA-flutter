import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/account_profile/account_profile_models.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_page.dart';
import 'package:ultcpa_flutter/src/main_tabs/mine_tab_page.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_repository.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_models.dart';
import 'package:ultcpa_flutter/src/web/legacy_webview_page.dart';

void main() {
  testWidgets('shows the Android three-tab shell and preserves visited tabs', (
    tester,
  ) async {
    final dataSource = _DataSource();

    await tester.pumpWidget(
      MaterialApp(home: MainTabsPage(dataSource: dataSource)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IndexedStack), findsOneWidget);
    expect(find.text('技巧练题'), findsWidgets);
    expect(find.text('技巧课程'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(dataSource.homeCalls, 1);
    expect(dataSource.courseCalls, 0);
    expect(dataSource.mineCalls, 0);

    await tester.tap(find.text('技巧课程'));
    await tester.pumpAndSettle();
    expect(dataSource.courseCalls, 1);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(dataSource.mineCalls, 1);

    await tester.tap(find.text('技巧练题').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('技巧课程'));
    await tester.pumpAndSettle();

    expect(dataSource.homeCalls, 1);
    expect(dataSource.courseCalls, 1);
    expect(dataSource.mineCalls, 1);
  });

  testWidgets('returns from mine login on the same tab and reloads it once', (
    tester,
  ) async {
    final dataSource = _DataSource();
    var loginCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MainTabsPage(
          dataSource: dataSource,
          loginLauncher: (context) async {
            loginCalls += 1;
            dataSource.loggedIn = true;
            return {
              'accessToken': 'phone-token',
              'user': {'id': '2038529229062426626'},
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(dataSource.mineCalls, 1);
    expect(find.text('一键登录'), findsOneWidget);

    await tester.tap(find.text('一键登录'));
    await tester.pumpAndSettle();

    final navigation = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(navigation.currentIndex, 2);
    expect(loginCalls, 1);
    expect(dataSource.mineCalls, 2);
    expect(find.text('登录后用户'), findsOneWidget);
  });

  testWidgets('home selection reloads visited tabs and preserves course type', (
    tester,
  ) async {
    final dataSource = _DataSource();
    await tester.pumpWidget(
      MaterialApp(home: MainTabsPage(dataSource: dataSource)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('技巧课程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('技巧密押'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('技巧练题').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('综合能力'));
    await tester.pumpAndSettle();

    expect(dataSource.courseCalls, 3);
    expect(dataSource.requestedTypes.last, CourseType.secret);
    expect(dataSource.requestedSubjects.last, isNull);
    expect(dataSource.mineCalls, 2);
  });

  testWidgets('passes the app-level module launcher to the home tab', (
    tester,
  ) async {
    final dataSource = _DataSource();
    final launched = <HomeModule>[];
    await tester.pumpWidget(
      MaterialApp(
        home: MainTabsPage(
          dataSource: dataSource,
          moduleLauncher: (context, module, circleModule) async =>
              launched.add(module),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-module-1')));
    await tester.pump();

    expect(launched, [_homeData.modules.single]);
  });

  testWidgets('home VIP action is wired and single-flight', (tester) async {
    final result = Completer<VipPurchaseResult?>();
    var launchCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MainTabsPage(
          dataSource: _DataSource(),
          mineVipPurchaseLauncher: (_) {
            launchCalls += 1;
            return result.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final purchase = find.byKey(const ValueKey('home-vip-purchase'));
    await tester.tap(purchase);
    await tester.tap(purchase);
    await tester.pump();

    expect(launchCalls, 1);
    result.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('passes the app-level review launcher to the Mine tab', (
    tester,
  ) async {
    final dataSource = _DataSource()..loggedIn = true;
    final launched = <MineReviewKind>[];
    await tester.pumpWidget(
      MaterialApp(
        home: MainTabsPage(
          dataSource: dataSource,
          mineReviewLauncher: (_, kind) async => launched.add(kind),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mine-review-errors')));
    await tester.pump();

    expect(launched, [MineReviewKind.errors]);
  });

  testWidgets('passes the app-level profile launcher to the Mine tab', (
    tester,
  ) async {
    final dataSource = _DataSource()..loggedIn = true;
    var launchCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MainTabsPage(
          dataSource: dataSource,
          mineProfileLauncher: (_) async {
            launchCalls += 1;
            return AccountProfileResult.signedOut;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mine-profile')));
    await tester.pump();

    expect(launchCalls, 1);
  });

  testWidgets('passes the purchase-history launcher to the Mine tab', (
    tester,
  ) async {
    final dataSource = _DataSource()..loggedIn = true;
    var launchCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MainTabsPage(
          dataSource: dataSource,
          minePurchaseHistoryLauncher: (_) async => launchCalls += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('mine-purchase-history'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pump();

    expect(launchCalls, 1);
  });

  testWidgets('passes the customer-service launcher to the Mine tab', (
    tester,
  ) async {
    final dataSource = _DataSource();
    var launchCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MainTabsPage(
          dataSource: dataSource,
          mineCustomerServiceLauncher: (_) async => launchCalls += 1,
        ),
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

    expect(launchCalls, 1);
  });

  testWidgets('passes the manual app-update launcher to the Mine tab', (
    tester,
  ) async {
    final dataSource = _DataSource();
    var launchCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MainTabsPage(
          dataSource: dataSource,
          mineAppUpdateLauncher: (_) async => launchCalls += 1,
        ),
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

    expect(launchCalls, 1);
  });

  testWidgets('passes typed Mine web requests to the app launcher', (
    tester,
  ) async {
    final dataSource = _DataSource()..loggedIn = true;
    final launched = <LegacyWebRequest>[];
    await tester.pumpWidget(
      MaterialApp(
        home: MainTabsPage(
          dataSource: dataSource,
          mineWebLauncher: (_, request) async => launched.add(request),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    for (final key in ['mine-collect-book', 'mine-invite-friends']) {
      final row = find.byKey(ValueKey(key));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
    }

    expect(launched, [_collectBookRequest, _inviteFriendsRequest]);
  });

  testWidgets('passes the app-level settings launcher to the Mine tab', (
    tester,
  ) async {
    final dataSource = _DataSource()..loggedIn = true;
    final loginStates = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: MainTabsPage(
          dataSource: dataSource,
          mineSettingsLauncher: (_, isLoggedIn) async {
            loginStates.add(isLoggedIn);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    final settings = find.byKey(const ValueKey('mine-settings'));
    await tester.ensureVisible(settings);
    await tester.pumpAndSettle();
    await tester.tap(settings);
    await tester.pump();

    expect(loginStates, [true]);
  });

  testWidgets('paid VIP returns Home and reloads only the preserved Mine', (
    tester,
  ) async {
    final dataSource = _DataSource();
    final results = <VipPurchaseResult?>[null, VipPurchaseResult.paid];
    var launchCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MainTabsPage(
          dataSource: dataSource,
          mineVipPurchaseLauncher: (_) async => results[launchCalls++],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('技巧课程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('技巧密押'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(dataSource.mineCalls, 1);

    final purchase = find.byKey(const ValueKey('mine-vip-purchase'));
    await tester.tap(purchase);
    await tester.pumpAndSettle();
    expect(dataSource.mineCalls, 1);

    await tester.tap(purchase);
    await tester.pumpAndSettle();

    expect(launchCalls, 2);
    expect(dataSource.mineCalls, 2);
    expect(dataSource.homeCalls, 1);
    expect(dataSource.courseCalls, 2);
    expect(dataSource.requestedTypes.last, CourseType.secret);
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      0,
    );
  });
}

final class _DataSource implements MainTabsDataSource {
  int homeCalls = 0;
  int courseCalls = 0;
  int mineCalls = 0;
  bool loggedIn = false;
  final List<CourseType> requestedTypes = [];
  final List<String?> requestedSubjects = [];

  @override
  Future<HomeTabData> loadHome({
    String? preferredCategoryKey,
    int? preferredSubjectId,
  }) async {
    homeCalls += 1;
    return preferredSubjectId == 1024 ? _secondSubjectHomeData : _homeData;
  }

  @override
  Future<CourseTabData> loadCourses({
    required CourseType courseType,
    String? subject,
  }) async {
    courseCalls += 1;
    requestedTypes.add(courseType);
    requestedSubjects.add(subject);
    return CourseTabData(
      categoryLabel: '初级社工',
      subjects: _subjects,
      selectedSubject: _subjects.first,
      courseType: courseType,
      items: const [],
    );
  }

  @override
  Future<MineTabData> loadMine() async {
    mineCalls += 1;
    return loggedIn ? _loggedInMineData : _mineData;
  }
}

const _subjects = [
  CategorySubject(id: 1023, name: '社工实务'),
  CategorySubject(id: 1024, name: '综合能力'),
];

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
  modules: [HomeModule(id: 1, name: '技巧练题', page: 'practice', tag: '')],
  bannerUrl: null,
  examCountdownDays: 5,
);

const _secondSubjectHomeData = HomeTabData(
  categoryGroups: [
    CategoryGroup(label: '社工', options: [_categoryOption]),
  ],
  selection: MainTabsSelection(
    category: _categoryOption,
    subject: CategorySubject(id: 1024, name: '综合能力'),
  ),
  modules: [HomeModule(id: 2, name: '综合能力模块', page: 'practice', tag: '')],
  bannerUrl: null,
  examCountdownDays: 5,
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

const _loggedInMineData = MineTabData(
  isLoggedIn: true,
  profile: MineProfile(
    userId: '2038529229062426626',
    nickname: '登录后用户',
    phone: '13800138000',
    avatar: '',
    userRole: 'student',
  ),
  errorCount: 1,
  collectionCount: 2,
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
