import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/network/method_channel_request_context.dart';
import 'package:ultcpa_flutter/src/practice/flat_practice_progress_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(MethodChannelRequestContext.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('uses exact Android flat position methods and arguments', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'getFlatPracticeQuestionPosition' ? 7 : null;
        });
    final store = MethodChannelRequestContext();

    expect(await store.loadFlatQuestionPosition(shelfId: 111), 7);
    await store.saveFlatQuestionPosition(shelfId: 111, position: 8);

    expect(calls.map((call) => call.method), [
      'getFlatPracticeQuestionPosition',
      'setFlatPracticeQuestionPosition',
    ]);
    expect(calls.map((call) => call.arguments), [
      {'shelfId': 111},
      {'shelfId': 111, 'position': 8},
    ]);
  });

  test('uses Android zero default when native read returns null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    expect(
      await MethodChannelRequestContext().loadFlatQuestionPosition(
        shelfId: 111,
      ),
      0,
    );
  });

  test('rejects invalid shelf and position before native I/O', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    final store = MethodChannelRequestContext();

    await expectLater(
      store.loadFlatQuestionPosition(shelfId: 0),
      throwsArgumentError,
    );
    await expectLater(
      store.saveFlatQuestionPosition(shelfId: -1, position: 0),
      throwsArgumentError,
    );
    await expectLater(
      store.saveFlatQuestionPosition(shelfId: 111, position: -1),
      throwsArgumentError,
    );
    expect(calls, isEmpty);
  });

  test('disabled store supplies harmless deterministic defaults', () async {
    const store = DisabledFlatPracticeProgressStore();

    expect(await store.loadFlatQuestionPosition(shelfId: 111), 0);
    await store.saveFlatQuestionPosition(shelfId: 111, position: 0);
  });
}
