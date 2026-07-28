import 'dart:convert';

import '../web/legacy_webview_page.dart';

final class MineWebRouteResolver {
  const MineWebRouteResolver._();

  static const inviteFriendsBaseUrl =
      'https://img.jx885.com/pass-license/html/invite/index.html';

  static LegacyWebRequest? collectBook(String? rawUrl) {
    final url = rawUrl?.trim() ?? '';
    if (url.isEmpty) return null;
    return LegacyWebRequest(url: url, title: '领取书籍');
  }

  static LegacyWebRequest? inviteFriends({
    required int activity,
    required String token,
    required bool isTestEnvironment,
    required String? userRole,
    required String? commissionRate,
  }) {
    if (activity == 0) return null;
    var url = inviteFriendsBaseUrl;
    url = _appendQuery(url, 't', token);
    url = _appendQuery(url, 'env', isTestEnvironment ? 'test' : 'prod');
    if (userRole != null && userRole.isNotEmpty) {
      url = _appendQuery(url, 'userRole', userRole);
    }
    if (commissionRate != null && commissionRate.isNotEmpty) {
      url = _appendQuery(url, 'commissionRate', commissionRate);
    }
    return LegacyWebRequest(url: url, title: '邀请好友', hideTitleBar: true);
  }

  static String _appendQuery(String url, String key, String value) {
    final separator = url.contains('?') ? '&' : '?';
    return '$url$separator$key=${_javaFormEncode(value)}';
  }

  static String _javaFormEncode(String value) {
    final encoded = StringBuffer();
    for (final byte in utf8.encode(value)) {
      if (_isJavaFormSafe(byte)) {
        encoded.writeCharCode(byte);
      } else if (byte == 0x20) {
        encoded.write('+');
      } else {
        encoded
          ..write('%')
          ..write(byte.toRadixString(16).padLeft(2, '0').toUpperCase());
      }
    }
    return encoded.toString();
  }

  static bool _isJavaFormSafe(int byte) {
    return (byte >= 0x41 && byte <= 0x5A) ||
        (byte >= 0x61 && byte <= 0x7A) ||
        (byte >= 0x30 && byte <= 0x39) ||
        byte == 0x2E ||
        byte == 0x2D ||
        byte == 0x2A ||
        byte == 0x5F;
  }
}
