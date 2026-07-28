import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/home_module_route.dart';

void main() {
  test('resolves the migrated mnemonic route after trimming', () {
    expect(
      resolveHomeModuleRoute('  技巧口诀  '),
      const ReadyHomeModuleRoute(HomeDestination.skillMnemonics),
    );
  });

  test('resolves current and historical practice routes', () {
    for (final page in ['技巧练题', '推广技巧', '首页大招练题活动']) {
      expect(
        resolveHomeModuleRoute(page),
        const ReadyHomeModuleRoute(HomeDestination.practice),
        reason: page,
      );
    }
  });

  test('resolves wrong-question consolidation as a ready review route', () {
    expect(
      resolveHomeModuleRoute('错题巩固'),
      const ReadyHomeModuleRoute(HomeDestination.errorReview),
    );
  });

  test('resolves chapter practice as its own ready catalog route', () {
    expect(
      resolveHomeModuleRoute('  章节练习  '),
      const ReadyHomeModuleRoute(HomeDestination.chapterPractice),
    );
  });

  test('resolves current and historical fast-practice routes', () {
    for (final page in ['速成300题', '速成N题', '首页速成300冲刺活动']) {
      expect(
        resolveHomeModuleRoute(page),
        const ReadyHomeModuleRoute(HomeDestination.fastPractice),
        reason: page,
      );
    }
  });

  test('resolves the exact daily skill route after trimming', () {
    expect(
      resolveHomeModuleRoute('  每日一招  '),
      const ReadyHomeModuleRoute(HomeDestination.dailySkill),
    );
  });

  test('resolves exact and historical pre-exam six-paper routes', () {
    for (final page in ['考前6页纸', '首页考前6页纸限时入口']) {
      expect(
        resolveHomeModuleRoute(page),
        const ReadyHomeModuleRoute(HomeDestination.preExamSixPaper),
        reason: page,
      );
    }
  });

  test('resolves exact and historical smart-card routes', () {
    for (final page in ['技巧卡片', '首页大招卡片限时入口']) {
      expect(
        resolveHomeModuleRoute(page),
        const ReadyHomeModuleRoute(HomeDestination.smartCard),
        reason: page,
      );
    }
  });

  test('resolves the exact past-exams route after trimming', () {
    expect(
      resolveHomeModuleRoute('  历年真题卷  '),
      const ReadyHomeModuleRoute(HomeDestination.pastExams),
    );
  });

  test('resolves exact and historical secret-paper routes', () {
    for (final page in [' 最后密押卷 ', '首页最后密押卷限时入口']) {
      expect(
        resolveHomeModuleRoute(page),
        const ReadyHomeModuleRoute(HomeDestination.preExamSecretPaper),
        reason: page,
      );
    }
  });

  test('resolves the Home free teacher-course route', () {
    expect(
      resolveHomeModuleRoute('  技巧讲解  '),
      const ReadyHomeModuleRoute(HomeDestination.teacherCourse),
    );
  });

  test('resolves learning materials and drops the retired circle entry', () {
    expect(
      resolveHomeModuleRoute('  学习资料  '),
      const ReadyHomeModuleRoute(HomeDestination.learningMaterials),
    );
    expect(
      resolveHomeModuleRoute('技巧圈题卷'),
      const UnsupportedHomeModuleRoute(
        reason: HomeRouteFailure.unknown,
        rawPage: '技巧圈题卷',
      ),
    );
  });

  test('distinguishes empty and unknown page values', () {
    expect(
      resolveHomeModuleRoute('  '),
      const UnsupportedHomeModuleRoute(reason: HomeRouteFailure.empty),
    );
    expect(
      resolveHomeModuleRoute('mnemonics'),
      const UnsupportedHomeModuleRoute(
        reason: HomeRouteFailure.unknown,
        rawPage: 'mnemonics',
      ),
    );
  });

  test('supports Android historical contains-based jump text', () {
    expect(
      resolveHomeModuleRoute('立即学习大招口诀详情'),
      const ReadyHomeModuleRoute(HomeDestination.skillMnemonics),
    );
    expect(
      resolveHomeModuleRoute('首页大招练题活动'),
      const ReadyHomeModuleRoute(HomeDestination.practice),
    );
    expect(
      resolveHomeModuleRoute('会员付费入口'),
      const ReadyHomeModuleRoute(HomeDestination.vipPurchase),
    );
    expect(
      resolveHomeModuleRoute('首页速成300冲刺活动'),
      const ReadyHomeModuleRoute(HomeDestination.fastPractice),
    );
    expect(
      resolveHomeModuleRoute('首页考前6页纸限时入口'),
      const ReadyHomeModuleRoute(HomeDestination.preExamSixPaper),
    );
    expect(
      resolveHomeModuleRoute('首页最后密押卷限时入口'),
      const ReadyHomeModuleRoute(HomeDestination.preExamSecretPaper),
    );
  });
}
