import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/startup/privacy_consent_dialog.dart';
import 'package:ultcpa_flutter/src/web/agreement_webview_page.dart';

void main() {
  testWidgets('shows the real agreement title and URL and closes with back', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => AgreementWebViewPage(
                    document: AgreementDocument.privacyPolicy,
                    contentBuilder: (context, uri) => Text('CONTENT:$uri'),
                  ),
                ),
              ),
              child: const Text('打开协议'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开协议'));
    await tester.pumpAndSettle();

    expect(find.text('隐私政策'), findsOneWidget);
    expect(
      find.text('CONTENT:https://img.jx885.com/pass-license/html/privacy.html'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    expect(find.text('打开协议'), findsOneWidget);
  });
}
