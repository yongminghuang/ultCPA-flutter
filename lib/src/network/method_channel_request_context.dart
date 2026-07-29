import 'package:flutter/services.dart';

import '../chapter_practice/chapter_practice_progress_store.dart';
import '../daily_skill/daily_skill_progress_store.dart';
import '../practice/flat_practice_progress_store.dart';
import '../practice/practice_settings_store.dart';
import '../storage/legacy_app_state_store.dart';
import '../practice/practice_review_store.dart';

final class MethodChannelRequestContext
    implements
        LegacyAppStateStore,
        PracticeReviewStore,
        ChapterPracticeProgressStore,
        FlatPracticeProgressStore,
        PracticeSettingsStore,
        DailySkillProgressPersistence {
  MethodChannelRequestContext({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.xmzj.ult.agg/request_context';

  final MethodChannel _channel;

  Future<String> apiBaseUrl() async {
    final value = await _channel.invokeMethod<String>('getApiBaseUrl');
    if (value == null || value.isEmpty) {
      throw StateError('Android did not provide an API base URL.');
    }
    return value;
  }

  Future<Map<String, String>> headers() async {
    final values = await _channel.invokeMapMethod<String, String>(
      'buildRequestHeaders',
    );
    return values ?? const {};
  }

  Future<Map<String, dynamic>> deviceLoginBody() async {
    final values = await _channel.invokeMapMethod<String, dynamic>(
      'buildDeviceLoginBody',
    );
    return values ?? const {};
  }

  Future<void> persistSession({
    required String accessToken,
    required String userId,
  }) {
    return _channel.invokeMethod<void>('persistSession', {
      'accessToken': accessToken,
      'userId': userId,
    });
  }

  Future<void> persistPhoneSession({
    required String accessToken,
    required Map<String, dynamic> user,
  }) {
    return _channel.invokeMethod<void>('persistPhoneSession', {
      'accessToken': accessToken,
      'user': user,
    });
  }

  Future<void> persistStaticConfiguration(Map<String, String> values) {
    return _channel.invokeMethod<void>('persistStaticConfiguration', {
      'values': values,
    });
  }

  Future<void> persistMineReferralProfile({
    required String userRole,
    required String commissionRate,
  }) {
    return _channel.invokeMethod<void>('persistMineReferralProfile', {
      'userRole': userRole,
      'commissionRate': commissionRate,
    });
  }

  Future<void> persistAppUpdateCheckTimestamp(int millis) {
    return _channel.invokeMethod<void>('persistAppUpdateCheckTimestamp', {
      'millis': millis,
    });
  }

  @override
  Future<Map<String, dynamic>> readAppSnapshot() async {
    final values = await _channel.invokeMapMethod<String, dynamic>(
      'readAppSnapshot',
    );
    return values ?? const {};
  }

  @override
  Future<void> persistCategorySelection({
    required String categoryBodyJson,
    required String category,
    required Map<String, dynamic> selectedCategory,
    required String selectedCategoryKey,
    required int marketId,
    required String subject,
  }) {
    return _channel.invokeMethod<void>('persistCategorySelection', {
      'categoryBodyJson': categoryBodyJson,
      'category': category,
      'selectedCategory': selectedCategory,
      'selectedCategoryKey': selectedCategoryKey,
      'marketId': marketId,
      'subject': subject,
    });
  }

  @override
  Future<int> loadWrongRemovalThreshold() async {
    return await _channel.invokeMethod<int>('getWrongRemovalThreshold') ?? -1;
  }

  @override
  Future<void> saveWrongRemovalThreshold(int threshold) {
    return _channel.invokeMethod<void>('setWrongRemovalThreshold', {
      'threshold': threshold,
    });
  }

  @override
  Future<bool> recordWrongQuestionCorrect(String questionId) async {
    return await _channel.invokeMethod<bool>('recordWrongQuestionCorrect', {
          'questionId': questionId,
        }) ??
        false;
  }

  @override
  Future<PracticeSettings> loadPracticeSettings() async {
    final values = await _channel.invokeMapMethod<String, dynamic>(
      'getPracticeSettings',
    );
    return PracticeSettings.fromMap(values ?? const {});
  }

  @override
  Future<void> savePracticeSettings(PracticeSettings settings) {
    return _channel.invokeMethod<void>('setPracticeSettings', settings.toMap());
  }

  @override
  Future<int> loadExpandedCatalog({required int moduleId}) async {
    _requirePositive(moduleId, 'moduleId');
    return await _channel.invokeMethod<int>(
          'getChapterPracticeExpandedCatalog',
          {'moduleId': moduleId},
        ) ??
        -1;
  }

  @override
  Future<void> saveExpandedCatalog({
    required int moduleId,
    required int catalogIndex,
  }) async {
    _requirePositive(moduleId, 'moduleId');
    _requireNonNegative(catalogIndex, 'catalogIndex');
    await _channel.invokeMethod<void>('setChapterPracticeExpandedCatalog', {
      'moduleId': moduleId,
      'catalogIndex': catalogIndex,
    });
  }

  @override
  Future<int> loadQuestionPosition({
    required int moduleId,
    required int catalogIndex,
    required int chapterIndex,
  }) async {
    _requirePositive(moduleId, 'moduleId');
    _requireNonNegative(catalogIndex, 'catalogIndex');
    _requireNonNegative(chapterIndex, 'chapterIndex');
    return await _channel.invokeMethod<int>(
          'getChapterPracticeQuestionPosition',
          {
            'moduleId': moduleId,
            'catalogIndex': catalogIndex,
            'chapterIndex': chapterIndex,
          },
        ) ??
        0;
  }

  @override
  Future<void> saveQuestionPosition({
    required int moduleId,
    required int catalogIndex,
    required int chapterIndex,
    required int position,
  }) async {
    _requirePositive(moduleId, 'moduleId');
    _requireNonNegative(catalogIndex, 'catalogIndex');
    _requireNonNegative(chapterIndex, 'chapterIndex');
    _requireNonNegative(position, 'position');
    await _channel.invokeMethod<void>('setChapterPracticeQuestionPosition', {
      'moduleId': moduleId,
      'catalogIndex': catalogIndex,
      'chapterIndex': chapterIndex,
      'position': position,
    });
  }

  @override
  Future<int> loadFlatQuestionPosition({required int shelfId}) async {
    _requirePositive(shelfId, 'shelfId');
    return await _channel.invokeMethod<int>('getFlatPracticeQuestionPosition', {
          'shelfId': shelfId,
        }) ??
        0;
  }

  @override
  Future<void> saveFlatQuestionPosition({
    required int shelfId,
    required int position,
  }) async {
    _requirePositive(shelfId, 'shelfId');
    _requireNonNegative(position, 'position');
    await _channel.invokeMethod<void>('setFlatPracticeQuestionPosition', {
      'shelfId': shelfId,
      'position': position,
    });
  }

  @override
  Future<String> readDailySkillProgressJson() async {
    return await _channel.invokeMethod<String>('readDailySkillProgressJson') ??
        '';
  }

  @override
  Future<void> writeDailySkillProgressJson(String json) {
    return _channel.invokeMethod<void>('writeDailySkillProgressJson', {
      'json': json,
    });
  }

  @override
  Future<String> readDailySkillCheckInJson() async {
    return await _channel.invokeMethod<String>('readDailySkillCheckInJson') ??
        '';
  }

  @override
  Future<void> writeDailySkillCheckInJson(String json) {
    return _channel.invokeMethod<void>('writeDailySkillCheckInJson', {
      'json': json,
    });
  }
}

void _requirePositive(int value, String name) {
  if (value <= 0) throw ArgumentError.value(value, name, '必须大于 0');
}

void _requireNonNegative(int value, String name) {
  if (value < 0) throw ArgumentError.value(value, name, '不能小于 0');
}
