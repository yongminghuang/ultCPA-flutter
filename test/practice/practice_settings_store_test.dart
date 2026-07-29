import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/practice/practice_settings_store.dart';

void main() {
  test('uses the same default settings as Android LearnPreferences', () {
    const settings = PracticeSettings.androidDefaults();

    expect(settings.autoNext, isTrue);
    expect(settings.playCorrectSound, isTrue);
    expect(settings.explainWrongAutomatically, isTrue);
    expect(settings.fontSize, PracticeFontSize.large);
    expect(settings.themeMode, PracticeThemeMode.standard);
  });

  test('parses and serializes the legacy integer setting values', () {
    final settings = PracticeSettings.fromMap({
      'autoNext': 0,
      'playCorrectSound': 1,
      'explainWrongAutomatically': false,
      'fontSize': -1,
      'themeMode': 2,
    });

    expect(settings.fontSize, PracticeFontSize.small);
    expect(settings.themeMode, PracticeThemeMode.night);
    expect(settings.toMap(), {
      'autoNext': false,
      'playCorrectSound': true,
      'explainWrongAutomatically': false,
      'fontSize': -1,
      'themeMode': 2,
    });
  });
}
