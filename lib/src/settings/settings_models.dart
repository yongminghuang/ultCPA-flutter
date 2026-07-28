final class SettingsSnapshot {
  const SettingsSnapshot({
    required this.notificationEnabled,
    required this.personalizedRecommendations,
  });

  final bool notificationEnabled;
  final bool personalizedRecommendations;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SettingsSnapshot &&
            other.notificationEnabled == notificationEnabled &&
            other.personalizedRecommendations == personalizedRecommendations;
  }

  @override
  int get hashCode =>
      Object.hash(notificationEnabled, personalizedRecommendations);
}
