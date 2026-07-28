import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_marketing.dart';

void main() {
  test('pins Android full-screen purchase pain points', () {
    expect(vipPurchasePainPoints, [
      '想要快速提分拿证',
      '找不到重点难点',
      '不了解具体考试内容情况难度',
      '基础差，还没开始复习',
      '工作忙，没时间系统学习',
    ]);
  });

  test('uses the five social-work comparison rows and student shares', () {
    final content = resolveVipPurchaseMarketing(
      category: 'social-work',
      level: '初级社工',
    );

    expect(content.showSocialComparison, isTrue);
    expect(content.showAccountingGuarantee, isFalse);
    expect(content.socialComparisons, hasLength(5));
    expect(content.socialComparisons.first.leftTitle, '基础差');
    expect(
      content.socialComparisons.first.leftDescription,
      '基础薄弱，无从下手？\n知识点散乱不成体系？',
    );
    expect(content.socialComparisons.last.rightTitle, '通关险');
    expect(content.socialComparisons.last.rightDescription, '额外1年通关险！\n通关更无忧');
    expect(content.studentShares.map((share) => share.name), [
      '张女士(初级VIP)',
      '王先生(中级VIP)',
    ]);
    expect(content.guaranteeTags, ['社工实务200+技巧', '综合能力100+技巧']);
  });

  test('uses accounting tags bullets and joy-ledger student shares', () {
    final initial = resolveVipPurchaseMarketing(
      category: 'joy-ledger',
      level: '初级会计',
    );
    final intermediate = resolveVipPurchaseMarketing(
      category: 'joy-ledger',
      level: '中级会计',
    );

    expect(initial.showAccountingGuarantee, isTrue);
    expect(initial.showSocialComparison, isFalse);
    expect(initial.guaranteeTags, ['会计实务200+技巧', '经济法基础100+技巧']);
    expect(intermediate.guaranteeTags, ['会计实务200+技巧', '经济法200+技巧', '财管100+技巧']);
    expect(initial.guaranteeBullets, [
      '技巧覆盖核心考点用大白话讲,解做题方法，总结考试规律，提升准确率',
      '精准练题，精选好题、母题紧扣考纲讲解',
      '答题技巧简单易懂，化繁为简，做一题通一类',
      '直播+回放提高高效学习，琐记考点',
    ]);
    expect(initial.studentShares.map((share) => share.name), [
      '小林(初级通关学员)',
      '王女士(在职考生)',
    ]);
    expect(initial.studentShares.first.content, contains('2个月从入门到拿证'));
    expect(initial.studentShares.first.boldKeywords, ['【技巧练题】功能']);
  });

  test('uses the intermediate-economist copy and hides guarantee tags', () {
    final content = resolveVipPurchaseMarketing(
      category: 'joy-ledger',
      level: '中级经济师',
    );

    expect(content.guaranteeTags, isEmpty);
    expect(content.guaranteeBullets, [
      '技巧覆盖核心考点\n用大白话讲解题方法\n总结考试规律\n提升准确率',
      '精讲母题，精选好题\n母题紧扣考纲讲解',
      '答题技巧简单易懂\n化繁为简\n做一题通一类',
      '直播+回放提高高效学习，琐记考点',
    ]);
    expect(content.studentShares.map((share) => share.name), [
      '小林(零基础小白)',
      '王女士(在职妈妈)',
    ]);
    expect(content.studentShares.first.content, contains('HR主动加薪30%约谈'));
  });
}
