final class SkillMnemonic {
  const SkillMnemonic({
    required this.skillId,
    required this.text,
    required this.name,
    required this.keyword,
    required this.textKeyword,
    required this.note,
    required this.imgUrl,
    required this.videoUrl,
    required this.voiceUrl,
    required this.coverUrl,
    required this.questionCount,
    required this.shelfId,
    required this.goodsId,
    required this.type,
    required this.content,
    required this.extend,
    required this.sort,
    required this.status,
  });

  factory SkillMnemonic.fromMap(Map<String, dynamic> map) {
    return SkillMnemonic(
      skillId: _text(map['skillId']).isNotEmpty
          ? _text(map['skillId'])
          : _text(map['id']),
      text: _text(map['text']),
      name: _text(map['name']),
      keyword: _text(map['keyword']),
      textKeyword: _text(map['textKeyword']),
      note: _text(map['note']),
      imgUrl: _nullableText(map['imgUrl']),
      videoUrl: _nullableText(map['videoUrl']),
      voiceUrl: _nullableText(map['voiceUrl']),
      coverUrl: _nullableText(map['coverUrl']),
      questionCount: _integer(map['questionCount']),
      shelfId: _text(map['shelfId']),
      goodsId: _text(map['goodsId']),
      type: _text(map['type']),
      content: _text(map['content']),
      extend: _nullableText(map['extend']),
      sort: _integer(map['sort']),
      status: _boolean(map['status']),
    );
  }

  final String skillId;
  final String text;
  final String name;
  final String keyword;
  final String textKeyword;
  final String note;
  final String? imgUrl;
  final String? videoUrl;
  final String? voiceUrl;
  final String? coverUrl;
  final int questionCount;
  final String shelfId;
  final String goodsId;
  final String type;
  final String content;
  final String? extend;
  final int sort;
  final bool status;

  String get displayText => text.trim().isNotEmpty ? text : name;

  List<String> get keywordTerms {
    final seen = <String>{};
    final terms = <String>[];
    for (final part in keyword.split(RegExp('[,，]'))) {
      final value = part.trim();
      if (value.isNotEmpty && seen.add(value)) terms.add(value);
    }
    return List.unmodifiable(terms);
  }
}

final class SkillMnemonicsCatalog {
  const SkillMnemonicsCatalog({
    required this.records,
    required this.total,
    required this.pages,
    required this.current,
    required this.size,
    required this.freeCount,
    required this.isVip,
  });

  factory SkillMnemonicsCatalog.fromBody(
    Object? body, {
    required int freeCount,
    bool isVip = false,
  }) {
    if (body is! Map) {
      throw const FormatException('技巧口诀响应 body 不是对象');
    }
    final map = Map<String, dynamic>.from(body);
    final rawRecords = map['records'];
    if (rawRecords != null && rawRecords is! List) {
      throw const FormatException('技巧口诀响应 records 不是数组');
    }
    final records = (rawRecords as List? ?? const <Object?>[])
        .map((value) {
          if (value is! Map) {
            throw const FormatException('技巧口诀条目不是对象');
          }
          return SkillMnemonic.fromMap(Map<String, dynamic>.from(value));
        })
        .toList(growable: false);
    return SkillMnemonicsCatalog(
      records: List.unmodifiable(records),
      total: _integer(map['total'], records.length),
      pages: _integer(map['pages']),
      current: _integer(map['current'], 1),
      size: _integer(map['size'], 200),
      freeCount: freeCount < 0 ? 0 : freeCount,
      isVip: isVip,
    );
  }

  final List<SkillMnemonic> records;
  final int total;
  final int pages;
  final int current;
  final int size;
  final int freeCount;
  final bool isVip;

  bool isUnlocked(int index, {bool? isVip}) {
    return index >= 0 && ((isVip ?? this.isVip) || index < freeCount);
  }
}

String _text(Object? value) {
  if (value == null) return '';
  final text = value.toString();
  return text.trim().toLowerCase() == 'null' ? '' : text;
}

String? _nullableText(Object? value) {
  final text = _text(value);
  return text.trim().isEmpty ? null : text;
}

int _integer(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _boolean(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return switch (value?.toString().trim().toLowerCase()) {
    'true' || '1' => true,
    _ => false,
  };
}
