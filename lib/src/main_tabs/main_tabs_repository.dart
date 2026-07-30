import 'dart:convert';

import '../network/app_api_client.dart';
import '../storage/legacy_app_state_store.dart';
import '../vip_purchase/vip_purchase_models.dart';
import 'main_tabs_models.dart';
import 'mine_web_route.dart';

typedef MineReferralProfilePersister =
    Future<void> Function({
      required String userRole,
      required String commissionRate,
    });

abstract interface class MainTabsDataSource {
  Future<HomeTabData> loadHome({
    String? preferredCategoryKey,
    int? preferredSubjectId,
  });

  Future<CourseTabData> loadCourses({
    required CourseType courseType,
    String? subject,
  });

  Future<MineTabData> loadMine();
}

final class MainTabsRepository implements MainTabsDataSource {
  MainTabsRepository({
    required AppApiClient api,
    required LegacyAppStateStore stateStore,
    DateTime Function()? now,
    MineReferralProfilePersister? persistMineReferralProfile,
  }) : _api = api,
       _stateStore = stateStore,
       _now = now ?? DateTime.now,
       _persistMineReferralProfile = persistMineReferralProfile;

  final AppApiClient _api;
  final LegacyAppStateStore _stateStore;
  final DateTime Function() _now;
  final MineReferralProfilePersister? _persistMineReferralProfile;

  @override
  Future<HomeTabData> loadHome({
    String? preferredCategoryKey,
    int? preferredSubjectId,
  }) async {
    final selection = await _loadSelection(
      preferredCategoryKey: preferredCategoryKey,
      preferredSubjectId: preferredSubjectId,
    );
    final rawModules = _listOf(
      await _api.getBody(
        '/knowledge/shelf/moduleLis',
        queryParameters: {'marketId': selection.subject.id},
      ),
      '首页模块响应不是数组',
    );
    final allModules = rawModules
        .map((item) {
          final map = _mapOf(item, '首页模块不是对象');
          return HomeModule(
            id: _int(map['id']),
            name: _text(map['name']),
            page: _text(map['page']),
            tag: _text(map['tag']),
            type: _text(map['type']),
          );
        })
        .toList(growable: false);
    HomeModule? bigSkillCircleModule;
    HomeModule? learningMaterialsModule;
    final modules = <HomeModule>[];
    for (final module in allModules) {
      if (_isBigSkillCircleModule(module)) {
        bigSkillCircleModule ??= module;
      } else if (_isLearningMaterialsModule(module)) {
        learningMaterialsModule ??= module;
      } else {
        modules.add(module);
      }
    }
    return HomeTabData(
      categoryGroups: selection.groups,
      selection: selection.value,
      modules: List<HomeModule>.unmodifiable(modules),
      bannerUrl: _homeBannerUrl(selection),
      examCountdownDays: _examCountdownDays(selection),
      bigSkillCircleModule: bigSkillCircleModule,
      learningMaterialsModule: learningMaterialsModule,
    );
  }

  @override
  Future<CourseTabData> loadCourses({
    required CourseType courseType,
    String? subject,
  }) async {
    final selection = await _loadSelection(preferredSubject: subject);
    final benefitSummary = resolveVipBenefitSummary(
      selection.snapshot.userBenefitsJson,
      category: selection.category,
      level: selection.level,
      categoryName: selection.level,
    );
    final rawItems = _listOf(
      await _api.postBody('/app/tempMedia/query', {
        'subject': selection.subject.name,
        'courseType': courseType.apiValue,
        'level': selection.level,
        'showOnHome': '0',
      }),
      '课程响应不是数组',
    );
    final items = rawItems
        .map((item) {
          final map = _mapOf(item, '课程条目不是对象');
          return CourseMedia(
            id: _int(map['id']),
            subject: _text(map['subject']),
            courseType: _text(map['courseType']),
            title: _text(map['title']),
            coverUrl: _resolveUrl(
              _text(map['coverUrl']),
              selection.snapshot.ossDomain,
            ),
            mediaUrl: _resolveUrl(
              _text(map['mediaUrl']),
              selection.snapshot.ossDomain,
            ),
          );
        })
        .toList(growable: false);
    return CourseTabData(
      categoryLabel: selection.level,
      subjects: selection.subjects,
      selectedSubject: selection.subject,
      courseType: courseType,
      items: items,
      isLoggedIn: selection.snapshot.isLoggedIn,
      hasVideoAccess: benefitSummary.lines.any(
        (benefit) => benefit.type == 'course_video',
      ),
      hasPracticePackage: benefitSummary.hasPracticePackage,
    );
  }

  @override
  Future<MineTabData> loadMine() async {
    final snapshot = AppSnapshot.fromMap(await _stateStore.readAppSnapshot());
    final query = <String, dynamic>{
      'pageNum': 1,
      'pageSize': 1,
      'subject': snapshot.selectedSubject,
      'level': snapshot.selectedLevel,
    };
    final results = await Future.wait<Object?>([
      _api.getBody('/app/question/pageErrorQuestion', queryParameters: query),
      _api.getBody('/app/question/pageCollectQuestion', queryParameters: query),
      _loadMineReferralProfile(snapshot),
    ]);
    final referral = results[2]! as _MineReferralProfile;
    return MineTabData(
      isLoggedIn: snapshot.isLoggedIn,
      profile: MineProfile(
        userId: snapshot.userId,
        nickname: snapshot.nickname,
        phone: snapshot.phone,
        avatar: snapshot.avatar,
        userRole: referral.userRole,
      ),
      errorCount: _total(results[0]),
      collectionCount: _total(results[1]),
      collectBookRequest: MineWebRouteResolver.collectBook(
        snapshot.collectBookH5Url,
      ),
      inviteFriendsRequest: MineWebRouteResolver.inviteFriends(
        activity: snapshot.inviteFissionActivity,
        token: snapshot.accessToken,
        isTestEnvironment: snapshot.isTestEnvironment,
        userRole: referral.userRole,
        commissionRate: referral.commissionRate,
      ),
    );
  }

  Future<_MineReferralProfile> _loadMineReferralProfile(
    AppSnapshot snapshot,
  ) async {
    final cached = _MineReferralProfile(
      userRole: snapshot.userRole,
      commissionRate: snapshot.commissionRate,
    );
    if (!snapshot.isLoggedIn) return cached;
    try {
      final body = _mapOf(
        await _api.getBody('/app/user/getUserRole'),
        '用户推荐资料响应不是对象',
      );
      final refreshed = _MineReferralProfile(
        userRole: _text(body['userRole']),
        commissionRate: _text(body['commissionRate']),
      );
      await _persistMineReferralProfile?.call(
        userRole: refreshed.userRole,
        commissionRate: refreshed.commissionRate,
      );
      return refreshed;
    } catch (_) {
      return cached;
    }
  }

  Future<_Selection> _loadSelection({
    String? preferredCategoryKey,
    int? preferredSubjectId,
    String? preferredSubject,
  }) async {
    final snapshot = AppSnapshot.fromMap(await _stateStore.readAppSnapshot());
    final categoryBody = _mapOf(
      await _api.getBody(
        '/knowledge/market/appCategory',
        queryParameters: {'marketType': '模块管理'},
      ),
      '分类响应不是对象',
    );
    final groups = _categoryGroups(categoryBody, snapshot);
    if (groups.isEmpty) throw const FormatException('没有有效分类');
    final options = groups
        .expand((group) => group.options)
        .toList(growable: false);
    final defaultParts = snapshot.staticDefaultCategory.split('&');
    final selectedId = _int(snapshot.selectedCategory['id'], -1);
    final configuredLevel = defaultParts.length > 1 ? defaultParts[1] : '';
    final configuredAppType = defaultParts.isEmpty ? '' : defaultParts.first;
    final category =
        _firstOption(options, (item) => item.key == preferredCategoryKey) ??
        _firstOption(
          options,
          (item) => item.key == snapshot.selectedCategoryKey,
        ) ??
        _firstOption(
          options,
          (item) =>
              item.appType == snapshot.category &&
              (item.id == selectedId || item.label == snapshot.selectedLevel),
        ) ??
        _firstOption(
          options,
          (item) =>
              item.appType == configuredAppType &&
              (configuredLevel.isEmpty || item.label == configuredLevel),
        ) ??
        options.first;
    final canUsePersistedSubject = category.appType == snapshot.category;
    final subject =
        _firstSubject(
          category.subjects,
          (item) => item.id == preferredSubjectId,
        ) ??
        _firstSubject(
          category.subjects,
          (item) =>
              preferredSubject?.isNotEmpty == true &&
              item.name == preferredSubject,
        ) ??
        _firstSubject(
          category.subjects,
          (item) =>
              canUsePersistedSubject &&
              (item.name == snapshot.selectedSubject ||
                  item.id == snapshot.selectedMarketId),
        ) ??
        category.subjects.first;
    await _stateStore.persistCategorySelection(
      categoryBodyJson: jsonEncode(categoryBody),
      category: category.appType,
      selectedCategory: category.raw,
      selectedCategoryKey: category.key,
      marketId: subject.id,
      subject: subject.name,
    );
    return _Selection(
      snapshot: snapshot,
      groups: groups,
      value: MainTabsSelection(category: category, subject: subject),
    );
  }

  List<CategoryGroup> _categoryGroups(
    Map<String, dynamic> categoryBody,
    AppSnapshot snapshot,
  ) {
    final labels = _categoryLabels(snapshot.appCategoryNameMappingJson);
    const fallbackLabels = <String, String>{
      'social-work': '社工',
      'joy-ledger': '会计',
    };
    final groups = <CategoryGroup>[];
    for (final entry in categoryBody.entries) {
      final appType = entry.key.trim();
      final mappedLabel = labels[appType]?.trim() ?? '';
      final label = mappedLabel.isNotEmpty
          ? mappedLabel
          : (fallbackLabels[appType] ?? '');
      if (appType.isEmpty || label.isEmpty || entry.value is! List) continue;
      final options = <CategoryOption>[];
      for (final value in entry.value as List) {
        if (value is! Map) continue;
        final raw = Map<String, dynamic>.from(value);
        final id = _int(raw['id'], -1);
        final optionLabel = _text(raw['level']).trim().isNotEmpty
            ? _text(raw['level']).trim()
            : _text(raw['name']).trim();
        if (id <= 0 || optionLabel.isEmpty || raw['children'] is! List) {
          continue;
        }
        final subjects = <CategorySubject>[];
        for (final child in raw['children'] as List) {
          if (child is! Map) continue;
          final childMap = Map<String, dynamic>.from(child);
          final subject = CategorySubject(
            id: _int(childMap['id'], -1),
            name: _text(childMap['name']).trim(),
          );
          if (subject.id > 0 && subject.name.isNotEmpty) subjects.add(subject);
        }
        if (subjects.isEmpty) continue;
        options.add(
          CategoryOption(
            key: '${appType}_$id',
            appType: appType,
            id: id,
            label: optionLabel,
            subjects: List.unmodifiable(subjects),
            raw: Map.unmodifiable(raw),
          ),
        );
      }
      if (options.isNotEmpty) {
        groups.add(
          CategoryGroup(label: label, options: List.unmodifiable(options)),
        );
      }
    }
    return List.unmodifiable(groups);
  }

  static Map<String, String> _categoryLabels(String raw) {
    if (raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    } on FormatException {
      return const {};
    }
  }

  static CategoryOption? _firstOption(
    List<CategoryOption> items,
    bool Function(CategoryOption item) predicate,
  ) {
    for (final item in items) {
      if (predicate(item)) return item;
    }
    return null;
  }

  static CategorySubject? _firstSubject(
    List<CategorySubject> items,
    bool Function(CategorySubject item) predicate,
  ) {
    for (final item in items) {
      if (predicate(item)) return item;
    }
    return null;
  }

  String? _homeBannerUrl(_Selection selection) {
    var path = '';
    final raw = selection.snapshot.homeTopBannerJson;
    if (raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded[selection.category] is List) {
        for (final item in decoded[selection.category] as List) {
          if (item is Map && item[selection.level] != null) {
            path = item[selection.level].toString();
            break;
          }
        }
      }
    }
    if (path.isEmpty) path = selection.snapshot.homeTopBannerUrl;
    if (path.isEmpty) return null;
    return _resolveUrl(path, selection.snapshot.ossDomain);
  }

  int? _examCountdownDays(_Selection selection) {
    final raw = selection.snapshot.examTimeJson;
    if (raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded[selection.category] is! List) return null;
    String? dateText;
    for (final group in decoded[selection.category] as List) {
      if (group is! Map || group[selection.level] is! List) continue;
      for (final subject in group[selection.level] as List) {
        if (subject is! Map) continue;
        for (final entry in subject.entries) {
          if (_normalizedSubject(entry.key.toString()) ==
              _normalizedSubject(selection.subject.name)) {
            dateText = entry.value?.toString();
            break;
          }
        }
      }
    }
    if (dateText == null || dateText.isEmpty) return null;
    final exam = DateTime.tryParse(dateText);
    if (exam == null) return null;
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime(
      exam.year,
      exam.month,
      exam.day,
    ).difference(today).inDays;
    return days < 0 ? null : days;
  }

  static bool _isBigSkillCircleModule(HomeModule module) {
    final page = module.page.trim();
    final name = module.name.trim();
    return page == '技巧圈题卷' ||
        page == '大招圈题卷' ||
        name == '技巧圈题卷' ||
        name == '大招圈题卷';
  }

  static bool _isLearningMaterialsModule(HomeModule module) {
    final page = module.page.trim();
    return page == '学习资料' || (page.isEmpty && module.name.trim() == '学习资料');
  }

  static String _normalizedSubject(String value) {
    return value.trim().replaceFirst(RegExp(r'^中级'), '');
  }

  static int _total(Object? value) {
    final map = _mapOf(value, '题目数量响应不是对象');
    return _int(map['total']);
  }

  static String _resolveUrl(String value, String domain) {
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    if (uri?.hasScheme == true) return value;
    if (domain.isEmpty) return value;
    return '${domain.replaceFirst(RegExp(r'/$'), '')}/${value.replaceFirst(RegExp(r'^/'), '')}';
  }

  static Map<String, dynamic> _mapOf(Object? value, String message) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw FormatException(message);
  }

  static List<Object?> _listOf(Object? value, String message) {
    if (value is List) return List<Object?>.from(value);
    throw FormatException(message);
  }

  static String _text(Object? value) => value?.toString() ?? '';

  static int _int(Object? value, [int fallback = 0]) {
    return value is int ? value : int.tryParse(value.toString()) ?? fallback;
  }
}

final class _Selection {
  const _Selection({
    required this.snapshot,
    required this.groups,
    required this.value,
  });

  final AppSnapshot snapshot;
  final List<CategoryGroup> groups;
  final MainTabsSelection value;

  String get category => value.category.appType;
  String get level => value.category.label;
  List<CategorySubject> get subjects => value.category.subjects;
  CategorySubject get subject => value.subject;
}

final class _MineReferralProfile {
  const _MineReferralProfile({
    required this.userRole,
    required this.commissionRate,
  });

  final String userRole;
  final String commissionRate;
}
