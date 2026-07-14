import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/ui/golden_surface.dart';

void main() {
  testWidgets('pins media size and text scaling', (tester) async {
    late MediaQueryData media;
    await tester.pumpWidget(
      GoldenSurface(
        child: Builder(
          builder: (context) {
            media = MediaQuery.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(media.size, const Size(360, 800));
    expect(media.devicePixelRatio, 1);
    expect(media.textScaler.scale(16), 16);
    expect(media.padding, EdgeInsets.zero);
  });
}
