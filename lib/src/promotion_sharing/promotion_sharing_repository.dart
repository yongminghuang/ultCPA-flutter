import '../network/app_api_client.dart';
import '../storage/legacy_app_state_store.dart';
import 'promotion_sharing_models.dart';

abstract interface class PromotionSharingDataSource {
  Future<PromotionSharingSession> load(String inviteContent);
}

final class PromotionSharingRepository implements PromotionSharingDataSource {
  const PromotionSharingRepository({
    required AppApiClient api,
    required LegacyAppStateStore stateStore,
  }) : _api = api,
       _stateStore = stateStore;

  final AppApiClient _api;
  final LegacyAppStateStore _stateStore;

  @override
  Future<PromotionSharingSession> load(String inviteContent) async {
    final snapshot = await _stateStore.readAppSnapshot();
    final ossDomain = _text(snapshot['ossDomain']).trim();
    final posters = <PromotionPoster>[];
    try {
      final body = await _api.getBody('/app/promotionPoster/list');
      if (body is! List) {
        throw const FormatException('推广海报列表响应不是数组');
      }
      for (final raw in body) {
        if (raw is! Map) continue;
        final poster = PromotionPoster.fromMap(
          Map<String, dynamic>.from(raw),
          ossDomain: ossDomain,
        );
        if (poster.showStatus && poster.templateUrl.isNotEmpty) {
          posters.add(poster);
        }
      }
    } catch (_) {
      // Keep the locally persisted Android fallback usable while offline.
    }
    if (posters.isEmpty) {
      final fallbackUrl = resolvePromotionAssetUrl(
        _text(snapshot['recommendUrl']),
        ossDomain,
      );
      if (fallbackUrl.isNotEmpty) {
        posters.add(
          PromotionPoster(
            id: _text(snapshot['recommendId']).trim(),
            templateUrl: fallbackUrl,
            sampleUrl: fallbackUrl,
            showStatus: true,
          ),
        );
      }
    }
    return PromotionSharingSession(
      inviteUrl: normalizePromotionInviteUrl(
        inviteContent,
        userId: _text(snapshot['userId']),
        isTestEnvironment: snapshot['isTestEnvironment'] == true,
      ),
      profile: PromotionProfile(
        name: _text(snapshot['nickname']).trim(),
        phone: _text(snapshot['phone']).trim(),
      ),
      posters: posters,
    );
  }
}

String _text(Object? value) => value?.toString() ?? '';
