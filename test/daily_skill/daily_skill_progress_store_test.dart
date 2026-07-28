import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/daily_skill/daily_skill_progress_store.dart';
import 'package:ultcpa_flutter/src/network/method_channel_request_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(MethodChannelRequestContext.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'creates new Android-shaped progress and refreshes same-day ids',
    () async {
      final persistence = _MemoryPersistence();
      final store = DailySkillProgressStore(
        persistence: persistence,
        now: () => DateTime(2026, 7, 16, 9),
      );

      final created = await store.ensureToday(
        skillId: '11',
        moduleId: 42,
        shelfId: 111,
      );
      expect(created.date, '2026-07-16');
      expect(created.skillId, '11');
      expect(created.moduleId, 42);
      expect(created.shelfId, 111);
      expect(created.answers, isEmpty);

      final raw = jsonDecode(persistence.progressJson) as Map<String, dynamic>;
      expect(
        raw.keys,
        containsAll(<String>{
          'date',
          'skillId',
          'moduleId',
          'shelfId',
          'currentIndex',
          'isFinished',
          'doneCount',
          'rightCount',
          'wrongCount',
          'questionOrder',
          'rightQuestionIds',
          'wrongQuestionIds',
          'answers',
        }),
      );

      await store.recordAnswer(
        questionId: 101,
        choose: 'A',
        isRight: true,
        currentIndex: 0,
        questionOrder: const [101, 102],
      );
      final refreshed = await store.ensureToday(
        skillId: '12',
        moduleId: 43,
        shelfId: 112,
      );
      expect(refreshed.skillId, '12');
      expect(refreshed.moduleId, 43);
      expect(refreshed.shelfId, 112);
      expect(refreshed.answers, contains(101));
    },
  );

  test('resets progress on a new local calendar date', () async {
    var now = DateTime(2026, 7, 16, 23, 59);
    final store = DailySkillProgressStore(
      persistence: _MemoryPersistence(),
      now: () => now,
    );
    await store.ensureToday(skillId: '11', moduleId: 42, shelfId: 111);
    await store.recordAnswer(
      questionId: 101,
      choose: 'B',
      isRight: false,
      currentIndex: 0,
      questionOrder: const [101],
    );

    now = DateTime(2026, 7, 17);
    final next = await store.ensureToday(
      skillId: '21',
      moduleId: 52,
      shelfId: 121,
    );

    expect(next.date, '2026-07-17');
    expect(next.skillId, '21');
    expect(next.answers, isEmpty);
    expect(next.isFinished, isFalse);
  });

  test('parses Android JSON and clears corrupt progress', () async {
    final persistence = _MemoryPersistence(
      progressJson: jsonEncode({
        'date': '2026-07-16',
        'skillId': '11',
        'moduleId': 42,
        'shelfId': 111,
        'currentIndex': 1,
        'isFinished': false,
        'doneCount': 2,
        'rightCount': 1,
        'wrongCount': 1,
        'questionOrder': [101, 102, 103],
        'rightQuestionIds': [101],
        'wrongQuestionIds': [102],
        'answers': {
          '101': {'pick': 1, 'isRight': true, 'timestamp': 10},
          '102': {'pick': 5, 'isRight': false, 'timestamp': 20},
        },
      }),
    );
    final store = DailySkillProgressStore(
      persistence: persistence,
      now: () => DateTime(2026, 7, 16),
    );

    final progress = await store.loadToday();
    expect(progress?.questionOrder, [101, 102, 103]);
    expect(progress?.answers[101]?.choose, 'A');
    expect(progress?.answers[102]?.choose, 'AC');
    expect(progress?.rightCount, 1);
    expect(progress?.wrongCount, 1);

    persistence.progressJson = '{broken';
    expect(await store.loadToday(), isNull);
    expect(persistence.progressJson, isEmpty);
  });

  test('records and replaces answers with exact counts and order', () async {
    var now = DateTime(2026, 7, 16, 10);
    final store = DailySkillProgressStore(
      persistence: _MemoryPersistence(),
      now: () => now,
    );
    await store.ensureToday(skillId: '11', moduleId: 42, shelfId: 111);

    await store.recordAnswer(
      questionId: 101,
      choose: 'AC',
      isRight: false,
      currentIndex: 1,
      questionOrder: const [101, 102],
    );
    now = DateTime(2026, 7, 16, 10, 1);
    await store.recordAnswer(
      questionId: 102,
      choose: 'B',
      isRight: true,
      currentIndex: 1,
      questionOrder: const [101, 102],
    );
    await store.recordAnswer(
      questionId: 101,
      choose: 'A',
      isRight: true,
      currentIndex: 0,
      questionOrder: const [101, 102],
    );

    final progress = (await store.loadToday())!;
    expect(progress.doneCount, 2);
    expect(progress.rightCount, 2);
    expect(progress.wrongCount, 0);
    expect(progress.rightQuestionIds, [102, 101]);
    expect(progress.wrongQuestionIds, isEmpty);
    expect(progress.answers[101]?.pick, 1);
    expect(progress.answers[101]?.isRight, isTrue);
    expect(progress.currentIndex, 0);
    expect(progress.questionOrder, [101, 102]);
  });

  test('persists order and resolves Android first-unanswered resume', () async {
    final store = DailySkillProgressStore(
      persistence: _MemoryPersistence(),
      now: () => DateTime(2026, 7, 16),
    );
    var progress = await store.ensureToday(
      skillId: '11',
      moduleId: 42,
      shelfId: 111,
    );
    expect(progress.resolveResumeIndex(const [101, 102, 103]), 0);

    await store.persistQuestionOrder(const [101, 102, 103]);
    await store.recordAnswer(
      questionId: 101,
      choose: 'A',
      isRight: true,
      currentIndex: 0,
      questionOrder: const [101, 102, 103],
    );
    await store.recordAnswer(
      questionId: 103,
      choose: 'B',
      isRight: false,
      currentIndex: 2,
      questionOrder: const [101, 102, 103],
    );
    progress = (await store.loadToday())!;
    expect(progress.resolveResumeIndex(progress.questionOrder), 1);

    await store.recordAnswer(
      questionId: 102,
      choose: 'A',
      isRight: true,
      currentIndex: 1,
      questionOrder: const [101, 102, 103],
    );
    progress = (await store.loadToday())!;
    expect(progress.resolveResumeIndex(progress.questionOrder), 2);
  });

  test(
    'marks completion idempotently and retry preserves check-in days',
    () async {
      final persistence = _MemoryPersistence();
      final store = DailySkillProgressStore(
        persistence: persistence,
        now: () => DateTime(2026, 7, 16),
      );
      await store.ensureToday(skillId: '11', moduleId: 42, shelfId: 111);

      await store.markFinished(true);
      await store.markFinished(true);
      expect((await store.loadToday())?.isFinished, isTrue);
      expect(await store.completedDaysCount(), 1);
      expect((jsonDecode(persistence.checkInJson) as Map)['completedDates'], [
        '2026-07-16',
      ]);

      await store.clear();
      expect(await store.loadToday(), isNull);
      expect(await store.completedDaysCount(), 1);
    },
  );

  test('disabled store returns deterministic harmless state', () async {
    const store = DisabledDailySkillProgressStore();

    expect(await store.loadToday(), isNull);
    expect(
      (await store.ensureToday(
        skillId: '11',
        moduleId: 42,
        shelfId: 111,
      )).skillId,
      '11',
    );
    expect(await store.completedDaysCount(), 0);
    await store.persistQuestionOrder(const [101]);
    await store.recordAnswer(
      questionId: 101,
      choose: 'A',
      isRight: true,
      currentIndex: 0,
      questionOrder: const [101],
    );
    await store.markFinished(true);
    await store.clear();
  });

  test('uses exact daily progress raw-JSON MethodChannel contracts', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'readDailySkillProgressJson' => '{"date":"2026-07-16"}',
            'readDailySkillCheckInJson' => '{"completedDates":["2026-07-16"]}',
            _ => null,
          };
        });
    final persistence = MethodChannelRequestContext();

    expect(
      await persistence.readDailySkillProgressJson(),
      '{"date":"2026-07-16"}',
    );
    await persistence.writeDailySkillProgressJson('{"skillId":"11"}');
    expect(
      await persistence.readDailySkillCheckInJson(),
      '{"completedDates":["2026-07-16"]}',
    );
    await persistence.writeDailySkillCheckInJson(
      '{"completedDates":["2026-07-16","2026-07-17"]}',
    );

    expect(calls.map((call) => call.method), [
      'readDailySkillProgressJson',
      'writeDailySkillProgressJson',
      'readDailySkillCheckInJson',
      'writeDailySkillCheckInJson',
    ]);
    expect(calls.map((call) => call.arguments), [
      null,
      {'json': '{"skillId":"11"}'},
      null,
      {'json': '{"completedDates":["2026-07-16","2026-07-17"]}'},
    ]);
  });

  test('uses empty JSON defaults when native reads return null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    final persistence = MethodChannelRequestContext();

    expect(await persistence.readDailySkillProgressJson(), isEmpty);
    expect(await persistence.readDailySkillCheckInJson(), isEmpty);
  });
}

final class _MemoryPersistence implements DailySkillProgressPersistence {
  _MemoryPersistence({this.progressJson = ''});

  String progressJson;
  String checkInJson = '';

  @override
  Future<String> readDailySkillProgressJson() async => progressJson;

  @override
  Future<void> writeDailySkillProgressJson(String json) async {
    progressJson = json;
  }

  @override
  Future<String> readDailySkillCheckInJson() async => checkInJson;

  @override
  Future<void> writeDailySkillCheckInJson(String json) async {
    checkInJson = json;
  }
}
