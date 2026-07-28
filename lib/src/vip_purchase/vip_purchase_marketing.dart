const vipPurchasePainPoints = <String>[
  '想要快速提分拿证',
  '找不到重点难点',
  '不了解具体考试内容情况难度',
  '基础差，还没开始复习',
  '工作忙，没时间系统学习',
];

final class VipStudentShare {
  const VipStudentShare({
    required this.name,
    required this.content,
    this.boldKeywords = const [],
  });

  final String name;
  final String content;
  final List<String> boldKeywords;
}

final class VipSocialComparison {
  const VipSocialComparison({
    required this.leftTitle,
    required this.leftDescription,
    required this.rightTitle,
    required this.rightDescription,
  });

  final String leftTitle;
  final String leftDescription;
  final String rightTitle;
  final String rightDescription;
}

final class VipPurchaseMarketing {
  const VipPurchaseMarketing({
    required this.showSocialComparison,
    required this.showAccountingGuarantee,
    required this.socialComparisons,
    required this.guaranteeTags,
    required this.guaranteeBullets,
    required this.studentShares,
  });

  final bool showSocialComparison;
  final bool showAccountingGuarantee;
  final List<VipSocialComparison> socialComparisons;
  final List<String> guaranteeTags;
  final List<String> guaranteeBullets;
  final List<VipStudentShare> studentShares;
}

VipPurchaseMarketing resolveVipPurchaseMarketing({
  required String category,
  required String level,
}) {
  final isSocialWork = category.trim() == 'social-work';
  final isJoyLedger = category.trim() == 'joy-ledger';
  final isIntermediateEconomist = isJoyLedger && level.trim() == '中级经济师';
  return VipPurchaseMarketing(
    showSocialComparison: isSocialWork,
    showAccountingGuarantee: !isSocialWork,
    socialComparisons: _socialComparisons,
    guaranteeTags: isIntermediateEconomist
        ? const []
        : _guaranteeTags(category.trim(), level.trim()),
    guaranteeBullets: isIntermediateEconomist
        ? _economistGuaranteeBullets
        : _defaultGuaranteeBullets,
    studentShares: isIntermediateEconomist
        ? _intermediateEconomistShares
        : isJoyLedger
        ? _joyLedgerShares
        : _socialWorkShares,
  );
}

List<String> _guaranteeTags(String category, String level) {
  if (category == 'joy-ledger') {
    return switch (level) {
      '中级会计' => const ['会计实务200+技巧', '经济法200+技巧', '财管100+技巧'],
      _ => const ['会计实务200+技巧', '经济法基础100+技巧'],
    };
  }
  return level == '初级社工'
      ? const ['社工实务200+技巧', '综合能力100+技巧']
      : const ['法规与政策200+技巧', '综合能力100+技巧'];
}

const _defaultGuaranteeBullets = <String>[
  '技巧覆盖核心考点用大白话讲,解做题方法，总结考试规律，提升准确率',
  '精准练题，精选好题、母题紧扣考纲讲解',
  '答题技巧简单易懂，化繁为简，做一题通一类',
  '直播+回放提高高效学习，琐记考点',
];

const _economistGuaranteeBullets = <String>[
  '技巧覆盖核心考点\n用大白话讲解题方法\n总结考试规律\n提升准确率',
  '精讲母题，精选好题\n母题紧扣考纲讲解',
  '答题技巧简单易懂\n化繁为简\n做一题通一类',
  '直播+回放提高高效学习，琐记考点',
];

const _joyLedgerShares = <VipStudentShare>[
  VipStudentShare(
    name: '小林(初级通关学员)',
    content:
        '“零基础小白也能一次过！用APP的【技巧练题】功能，自动匹配薄弱点推送真题。'
        '分录口诀+税法速记表+AI智能解析，2个月从入门到拿证，告别死记硬背！”',
    boldKeywords: ['【技巧练题】功能'],
  ),
  VipStudentShare(
    name: '王女士(在职考生)',
    content:
        '“白天上班，晚上用10分钟刷一组「考点秒杀题」，周末做「真题技巧解析」。'
        '实务分录用套路模板，经济法用关键词记忆法，高效刷题让我1年过双科，升职加薪稳了！”',
    boldKeywords: ['「考点秒杀题」', '「真题技巧解析」'],
  ),
];

const _intermediateEconomistShares = <VipStudentShare>[
  VipStudentShare(
    name: '小林(零基础小白)',
    content:
        '“专业术语像天书，刷题1000道还是抓不住重点，每天学5小时却越学越慌。'
        '用【速成300题】直击高频核心考点，3天掌握‘万能答题技巧+高频考点’，套题直接套出正确答案！'
        '2个月从零基础到稳过拿证，证书到手当天，HR主动加薪30%约谈！”',
    boldKeywords: ['【速成300题】'],
  ),
  VipStudentShare(
    name: '王女士(在职妈妈)',
    content:
        '“白天上班+带娃，晚上只能挤10分钟刷题。用【技巧练题】+【历年真题卷】，'
        '周末套用‘技巧口诀’，1年过2科！现在薪资涨了30%，考证真的改变了我的职场命运！”',
    boldKeywords: ['【技巧练题】', '【历年真题卷】', '技巧口诀'],
  ),
];

const _socialWorkShares = <VipStudentShare>[
  VipStudentShare(
    name: '张女士(初级VIP)',
    content:
        '“零基础在职备考，每天只有1小时。《初级实务》 + 《初级综合》双科一次过！'
        '多亏了考前押题卷和思维导图，太省心了！”',
    boldKeywords: ['《初级实务》', '《初级综合》'],
  ),
  VipStudentShare(
    name: '王先生(中级VIP)',
    content:
        '“《中级法规》条款太多记不住，《实务》案例分析没思路。'
        '跟着老师直播课梳理重点，终于拿下中级社工证，今年评职称稳了！”',
    boldKeywords: ['《中级法规》', '《实务》'],
  ),
];

const _socialComparisons = <VipSocialComparison>[
  VipSocialComparison(
    leftTitle: '基础差',
    leftDescription: '基础薄弱，无从下手？\n知识点散乱不成体系？',
    rightTitle: '3阶直播',
    rightDescription: '老师带学带练\n全程答题技巧',
  ),
  VipSocialComparison(
    leftTitle: '时间少',
    leftDescription: '学习时间少\n备考周期有限？',
    rightTitle: '极速密训',
    rightDescription: '考前关门密训\n老师亲划重点',
  ),
  VipSocialComparison(
    leftTitle: '做题难',
    leftDescription: '一学就会\n 一做就废？',
    rightTitle: '技巧练题',
    rightDescription: '技巧智能解析\n搞定错题难题',
  ),
  VipSocialComparison(
    leftTitle: '疑问多',
    leftDescription: '遇到难题，无人可问？\n越积越多，最终选择放弃？',
    rightTitle: '群答疑',
    rightDescription: '随时解答\n及时扫清学习障碍',
  ),
  VipSocialComparison(
    leftTitle: '无保障',
    leftDescription: '担心考试没过\n白花钱怎么办？',
    rightTitle: '通关险',
    rightDescription: '额外1年通关险！\n通关更无忧',
  ),
];
