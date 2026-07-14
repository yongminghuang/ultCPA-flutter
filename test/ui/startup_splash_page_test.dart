import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/startup/startup_splash_page.dart';

void main() {
  testWidgets('fills the screen with the Android splash artwork', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: StartupSplashPage(),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, const AssetImage('assets/images/bg_wel_new.png'));
    expect(image.fit, BoxFit.fill);
    expect(
      find.text('You have pushed the button this many times:'),
      findsNothing,
    );
  });
}
