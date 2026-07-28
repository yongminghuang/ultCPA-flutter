import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/account_profile/account_profile_data_source.dart';
import 'package:ultcpa_flutter/src/account_profile/account_profile_models.dart';
import 'package:ultcpa_flutter/src/account_profile/account_profile_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('loads a fresh profile and retries a failure', (tester) async {
    final first = Completer<AccountProfileSnapshot>();
    final second = Completer<AccountProfileSnapshot>();
    var attempt = 0;
    final source = _Source(
      loader: () => attempt++ == 0 ? first.future : second.future,
    );
    await tester.pumpWidget(_app(source));

    expect(
      find.byKey(const ValueKey('account-profile-loading')),
      findsOneWidget,
    );
    first.completeError(StateError('offline'));
    await tester.pump();
    expect(find.byKey(const ValueKey('account-profile-error')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('account-profile-retry')));
    await tester.pump();
    second.complete(_snapshot);
    await tester.pumpAndSettle();

    expect(find.text('我的资料'), findsOneWidget);
    expect(find.text('考友'), findsOneWidget);
    expect(source.loadCalls, 2);
  });

  testWidgets('shows only Android visible read-only rows', (tester) async {
    await tester.pumpWidget(_app(_Source()));
    await tester.pumpAndSettle();

    expect(find.text('头像'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('考友'), findsOneWidget);
    expect(find.text('账号ID'), findsOneWidget);
    expect(find.text('2038529229062426626'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
    expect(find.text('手机号'), findsNothing);
    expect(find.text('微信'), findsNothing);
    expect(find.textContaining('绑定'), findsNothing);
    expect(find.textContaining('编辑'), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

    await tester.tap(find.byKey(const ValueKey('account-profile-avatar')));
    await tester.tap(find.byKey(const ValueKey('account-profile-nickname')));
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('copies the complete account ID and shows Android feedback', (
    tester,
  ) async {
    MethodCall? clipboardCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') clipboardCall = call;
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.pumpWidget(_app(_Source()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('account-profile-user-id')));
    await tester.pump();

    expect(clipboardCall?.arguments, {'text': '2038529229062426626'});
    expect(find.text('已复制userId'), findsOneWidget);
  });

  testWidgets('does not copy an empty account ID', (tester) async {
    var clipboardCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') clipboardCalls += 1;
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.pumpWidget(
      _app(
        _Source(
          snapshot: const AccountProfileSnapshot(
            isLoggedIn: true,
            userId: '   ',
            nickname: '考友',
            avatar: '',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('account-profile-user-id')));
    await tester.pump();

    expect(clipboardCalls, 0);
    expect(find.text('已复制userId'), findsNothing);
  });

  testWidgets(
    'uses the exact Android sign-out confirmation and supports cancel',
    (tester) async {
      final source = _Source();
      await tester.pumpWidget(_app(source));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('account-profile-sign-out')));
      await tester.pumpAndSettle();

      expect(find.text('提示'), findsOneWidget);
      expect(find.text('退出登录您可能会丢失做题记录，是否确定退出？'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确定'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('account-profile-cancel')));
      await tester.pumpAndSettle();
      expect(source.signOutCalls, 0);
    },
  );

  testWidgets('guards the unreachable logged-out profile state', (
    tester,
  ) async {
    final source = _Source(
      snapshot: const AccountProfileSnapshot(
        isLoggedIn: false,
        userId: '',
        nickname: '',
        avatar: '',
      ),
    );
    await tester.pumpWidget(_app(source));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('account-profile-sign-out')));
    await tester.pump();

    expect(find.text('当前未登录'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(source.signOutCalls, 0);
  });

  testWidgets('submits once, blocks navigation, and returns signedOut', (
    tester,
  ) async {
    final pending = Completer<void>();
    final source = _Source(onSignOut: () => pending.future);
    final results = <AccountProfileResult?>[];
    await tester.pumpWidget(_harness(source, results));
    await _open(tester);

    await _confirmSignOut(tester);
    expect(source.signOutCalls, 1);
    expect(
      find.byKey(const ValueKey('account-profile-progress')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('account-profile-back')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(
      find.byKey(const ValueKey('account-profile-sign-out')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(source.signOutCalls, 1);

    pending.complete();
    await tester.pumpAndSettle();
    expect(results, [AccountProfileResult.signedOut]);
  });

  testWidgets('keeps the page and hides native cleanup details on failure', (
    tester,
  ) async {
    final source = _Source(
      onSignOut: () async => throw PlatformException(
        code: 'account_safety_error',
        message: 'Could not clear legacy account preferences',
      ),
    );
    await tester.pumpWidget(_app(source));
    await tester.pumpAndSettle();

    await _confirmSignOut(tester);
    await tester.pumpAndSettle();

    expect(find.text('退出登录失败，请重试'), findsOneWidget);
    expect(find.textContaining('legacy account'), findsNothing);
    expect(find.byKey(const ValueKey('account-profile-list')), findsOneWidget);
    expect(source.signOutCalls, 1);
  });

  testWidgets('supports back without reporting sign out', (tester) async {
    final results = <AccountProfileResult?>[];
    await tester.pumpWidget(_harness(_Source(), results));
    await _open(tester);

    await tester.tap(find.byKey(const ValueKey('account-profile-back')));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });

  testWidgets('ignores a stale load after disposal', (tester) async {
    final load = Completer<AccountProfileSnapshot>();
    await tester.pumpWidget(_app(_Source(loader: () => load.future)));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    load.complete(_snapshot);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('fits the Android profile surface at 320 by 568', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_Source()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-profile-sign-out')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('account-profile-dialog')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

const _snapshot = AccountProfileSnapshot(
  isLoggedIn: true,
  userId: '2038529229062426626',
  nickname: '考友',
  avatar: '',
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _confirmSignOut(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('account-profile-sign-out')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('account-profile-confirm')));
  await tester.pump();
}

Widget _app(AccountProfileDataSource source) {
  return MaterialApp(home: AccountProfilePage(dataSource: source));
}

Widget _harness(
  AccountProfileDataSource source,
  List<AccountProfileResult?> results,
) {
  return MaterialApp(
    home: _Harness(source: source, results: results),
  );
}

final class _Source implements AccountProfileDataSource {
  _Source({this.snapshot = _snapshot, this.loader, this.onSignOut});

  final AccountProfileSnapshot snapshot;
  final Future<AccountProfileSnapshot> Function()? loader;
  final Future<void> Function()? onSignOut;
  int loadCalls = 0;
  int signOutCalls = 0;

  @override
  Future<AccountProfileSnapshot> load() {
    loadCalls += 1;
    return loader?.call() ?? Future.value(snapshot);
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    await onSignOut?.call();
  }
}

final class _Harness extends StatelessWidget {
  const _Harness({required this.source, required this.results});

  final AccountProfileDataSource source;
  final List<AccountProfileResult?> results;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('host'),
          TextButton(
            onPressed: () async {
              final result = await Navigator.of(context)
                  .push<AccountProfileResult>(
                    MaterialPageRoute<AccountProfileResult>(
                      builder: (_) => AccountProfilePage(dataSource: source),
                    ),
                  );
              results.add(result);
            },
            child: const Text('open'),
          ),
        ],
      ),
    );
  }
}
