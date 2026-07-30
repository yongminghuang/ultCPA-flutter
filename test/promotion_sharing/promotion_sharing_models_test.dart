import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/promotion_sharing/promotion_sharing_models.dart';

void main() {
  test('normalizes invite codes and legacy invite URLs like Android', () {
    expect(
      normalizePromotionInviteUrl(
        'INVITE-8',
        userId: 'user-1',
        isTestEnvironment: true,
      ),
      'https://img.jx885.com/pass-license/html/web-ult-test/invite.html?inviteCode=INVITE-8',
    );
    expect(
      normalizePromotionInviteUrl(
        'https://img.jx885.com/pass-license/html/invite/index.html?a=1',
        userId: 'user-1',
        isTestEnvironment: false,
      ),
      'https://img.jx885.com/pass-license/html/web-ult/invite.html?inviteCode=user-1',
    );
    expect(
      normalizePromotionInviteUrl(
        'https://img.jx885.com/pass-license/html/web-ult/invite.html?from=h5',
        userId: 'user-1',
        isTestEnvironment: false,
      ),
      'https://img.jx885.com/pass-license/html/web-ult/invite.html?from=h5&inviteCode=user-1',
    );
    expect(
      normalizePromotionInviteUrl(
        'https://example.com/custom-invite?code=2',
        userId: 'user-1',
        isTestEnvironment: false,
      ),
      'https://example.com/custom-invite?code=2',
    );
  });

  test('parses poster and resolves OSS template and sample paths', () {
    final poster = PromotionPoster.fromMap({
      'id': 12,
      'templateUrl': '/poster/template.png',
      'sampleUrl': 'poster/sample.png',
      'showStatus': 1,
    }, ossDomain: 'https://files.example.com/');

    expect(poster.id, '12');
    expect(poster.templateUrl, 'https://files.example.com/poster/template.png');
    expect(poster.previewUrl, 'https://files.example.com/poster/sample.png');
    expect(poster.showStatus, isTrue);
  });
}
