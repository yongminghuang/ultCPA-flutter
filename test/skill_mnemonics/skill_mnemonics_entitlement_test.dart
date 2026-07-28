import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/practice/practice_benefit_kind.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_entitlement.dart';

void main() {
  final resolver = SkillMnemonicsEntitlementResolver(
    now: () => DateTime(2026, 7, 16, 12),
  );

  test('matches the Android member prefix for the selected category level', () {
    expect(
      resolver.isVip(
        const [
          {
            'category': 'social-work',
            'benefitsCode': 'SW_MEMBER_L1_3M',
            'expireTime': '2026-12-31 23:59:59',
          },
        ],
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isTrue,
    );
    expect(
      resolver.isVip(
        const [
          {
            'category': 'social-work',
            'benefitsCode': 'SW_MEMBER_L2_3M',
            'expireTime': '2026-12-31',
          },
        ],
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isFalse,
    );
  });

  test('requires all three matching answering benefits', () {
    const benefits = [
      {
        'benefitsCode': 'social-work:初级社工:社工实务:practice_skill',
        'expireTime': '',
      },
      {
        'benefitsCode': 'social-work:初级社工:all:practice_speed',
        'expireTime': '1785427200',
      },
      {
        'benefitsCode': 'all:初级社工:社工实务:past_exams',
        'expireTime': '1785427200000',
      },
    ];

    expect(
      resolver.isVip(
        benefits,
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isTrue,
    );
    expect(
      resolver.isVip(
        benefits.take(2).toList(),
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isFalse,
    );
  });

  test('rejects expired and malformed benefit dates', () {
    for (final expiry in ['2026-01-01', 'not-a-date']) {
      expect(
        resolver.isVip(
          [
            {
              'category': 'social-work',
              'benefitsCode': 'SW_MEMBER_L1',
              'expireTime': expiry,
            },
          ],
          category: 'social-work',
          level: '初级社工',
          subject: '社工实务',
        ),
        isFalse,
      );
    }
  });

  test('regular practice accepts one matching abstract benefit', () {
    const benefits = [
      {
        'benefitsCode': 'social-work:初级社工:社工实务:practice_skill',
        'expireTime': '2026-12-31',
      },
    ];

    expect(
      resolver.hasRegularPracticeAccess(
        benefits,
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isTrue,
    );
    expect(
      resolver.isVip(
        benefits,
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isFalse,
    );
  });

  test('regular practice accepts the legacy selected-level prefix', () {
    expect(
      resolver.hasRegularPracticeAccess(
        const [
          {
            'benefitsCode': 'SW_PRACTICE_REGULAR_L1_3M',
            'expireTime': '2026-12-31 23:59:59',
          },
        ],
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isTrue,
    );
    expect(
      resolver.hasRegularPracticeAccess(
        const [
          {
            'benefitsCode': 'SW_PRACTICE_REGULAR_L2_3M',
            'expireTime': '2026-12-31 23:59:59',
          },
        ],
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isFalse,
    );
  });

  test('chapter practice accepts membership and scoped abstract benefits', () {
    expect(
      resolver.hasChapterPracticeAccess(
        const [
          {
            'category': 'social-work',
            'benefitsCode': 'SW_MEMBER_L1_3M',
            'expireTime': '2026-12-31',
          },
        ],
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isTrue,
    );
    for (final type in ['practice_chapter', 'all']) {
      expect(
        resolver.hasChapterPracticeAccess(
          [
            {
              'benefitsCode': 'social-work:初级社工:社工实务:$type',
              'expireTime': '2026-12-31',
            },
          ],
          category: 'social-work',
          level: '初级社工',
          subject: '社工实务',
        ),
        isTrue,
        reason: type,
      );
    }
  });

  test('chapter practice accepts only the matching legacy level prefix', () {
    expect(
      resolver.hasChapterPracticeAccess(
        const [
          {
            'benefitsCode': 'SW_PRACTICE_CHAPTER_L1_3M',
            'expireTime': '2026-12-31',
          },
        ],
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isTrue,
    );
    expect(
      resolver.hasChapterPracticeAccess(
        const [
          {
            'benefitsCode': 'SW_PRACTICE_CHAPTER_L2_3M',
            'expireTime': '2026-12-31',
          },
        ],
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isFalse,
    );
  });

  test('chapter practice rejects expired and mismatched scoped benefits', () {
    expect(
      resolver.hasChapterPracticeAccess(
        const [
          {
            'benefitsCode': 'social-work:初级社工:社会法规:practice_chapter',
            'expireTime': '2026-12-31',
          },
          {
            'benefitsCode': 'social-work:初级社工:社工实务:practice_chapter',
            'expireTime': '2026-01-01',
          },
        ],
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isFalse,
    );
  });

  test('fast practice accepts membership and scoped speed benefits', () {
    expect(
      resolver.hasFastPracticeAccess(
        const [
          {
            'category': 'social-work',
            'benefitsCode': 'SW_MEMBER_L1_3M',
            'expireTime': '2026-12-31',
          },
        ],
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isTrue,
    );
    for (final type in ['practice_speed', 'all']) {
      expect(
        resolver.hasFastPracticeAccess(
          [
            {
              'benefitsCode': 'social-work:初级社工:社工实务:$type',
              'expireTime': '2026-12-31',
            },
          ],
          category: 'social-work',
          level: '初级社工',
          subject: '社工实务',
        ),
        isTrue,
        reason: type,
      );
    }
  });

  test('fast practice accepts only the matching legacy speed prefix', () {
    expect(
      resolver.hasFastPracticeAccess(
        const [
          {
            'benefitsCode': 'SW_PRACTICE_SPEED_L1_3M',
            'expireTime': '2026-12-31',
          },
        ],
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isTrue,
    );
    expect(
      resolver.hasFastPracticeAccess(
        const [
          {
            'benefitsCode': 'SW_PRACTICE_SPEED_L2_3M',
            'expireTime': '2026-12-31',
          },
        ],
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isFalse,
    );
  });

  test('fast practice rejects expired and mismatched speed benefits', () {
    expect(
      resolver.hasFastPracticeAccess(
        const [
          {
            'benefitsCode': 'social-work:初级社工:社会法规:practice_speed',
            'expireTime': '2026-12-31',
          },
          {
            'benefitsCode': 'social-work:初级社工:社工实务:practice_speed',
            'expireTime': '2026-01-01',
          },
        ],
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isFalse,
    );
  });

  test('past exams accepts membership and scoped past-exams benefits', () {
    expect(
      resolver.hasPastExamsAccess(
        const [
          {
            'category': 'social-work',
            'benefitsCode': 'SW_MEMBER_L1_3M',
            'expireTime': '2026-12-31',
          },
        ],
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isTrue,
    );
    for (final type in ['past_exams', 'all']) {
      expect(
        resolver.hasPastExamsAccess(
          [
            {
              'benefitsCode': 'social-work:初级社工:社工实务:$type',
              'expireTime': '2026-12-31',
            },
          ],
          category: 'social-work',
          level: '初级社工',
          subject: '社工实务',
        ),
        isTrue,
        reason: type,
      );
    }
  });

  test('past exams accepts only the matching legacy level prefix', () {
    expect(
      resolver.hasPastExamsAccess(
        const [
          {
            'benefitsCode': 'SW_PRACTICE_PAST_EXAMS_L1_3M',
            'expireTime': '2026-12-31',
          },
        ],
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isTrue,
    );
    expect(
      resolver.hasPastExamsAccess(
        const [
          {
            'benefitsCode': 'SW_PRACTICE_PAST_EXAMS_L2_3M',
            'expireTime': '2026-12-31',
          },
        ],
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isFalse,
    );
  });

  test('past exams rejects expired and mismatched scoped benefits', () {
    expect(
      resolver.hasPastExamsAccess(
        const [
          {
            'benefitsCode': 'social-work:初级社工:社会法规:past_exams',
            'expireTime': '2026-12-31',
          },
          {
            'benefitsCode': 'social-work:初级社工:社工实务:past_exams',
            'expireTime': '2026-01-01',
          },
          {
            'benefitsCode': 'joy-ledger:初级社工:社工实务:past_exams',
            'expireTime': '2026-12-31',
          },
        ],
        category: 'social-work',
        level: '初级社工',
        subject: '社工实务',
      ),
      isFalse,
    );
  });

  test(
    'typed practice access dispatches only to the selected package kind',
    () {
      for (final ownedKind in PracticeBenefitKind.values) {
        final benefits = [
          {
            'benefitsCode': 'social-work:初级社工:社工实务:${ownedKind.benefitType}',
            'expireTime': '2026-12-31',
          },
        ];
        for (final requestedKind in PracticeBenefitKind.values) {
          expect(
            resolver.hasPracticeAccess(
              benefits,
              kind: requestedKind,
              category: 'social-work',
              level: '初级社工',
              subject: '社工实务',
            ),
            requestedKind == ownedKind,
            reason: 'owned=$ownedKind requested=$requestedKind',
          );
        }
      }
    },
  );

  test('typed practice access accepts full membership for every kind', () {
    const benefits = [
      {
        'category': 'social-work',
        'benefitsCode': 'SW_MEMBER_L1_3M',
        'expireTime': '2026-12-31',
      },
    ];
    for (final kind in PracticeBenefitKind.values) {
      expect(
        resolver.hasPracticeAccess(
          benefits,
          kind: kind,
          category: 'social-work',
          level: '初级社工',
          subject: '社工实务',
        ),
        isTrue,
        reason: '$kind',
      );
    }
  });
}
