import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/ultcpa_flutter.dart';

void main() {
  test('exports the complete daily skill public surface', () {
    expect(<Type>[
      DailySkillDetail,
      DailySkillAnswer,
      DailySkillDataSource,
      DailySkillRepository,
      DailySkillProgress,
      DailySkillProgressDataSource,
      DailySkillProgressStore,
      DailySkillDetailPage,
      DailySkillReportPage,
      DailySkillPracticeRequest,
    ], hasLength(10));
  });
}
