import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/practice/practice_media_player.dart';

void main() {
  test('resolves Android-compatible practice media URLs', () {
    expect(
      resolvePracticeMediaUrl('lrjk/skill/voice.mp3'),
      'https://file.xmzhujing.com/lrjk/skill/voice.mp3',
    );
    expect(
      resolvePracticeMediaUrl(
        '/skill/video.mp4',
        ossDomain: 'https://cdn.example.com/root/',
      ),
      'https://cdn.example.com/root/skill/video.mp4',
    );
    expect(
      resolvePracticeMediaUrl('https://cdn.example.com/full.mp3'),
      'https://cdn.example.com/full.mp3',
    );
  });

  test('rejects empty and unsupported media schemes', () {
    expect(resolvePracticeMediaUrl(null), isEmpty);
    expect(resolvePracticeMediaUrl('null'), isEmpty);
    expect(resolvePracticeMediaUrl('file:///private/voice.mp3'), isEmpty);
  });
}
