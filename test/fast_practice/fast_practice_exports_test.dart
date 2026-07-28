import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/ultcpa_flutter.dart';

void main() {
  test('exports the complete fast-practice surface', () {
    expect(FastPracticeEntryDestination.catalog.name, 'catalog');
    expect(FastPracticeEntryPage, isNotNull);
    expect(FastPracticeCatalogPage, isNotNull);
    expect(FastPracticeLandingPage, isNotNull);
    expect(FastPracticeRepository, isNotNull);
    expect(
      const DisabledFlatPracticeProgressStore(),
      isA<FlatPracticeProgressStore>(),
    );
  });
}
