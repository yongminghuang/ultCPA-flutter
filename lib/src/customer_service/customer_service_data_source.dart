import '../network/app_api_client.dart';

abstract interface class CustomerServiceDataSource {
  Future<String?> loadUrl();
}

final class AppApiCustomerServiceDataSource
    implements CustomerServiceDataSource {
  const AppApiCustomerServiceDataSource({required AppApiClient api})
    : _api = api;

  static const path = '/app/v2/getWxCustomerUrl';

  final AppApiClient _api;

  @override
  Future<String?> loadUrl() async {
    final body = await _api.getBody(path);
    if (body == null || body is String) return body as String?;
    throw const FormatException('客服链接解析失败');
  }
}
