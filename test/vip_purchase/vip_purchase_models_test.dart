import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/practice/practice_benefit_kind.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_models.dart';

void main() {
  group('VIP product types', () {
    test('maps Android indexes labels and API values', () {
      expect(VipProductType.skill.androidIndex, 0);
      expect(VipProductType.skill.label, '答题技巧VIP');
      expect(VipProductType.skill.apiValue, 'skills_feature_package');
      expect(VipProductType.svip.androidIndex, 1);
      expect(VipProductType.svip.label, '全能 SVIP');
      expect(VipProductType.svip.apiValue, 'level_member');
      expect(VipProductType.course.androidIndex, 2);
      expect(VipProductType.course.label, '课程VIP');
      expect(VipProductType.course.apiValue, 'video_course');
    });

    test('uses skill only without media and SVIP first when expanded', () {
      expect(visibleVipProductTypes(expanded: false), [VipProductType.skill]);
      expect(visibleVipProductTypes(expanded: true), [
        VipProductType.svip,
        VipProductType.skill,
        VipProductType.course,
      ]);
      expect(defaultVipProductType(expanded: false), VipProductType.skill);
      expect(defaultVipProductType(expanded: true), VipProductType.svip);
      expect(
        defaultVipProductType(expanded: true, explicit: VipProductType.course),
        VipProductType.course,
      );
      expect(
        defaultVipProductType(expanded: false, explicit: VipProductType.course),
        VipProductType.skill,
      );
    });

    test('payment sources preserve Android attribution and flow policy', () {
      expect(VipPayEntry.fast300.conversionEntryId, 1010);
      expect(VipPayEntry.secretPaperList.conversionEntryId, 1011);
      expect(VipPayEntry.secretPaperBottom.conversionEntryId, 1012);
      expect(VipPayEntry.smartCard.conversionEntryId, 1013);
      expect(VipPayEntry.preExamSixPaper.conversionEntryId, 1014);
      expect(VipPayEntry.pastExams.conversionEntryId, 1021);
      expect(VipPayEntry.circlePaperResult.conversionEntryId, 1026);

      expect(VipPaymentSource.home.normalPayPageSourceId, 1001);
      expect(VipPaymentSource.home.differencePayPageSourceId, 2001);
      expect(VipPaymentSource.home.returnPolicy, VipPurchaseReturnPolicy.home);
      expect(VipPaymentSource.homeTopBanner.normalPayPageSourceId, 1025);
      expect(
        VipPaymentSource.homeMarketingFloat.presentation,
        VipPaymentPresentation.practicePackage,
      );
      expect(
        VipPaymentSource.homeMarketingFloat.successDestination,
        VipPurchaseSuccessDestination.practicePackage,
      );
      expect(VipPaymentSource.fast300.differencePayPageSourceId, 2003);
      expect(VipPaymentSource.smartCard.differencePayPageSourceId, 2004);
      expect(VipPaymentSource.courseTrial.differencePayPageSourceId, 2008);

      final request = VipPurchaseRequest.popup(
        entry: VipPayEntry.fast300,
        defaultProductType: VipProductType.skill,
      );

      expect(request.normalPayPageSourceId, 1010);
      expect(request.differencePayPageSourceId, 2003);
      expect(request.presentation, VipPaymentPresentation.sheet);
      expect(request.defaultProductType, VipProductType.skill);
    });

    test('full-screen requests preserve the attributed Android entry', () {
      final request = VipPurchaseRequest.fullScreen(
        entry: VipPayEntry.preExamSixPaper,
      );

      expect(request.normalPayPageSourceId, 1014);
      expect(request.differencePayPageSourceId, 1014);
      expect(request.presentation, VipPaymentPresentation.fullScreen);
      expect(request.defaultProductType, isNull);
    });

    test(
      'Home and Mine requests keep distinct normal and difference sources',
      () {
        const home = VipPurchaseRequest.home();
        const banner = VipPurchaseRequest.topBanner();
        const mine = VipPurchaseRequest.mine();

        expect(
          (home.normalPayPageSourceId, home.differencePayPageSourceId),
          (1001, 2001),
        );
        expect(home.returnPolicy, VipPurchaseReturnPolicy.home);
        expect(
          (banner.normalPayPageSourceId, banner.differencePayPageSourceId),
          (1025, 2001),
        );
        expect(
          (mine.normalPayPageSourceId, mine.differencePayPageSourceId),
          (1020, 2002),
        );
      },
    );
  });

  group('VIP formatting', () {
    test('rounds money half up and strips trailing zeros', () {
      expect(formatVipMoney(0), '0');
      expect(formatVipMoney(19.9), '19.9');
      expect(formatVipMoney(19.995), '20');
      expect(formatVipMoney(120), '120');
      expect(() => formatVipMoney(double.nan), throwsArgumentError);
    });

    test('formats per-subject daily price with two decimals', () {
      expect(
        formatVipDailyPrice(totalPrice: 39.9, subjectCount: 2, days: 90),
        '仅¥0.22/科/天',
      );
      expect(formatVipDailyPrice(totalPrice: 0, subjectCount: 2, days: 90), '');
      expect(
        formatVipDailyPrice(totalPrice: 39.9, subjectCount: 0, days: 90),
        '',
      );
    });

    test('prefers matching expiry minutes and falls back to SKU name', () {
      const productSkus = [
        VipProductSku(skuName: '季卡', benefitsExpiryMinute: 129600),
        VipProductSku(skuName: '年卡', benefitsExpiryMinute: 525600),
      ];
      expect(resolveVipSkuDays('季卡', productSkus), 90);
      expect(resolveVipSkuDays('月卡', productSkus), 30);
      expect(resolveVipSkuDays('年卡', const []), 365);
      expect(resolveVipSkuDays('终身卡', const []), 0);
    });
  });

  group('VIP subject selection', () {
    const subjects = [
      VipSubject(id: 6, name: '会计实务'),
      VipSubject(id: 7, name: '经济法基础'),
      VipSubject(id: 8, name: '财务管理'),
    ];

    test('selects the persisted market or the first subject', () {
      expect(resolveInitialVipSubjectIndex(subjects, selectedMarketId: 7), 1);
      expect(resolveInitialVipSubjectIndex(subjects, selectedMarketId: 99), 0);
      expect(resolveInitialVipSubjectIndex(const [], selectedMarketId: 7), -1);
    });

    test('never removes the last subject', () {
      expect(toggleVipSubject(const {1}, subjectIndex: 1), {1});
      expect(toggleVipSubject(const {0, 1}, subjectIndex: 1), {0});
      expect(toggleVipSubject(const {0}, subjectIndex: 2), {0, 2});
    });

    test('select all then clear restores the fallback subject', () {
      expect(
        toggleAllVipSubjects(
          const {0},
          subjectCount: subjects.length,
          fallbackIndex: 1,
        ),
        {0, 1, 2},
      );
      expect(
        toggleAllVipSubjects(
          const {0, 1, 2},
          subjectCount: subjects.length,
          fallbackIndex: 1,
        ),
        {1},
      );
    });
  });

  group('VIP response models', () {
    test('parses a product and its SKU expiry metadata', () {
      final product = VipProduct.fromMap({
        'productId': 'product-6',
        'productName': '会计实务答题技巧',
        'category': 'joy-ledger',
        'level': '初级会计',
        'subject': '会计实务',
        'productType': 'skills_feature_package',
        'skuList': [
          {
            'skuProductId': 601,
            'skuName': '季卡',
            'benefitsExpiryMinute': 129600,
          },
        ],
      });

      expect(product.productId, 'product-6');
      expect(product.subject, '会计实务');
      expect(product.skus.single.skuProductId, 601);
      expect(product.skus.single.benefitsExpiryMinute, 129600);
      expect(
        () => product.skus.add(const VipProductSku(skuName: 'x')),
        throwsUnsupportedError,
      );
    });

    test('parses common SKU and preserves shop-cart order', () {
      final sku = VipCommonSku.fromMap({
        'skuName': '季卡',
        'totalPrice': '39.90',
        'aggProductList': [
          {'productId': 'product-7', 'productSkuId': 702},
          {'productId': 'product-6', 'productSkuId': 602},
        ],
      });

      expect(sku.skuName, '季卡');
      expect(sku.totalPrice, 39.9);
      expect(sku.shopCart, const [
        VipShopCartItem(productId: 'product-7', productSkuId: 702),
        VipShopCartItem(productId: 'product-6', productSkuId: 602),
      ]);
      expect(() => sku.shopCart.clear(), throwsUnsupportedError);
    });

    test('rejects malformed products common SKUs and cart items', () {
      expect(
        () => VipProduct.fromMap({'productId': ''}),
        throwsFormatException,
      );
      expect(
        () => VipProduct.fromMap({'productId': 'p', 'skuList': {}}),
        throwsFormatException,
      );
      expect(
        () => VipCommonSku.fromMap({
          'skuName': '季卡',
          'totalPrice': double.infinity,
          'aggProductList': const [],
        }),
        throwsFormatException,
      );
      expect(
        () => VipShopCartItem.fromMap({'productId': 'p', 'productSkuId': 0}),
        throwsFormatException,
      );
    });

    test('parses complete WeChat credential and rejects missing fields', () {
      final credential = VipWechatCredential.fromMap({
        'appId': 'wx-app',
        'partnerId': 'partner',
        'prepayId': 'prepay',
        'nonceStr': 'nonce',
        'timeStamp': 123456,
        'packageValue': 'Sign=WXPay',
        'sign': 'signature',
      });

      expect(credential.timeStamp, '123456');
      expect(credential.toMap(), {
        'appId': 'wx-app',
        'partnerId': 'partner',
        'prepayId': 'prepay',
        'nonceStr': 'nonce',
        'timeStamp': '123456',
        'packageValue': 'Sign=WXPay',
        'sign': 'signature',
      });
      expect(
        () => VipWechatCredential.fromMap({'appId': 'wx-app'}),
        throwsFormatException,
      );
    });
  });

  group('VIP static privileges', () {
    test('matches Android privilege groups for every type', () {
      expect(vipPrivilegesFor(VipProductType.skill), hasLength(6));
      expect(vipBonusPrivilegesFor(VipProductType.skill), isEmpty);
      expect(vipPrivilegesFor(VipProductType.svip), hasLength(6));
      expect(vipBonusPrivilegesFor(VipProductType.svip), hasLength(3));
      expect(vipPrivilegesFor(VipProductType.course), hasLength(3));
      expect(vipBonusPrivilegesFor(VipProductType.course), isEmpty);
      expect(vipPrivilegesFor(VipProductType.skill).map((item) => item.title), [
        '速成300题',
        '技巧练题+口诀',
        '最后密押卷',
        '历年真题卷',
        '章节练习',
        '技巧卡片',
      ]);
      expect(
        vipBonusPrivilegesFor(VipProductType.svip).map((item) => item.title),
        ['名师全科课程', '独家电子资料', '1V1督学老师'],
      );
    });
  });

  test('Mine purchase request pins Android source IDs', () {
    const request = VipPurchaseRequest.mine();
    expect(request.normalPayPageSourceId, 1020);
    expect(request.differencePayPageSourceId, 2002);
    expect(request.defaultProductType, isNull);
    expect(VipPurchaseResult.values, [VipPurchaseResult.paid]);
    expect(VipPaymentChannel.values, [
      VipPaymentChannel.wechat,
      VipPaymentChannel.alipay,
    ]);
  });

  group('VIP benefit summary', () {
    final now = DateTime(2026, 7, 17, 12);

    test('filters current benefits consolidates and sorts Android lines', () {
      final summary = resolveVipBenefitSummary(
        [
          {
            'category': 'joy-ledger',
            'benefitsCode': 'joy-ledger:中级会计:会计实务:practice_skill',
            'expireTime': '2026-07-18 13:40:27',
          },
          {
            'category': 'joy-ledger',
            'benefitsCode': 'joy-ledger:中级会计:会计实务:practice_speed',
            'expireTime': '2026-07-18 13:40:27',
          },
          {
            'category': 'joy-ledger',
            'benefitsCode': 'joy-ledger:中级会计:会计实务:past_exams',
            'expireTime': '2026-07-18 13:40:27',
          },
          {
            'category': 'joy-ledger',
            'benefitsCode': 'joy-ledger:中级会计:财务管理:course_video',
            'expireTime': '2026-07-18 13:40:27',
          },
          {
            'category': 'joy-ledger',
            'benefitsCode': 'joy-ledger:中级会计:all:all',
            'expireTime': '2026-07-19',
          },
          {
            'category': 'joy-ledger',
            'benefitsCode': 'joy-ledger:中级会计:会计实务:course_video',
            'expireTime': '2026-07-16 13:40:27',
          },
          {
            'category': 'social-work',
            'benefitsCode': 'social-work:中级社工:社工实务:all',
            'expireTime': '2026-07-19',
          },
        ],
        category: 'joy-ledger',
        level: '中级会计',
        categoryName: '中级会计',
        now: () => now,
      );

      expect(summary.lines.map((line) => line.text), [
        '中级会计 全能SVIP 有效期至 2026-07-19',
        '会计实务 答题技巧VIP 有效期至 2026-07-18',
        '财务管理 课程VIP 有效期至 2026-07-18',
      ]);
      expect(summary.isFullMember, isTrue);
      expect(summary.hasPracticePackage, isTrue);
      expect(summary.headerPreview, [
        '中级会计 全能SVIP 有效期至 2026-07-19',
        '会计实务 答题技巧VIP 有效期至 2026-07-18',
        '查看更多',
      ]);
      expect(summary.payPageSourceId(const VipPurchaseRequest.mine()), 1020);
    });

    test('parses cached JSON legacy prefixes and difference attribution', () {
      final summary = resolveVipBenefitSummary(
        '''[
          {"category":"social-work","benefitsCode":"SW_PRACTICE_REGULAR_L1_3M","expireTime":"1784390400000"},
          {"category":"social-work","benefitsCode":"SW_PRACTICE_SPEED_L1_3M","expireTime":"1784390400000"},
          {"category":"social-work","benefitsCode":"SW_PRACTICE_PAST_EXAMS_L1_3M","expireTime":"1784390400000"}
        ]''',
        category: 'social-work',
        level: '初级社工',
        categoryName: '初级社工',
        now: () => now,
      );

      expect(summary.isFullMember, isFalse);
      expect(summary.hasPracticePackage, isTrue);
      expect(summary.lines.map((line) => line.text), [
        '初级社工 答题技巧VIP 有效期至 2026-07-19',
      ]);
      expect(summary.payPageSourceId(const VipPurchaseRequest.mine()), 2002);
    });

    test(
      'legacy member wins over difference entry and invalid input is empty',
      () {
        final member = resolveVipBenefitSummary(
          [
            {
              'category': 'joy-ledger',
              'benefitsCode': 'KJ_MEMBER_L1_3M',
              'expireTime': '',
            },
          ],
          category: 'joy-ledger',
          level: '初级会计',
          categoryName: '初级会计',
          now: () => now,
        );
        final empty = resolveVipBenefitSummary(
          '{bad json',
          category: 'joy-ledger',
          level: '初级会计',
          categoryName: '初级会计',
          now: () => now,
        );

        expect(member.isFullMember, isTrue);
        expect(member.lines.single.text, '初级会计 全能SVIP');
        expect(member.payPageSourceId(const VipPurchaseRequest.mine()), 1020);
        expect(empty.lines, isEmpty);
        expect(empty.headerPreview, isEmpty);
        expect(empty.isFullMember, isFalse);
        expect(empty.hasPracticePackage, isFalse);
      },
    );
  });

  group('VIP purchase success summary', () {
    final now = DateTime(2026, 7, 17, 12);

    test('uses the first current unexpired legacy member tier', () {
      final summary = resolveVipPurchaseSuccessSummary(
        [
          {
            'category': 'joy-ledger',
            'benefitsCode': 'KJ_PRACTICE_REGULAR_L1_3M',
            'benefitsDesc': '练题权益',
            'expireTime': '2026-08-01',
          },
          {
            'category': 'social-work',
            'benefitsCode': 'SW_MEMBER_L1_3M',
            'benefitsDesc': '其他分类会员',
            'expireTime': '2026-08-01',
          },
          {
            'category': 'joy-ledger',
            'benefitsCode': 'KJ_MEMBER_L1_3M',
            'benefitsDesc': '过期会员',
            'expireTime': '2026-07-16',
          },
          {
            'category': 'joy-ledger',
            'benefitsCode': 'KJ_MEMBER_L1_3M',
            'benefitsDesc': '  初级会计畅学卡  ',
            'expireTime': '2026-08-01 13:40:27',
          },
          {
            'category': 'joy-ledger',
            'benefitsCode': 'KJ_MEMBER_L1_12M',
            'benefitsDesc': '不应覆盖第一条',
            'expireTime': '2027-08-01',
          },
        ],
        category: 'joy-ledger',
        level: '初级会计',
        now: () => now,
      );

      expect(summary.title, '恭喜！【初级会计畅学卡】开通成功');
      expect(summary.expiresOn, '2026-08-01');
      expect(summary.hasMemberTier, isTrue);
    });

    test('supports abstract codes timestamps and empty descriptions', () {
      final expires = DateTime(2026, 8, 1, 13).millisecondsSinceEpoch;
      final milliseconds = resolveVipPurchaseSuccessSummary(
        [
          {
            'category': 'joy-ledger',
            'benefitsCode': 'joy-ledger:初级会计:all:all',
            'benefitsDesc': '   ',
            'expireTime': '$expires',
          },
          {
            'category': 'joy-ledger',
            'benefitsCode': 'joy-ledger:初级会计:all:all',
            'benefitsDesc': '后续文案',
            'expireTime': '2027-01-01',
          },
        ],
        category: 'joy-ledger',
        level: '初级会计',
        now: () => now,
      );
      final seconds = resolveVipPurchaseSuccessSummary(
        [
          {
            'category': 'joy-ledger',
            'benefitsCode': 'joy-ledger:初级会计:all:all',
            'benefitsDesc': '季度会员',
            'expireTime': '${expires ~/ 1000}',
          },
        ],
        category: 'joy-ledger',
        level: '初级会计',
        now: () => now,
      );

      expect(
        milliseconds,
        const VipPurchaseSuccessSummary(
          title: '恭喜！会员开通成功',
          expiresOn: '2026-08-01',
          hasMemberTier: true,
        ),
      );
      expect(seconds.expiresOn, '2026-08-01');
      expect(seconds.title, '恭喜！【季度会员】开通成功');
    });

    test('falls back for malformed non-member and mismatched benefits', () {
      for (final raw in <Object?>[
        null,
        '{bad json',
        {'body': <Object?>[]},
        [
          {
            'category': 'joy-ledger',
            'benefitsCode': 'KJ_PRACTICE_REGULAR_L1_3M',
            'benefitsDesc': '练题权益',
            'expireTime': '2026-08-01',
          },
          {
            'category': 'joy-ledger',
            'benefitsCode': 'joy-ledger:中级会计:all:all',
            'benefitsDesc': '其他级别',
            'expireTime': '2026-08-01',
          },
          'not-an-object',
        ],
      ]) {
        expect(
          resolveVipPurchaseSuccessSummary(
            raw,
            category: 'joy-ledger',
            level: '初级会计',
            now: () => now,
          ),
          const VipPurchaseSuccessSummary.generic(),
        );
      }
    });

    test('is an immutable value', () {
      const first = VipPurchaseSuccessSummary(
        title: '恭喜！【畅学卡】开通成功',
        expiresOn: '2026-08-01',
        hasMemberTier: true,
      );
      const second = VipPurchaseSuccessSummary(
        title: '恭喜！【畅学卡】开通成功',
        expiresOn: '2026-08-01',
        hasMemberTier: true,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(const VipPurchaseSuccessSummary.generic().hasMemberTier, isFalse);
    });
  });

  group('big-skill practice purchase success', () {
    final now = DateTime(2026, 7, 17, 12);

    test('pins Android benefit kinds defaults and request fields', () {
      expect(
        PracticeBenefitKind.values.map(
          (kind) => (kind.benefitType, kind.defaultBenefitName),
        ),
        const [
          ('practice_skill', '技巧练题功能'),
          ('practice_speed', '速成300题功能'),
          ('practice_chapter', '章节练习权益'),
          ('past_exams', '历年真题卷功能'),
        ],
      );

      const defaultRequest = BigSkillPracticePurchaseSuccessRequest();
      const practice = HomeModule(id: 41, name: '技巧练题', page: '技巧练题', tag: '');
      const circle = HomeModule(id: 42, name: '技巧圈题卷', page: '技巧圈题卷', tag: '');
      const explicit = BigSkillPracticePurchaseSuccessRequest(
        benefitKind: PracticeBenefitKind.pastExams,
        navigateHomeOnBack: false,
        cachedPracticeModule: practice,
        cachedCircleModule: circle,
      );

      expect(defaultRequest.benefitKind, PracticeBenefitKind.regularPractice);
      expect(defaultRequest.navigateHomeOnBack, isTrue);
      expect(defaultRequest.cachedPracticeModule, isNull);
      expect(defaultRequest.cachedCircleModule, isNull);
      expect(explicit.benefitKind, PracticeBenefitKind.pastExams);
      expect(explicit.navigateHomeOnBack, isFalse);
      expect(explicit.cachedPracticeModule, same(practice));
      expect(explicit.cachedCircleModule, same(circle));
    });

    test('uses first current unexpired legacy benefit and trims copy', () {
      final summary = resolveBigSkillPracticePurchaseSuccessSummary(
        [
          {
            'category': 'joy-ledger',
            'benefitsCode': 'KJ_PRACTICE_CHAPTER_L1_3M',
            'benefitsDesc': '其他级别',
            'expireTime': '2026-08-01',
          },
          {
            'category': 'other',
            'benefitsCode': 'KJ_PRACTICE_CHAPTER_L2_3M',
            'benefitsDesc': '其他分类',
            'expireTime': '2026-08-01',
          },
          {
            'category': 'joy-ledger',
            'benefitsCode': 'KJ_PRACTICE_CHAPTER_L2_3M',
            'benefitsDesc': '过期权益',
            'expireTime': '2026-07-16',
          },
          {
            'category': 'joy-ledger',
            'benefitsCode': 'KJ_PRACTICE_CHAPTER_L2_3M',
            'benefitsDesc': '  章节专项包  ',
            'expireTime': '2026-08-01 13:40:27',
          },
          {
            'category': 'joy-ledger',
            'benefitsCode': 'KJ_PRACTICE_CHAPTER_L2_12M',
            'benefitsDesc': '不应覆盖首条',
            'expireTime': '2027-08-01',
          },
        ],
        kind: PracticeBenefitKind.chapterPractice,
        category: 'joy-ledger',
        level: '中级会计',
        now: () => now,
      );

      expect(
        summary,
        const BigSkillPracticePurchaseSuccessSummary(
          kind: PracticeBenefitKind.chapterPractice,
          benefitName: '章节专项包',
          expiresOn: '2026-08-01',
        ),
      );
      expect(summary.title, '恭喜！【章节专项包】开通成功');
    });

    test('supports every abstract benefit type and kind-specific fallback', () {
      for (final kind in PracticeBenefitKind.values) {
        final matched = resolveBigSkillPracticePurchaseSuccessSummary(
          [
            {
              'category': 'social-work',
              'benefitsCode': 'social-work:初级社工:all:${kind.benefitType}',
              'benefitsDesc': ' ${kind.name}权益 ',
              'expireTime': '2026-08-01',
            },
          ],
          kind: kind,
          category: 'social-work',
          level: '初级社工',
          now: () => now,
        );
        final fallback = BigSkillPracticePurchaseSuccessSummary.generic(kind);

        expect(matched.title, '恭喜！【${kind.name}权益】开通成功');
        expect(matched.expiresOn, '2026-08-01');
        expect(fallback.title, '恭喜！【${kind.defaultBenefitName}】开通成功');
        expect(fallback.expiresOn, isEmpty);
      }
    });

    test('keeps expiry with default copy and normalizes timestamps', () {
      final milliseconds = DateTime(2026, 8, 1, 13).millisecondsSinceEpoch;
      final expiryOnly = resolveBigSkillPracticePurchaseSuccessSummary(
        [
          {
            'category': 'social-work',
            'benefitsCode': 'SW_PRACTICE_SPEED_L1_3M',
            'benefitsDesc': '   ',
            'expireTime': '$milliseconds',
          },
        ],
        kind: PracticeBenefitKind.fastPractice,
        category: 'social-work',
        level: '初级社工',
        now: () => now,
      );
      final seconds = resolveBigSkillPracticePurchaseSuccessSummary(
        [
          {
            'category': 'social-work',
            'benefitsCode': 'social-work:初级社工:all:past_exams',
            'benefitsDesc': '真题包',
            'expireTime': '${milliseconds ~/ 1000}',
          },
        ],
        kind: PracticeBenefitKind.pastExams,
        category: 'social-work',
        level: '初级社工',
        now: () => now,
      );

      expect(expiryOnly.title, '恭喜！【速成300题功能】开通成功');
      expect(expiryOnly.expiresOn, '2026-08-01');
      expect(seconds.expiresOn, '2026-08-01');
    });

    test('falls back for malformed mismatched and wrong-kind benefits', () {
      for (final raw in <Object?>[
        null,
        '{bad json',
        const {'body': <Object?>[]},
        const [
          {
            'category': 'social-work',
            'benefitsCode': 'SW_PRACTICE_REGULAR_L1_3M',
            'benefitsDesc': '错误种类',
            'expireTime': '2026-08-01',
          },
          {
            'category': 'social-work',
            'benefitsCode': 'social-work:中级社工:all:practice_chapter',
            'benefitsDesc': '错误级别',
            'expireTime': '2026-08-01',
          },
          'not-an-object',
        ],
      ]) {
        expect(
          resolveBigSkillPracticePurchaseSuccessSummary(
            raw,
            kind: PracticeBenefitKind.chapterPractice,
            category: 'social-work',
            level: '初级社工',
            now: () => now,
          ),
          const BigSkillPracticePurchaseSuccessSummary.generic(
            PracticeBenefitKind.chapterPractice,
          ),
        );
      }
    });

    test('summary is an immutable value', () {
      const first = BigSkillPracticePurchaseSuccessSummary(
        kind: PracticeBenefitKind.regularPractice,
        benefitName: '练题包',
        expiresOn: '2026-08-01',
      );
      const second = BigSkillPracticePurchaseSuccessSummary(
        kind: PracticeBenefitKind.regularPractice,
        benefitName: '练题包',
        expiresOn: '2026-08-01',
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
