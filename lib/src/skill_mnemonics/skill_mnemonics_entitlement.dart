import '../practice/practice_benefit_kind.dart';

final class SkillMnemonicsEntitlementResolver {
  SkillMnemonicsEntitlementResolver({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  bool hasPracticeAccess(
    Object? rawBenefits, {
    required PracticeBenefitKind kind,
    required String category,
    required String level,
    required String subject,
  }) {
    return switch (kind) {
      PracticeBenefitKind.regularPractice => hasRegularPracticeAccess(
        rawBenefits,
        category: category,
        level: level,
        subject: subject,
      ),
      PracticeBenefitKind.fastPractice => hasFastPracticeAccess(
        rawBenefits,
        category: category,
        level: level,
        subject: subject,
      ),
      PracticeBenefitKind.chapterPractice => hasChapterPracticeAccess(
        rawBenefits,
        category: category,
        level: level,
        subject: subject,
      ),
      PracticeBenefitKind.pastExams => hasPastExamsAccess(
        rawBenefits,
        category: category,
        level: level,
        subject: subject,
      ),
    };
  }

  bool isVip(
    Object? rawBenefits, {
    required String category,
    required String level,
    required String subject,
  }) {
    if (rawBenefits is! List) return false;
    final benefits = rawBenefits
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .where((value) => _isUnexpired(value['expireTime']))
        .toList(growable: false);
    final normalizedCategory = category.trim();
    final memberPrefix = _memberPrefix(normalizedCategory, level.trim());
    if (memberPrefix != null) {
      for (final benefit in benefits) {
        if (_text(benefit['category']).trim() == normalizedCategory &&
            _text(benefit['benefitsCode']).trim().startsWith(memberPrefix)) {
          return true;
        }
      }
    }

    const requiredBenefits = <String>{
      'practice_skill',
      'practice_speed',
      'past_exams',
    };
    final matched = <String>{};
    for (final benefit in benefits) {
      final code = _text(benefit['benefitsCode']).trim();
      final parts = code.split(':');
      if (parts.length < 4 ||
          !_matches(parts[0], normalizedCategory) ||
          !_matches(parts[1], level) ||
          !_matches(parts[2], subject)) {
        continue;
      }
      final type = parts[3].trim().toLowerCase();
      if (type == 'all') {
        matched.addAll(requiredBenefits);
      } else if (requiredBenefits.contains(type)) {
        matched.add(type);
      }
    }
    return matched.containsAll(requiredBenefits);
  }

  bool hasRegularPracticeAccess(
    Object? rawBenefits, {
    required String category,
    required String level,
    required String subject,
  }) {
    if (isVip(
      rawBenefits,
      category: category,
      level: level,
      subject: subject,
    )) {
      return true;
    }
    if (rawBenefits is! List) return false;
    final benefits = rawBenefits
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .where((value) => _isUnexpired(value['expireTime']));
    final regularPrefix = _regularPrefix(category.trim(), level.trim());
    for (final benefit in benefits) {
      final code = _text(benefit['benefitsCode']).trim();
      if (regularPrefix != null && code.startsWith(regularPrefix)) {
        return true;
      }
      final parts = code.split(':');
      if (parts.length < 4 ||
          !_matches(parts[0], category) ||
          !_matches(parts[1], level) ||
          !_matches(parts[2], subject)) {
        continue;
      }
      final type = parts[3].trim().toLowerCase();
      if (type == 'all' || type == 'practice_skill') return true;
    }
    return false;
  }

  bool hasChapterPracticeAccess(
    Object? rawBenefits, {
    required String category,
    required String level,
    required String subject,
  }) {
    if (isVip(
      rawBenefits,
      category: category,
      level: level,
      subject: subject,
    )) {
      return true;
    }
    if (rawBenefits is! List) return false;
    final benefits = rawBenefits
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .where((value) => _isUnexpired(value['expireTime']));
    final chapterPrefix = _chapterPrefix(category.trim(), level.trim());
    for (final benefit in benefits) {
      final code = _text(benefit['benefitsCode']).trim();
      if (chapterPrefix != null && code.startsWith(chapterPrefix)) {
        return true;
      }
      final parts = code.split(':');
      if (parts.length < 4 ||
          !_matches(parts[0], category) ||
          !_matches(parts[1], level) ||
          !_matches(parts[2], subject)) {
        continue;
      }
      final type = parts[3].trim().toLowerCase();
      if (type == 'all' || type == 'practice_chapter') return true;
    }
    return false;
  }

  bool hasFastPracticeAccess(
    Object? rawBenefits, {
    required String category,
    required String level,
    required String subject,
  }) {
    if (isVip(
      rawBenefits,
      category: category,
      level: level,
      subject: subject,
    )) {
      return true;
    }
    if (rawBenefits is! List) return false;
    final benefits = rawBenefits
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .where((value) => _isUnexpired(value['expireTime']));
    final speedPrefix = _speedPrefix(category.trim(), level.trim());
    for (final benefit in benefits) {
      final code = _text(benefit['benefitsCode']).trim();
      if (speedPrefix != null && code.startsWith(speedPrefix)) return true;
      final parts = code.split(':');
      if (parts.length < 4 ||
          !_matches(parts[0], category) ||
          !_matches(parts[1], level) ||
          !_matches(parts[2], subject)) {
        continue;
      }
      final type = parts[3].trim().toLowerCase();
      if (type == 'all' || type == 'practice_speed') return true;
    }
    return false;
  }

  bool hasPastExamsAccess(
    Object? rawBenefits, {
    required String category,
    required String level,
    required String subject,
  }) {
    if (isVip(
      rawBenefits,
      category: category,
      level: level,
      subject: subject,
    )) {
      return true;
    }
    if (rawBenefits is! List) return false;
    final benefits = rawBenefits
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .where((value) => _isUnexpired(value['expireTime']));
    final pastExamsPrefix = _pastExamsPrefix(category.trim(), level.trim());
    for (final benefit in benefits) {
      final code = _text(benefit['benefitsCode']).trim();
      if (pastExamsPrefix != null && code.startsWith(pastExamsPrefix)) {
        return true;
      }
      final parts = code.split(':');
      if (parts.length < 4 ||
          !_matches(parts[0], category) ||
          !_matches(parts[1], level) ||
          !_matches(parts[2], subject)) {
        continue;
      }
      final type = parts[3].trim().toLowerCase();
      if (type == 'all' || type == 'past_exams') return true;
    }
    return false;
  }

  bool _isUnexpired(Object? rawExpiry) {
    final value = _text(rawExpiry).trim();
    if (value.isEmpty) return true;
    final timestamp = int.tryParse(value);
    if (timestamp != null) {
      if (timestamp <= 0) return true;
      final milliseconds = timestamp < 100000000000
          ? timestamp * 1000
          : timestamp;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds).isAfter(_now());
    }
    final parsed = DateTime.tryParse(value.replaceFirst(' ', 'T'));
    return parsed?.isAfter(_now()) ?? false;
  }
}

bool _matches(String rule, String current) {
  final normalizedRule = rule.trim().toLowerCase();
  return normalizedRule == 'all' ||
      normalizedRule == current.trim().toLowerCase();
}

String? _memberPrefix(String category, String level) {
  return switch ((category, level)) {
    ('joy-ledger', '初级会计') => 'KJ_MEMBER_L1',
    ('joy-ledger', '中级会计') => 'KJ_MEMBER_L2',
    ('joy-ledger', '中级经济师') => 'KJEC_MEMBER_L2',
    ('joy-ledger', '注册会计师') => 'ZCKJ_MEMBER_L3',
    ('joy-ledger', '税务师') => 'SWS_MEMBER_L3',
    ('social-work', '初级社工') => 'SW_MEMBER_L1',
    ('social-work', '中级社工') => 'SW_MEMBER_L2',
    ('cert-edu', '导游资格证') => 'DY_MEMBER_L1',
    ('cert-edu', '计算机等级考试(一级)') => 'JSJ_MEMBER_L1',
    ('cert-edu', '计算机等级考试(二级)') => 'JSJ_MEMBER_L2',
    ('cert-edu', '计算机等级考试(三级)') => 'JSJ_MEMBER_L3',
    ('cert-edu', '计算机等级考试(四级)') => 'JSJ_MEMBER_L4',
    ('engineer', '消防工程师(一级)') => 'XF_MEMBER_L1',
    ('engineer', '消防工程师(二级)') => 'XF_MEMBER_L2',
    ('engineer', '造价工程师(一级)') => 'ZJ_MEMBER_L1',
    ('finance', '证券从业资格') => 'ZQ_MEMBER_L1',
    _ => null,
  };
}

String? _regularPrefix(String category, String level) {
  return _memberPrefix(
    category,
    level,
  )?.replaceFirst('_MEMBER_', '_PRACTICE_REGULAR_');
}

String? _chapterPrefix(String category, String level) {
  return _memberPrefix(
    category,
    level,
  )?.replaceFirst('_MEMBER_', '_PRACTICE_CHAPTER_');
}

String? _speedPrefix(String category, String level) {
  return _memberPrefix(
    category,
    level,
  )?.replaceFirst('_MEMBER_', '_PRACTICE_SPEED_');
}

String? _pastExamsPrefix(String category, String level) {
  return _memberPrefix(
    category,
    level,
  )?.replaceFirst('_MEMBER_', '_PRACTICE_PAST_EXAMS_');
}

String _text(Object? value) => value?.toString() ?? '';
