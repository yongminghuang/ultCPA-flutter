enum HomeDestination {
  skillMnemonics,
  teacherCourse,
  vipPurchase,
  practice,
  chapterPractice,
  fastPractice,
  errorReview,
  dailySkill,
  preExamSixPaper,
  preExamSecretPaper,
  smartCard,
  pastExams,
  learningMaterials,
}

enum HomeRouteFailure { empty, unknown }

sealed class HomeModuleRoute {
  const HomeModuleRoute();
}

final class ReadyHomeModuleRoute extends HomeModuleRoute {
  const ReadyHomeModuleRoute(this.destination);

  final HomeDestination destination;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ReadyHomeModuleRoute && other.destination == destination;
  }

  @override
  int get hashCode => destination.hashCode;
}

final class PendingHomeModuleRoute extends HomeModuleRoute {
  const PendingHomeModuleRoute(this.canonicalPage);

  final String canonicalPage;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PendingHomeModuleRoute && other.canonicalPage == canonicalPage;
  }

  @override
  int get hashCode => canonicalPage.hashCode;
}

final class UnsupportedHomeModuleRoute extends HomeModuleRoute {
  const UnsupportedHomeModuleRoute({required this.reason, this.rawPage = ''});

  final HomeRouteFailure reason;
  final String rawPage;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UnsupportedHomeModuleRoute &&
            other.reason == reason &&
            other.rawPage == rawPage;
  }

  @override
  int get hashCode => Object.hash(reason, rawPage);
}

HomeModuleRoute resolveHomeModuleRoute(String rawPage) {
  final page = rawPage.trim();
  if (page.isEmpty) {
    return const UnsupportedHomeModuleRoute(reason: HomeRouteFailure.empty);
  }
  if (page == '技巧讲解') {
    return const ReadyHomeModuleRoute(HomeDestination.teacherCourse);
  }
  if (page == '技巧口诀') {
    return const ReadyHomeModuleRoute(HomeDestination.skillMnemonics);
  }
  if (page == '技巧练题' || page == '推广技巧') {
    return const ReadyHomeModuleRoute(HomeDestination.practice);
  }
  if (page == '错题巩固') {
    return const ReadyHomeModuleRoute(HomeDestination.errorReview);
  }
  if (page == '章节练习') {
    return const ReadyHomeModuleRoute(HomeDestination.chapterPractice);
  }
  if (page == '速成300题' || page == '速成N题') {
    return const ReadyHomeModuleRoute(HomeDestination.fastPractice);
  }
  if (page == '每日一招') {
    return const ReadyHomeModuleRoute(HomeDestination.dailySkill);
  }
  if (page == '考前6页纸') {
    return const ReadyHomeModuleRoute(HomeDestination.preExamSixPaper);
  }
  if (page == '最后密押卷') {
    return const ReadyHomeModuleRoute(HomeDestination.preExamSecretPaper);
  }
  if (page == '技巧卡片') {
    return const ReadyHomeModuleRoute(HomeDestination.smartCard);
  }
  if (page == '历年真题卷') {
    return const ReadyHomeModuleRoute(HomeDestination.pastExams);
  }
  if (page == '学习资料') {
    return const ReadyHomeModuleRoute(HomeDestination.learningMaterials);
  }
  if (page.contains('大招口诀')) {
    return const ReadyHomeModuleRoute(HomeDestination.skillMnemonics);
  }
  if (page.contains('大招练题')) {
    return const ReadyHomeModuleRoute(HomeDestination.practice);
  }
  if (page.contains('速成300')) {
    return const ReadyHomeModuleRoute(HomeDestination.fastPractice);
  }
  if (page.contains('考前6页纸')) {
    return const ReadyHomeModuleRoute(HomeDestination.preExamSixPaper);
  }
  if (page.contains('大招卡片')) {
    return const ReadyHomeModuleRoute(HomeDestination.smartCard);
  }
  if (page.contains('最后密押卷')) {
    return const ReadyHomeModuleRoute(HomeDestination.preExamSecretPaper);
  }
  const historicalReadyPages = <(String, HomeDestination)>[
    ('会员付费', HomeDestination.vipPurchase),
  ];
  for (final (token, destination) in historicalReadyPages) {
    if (page.contains(token)) return ReadyHomeModuleRoute(destination);
  }
  return UnsupportedHomeModuleRoute(
    reason: HomeRouteFailure.unknown,
    rawPage: page,
  );
}
