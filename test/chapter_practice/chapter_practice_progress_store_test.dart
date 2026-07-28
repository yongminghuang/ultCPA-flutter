import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/chapter_practice/chapter_practice_progress_store.dart';
import 'package:ultcpa_flutter/src/network/method_channel_request_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(MethodChannelRequestContext.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('uses exact Android chapter progress methods and arguments', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'getChapterPracticeExpandedCatalog' => 3,
            'getChapterPracticeQuestionPosition' => 7,
            _ => null,
          };
        });
    final store = MethodChannelRequestContext();

    expect(await store.loadExpandedCatalog(moduleId: 42), 3);
    await store.saveExpandedCatalog(moduleId: 42, catalogIndex: 4);
    expect(
      await store.loadQuestionPosition(
        moduleId: 42,
        catalogIndex: 4,
        chapterIndex: 2,
      ),
      7,
    );
    await store.saveQuestionPosition(
      moduleId: 42,
      catalogIndex: 4,
      chapterIndex: 2,
      position: 8,
    );

    expect(calls.map((call) => call.method), [
      'getChapterPracticeExpandedCatalog',
      'setChapterPracticeExpandedCatalog',
      'getChapterPracticeQuestionPosition',
      'setChapterPracticeQuestionPosition',
    ]);
    expect(calls.map((call) => call.arguments), [
      {'moduleId': 42},
      {'moduleId': 42, 'catalogIndex': 4},
      {'moduleId': 42, 'catalogIndex': 4, 'chapterIndex': 2},
      {'moduleId': 42, 'catalogIndex': 4, 'chapterIndex': 2, 'position': 8},
    ]);
  });

  test('uses Android defaults when native reads return null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    final store = MethodChannelRequestContext();

    expect(await store.loadExpandedCatalog(moduleId: 42), -1);
    expect(
      await store.loadQuestionPosition(
        moduleId: 42,
        catalogIndex: 0,
        chapterIndex: 0,
      ),
      0,
    );
  });

  test('rejects invalid progress coordinates before native I/O', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    final store = MethodChannelRequestContext();

    await expectLater(
      store.loadExpandedCatalog(moduleId: 0),
      throwsArgumentError,
    );
    await expectLater(
      store.saveExpandedCatalog(moduleId: 42, catalogIndex: -1),
      throwsArgumentError,
    );
    await expectLater(
      store.saveQuestionPosition(
        moduleId: 42,
        catalogIndex: 0,
        chapterIndex: 0,
        position: -1,
      ),
      throwsArgumentError,
    );
    expect(calls, isEmpty);
  });

  test('disabled store supplies harmless deterministic defaults', () async {
    const store = DisabledChapterPracticeProgressStore();

    expect(await store.loadExpandedCatalog(moduleId: 42), -1);
    expect(
      await store.loadQuestionPosition(
        moduleId: 42,
        catalogIndex: 0,
        chapterIndex: 0,
      ),
      0,
    );
    await store.saveExpandedCatalog(moduleId: 42, catalogIndex: 0);
    await store.saveQuestionPosition(
      moduleId: 42,
      catalogIndex: 0,
      chapterIndex: 0,
      position: 0,
    );
  });
}
