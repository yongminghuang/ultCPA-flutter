import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/ultcpa_flutter.dart';

void main() {
  test('exports the complete pre-exam six-paper public surface', () {
    expect(PreExamSixPaperEntryDestination.preview.name, 'preview');
    expect(<Type>[
      PreExamSixPaperEntry,
      PreExamSixPaperFile,
      PreExamSixPaperDataSource,
      PreExamSixPaperRepository,
      PreExamSixPaperFileTransfer,
      PreExamSixPaperNativeBridge,
      MethodChannelPreExamSixPaperNativeBridge,
      DioPreExamSixPaperFileTransfer,
      PreExamSixPaperLandingPage,
      PreExamSixPaperPreviewPage,
      PreExamSixPaperEntryPage,
    ], hasLength(11));

    Widget builder(
      BuildContext context, {
      required String? url,
      required String? html,
      required String baseUrl,
    }) => const SizedBox();
    final PreExamSixPaperContentBuilder typedBuilder = builder;
    expect(typedBuilder, isNotNull);
    expect(limitPreExamSixPaperTitle('ABCDEFGHIJK'), 'ABCDEFGHIJ..');
    expect(preExamSixPaperShareMimeType('/cache/a.pdf'), 'application/pdf');
  });
}
