final class PromotionPoster {
  const PromotionPoster({
    required this.id,
    required this.templateUrl,
    required this.sampleUrl,
    required this.showStatus,
  });

  factory PromotionPoster.fromMap(
    Map<String, dynamic> map, {
    required String ossDomain,
  }) {
    return PromotionPoster(
      id: _text(map['id']).trim(),
      templateUrl: resolvePromotionAssetUrl(
        _text(map['templateUrl']),
        ossDomain,
      ),
      sampleUrl: resolvePromotionAssetUrl(_text(map['sampleUrl']), ossDomain),
      showStatus: _bool(map['showStatus'], fallback: true),
    );
  }

  final String id;
  final String templateUrl;
  final String sampleUrl;
  final bool showStatus;

  String get previewUrl => sampleUrl.isEmpty ? templateUrl : sampleUrl;
}

final class PromotionProfile {
  const PromotionProfile({required this.name, required this.phone});

  final String name;
  final String phone;
}

final class PromotionSharingSession {
  PromotionSharingSession({
    required this.inviteUrl,
    required this.profile,
    required List<PromotionPoster> posters,
  }) : posters = List<PromotionPoster>.unmodifiable(posters);

  final String inviteUrl;
  final PromotionProfile profile;
  final List<PromotionPoster> posters;
}

String normalizePromotionInviteUrl(
  String rawContent, {
  required String userId,
  required bool isTestEnvironment,
}) {
  final content = rawContent.trim();
  final inviteCode = content.isNotEmpty && !content.startsWith('http')
      ? content
      : userId.trim();
  final environment = isTestEnvironment ? 'web-ult-test' : 'web-ult';
  final replacement = Uri.https(
    'img.jx885.com',
    '/pass-license/html/$environment/invite.html',
    {'inviteCode': inviteCode},
  ).toString();
  if (content.isEmpty ||
      !content.startsWith('http') ||
      content.contains('pass-license/html/invite/index.html')) {
    return replacement;
  }
  final isCurrentInvite =
      content.contains('web-ult-test/invite.html') ||
      content.contains('web-ult/invite.html');
  if (!isCurrentInvite || content.contains('inviteCode=')) return content;
  final uri = Uri.tryParse(content);
  if (uri == null) return replacement;
  return uri
      .replace(
        queryParameters: {...uri.queryParameters, 'inviteCode': inviteCode},
      )
      .toString();
}

String resolvePromotionAssetUrl(String raw, String ossDomain) {
  final value = raw.trim();
  if (value.isEmpty || value.toLowerCase() == 'null') return '';
  final uri = Uri.tryParse(value);
  if (uri?.hasScheme == true) return value;
  final domain = ossDomain.trim();
  if (value.startsWith('//')) {
    return '${Uri.tryParse(domain)?.scheme.isNotEmpty == true ? Uri.parse(domain).scheme : 'https'}:$value';
  }
  if (domain.isEmpty) return value;
  return '${domain.replaceFirst(RegExp(r'/$'), '')}/${value.replaceFirst(RegExp(r'^/'), '')}';
}

bool _bool(Object? value, {required bool fallback}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().trim().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return fallback;
}

String _text(Object? value) => value?.toString() ?? '';
