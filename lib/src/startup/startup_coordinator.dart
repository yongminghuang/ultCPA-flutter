enum StartupPhase {
  checkingConsent,
  awaitingConsent,
  initializing,
  launchDelay,
  ready,
  failed,
  terminated,
}

abstract interface class StartupConsentStore {
  Future<bool> hasAcceptedPrivacy();

  Future<void> acceptPrivacy();
}

abstract interface class StartupPostConsentInitializer {
  Future<void> initialize();
}

typedef StartupDelay = Future<void> Function(Duration duration);

final class StartupCoordinator {
  StartupCoordinator({
    required StartupConsentStore consentStore,
    required StartupPostConsentInitializer initializer,
    required StartupDelay delay,
    void Function(StartupPhase phase)? onPhaseChanged,
  }) : _consentStore = consentStore,
       _initializer = initializer,
       _delay = delay,
       _onPhaseChanged = onPhaseChanged;

  final StartupConsentStore _consentStore;
  final StartupPostConsentInitializer _initializer;
  final StartupDelay _delay;
  final void Function(StartupPhase phase)? _onPhaseChanged;

  StartupPhase phase = StartupPhase.checkingConsent;

  Future<void> start() async {
    if (phase != StartupPhase.checkingConsent) {
      throw StateError('StartupCoordinator.start may only be called once.');
    }
    if (!await _consentStore.hasAcceptedPrivacy()) {
      _setPhase(StartupPhase.awaitingConsent);
      return;
    }
    await _initializeAfterConsent();
  }

  Future<void> acceptPrivacy() async {
    if (phase != StartupPhase.awaitingConsent) {
      throw StateError('Privacy can only be accepted while awaiting consent.');
    }
    await _consentStore.acceptPrivacy();
    await _initializeAfterConsent();
  }

  void declinePrivacy() {
    if (phase != StartupPhase.awaitingConsent) {
      throw StateError('Privacy can only be declined while awaiting consent.');
    }
    _setPhase(StartupPhase.terminated);
  }

  Future<void> retryInitialization() async {
    if (phase != StartupPhase.failed) {
      throw StateError('Initialization can only be retried after a failure.');
    }
    await _initializeAfterConsent();
  }

  Future<void> _initializeAfterConsent() async {
    _setPhase(StartupPhase.initializing);
    try {
      await _initializer.initialize();
      _setPhase(StartupPhase.launchDelay);
      await _delay(const Duration(seconds: 3));
      _setPhase(StartupPhase.ready);
    } catch (_) {
      _setPhase(StartupPhase.failed);
      rethrow;
    }
  }

  void _setPhase(StartupPhase nextPhase) {
    phase = nextPhase;
    _onPhaseChanged?.call(nextPhase);
  }
}
