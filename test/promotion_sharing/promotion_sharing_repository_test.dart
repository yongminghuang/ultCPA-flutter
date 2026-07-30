import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';
import 'package:ultcpa_flutter/src/promotion_sharing/promotion_sharing_repository.dart';
import 'package:ultcpa_flutter/src/storage/legacy_app_state_store.dart';

void main() {
  test('loads visible promotion posters and account profile', () async {
    final api = _Api([
      {
        'id': 1,
        'templateUrl': 'one.png',
        'sampleUrl': 'one-small.png',
        'showStatus': true,
      },
      {'id': 2, 'templateUrl': 'two.png', 'showStatus': false},
    ]);
    final repository = PromotionSharingRepository(
      api: api,
      stateStore: _Store(),
    );

    final session = await repository.load('');

    expect(api.paths, ['/app/promotionPoster/list']);
    expect(session.posters, hasLength(1));
    expect(session.posters.single.templateUrl, 'https://oss.test/one.png');
    expect(session.profile.name, '推广老师');
    expect(session.profile.phone, '13800138000');
    expect(session.inviteUrl, contains('inviteCode=user-9'));
  });
}

final class _Api implements AppApiClient {
  _Api(this.body);

  final Object? body;
  final paths = <String>[];

  @override
  Future<Object?> getBody(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    paths.add(path);
    return body;
  }

  @override
  Future<Object?> postBody(String path, Map<String, dynamic> body) {
    throw UnimplementedError();
  }
}

final class _Store implements LegacyAppStateStore {
  @override
  Future<Map<String, dynamic>> readAppSnapshot() async => {
    'ossDomain': 'https://oss.test/',
    'userId': 'user-9',
    'nickname': '推广老师',
    'phone': '13800138000',
    'isTestEnvironment': false,
  };

  @override
  Future<void> persistCategorySelection({
    required String categoryBodyJson,
    required String category,
    required Map<String, dynamic> selectedCategory,
    required String selectedCategoryKey,
    required int marketId,
    required String subject,
  }) async {}
}
