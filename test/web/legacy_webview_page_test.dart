import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/web/legacy_webview_page.dart';

void main() {
  testWidgets('shows the exact title and URI then returns with back', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(
        request: const LegacyWebRequest(
          url: 'https://example.com/collect-book?a=1&b=2',
          title: '领取书籍',
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byType(LegacyWebViewPage), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('领取书籍'), findsOneWidget);
    expect(
      find.text('CONTENT:https://example.com/collect-book?a=1&b=2'),
      findsOneWidget,
    );
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
    expect(scaffold.backgroundColor, Colors.white);

    await tester.tap(find.byKey(const ValueKey('legacy-web-back')));
    await tester.pumpAndSettle();
    expect(find.text('打开'), findsOneWidget);
  });

  testWidgets('hidden-title mode is full screen and supports system back', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(
        request: const LegacyWebRequest(
          url: 'https://example.com/invite?t=token&env=test',
          title: '邀请好友',
          hideTitleBar: true,
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byType(LegacyWebViewPage), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('邀请好友'), findsNothing);
    expect(
      find.text('CONTENT:https://example.com/invite?t=token&env=test'),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('打开'), findsOneWidget);
  });

  testWidgets('both title modes fit a 320 by 568 viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final hidden in <bool>[false, true]) {
      await tester.pumpWidget(
        _Harness(
          key: ValueKey(hidden),
          request: LegacyWebRequest(
            url: 'https://example.com/${List.filled(20, 'path/').join()}',
            title: '很长的网页标题用于窄屏布局验证',
            hideTitleBar: hidden,
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'hidden=$hidden');
    }
  });
}

final class _Harness extends StatelessWidget {
  const _Harness({required this.request, super.key});

  final LegacyWebRequest request;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => LegacyWebViewPage(
                    request: request,
                    contentBuilder: (context, uri) => Center(
                      child: Text(
                        'CONTENT:$uri',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
  }
}
