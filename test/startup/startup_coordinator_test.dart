import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/startup/startup_coordinator.dart';

void main() {
  test('waits for privacy consent without initializing services', () async {
    final events = <String>[];
    final coordinator = StartupCoordinator(
      consentStore: _MemoryConsentStore(accepted: false, events: events),
      initializer: _RecordingInitializer(events),
      delay: (duration) async => events.add('delay:$duration'),
    );

    await coordinator.start();

    expect(coordinator.phase, StartupPhase.awaitingConsent);
    expect(events, <String>['read-consent']);
  });

  test('persists acceptance before initialization and launch delay', () async {
    final events = <String>[];
    final coordinator = StartupCoordinator(
      consentStore: _MemoryConsentStore(accepted: false, events: events),
      initializer: _RecordingInitializer(events),
      delay: (duration) async => events.add('delay:$duration'),
    );
    await coordinator.start();

    await coordinator.acceptPrivacy();

    expect(coordinator.phase, StartupPhase.ready);
    expect(events, <String>[
      'read-consent',
      'write-consent',
      'initialize',
      'delay:0:00:03.000000',
    ]);
  });

  test(
    'existing consent starts post-consent initialization directly',
    () async {
      final events = <String>[];
      final phases = <StartupPhase>[];
      final coordinator = StartupCoordinator(
        consentStore: _MemoryConsentStore(accepted: true, events: events),
        initializer: _RecordingInitializer(events),
        delay: (duration) async => events.add('delay:$duration'),
        onPhaseChanged: phases.add,
      );

      await coordinator.start();

      expect(coordinator.phase, StartupPhase.ready);
      expect(events, <String>[
        'read-consent',
        'initialize',
        'delay:0:00:03.000000',
      ]);
      expect(phases, <StartupPhase>[
        StartupPhase.initializing,
        StartupPhase.launchDelay,
        StartupPhase.ready,
      ]);
    },
  );

  test('failed initialization can be retried', () async {
    final initializer = _FailOnceInitializer();
    final coordinator = StartupCoordinator(
      consentStore: _MemoryConsentStore(accepted: true, events: []),
      initializer: initializer,
      delay: (_) async {},
    );

    await expectLater(coordinator.start(), throwsStateError);
    expect(coordinator.phase, StartupPhase.failed);

    await coordinator.retryInitialization();

    expect(initializer.calls, 2);
    expect(coordinator.phase, StartupPhase.ready);
  });

  test('declining consent terminates without initialization', () async {
    final events = <String>[];
    final coordinator = StartupCoordinator(
      consentStore: _MemoryConsentStore(accepted: false, events: events),
      initializer: _RecordingInitializer(events),
      delay: (duration) async => events.add('delay:$duration'),
    );
    await coordinator.start();

    coordinator.declinePrivacy();

    expect(coordinator.phase, StartupPhase.terminated);
    expect(events, <String>['read-consent']);
  });
}

final class _MemoryConsentStore implements StartupConsentStore {
  _MemoryConsentStore({required this.accepted, required this.events});

  bool accepted;
  final List<String> events;

  @override
  Future<bool> hasAcceptedPrivacy() async {
    events.add('read-consent');
    return accepted;
  }

  @override
  Future<void> acceptPrivacy() async {
    events.add('write-consent');
    accepted = true;
  }
}

final class _RecordingInitializer implements StartupPostConsentInitializer {
  _RecordingInitializer(this.events);

  final List<String> events;

  @override
  Future<void> initialize() async {
    events.add('initialize');
  }
}

final class _FailOnceInitializer implements StartupPostConsentInitializer {
  int calls = 0;

  @override
  Future<void> initialize() async {
    calls += 1;
    if (calls == 1) throw StateError('network unavailable');
  }
}
