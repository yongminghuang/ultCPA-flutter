import 'dart:convert';

import '../web/legacy_webview_page.dart';

enum CourseType {
  intensive('技巧精讲', '大招精讲'),
  secret('技巧密押', '大招密押'),
  emergency('技巧急救', '大招急救');

  const CourseType(this.label, this.apiValue);

  final String label;
  final String apiValue;
}

final class CategorySubject {
  const CategorySubject({required this.id, required this.name});

  final int id;
  final String name;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CategorySubject && other.id == id && other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);
}

final class CategoryGroup {
  const CategoryGroup({required this.label, required this.options});

  final String label;
  final List<CategoryOption> options;
}

final class CategoryOption {
  const CategoryOption({
    required this.key,
    required this.appType,
    required this.id,
    required this.label,
    required this.subjects,
    required this.raw,
  });

  final String key;
  final String appType;
  final int id;
  final String label;
  final List<CategorySubject> subjects;
  final Map<String, dynamic> raw;
}

final class MainTabsSelection {
  const MainTabsSelection({required this.category, required this.subject});

  final CategoryOption category;
  final CategorySubject subject;
}

final class HomeModule {
  const HomeModule({
    required this.id,
    required this.name,
    required this.page,
    required this.tag,
    this.type = '',
  });

  final int id;
  final String name;
  final String page;
  final String tag;
  final String type;

  bool get isHot => tag.toLowerCase() == 'hot';
}

final class CourseMedia {
  const CourseMedia({
    required this.id,
    required this.subject,
    required this.courseType,
    required this.title,
    required this.coverUrl,
    required this.mediaUrl,
  });

  final int id;
  final String subject;
  final String courseType;
  final String title;
  final String coverUrl;
  final String mediaUrl;

  bool get hasPlayableMedia {
    final uri = Uri.tryParse(mediaUrl);
    return uri?.hasScheme == true && uri!.path.isNotEmpty && uri.path != '/';
  }
}

final class MineProfile {
  const MineProfile({
    required this.userId,
    required this.nickname,
    required this.phone,
    required this.avatar,
    required this.userRole,
  });

  final String userId;
  final String nickname;
  final String phone;
  final String avatar;
  final String userRole;
}

final class HomeTabData {
  const HomeTabData({
    required this.categoryGroups,
    required this.selection,
    required this.modules,
    required this.bannerUrl,
    required this.examCountdownDays,
    this.bigSkillCircleModule,
    this.learningMaterialsModule,
  });

  final List<CategoryGroup> categoryGroups;
  final MainTabsSelection selection;
  final List<HomeModule> modules;
  final String? bannerUrl;
  final int? examCountdownDays;
  final HomeModule? bigSkillCircleModule;
  final HomeModule? learningMaterialsModule;

  String get category => selection.category.appType;
  String get categoryLabel => selection.category.label;
  List<CategorySubject> get subjects => selection.category.subjects;
  CategorySubject get selectedSubject => selection.subject;
}

final class CourseTabData {
  const CourseTabData({
    required this.categoryLabel,
    required this.subjects,
    required this.selectedSubject,
    required this.courseType,
    required this.items,
    this.isLoggedIn = false,
    this.hasVideoAccess = false,
    this.hasPracticePackage = false,
  });

  final String categoryLabel;
  final List<CategorySubject> subjects;
  final CategorySubject selectedSubject;
  final CourseType courseType;
  final List<CourseMedia> items;
  final bool isLoggedIn;
  final bool hasVideoAccess;
  final bool hasPracticePackage;
}

final class MineTabData {
  const MineTabData({
    required this.isLoggedIn,
    required this.profile,
    required this.errorCount,
    required this.collectionCount,
    required this.collectBookRequest,
    required this.inviteFriendsRequest,
  });

  final bool isLoggedIn;
  final MineProfile profile;
  final int errorCount;
  final int collectionCount;
  final LegacyWebRequest? collectBookRequest;
  final LegacyWebRequest? inviteFriendsRequest;
}

final class AppSnapshot {
  const AppSnapshot({
    required this.category,
    required this.selectedCategory,
    required this.selectedCategoryKey,
    required this.selectedLevel,
    required this.selectedMarketId,
    required this.selectedSubject,
    required this.categoryBodyJson,
    required this.staticDefaultCategory,
    required this.appCategoryNameMappingJson,
    required this.ossDomain,
    required this.homeTopBannerJson,
    required this.homeTopBannerUrl,
    required this.examTimeJson,
    required this.collectBookH5Url,
    required this.inviteFissionActivity,
    required this.skillFormulaFreeCount,
    required this.skillQuestionFreeCount,
    required this.isLoggedIn,
    required this.userId,
    required this.nickname,
    required this.phone,
    required this.avatar,
    required this.userRole,
    required this.accessToken,
    required this.commissionRate,
    required this.isTestEnvironment,
    required this.showWxPay,
    required this.defaultPayType,
    required this.userBenefitsJson,
  });

  factory AppSnapshot.fromMap(Map<String, dynamic> map) {
    final selectedJson = _text(map['selectedCategoryJson']);
    Map<String, dynamic> selected = const {};
    if (selectedJson.isNotEmpty) {
      final decoded = jsonDecode(selectedJson);
      if (decoded is Map) selected = Map<String, dynamic>.from(decoded);
    }
    return AppSnapshot(
      category: _text(map['category'], 'social-work'),
      selectedCategory: selected,
      selectedCategoryKey: _text(map['selectedCategoryKey']),
      selectedLevel: _text(map['selectedLevel']),
      selectedMarketId: _integer(map['selectedMarketId'], -1),
      selectedSubject: _text(map['selectedSubject']),
      categoryBodyJson: _text(map['categoryBodyJson']),
      staticDefaultCategory: _text(map['staticDefaultCategory']),
      appCategoryNameMappingJson: _text(map['appCategoryNameMappingJson']),
      ossDomain: _text(map['ossDomain']),
      homeTopBannerJson: _text(map['homeTopBannerJson']),
      homeTopBannerUrl: _text(map['homeTopBannerUrl']),
      examTimeJson: _text(map['examTimeJson']),
      collectBookH5Url: _text(map['collectBookH5Url']),
      inviteFissionActivity: _integer(map['inviteFissionActivity'], 0),
      skillFormulaFreeCount: _integer(map['skillFormulaFreeCount'], 3),
      skillQuestionFreeCount: _integer(map['skillQuestionFreeCount'], 5),
      isLoggedIn: map['isLoggedIn'] == true,
      userId: _text(map['userId']),
      nickname: _text(map['nickname']),
      phone: _text(map['phone']),
      avatar: _text(map['avatar']),
      userRole: _text(map['userRole']),
      accessToken: _text(map['accessToken']),
      commissionRate: _text(map['commissionRate']),
      isTestEnvironment: map['isTestEnvironment'] == true,
      showWxPay: _boolean(map['showWxPay'], true),
      defaultPayType: _integer(map['defaultPayType'], 1),
      userBenefitsJson: _text(map['userBenefitsJson']),
    );
  }

  final String category;
  final Map<String, dynamic> selectedCategory;
  final String selectedCategoryKey;
  final String selectedLevel;
  final int selectedMarketId;
  final String selectedSubject;
  final String categoryBodyJson;
  final String staticDefaultCategory;
  final String appCategoryNameMappingJson;
  final String ossDomain;
  final String homeTopBannerJson;
  final String homeTopBannerUrl;
  final String examTimeJson;
  final String collectBookH5Url;
  final int inviteFissionActivity;
  final int skillFormulaFreeCount;
  final int skillQuestionFreeCount;
  final bool isLoggedIn;
  final String userId;
  final String nickname;
  final String phone;
  final String avatar;
  final String userRole;
  final String accessToken;
  final String commissionRate;
  final bool isTestEnvironment;
  final bool showWxPay;
  final int defaultPayType;
  final String userBenefitsJson;
}

String _text(Object? value, [String fallback = '']) {
  return value?.toString() ?? fallback;
}

int _integer(Object? value, int fallback) {
  return value is int ? value : int.tryParse(value.toString()) ?? fallback;
}

bool _boolean(Object? value, bool fallback) {
  if (value is bool) return value;
  if (value is String) {
    if (value.toLowerCase() == 'true') return true;
    if (value.toLowerCase() == 'false') return false;
  }
  return fallback;
}
