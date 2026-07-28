import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/account_profile/account_profile_models.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_repository.dart';
import 'package:ultcpa_flutter/src/main_tabs/mine_tab_page.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_models.dart';
import 'package:ultcpa_flutter/src/web/legacy_webview_page.dart';

void main() {
  testWidgets('shows the Android logged-out mine state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: MineTabPage(dataSource: _DataSource(_loggedOut))),
    );
    await tester.pumpAndSettle();

    expect(find.text('一键登录'), findsOneWidget);
    expect(find.text('错题集'), findsOneWidget);
    expect(find.text('我的收藏'), findsOneWidget);
    expect(find.text('邀请好友'), findsNothing);
  });

  testWidgets('shows profile, counts, and gated menu for a logged-in user', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: MineTabPage(dataSource: _DataSource(_loggedIn))),
    );
    await tester.pumpAndSettle();

    expect(find.text('考友'), findsOneWidget);
    expect(find.text('13800138000'), findsOneWidget);
    expect(find.text('共12题'), findsOneWidget);
    expect(find.text('共3题'), findsOneWidget);
    expect(find.text('邀请好友'), findsOneWidget);
  });

  testWidgets('opens profile only from the logged-in user band', (
    tester,
  ) async {
    var loginCalls = 0;
    var profileCalls = 0;
    for (final data in [_loggedOut, _loggedIn]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MineTabPage(
            key: ValueKey(data.isLoggedIn),
            dataSource: _DataSource(data),
            onLoginRequested: () async => loginCalls += 1,
            profileLauncher: (_) async {
              profileCalls += 1;
              return AccountProfileResult.signedOut;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mine-profile')));
      await tester.pump();
    }

    expect(loginCalls, 1);
    expect(profileCalls, 1);
  });

  testWidgets('selection revision reloads exactly once', (tester) async {
    final dataSource = _DataSource(_loggedIn);
    await tester.pumpWidget(
      MaterialApp(
        home: MineTabPage(dataSource: dataSource, selectionRevision: 0),
      ),
    );
    await tester.pumpAndSettle();
    expect(dataSource.mineCalls, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: MineTabPage(dataSource: dataSource, selectionRevision: 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(dataSource.mineCalls, 2);

    await tester.pumpWidget(
      MaterialApp(
        home: MineTabPage(dataSource: dataSource, selectionRevision: 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(dataSource.mineCalls, 2);
  });

  testWidgets('review rows require login before checking empty counts', (
    tester,
  ) async {
    var loginCalls = 0;
    final launched = <MineReviewKind>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MineTabPage(
            dataSource: _DataSource(_loggedOut),
            onLoginRequested: () async => loginCalls += 1,
            reviewLauncher: (_, kind) async => launched.add(kind),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mine-review-errors')));
    await tester.pump();

    expect(loginCalls, 1);
    expect(launched, isEmpty);
    expect(find.text('还没有错题哟'), findsNothing);
  });

  testWidgets('logged-in empty review rows show Android messages', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MineTabPage(
            dataSource: _DataSource(_loggedInEmpty),
            reviewLauncher: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mine-review-errors')));
    await tester.pump();
    expect(find.text('还没有错题哟'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mine-review-collections')));
    await tester.pump();
    expect(find.text('还没有收藏哟'), findsOneWidget);
  });

  testWidgets('logged-in review rows launch their exact modes', (tester) async {
    final launched = <MineReviewKind>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MineTabPage(
            dataSource: _DataSource(_loggedIn),
            reviewLauncher: (_, kind) async => launched.add(kind),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mine-review-errors')));
    await tester.tap(find.byKey(const ValueKey('mine-review-collections')));
    await tester.pump();

    expect(launched, [MineReviewKind.errors, MineReviewKind.collections]);
  });

  testWidgets('purchase history requires login then launches for a user', (
    tester,
  ) async {
    var loginCalls = 0;
    var purchaseCalls = 0;
    for (final data in [_loggedOut, _loggedIn]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MineTabPage(
            key: ValueKey('purchase-${data.isLoggedIn}'),
            dataSource: _DataSource(data),
            onLoginRequested: () async => loginCalls += 1,
            purchaseHistoryLauncher: (_) async => purchaseCalls += 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('mine-purchase-history'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pump();
    }

    expect(loginCalls, 1);
    expect(purchaseCalls, 1);
  });

  testWidgets('web rows match Android visibility order and hidden guide', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: MineTabPage(dataSource: _DataSource(_loggedIn))),
    );
    await tester.pumpAndSettle();

    final purchase = find.byKey(const ValueKey('mine-purchase-history'));
    final collect = find.byKey(const ValueKey('mine-collect-book'));
    final invite = find.byKey(const ValueKey('mine-invite-friends'));
    final customer = find.byKey(const ValueKey('mine-customer-service'));
    final update = find.byKey(const ValueKey('mine-check-update'));
    final settings = find.byKey(const ValueKey('mine-settings'));
    expect(collect, findsOneWidget);
    expect(invite, findsOneWidget);
    expect(find.text('驾考学习指南'), findsNothing);
    expect(
      tester.getTopLeft(purchase).dy,
      lessThan(tester.getTopLeft(collect).dy),
    );
    expect(
      tester.getTopLeft(collect).dy,
      lessThan(tester.getTopLeft(invite).dy),
    );
    expect(
      tester.getTopLeft(invite).dy,
      lessThan(tester.getTopLeft(customer).dy),
    );
    expect(
      tester.getTopLeft(customer).dy,
      lessThan(tester.getTopLeft(update).dy),
    );
    expect(
      tester.getTopLeft(update).dy,
      lessThan(tester.getTopLeft(settings).dy),
    );
  });

  testWidgets('both Mine web rows require login before launching', (
    tester,
  ) async {
    var loginCalls = 0;
    final launched = <LegacyWebRequest>[];
    await tester.pumpWidget(
      MaterialApp(
        home: MineTabPage(
          dataSource: _DataSource(_loggedOutWeb),
          onLoginRequested: () async => loginCalls += 1,
          webLauncher: (_, request) async => launched.add(request),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final key in ['mine-collect-book', 'mine-invite-friends']) {
      final row = find.byKey(ValueKey(key));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pump();
    }

    expect(loginCalls, 2);
    expect(launched, isEmpty);
  });

  testWidgets('logged-in Mine web rows launch their exact requests', (
    tester,
  ) async {
    final launched = <LegacyWebRequest>[];
    await tester.pumpWidget(
      MaterialApp(
        home: MineTabPage(
          dataSource: _DataSource(_loggedIn),
          webLauncher: (_, request) async => launched.add(request),
        ),
      ),
    );
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

  testWidgets('Mine web navigation allows only one in-flight request', (
    tester,
  ) async {
    final launch = Completer<void>();
    final launched = <LegacyWebRequest>[];
    await tester.pumpWidget(
      MaterialApp(
        home: MineTabPage(
          dataSource: _DataSource(_loggedIn),
          webLauncher: (_, request) {
            launched.add(request);
            return launch.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final collect = find.byKey(const ValueKey('mine-collect-book'));
    await tester.ensureVisible(collect);
    await tester.pumpAndSettle();

    await tester.tap(collect);
    await tester.pump();
    expect(launched, [_collectBookRequest]);
    expect(find.byKey(const ValueKey('mine-web-progress')), findsOneWidget);

    final invite = find.byKey(const ValueKey('mine-invite-friends'));
    await tester.ensureVisible(invite);
    await tester.pump();
    await tester.tap(invite);
    await tester.pump();
    expect(launched, [_collectBookRequest]);

    launch.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mine-web-progress')), findsNothing);
  });

  testWidgets('Mine web launcher errors restore actions and notify', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MineTabPage(
            dataSource: _DataSource(_loggedIn),
            webLauncher: (_, request) => throw StateError('navigation failed'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final collect = find.byKey(const ValueKey('mine-collect-book'));
    await tester.ensureVisible(collect);
    await tester.pumpAndSettle();

    await tester.tap(collect);
    await tester.pumpAndSettle();

    expect(find.text('暂时无法打开页面，请稍后重试'), findsOneWidget);
    expect(find.byKey(const ValueKey('mine-web-progress')), findsNothing);
  });

  testWidgets('customer service launches for both login states without gate', (
    tester,
  ) async {
    var loginCalls = 0;
    var customerServiceCalls = 0;
    for (final data in [_loggedOut, _loggedIn]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MineTabPage(
            key: ValueKey('customer-service-${data.isLoggedIn}'),
            dataSource: _DataSource(data),
            onLoginRequested: () async => loginCalls += 1,
            customerServiceLauncher: (_) async => customerServiceCalls += 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('mine-customer-service'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
    }

    expect(customerServiceCalls, 2);
    expect(loginCalls, 0);
  });

  testWidgets('customer service allows only one in-flight launch', (
    tester,
  ) async {
    final launch = Completer<void>();
    var launchCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MineTabPage(
            dataSource: _DataSource(_loggedOut),
            customerServiceLauncher: (_) {
              launchCalls += 1;
              return launch.future;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('mine-customer-service'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();

    await tester.tap(row);
    await tester.pump();
    expect(launchCalls, 1);
    expect(
      find.byKey(const ValueKey('mine-customer-service-progress')),
      findsOneWidget,
    );

    await tester.tap(row);
    await tester.pump();
    expect(launchCalls, 1);

    launch.complete();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mine-customer-service-progress')),
      findsNothing,
    );
  });

  testWidgets('customer service platform errors restore the row and notify', (
    tester,
  ) async {
    var launchCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MineTabPage(
            dataSource: _DataSource(_loggedIn),
            customerServiceLauncher: (_) async {
              launchCalls += 1;
              throw PlatformException(
                code: 'wechat_not_installed',
                message: '未安装微信',
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('mine-customer-service'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();

    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(launchCalls, 1);
    expect(find.text('暂时无法打开微信客服，请稍后重试'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mine-customer-service-progress')),
      findsNothing,
    );
  });

  testWidgets('customer service completion after disposal is ignored', (
    tester,
  ) async {
    final launch = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MineTabPage(
            dataSource: _DataSource(_loggedOut),
            customerServiceLauncher: (_) => launch.future,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('mine-customer-service'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    launch.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('manual update checks for both login states without a gate', (
    tester,
  ) async {
    var loginCalls = 0;
    var updateCalls = 0;
    for (final data in [_loggedOut, _loggedIn]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MineTabPage(
            key: ValueKey('app-update-${data.isLoggedIn}'),
            dataSource: _DataSource(data),
            onLoginRequested: () async => loginCalls += 1,
            appUpdateLauncher: (_) async => updateCalls += 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('mine-check-update'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
    }

    expect(updateCalls, 2);
    expect(loginCalls, 0);
  });

  testWidgets('manual update is single-flight and failures recover silently', (
    tester,
  ) async {
    final first = Completer<void>();
    var updateCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MineTabPage(
            dataSource: _DataSource(_loggedOut),
            appUpdateLauncher: (_) {
              updateCalls += 1;
              return updateCalls == 1 ? first.future : Future<void>.value();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('mine-check-update'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();

    await tester.tap(row);
    await tester.pump();
    await tester.tap(row);
    await tester.pump();
    expect(updateCalls, 1);

    first.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(updateCalls, 2);
  });

  testWidgets('settings row forwards the current login state', (tester) async {
    final loginStates = <bool>[];
    for (final data in [_loggedOut, _loggedIn]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MineTabPage(
            key: ValueKey(data.isLoggedIn),
            dataSource: _DataSource(data),
            settingsLauncher: (_, isLoggedIn) async {
              loginStates.add(isLoggedIn);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final settings = find.byKey(const ValueKey('mine-settings'));
      await tester.ensureVisible(settings);
      await tester.pumpAndSettle();
      await tester.tap(settings);
      await tester.pump();
    }

    expect(loginStates, [false, true]);
  });

  testWidgets('VIP panel keeps five features and opens for both login states', (
    tester,
  ) async {
    var launchCalls = 0;
    for (final data in [_loggedOut, _loggedIn]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MineTabPage(
            key: ValueKey('vip-${data.isLoggedIn}'),
            dataSource: _DataSource(data),
            vipPurchaseLauncher: (_) async {
              launchCalls += 1;
              return null;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in const [
        '技巧练题',
        '速成300\n题',
        '最后密押\n卷',
        '技巧口诀',
        '考前6\n页纸',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('解锁全部学习特权'), findsOneWidget);
      expect(find.text('开通会员'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('mine-vip-purchase')));
      await tester.pump();
    }

    expect(launchCalls, 2);
  });

  testWidgets('VIP purchase launcher is single-flight and recovers', (
    tester,
  ) async {
    final firstLaunch = Completer<VipPurchaseResult?>();
    var launchCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MineTabPage(
          dataSource: _DataSource(_loggedOut),
          vipPurchaseLauncher: (_) {
            launchCalls += 1;
            return firstLaunch.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final purchase = find.byKey(const ValueKey('mine-vip-purchase'));
    await tester.tap(purchase);
    await tester.tap(purchase);
    await tester.pump();
    expect(launchCalls, 1);

    firstLaunch.complete(null);
    await tester.pumpAndSettle();
    await tester.tap(purchase);
    await tester.pump();
    expect(launchCalls, 2);
  });
}

final class _DataSource implements MainTabsDataSource {
  _DataSource(this.data);

  final MineTabData data;
  int mineCalls = 0;

  @override
  Future<MineTabData> loadMine() async {
    mineCalls += 1;
    return data;
  }

  @override
  Future<HomeTabData> loadHome({
    String? preferredCategoryKey,
    int? preferredSubjectId,
  }) => throw UnimplementedError();

  @override
  Future<CourseTabData> loadCourses({
    required CourseType courseType,
    String? subject,
  }) => throw UnimplementedError();
}

const _loggedOut = MineTabData(
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

const _loggedOutWeb = MineTabData(
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
  collectBookRequest: _collectBookRequest,
  inviteFriendsRequest: _inviteFriendsRequest,
);

const _loggedIn = MineTabData(
  isLoggedIn: true,
  profile: MineProfile(
    userId: '2038529229062426626',
    nickname: '考友',
    phone: '13800138000',
    avatar: '',
    userRole: 'student',
  ),
  errorCount: 12,
  collectionCount: 3,
  collectBookRequest: _collectBookRequest,
  inviteFriendsRequest: _inviteFriendsRequest,
);

const _loggedInEmpty = MineTabData(
  isLoggedIn: true,
  profile: MineProfile(
    userId: '2038529229062426626',
    nickname: '考友',
    phone: '13800138000',
    avatar: '',
    userRole: 'student',
  ),
  errorCount: 0,
  collectionCount: 0,
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
