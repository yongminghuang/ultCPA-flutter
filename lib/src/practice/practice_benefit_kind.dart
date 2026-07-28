enum PracticeBenefitKind {
  regularPractice('practice_skill', '技巧练题功能'),
  fastPractice('practice_speed', '速成300题功能'),
  chapterPractice('practice_chapter', '章节练习权益'),
  pastExams('past_exams', '历年真题卷功能');

  const PracticeBenefitKind(this.benefitType, this.defaultBenefitName);

  final String benefitType;
  final String defaultBenefitName;
}
