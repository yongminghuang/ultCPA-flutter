import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/startup/privacy_consent_dialog.dart';

void main() {
  testWidgets('matches the Android two-stage decline flow', (tester) async {
    var accepted = false;
    var exited = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivacyConsentDialog(
            onAccept: () => accepted = true,
            onExit: () => exited = true,
            onOpenDocument: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('个人信息保护指引'), findsOneWidget);
    expect(find.text('同意'), findsOneWidget);
    expect(find.text('不同意'), findsOneWidget);

    await tester.tap(find.text('不同意'));
    await tester.pump();

    expect(find.text('温馨提示'), findsOneWidget);
    expect(find.text('同意并继续'), findsOneWidget);
    expect(find.text('放弃使用'), findsOneWidget);

    await tester.tap(find.text('放弃使用'));
    expect(exited, isTrue);
    expect(accepted, isFalse);
  });

  testWidgets('accepts from either Android consent stage', (tester) async {
    var acceptCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivacyConsentDialog(
            onAccept: () => acceptCount += 1,
            onExit: () {},
            onOpenDocument: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('同意'));
    expect(acceptCount, 1);
  });

  testWidgets('opens the real privacy and user agreement URLs', (tester) async {
    final opened = <AgreementDocument>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivacyConsentDialog(
            onAccept: () {},
            onExit: () {},
            onOpenDocument: opened.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('privacy-policy-link')));
    await tester.tap(find.byKey(const Key('user-agreement-link')));

    expect(opened, <AgreementDocument>[
      AgreementDocument.privacyPolicy,
      AgreementDocument.userAgreement,
    ]);
    expect(
      AgreementDocument.privacyPolicy.uri.toString(),
      'https://img.jx885.com/pass-license/html/privacy.html',
    );
    expect(
      AgreementDocument.userAgreement.uri.toString(),
      'https://img.jx885.com/pass-license/html/user.html',
    );
  });
}
