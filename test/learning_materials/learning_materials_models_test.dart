import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/learning_materials/learning_materials_models.dart';

void main() {
  test('parses every Android goods alias and derives display helpers', () {
    final item = LearningMaterialsItem.fromMap({
      'id': '42',
      'type': '文档',
      'title': '',
      'name': '',
      'goodsName': '法规速记',
      'isShow': 'true',
      'tags': ['限时免费', '', '重点'],
      'viewCount': '23700',
      'downloadCount': '18',
      'bannerImage': '/banner.png',
      'bannerJumpPage': '章节练习',
      'text': '<p>第一段&nbsp;<strong>重点</strong></p>',
      'videoUrl': '/lesson.m3u8',
      'videoCoverUrl': '/video.png',
      'imgUrl': '/image.png',
      'coverUrl': '/cover.png',
      'payButtonText': '9.9 解锁',
      'payJumpPage': '速成300题',
      'commodityId': 998,
    });

    expect(item.id, 42);
    expect(item.kind, LearningMaterialKind.document);
    expect(item.displayTitle, '法规速记');
    expect(item.tags, ['限时免费', '重点']);
    expect(item.tagsLabel, '限时免费 | 重点');
    expect(item.viewCount, 23700);
    expect(item.printCount, 18);
    expect(item.imageUrl, '/image.png');
    expect(item.coverImageUrl, '/cover.png');
    expect(item.commodityId, '998');
    expect(item.documentPreview(), '第一段 重点');
    expect(item.resolvedListCover('https://cdn.example.com/'),
        'https://cdn.example.com/cover.png');
    expect(item.resolvedVideoUrl('https://cdn.example.com'),
        'https://cdn.example.com/lesson.m3u8');
    expect(item.resolvedVideoCover('https://cdn.example.com'),
        'https://cdn.example.com/video.png');
    expect(item.shouldAutoOpenDetail, isTrue);
  });

  test('falls back through legacy tags, titles, covers, and count aliases', () {
    final document = LearningMaterialsItem.fromMap({
      'type': '文档',
      'text': '<h1>正文标题</h1>${'字' * 100}',
      'payType': '会员专享',
      'copyCount': 7,
      'pictureUrl': 'picture.webp',
    });
    final video = LearningMaterialsItem.fromMap({
      'type': '视频',
      'bannerJumpPage': '视频标题备用',
      'bannerImage': 'poster.jpg',
    });
    final pay = LearningMaterialsItem.fromMap({
      'type': '支付卡片',
      'payButtonText': '立即解锁题包',
    });

    expect(document.displayTitle, startsWith('正文标题'));
    expect(document.displayTitle.length, 81);
    expect(document.tags, ['会员专享']);
    expect(document.printCount, 7);
    expect(document.imageUrl, 'picture.webp');
    expect(document.coverImageUrl, 'picture.webp');
    expect(video.displayTitle, '视频标题备用');
    expect(video.resolvedVideoCover('https://oss.test'),
        'https://oss.test/poster.jpg');
    expect(pay.displayTitle, '立即解锁题包');
    expect(pay.shouldAutoOpenDetail, isFalse);
  });

  test('page keeps hidden pay-jump rows and filters malformed rows', () {
    final page = LearningMaterialsPage.fromBody({
      'total': '4',
      'pages': 3,
      'size': '20',
      'current': '2',
      'records': [
        {'id': 1, 'type': '文档'},
        {'id': 2, 'type': '视频', 'isShow': false},
        {'id': 3},
        'not-an-object',
      ],
    });

    expect(page.total, 4);
    expect(page.records.map((item) => item.id), [1, 2]);
    expect(page.hasMore, isTrue);
    expect(page.nextPageNumber, 3);
    expect(() => page.records.add(page.records.first), throwsUnsupportedError);
  });

  test('shelf helper exactly unwraps one root level and keeps multi roots', () {
    final single = learningMaterialsTabsFromBody([
      {
        'id': 1,
        'name': 'root',
        'children': [
          {'id': '11', 'name': '每日精选', 'goodsCount': '8'},
          {'id': 12, 'name': '冲刺资料'},
        ],
      },
    ]);
    final multiple = learningMaterialsTabsFromBody([
      {'id': 21, 'name': 'A'},
      {'id': 22, 'name': 'B'},
    ]);

    expect(single.map((tab) => tab.id), [11, 12]);
    expect(single.first.goodsCount, 8);
    expect(multiple.map((tab) => tab.id), [21, 22]);
  });

  test('snapshot, share, URL and clicked-first contracts match Android', () {
    final snapshot = LearningMaterialsAppSnapshot.fromMap({
      'selectedCategoryJson': '{"level":"会计初级职称"}',
      'ossDomain': 'https://oss.example.com/',
      'isLoggedIn': true,
      'isTestEnvironment': true,
    });
    final items = [
      _item(1, '第一条'),
      _item(2, '第二条'),
      _item(3, '第三条'),
      _item(4, '第四条'),
    ];
    final reordered = reorderLearningMaterialsClickedFirst(items, 2);
    final share = LearningMaterialsShareRequest.fromItem(
      LearningMaterialsItem.fromMap({
        'id': 9,
        'type': '文档',
        'title': '资料标题',
        'text': '<p>${'摘要' * 40}</p>',
      }),
      isTestEnvironment: snapshot.isTestEnvironment,
    );

    expect(snapshot.libraryTitle, '初级会计职称资料库');
    expect(reordered.map((item) => item.id), [3, 1, 2, 4]);
    expect(() => reordered.add(items.first), throwsUnsupportedError);
    expect(Uri.parse(share.url).queryParameters, {
      'env': 'test',
      'goodsId': '9',
    });
    expect(share.title, '资料标题');
    expect(share.description.endsWith('…'), isTrue);
    expect(resolveLearningMaterialsUrl('//cdn.example.com/a.png', ''),
        'https://cdn.example.com/a.png');
    expect(resolveLearningMaterialsUrl('null', 'https://oss'), isEmpty);
  });

  test('formats Android home and compact view counts', () {
    expect(formatLearningMaterialsHomeViews(null), '浏览0');
    expect(formatLearningMaterialsHomeViews(999), '浏览999');
    expect(formatLearningMaterialsHomeViews(1500), '浏览1.5K');
    expect(formatLearningMaterialsHomeViews(20000), '浏览2W');
    expect(formatLearningMaterialsHomeViews(120000), '浏览12W');
    expect(formatLearningMaterialsCompactViews(1500), '1.5k');
    expect(formatLearningMaterialsCompactViews(23700), '2.4万');
  });

  test('rejects malformed top-level shapes and a missing type', () {
    expect(
      () => LearningMaterialsItem.fromMap({'title': 'missing'}),
      throwsFormatException,
    );
    expect(
      () => LearningMaterialsPage.fromBody([]),
      throwsFormatException,
    );
    expect(
      () => LearningMaterialsPage.fromBody({'records': 'bad'}),
      throwsFormatException,
    );
    expect(
      () => learningMaterialsTabsFromBody({'id': 1}),
      throwsFormatException,
    );
  });
}

LearningMaterialsItem _item(int id, String title) {
  return LearningMaterialsItem.fromMap({
    'id': id,
    'type': '文档',
    'title': title,
  });
}
