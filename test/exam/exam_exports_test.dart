import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/ultcpa_flutter.dart';

void main() {
  test('exports the complete normal-exam public surface', () {
    expect(ExamQuestionStatus.right.name, 'right');
    expect(<Type>[
      ExamRequest,
      ExamCatalog,
      ExamAnswerSection,
      ExamResult,
      ExamSession,
      ExamDataSource,
      ExamRepository,
      ExamPage,
      ExamResultPage,
      ExamReviewPage,
    ], hasLength(10));

    void resultLauncher(
      BuildContext context, {
      required ExamResult result,
      required bool uploadFailed,
    }) {}
    void improveLauncher(BuildContext context) {}
    final ExamResultLauncher typedResultLauncher = resultLauncher;
    final ExamImproveLauncher typedImproveLauncher = improveLauncher;
    expect(typedResultLauncher, isNotNull);
    expect(typedImproveLauncher, isNotNull);
  });
}
