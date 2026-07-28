import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/ultcpa_flutter.dart';

void main() {
  test('exports the complete past-exams public surface', () {
    expect(pastExamFreePaperCount, 2);
    expect(<Type>[
      PastExamPaper,
      PastExamsCatalog,
      PastExamsDataSource,
      PastExamsRepository,
      PastExamsPage,
    ], hasLength(5));

    void examLauncher(BuildContext context, ExamRequest request) {}
    void unlockLauncher() {}
    final PastExamLauncher typedExamLauncher = examLauncher;
    final PastExamsUnlockLauncher typedUnlockLauncher = unlockLauncher;
    expect(typedExamLauncher, isNotNull);
    expect(typedUnlockLauncher, isNotNull);
  });
}
