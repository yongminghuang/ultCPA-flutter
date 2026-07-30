import 'dart:convert';

enum LearningMaterialKind { document, video, payCard, unknown }

enum LearningMaterialsPaymentChannel { wechat, alipay }

final class LearningMaterialsShelf {
  LearningMaterialsShelf({
    required this.id,
    required this.name,
    required this.children,
    this.difficult = '',
    this.sort = 0,
    this.type = '',
    this.parentId,
    this.marketId,
    this.status,
    this.goodsCount = 0,
  });

  factory LearningMaterialsShelf.fromMap(Map<String, dynamic> map) {
    final rawChildren = map['children'];
    final children = <LearningMaterialsShelf>[];
    if (rawChildren is List) {
      for (final raw in rawChildren) {
        if (raw is Map) {
          children.add(
            LearningMaterialsShelf.fromMap(Map<String, dynamic>.from(raw)),
          );
        }
      }
    }
    return LearningMaterialsShelf(
      id: _int(map['id']),
      name: _text(map['name']),
      difficult: _text(map['difficult']),
      sort: _int(map['sort']),
      type: _text(map['type']),
      parentId: _nullableInt(map['parentId']),
      marketId: _nullableInt(map['marketId']),
      status: _nullableBool(map['status']),
      goodsCount: _int(map['goodsCount']),
      children: List.unmodifiable(children),
    );
  }

  final int id;
  final String name;
  final String difficult;
  final int sort;
  final String type;
  final int? parentId;
  final int? marketId;
  final bool? status;
  final int goodsCount;
  final List<LearningMaterialsShelf> children;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LearningMaterialsShelf &&
            other.id == id &&
            other.name == name &&
            other.difficult == difficult &&
            other.sort == sort &&
            other.type == type &&
            other.parentId == parentId &&
            other.marketId == marketId &&
            other.status == status &&
            other.goodsCount == goodsCount &&
            _listEquals(other.children, children);
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    difficult,
    sort,
    type,
    parentId,
    marketId,
    status,
    goodsCount,
    Object.hashAll(children),
  );
}

List<LearningMaterialsShelf> learningMaterialsTabsFromBody(Object? body) {
  if (body is! List) {
    throw const FormatException('学习资料书架响应不是数组');
  }
  final roots = <LearningMaterialsShelf>[];
  for (final raw in body) {
    if (raw is! Map) continue;
    roots.add(
      LearningMaterialsShelf.fromMap(Map<String, dynamic>.from(raw)),
    );
  }
  if (roots.length == 1 && roots.single.children.isNotEmpty) {
    return List.unmodifiable(roots.single.children);
  }
  return List.unmodifiable(roots);
}

final class LearningMaterialsItem {
  LearningMaterialsItem({
    required this.type,
    required this.isShow,
    required List<String> tags,
    this.id,
    this.viewCount,
    this.printCount,
    this.bannerImage = '',
    this.bannerJumpPage = '',
    this.text = '',
    this.videoUrl = '',
    this.videoCoverUrl = '',
    this.imageUrl = '',
    this.coverImageUrl = '',
    this.payJumpPage = '',
    this.payButtonText = '',
    this.commodityId = '',
    this.title = '',
    this.name = '',
    this.goodsName = '',
  }) : tags = List.unmodifiable(tags);

  factory LearningMaterialsItem.fromMap(Map<String, dynamic> map) {
    final type = _text(map['type']).trim();
    if (type.isEmpty) {
      throw const FormatException('学习资料条目缺少 type');
    }
    return LearningMaterialsItem(
      id: _nullableInt(map['id']),
      type: type,
      isShow: _bool(map['isShow'], true),
      tags: _tags(map),
      viewCount: _nullableInt(map['viewCount']),
      printCount: _firstInt(map, const [
        'printCount',
        'downloadCount',
        'downCount',
        'printNum',
        'copyCount',
      ]),
      bannerImage: _text(map['bannerImage']),
      bannerJumpPage: _text(map['bannerJumpPage']),
      text: _text(map['text']),
      videoUrl: _text(map['videoUrl']),
      videoCoverUrl: _text(map['videoCoverUrl']),
      imageUrl: _firstText(map, const [
        'imageUrl',
        'imgUrl',
        'coverUrl',
        'coverImage',
        'pictureUrl',
      ]),
      coverImageUrl: _firstText(map, const [
        'coverImageUrl',
        'coverUrl',
        'coverImage',
        'imageUrl',
        'imgUrl',
        'pictureUrl',
      ]),
      payButtonText: _text(map['payButtonText']),
      payJumpPage: _text(map['payJumpPage']),
      commodityId: _text(map['commodityId']),
      title: _text(map['title']),
      name: _text(map['name']),
      goodsName: _text(map['goodsName']),
    );
  }

  final int? id;
  final String type;
  final bool isShow;
  final List<String> tags;
  final int? viewCount;
  final int? printCount;
  final String bannerImage;
  final String bannerJumpPage;
  final String text;
  final String videoUrl;
  final String videoCoverUrl;
  final String imageUrl;
  final String coverImageUrl;
  final String payJumpPage;
  final String payButtonText;
  final String commodityId;
  final String title;
  final String name;
  final String goodsName;

  LearningMaterialKind get kind => switch (type) {
    '文档' => LearningMaterialKind.document,
    '视频' => LearningMaterialKind.video,
    '支付卡片' => LearningMaterialKind.payCard,
    _ => LearningMaterialKind.unknown,
  };

  bool get shouldAutoOpenDetail =>
      kind == LearningMaterialKind.document ||
      kind == LearningMaterialKind.video;

  String get displayTitle {
    for (final candidate in [title, name, goodsName]) {
      if (candidate.trim().isNotEmpty) return candidate.trim();
    }
    if (kind == LearningMaterialKind.document && text.trim().isNotEmpty) {
      return learningMaterialsPlainText(text, maxCharacters: 80);
    }
    if (kind == LearningMaterialKind.video) {
      return bannerJumpPage.trim().isNotEmpty
          ? bannerJumpPage.trim()
          : '视频学习';
    }
    if (kind == LearningMaterialKind.payCard) {
      return payButtonText.trim().isNotEmpty ? payButtonText.trim() : '精选内容';
    }
    return '未命名';
  }

  String get tagsLabel => tags
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .join(' | ');

  String documentPreview([int maxCharacters = 480]) {
    return learningMaterialsPlainText(text, maxCharacters: maxCharacters);
  }

  String resolvedListCover(String ossDomain) {
    return resolveLearningMaterialsUrl(coverImageUrl, ossDomain);
  }

  String resolvedVideoCover(String ossDomain) {
    final raw = _firstMeaningful([videoCoverUrl, bannerImage]);
    return resolveLearningMaterialsUrl(raw, ossDomain);
  }

  String resolvedVideoUrl(String ossDomain) {
    return resolveLearningMaterialsUrl(videoUrl, ossDomain);
  }

  String resolvedBannerImage(String ossDomain) {
    return resolveLearningMaterialsUrl(bannerImage, ossDomain);
  }

  LearningMaterialsItem copyWith({bool? isShow}) {
    return LearningMaterialsItem(
      id: id,
      type: type,
      isShow: isShow ?? this.isShow,
      tags: tags,
      viewCount: viewCount,
      printCount: printCount,
      bannerImage: bannerImage,
      bannerJumpPage: bannerJumpPage,
      text: text,
      videoUrl: videoUrl,
      videoCoverUrl: videoCoverUrl,
      imageUrl: imageUrl,
      coverImageUrl: coverImageUrl,
      payJumpPage: payJumpPage,
      payButtonText: payButtonText,
      commodityId: commodityId,
      title: title,
      name: name,
      goodsName: goodsName,
    );
  }
}

final class LearningMaterialsPage {
  LearningMaterialsPage({
    required this.total,
    required this.pages,
    required this.size,
    required this.current,
    required List<LearningMaterialsItem> records,
  }) : records = List.unmodifiable(records);

  factory LearningMaterialsPage.fromBody(Object? body) {
    if (body is! Map) {
      throw const FormatException('学习资料分页响应不是对象');
    }
    final map = Map<String, dynamic>.from(body);
    final rawRecords = map['records'];
    if (rawRecords != null && rawRecords is! List) {
      throw const FormatException('学习资料 records 不是数组');
    }
    final records = <LearningMaterialsItem>[];
    if (rawRecords is List) {
      for (final raw in rawRecords) {
        if (raw is! Map) continue;
        final itemMap = Map<String, dynamic>.from(raw);
        if (_text(itemMap['type']).trim().isEmpty) continue;
        final item = LearningMaterialsItem.fromMap(itemMap);
        records.add(item);
      }
    }
    return LearningMaterialsPage(
      total: _int(map['total']),
      pages: _int(map['pages']),
      size: _int(map['size']),
      current: _int(map['current']),
      records: records,
    );
  }

  final int total;
  final int pages;
  final int size;
  final int current;
  final List<LearningMaterialsItem> records;

  bool get hasMore => current > 0 && current < pages;
  int get nextPageNumber => hasMore ? current + 1 : current;
}

final class LearningMaterialsAppSnapshot {
  const LearningMaterialsAppSnapshot({
    required this.isLoggedIn,
    required this.ossDomain,
    required this.categoryLabel,
    required this.isTestEnvironment,
  });

  factory LearningMaterialsAppSnapshot.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> selectedCategory = const {};
    final direct = map['selectedCategory'];
    if (direct is Map) {
      selectedCategory = Map<String, dynamic>.from(direct);
    } else {
      final encoded = _text(map['selectedCategoryJson']).trim();
      if (encoded.isNotEmpty) {
        try {
          final decoded = jsonDecode(encoded);
          if (decoded is Map) {
            selectedCategory = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {
          selectedCategory = const {};
        }
      }
    }
    final level = _text(selectedCategory['level']).trim();
    final name = _text(selectedCategory['name']).trim();
    final selectedLevel = _text(map['selectedLevel']).trim();
    return LearningMaterialsAppSnapshot(
      isLoggedIn: _bool(map['isLoggedIn'], false),
      ossDomain: _text(map['ossDomain']).trim(),
      categoryLabel: level.isNotEmpty
          ? level
          : name.isNotEmpty
          ? name
          : selectedLevel.isNotEmpty
          ? selectedLevel
          : '初级社工',
      isTestEnvironment: _bool(map['isTestEnvironment'], false),
    );
  }

  final bool isLoggedIn;
  final String ossDomain;
  final String categoryLabel;
  final bool isTestEnvironment;

  String get libraryTitle {
    final display = categoryLabel == '会计初级职称' ? '初级会计职称' : categoryLabel;
    return '${display.trim().isEmpty ? '初级会计职称' : display}资料库';
  }

  LearningMaterialsAppSnapshot copyWith({bool? isLoggedIn}) {
    return LearningMaterialsAppSnapshot(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      ossDomain: ossDomain,
      categoryLabel: categoryLabel,
      isTestEnvironment: isTestEnvironment,
    );
  }
}

final class LearningMaterialsShareRequest {
  const LearningMaterialsShareRequest({
    required this.url,
    required this.title,
    required this.description,
    required this.item,
  });

  factory LearningMaterialsShareRequest.fromItem(
    LearningMaterialsItem item, {
    required bool isTestEnvironment,
  }) {
    final description = item.documentPreview(60);
    final uri = Uri.parse('https://xmzhujing.com/h5/doc-share.html')
        .replace(
          queryParameters: {
            'env': isTestEnvironment ? 'test' : 'prod',
            'goodsId': '${item.id ?? ''}',
          },
        )
        .toString();
    return LearningMaterialsShareRequest(
      url: uri,
      title: item.displayTitle,
      description: description.isEmpty ? item.displayTitle : description,
      item: item,
    );
  }

  final String url;
  final String title;
  final String description;
  final LearningMaterialsItem item;
}

List<LearningMaterialsItem> reorderLearningMaterialsClickedFirst(
  List<LearningMaterialsItem> items,
  int clickedIndex,
) {
  if (items.isEmpty) return const [];
  final index = clickedIndex.clamp(0, items.length - 1);
  return List.unmodifiable([
    items[index],
    ...items.take(index),
    ...items.skip(index + 1),
  ]);
}

String resolveLearningMaterialsUrl(String raw, String ossDomain) {
  final value = raw.trim();
  if (value.isEmpty || value.toLowerCase() == 'null') return '';
  final uri = Uri.tryParse(value);
  if (uri?.hasScheme == true) return value;
  final domain = ossDomain.trim();
  if (value.startsWith('//')) {
    final scheme = Uri.tryParse(domain)?.scheme;
    return '${scheme?.isNotEmpty == true ? scheme : 'https'}:$value';
  }
  if (domain.isEmpty) return value;
  return '${domain.replaceFirst(RegExp(r'/$'), '')}/${value.replaceFirst(RegExp(r'^/'), '')}';
}

String learningMaterialsPlainText(String html, {int? maxCharacters}) {
  if (html.trim().isEmpty) return '';
  var value = html
      .replaceAll(
        RegExp(r'<script\b[^>]*>[\s\S]*?</script>', caseSensitive: false),
        ' ',
      )
      .replaceAll(
        RegExp(r'<style\b[^>]*>[\s\S]*?</style>', caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&#160;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (maxCharacters != null &&
      maxCharacters >= 0 &&
      value.length > maxCharacters) {
    value = '${value.substring(0, maxCharacters).trim()}…';
  }
  return value;
}

String formatLearningMaterialsHomeViews(int? value) {
  final count = value ?? 0;
  if (count <= 0) return '浏览0';
  if (count >= 10000) {
    final number = count / 10000;
    return '浏览${_decimal(number, uppercaseThreshold: 10)}W';
  }
  if (count >= 1000) return '浏览${_decimal(count / 1000)}K';
  return '浏览$count';
}

String formatLearningMaterialsCompactViews(int? value) {
  final count = value ?? 0;
  if (count <= 0) return '0';
  if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
  return '$count';
}

String _decimal(double value, {double? uppercaseThreshold}) {
  if (uppercaseThreshold != null && value >= uppercaseThreshold) {
    return value.toStringAsFixed(0);
  }
  if ((value - value.round()).abs() < 0.05) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

List<String> _tags(Map<String, dynamic> map) {
  final tags = <String>[];
  final raw = map['tags'];
  if (raw is List) {
    for (final tag in raw) {
      final text = _text(tag).trim();
      if (text.isNotEmpty) tags.add(text);
    }
  }
  if (tags.isEmpty) {
    final legacy = _text(map['payType']).trim();
    if (legacy.isNotEmpty) tags.add(legacy);
  }
  return tags;
}

int? _firstInt(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    if (map.containsKey(key) && map[key] != null) {
      return _nullableInt(map[key]);
    }
  }
  return null;
}

String _firstText(Map<String, dynamic> map, List<String> keys) {
  return _firstMeaningful(keys.map((key) => _text(map[key])));
}

String _firstMeaningful(Iterable<String> values) {
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'null') return trimmed;
  }
  return '';
}

String _text(Object? value) => value?.toString() ?? '';

int _int(Object? value) => _nullableInt(value) ?? 0;

int? _nullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool _bool(Object? value, bool fallback) => _nullableBool(value) ?? fallback;

bool? _nullableBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return null;
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
