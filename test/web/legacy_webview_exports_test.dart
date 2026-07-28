import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/ultcpa_flutter.dart';

void main() {
  test('exports the legacy web request, page, and Mine route resolver', () {
    const request = LegacyWebRequest(
      url: 'https://example.com/collect-book',
      title: 'Collect book',
    );
    const page = LegacyWebViewPage(request: request);

    final resolved = MineWebRouteResolver.collectBook(
      ' https://example.com/collect-book ',
    );

    expect(page.request, same(request));
    expect(resolved, isA<LegacyWebRequest>());
    expect(resolved?.url, request.url);
  });
}
