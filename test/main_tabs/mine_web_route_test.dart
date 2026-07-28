import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/mine_web_route.dart';

void main() {
  group('collect book', () {
    test('hides a missing or blank static dictionary URL', () {
      for (final raw in <String?>[null, '', '   ', '\t\r\n']) {
        expect(
          MineWebRouteResolver.collectBook(raw),
          isNull,
          reason: 'raw=$raw',
        );
      }
    });

    test('trims the URL and preserves the Android title bar', () {
      final request = MineWebRouteResolver.collectBook(
        '  https://example.com/collect-book?a=1&b=2  ',
      );

      expect(request?.url, 'https://example.com/collect-book?a=1&b=2');
      expect(request?.title, '领取书籍');
      expect(request?.hideTitleBar, isFalse);
    });
  });

  group('invite friends', () {
    test('hides only when the activity switch is zero', () {
      for (final activity in <int>[1, -1, 2]) {
        expect(
          MineWebRouteResolver.inviteFriends(
            activity: activity,
            token: '',
            isTestEnvironment: false,
            userRole: '',
            commissionRate: '',
          ),
          isNotNull,
          reason: 'activity=$activity',
        );
      }
      expect(
        MineWebRouteResolver.inviteFriends(
          activity: 0,
          token: 'token',
          isTestEnvironment: false,
          userRole: 'creator',
          commissionRate: '0.25',
        ),
        isNull,
      );
    });

    test('always appends token and prod environment in Android order', () {
      final request = MineWebRouteResolver.inviteFriends(
        activity: 1,
        token: '',
        isTestEnvironment: false,
        userRole: '',
        commissionRate: '',
      );

      expect(
        request?.url,
        'https://img.jx885.com/pass-license/html/invite/index.html'
        '?t=&env=prod',
      );
      expect(request?.title, '邀请好友');
      expect(request?.hideTitleBar, isTrue);
    });

    test('uses test environment and optional referral parameters', () {
      final request = MineWebRouteResolver.inviteFriends(
        activity: 1,
        token: 'token',
        isTestEnvironment: true,
        userRole: 'creator,teacher',
        commissionRate: '0.25',
      );

      expect(
        request?.url,
        'https://img.jx885.com/pass-license/html/invite/index.html'
        '?t=token&env=test&userRole=creator%2Cteacher&commissionRate=0.25',
      );
    });

    test('matches Java URLEncoder UTF-8 form semantics', () {
      final request = MineWebRouteResolver.inviteFriends(
        activity: 1,
        token: 'a b+c*~',
        isTestEnvironment: false,
        userRole: '考有招达人',
        commissionRate: '',
      );

      expect(
        request?.url,
        'https://img.jx885.com/pass-license/html/invite/index.html'
        '?t=a+b%2Bc*%7E&env=prod&userRole='
        '%E8%80%83%E6%9C%89%E6%8B%9B%E8%BE%BE%E4%BA%BA',
      );
    });

    test('omits optional null values without trimming non-empty text', () {
      final request = MineWebRouteResolver.inviteFriends(
        activity: 1,
        token: 'token',
        isTestEnvironment: false,
        userRole: null,
        commissionRate: ' ',
      );

      expect(
        request?.url,
        'https://img.jx885.com/pass-license/html/invite/index.html'
        '?t=token&env=prod&commissionRate=+',
      );
    });
  });
}
