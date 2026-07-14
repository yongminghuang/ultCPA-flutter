import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/app/startup_app.dart';
import 'package:ultcpa_flutter/src/startup/startup_splash_page.dart';

void main() {
  testWidgets('starts on the real splash without a debug banner', (
    tester,
  ) async {
    await tester.pumpWidget(const StartupApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(find.byType(StartupSplashPage), findsOneWidget);
  });
}
