enum PracticeThemeMode { standard, eyeCare, night }

enum PracticeFontSize { small, normal, large, extraLarge }

final class PracticeSettings {
  const PracticeSettings({
    required this.autoNext,
    required this.playCorrectSound,
    required this.explainWrongAutomatically,
    required this.fontSize,
    required this.themeMode,
  });

  const PracticeSettings.androidDefaults()
    : autoNext = true,
      playCorrectSound = true,
      explainWrongAutomatically = true,
      fontSize = PracticeFontSize.large,
      themeMode = PracticeThemeMode.standard;

  const PracticeSettings.disabledDefaults()
    : autoNext = false,
      playCorrectSound = false,
      explainWrongAutomatically = false,
      fontSize = PracticeFontSize.normal,
      themeMode = PracticeThemeMode.standard;

  factory PracticeSettings.fromMap(Map<String, dynamic> map) {
    return PracticeSettings(
      autoNext: _boolean(map['autoNext'], true),
      playCorrectSound: _boolean(map['playCorrectSound'], true),
      explainWrongAutomatically: _boolean(
        map['explainWrongAutomatically'],
        true,
      ),
      fontSize: _fontSize(map['fontSize']),
      themeMode: _themeMode(map['themeMode']),
    );
  }

  final bool autoNext;
  final bool playCorrectSound;
  final bool explainWrongAutomatically;
  final PracticeFontSize fontSize;
  final PracticeThemeMode themeMode;

  double get textScale => switch (fontSize) {
    PracticeFontSize.small => 0.82,
    PracticeFontSize.normal => 1,
    PracticeFontSize.large => 1.16,
    PracticeFontSize.extraLarge => 1.38,
  };

  PracticeSettings copyWith({
    bool? autoNext,
    bool? playCorrectSound,
    bool? explainWrongAutomatically,
    PracticeFontSize? fontSize,
    PracticeThemeMode? themeMode,
  }) {
    return PracticeSettings(
      autoNext: autoNext ?? this.autoNext,
      playCorrectSound: playCorrectSound ?? this.playCorrectSound,
      explainWrongAutomatically:
          explainWrongAutomatically ?? this.explainWrongAutomatically,
      fontSize: fontSize ?? this.fontSize,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, Object> toMap() {
    return {
      'autoNext': autoNext,
      'playCorrectSound': playCorrectSound,
      'explainWrongAutomatically': explainWrongAutomatically,
      'fontSize': switch (fontSize) {
        PracticeFontSize.small => -1,
        PracticeFontSize.normal => 0,
        PracticeFontSize.large => 1,
        PracticeFontSize.extraLarge => 2,
      },
      'themeMode': switch (themeMode) {
        PracticeThemeMode.standard => 0,
        PracticeThemeMode.eyeCare => 1,
        PracticeThemeMode.night => 2,
      },
    };
  }
}

abstract interface class PracticeSettingsStore {
  Future<PracticeSettings> loadPracticeSettings();

  Future<void> savePracticeSettings(PracticeSettings settings);
}

final class DisabledPracticeSettingsStore implements PracticeSettingsStore {
  const DisabledPracticeSettingsStore();

  @override
  Future<PracticeSettings> loadPracticeSettings() async =>
      const PracticeSettings.disabledDefaults();

  @override
  Future<void> savePracticeSettings(PracticeSettings settings) async {}
}

bool _boolean(Object? value, bool fallback) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return switch (value?.toString().trim().toLowerCase()) {
    'true' || '1' => true,
    'false' || '0' => false,
    _ => fallback,
  };
}

PracticeFontSize _fontSize(Object? value) {
  final index = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? 1;
  return switch (index) {
    -1 => PracticeFontSize.small,
    0 => PracticeFontSize.normal,
    2 => PracticeFontSize.extraLarge,
    _ => PracticeFontSize.large,
  };
}

PracticeThemeMode _themeMode(Object? value) {
  final index = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? 0;
  return switch (index) {
    1 => PracticeThemeMode.eyeCare,
    2 => PracticeThemeMode.night,
    _ => PracticeThemeMode.standard,
  };
}
