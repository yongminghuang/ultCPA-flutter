import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/ultcpa_flutter.dart';

void main() {
  test('exports the complete pre-exam secret-paper public surface', () {
    expect(preExamSecretPaperCardCopies, hasLength(3));
    expect(<Type>[
      PreExamSecretPaper,
      PreExamSecretPaperCatalog,
      PreExamSecretPaperCardCopy,
      PreExamSecretPaperDataSource,
      PreExamSecretPaperRepository,
      PreExamSecretPaperPage,
      PreExamSecretPaperUnlockSource,
    ], hasLength(7));

    void examLauncher(BuildContext context, ExamRequest request) {}
    void unlockLauncher(PreExamSecretPaperUnlockSource source) {}
    final PreExamSecretPaperExamLauncher typedExamLauncher = examLauncher;
    final PreExamSecretPaperUnlockLauncher typedUnlockLauncher = unlockLauncher;
    expect(typedExamLauncher, isNotNull);
    expect(typedUnlockLauncher, isNotNull);
  });
}
