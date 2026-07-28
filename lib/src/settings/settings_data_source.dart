import 'package:flutter/services.dart';

import 'settings_models.dart';

abstract interface class SettingsDataSource {
  Future<SettingsSnapshot> load();

  Future<void> setNotificationEnabled(bool enabled);

  Future<void> setPersonalizedRecommendations(bool enabled);

  Future<void> clearCaches();

  Future<void> openStoreRating();

  Future<void> openExternalUrl(Uri url);
}

final class MethodChannelSettingsDataSource implements SettingsDataSource {
  MethodChannelSettingsDataSource({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.xmzj.ult.agg/settings';

  final MethodChannel _channel;

  @override
  Future<SettingsSnapshot> load() async {
    final values = await _channel.invokeMapMethod<String, dynamic>(
      'readSettings',
    );
    final notificationEnabled = values?['notificationEnabled'];
    final personalizedRecommendations = values?['personalizedRecommendations'];
    if (notificationEnabled is! bool || personalizedRecommendations is! bool) {
      throw const FormatException('原生设置快照缺少布尔字段');
    }
    return SettingsSnapshot(
      notificationEnabled: notificationEnabled,
      personalizedRecommendations: personalizedRecommendations,
    );
  }

  @override
  Future<void> setNotificationEnabled(bool enabled) {
    return _channel.invokeMethod<void>('setNotificationEnabled', {
      'enabled': enabled,
    });
  }

  @override
  Future<void> setPersonalizedRecommendations(bool enabled) {
    return _channel.invokeMethod<void>('setPersonalizedRecommendations', {
      'enabled': enabled,
    });
  }

  @override
  Future<void> clearCaches() {
    return _channel.invokeMethod<void>('clearCaches');
  }

  @override
  Future<void> openStoreRating() {
    return _channel.invokeMethod<void>('openStoreRating');
  }

  @override
  Future<void> openExternalUrl(Uri url) async {
    final scheme = url.scheme.toLowerCase();
    if ((scheme != 'http' && scheme != 'https') || url.host.isEmpty) {
      throw ArgumentError.value(url, 'url', '仅支持 HTTP(S) URL');
    }
    await _channel.invokeMethod<void>('openExternalUrl', {
      'url': url.toString(),
    });
  }
}
