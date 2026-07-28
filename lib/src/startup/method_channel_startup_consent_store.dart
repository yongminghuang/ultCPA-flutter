import 'package:flutter/services.dart';

import 'startup_coordinator.dart';
import 'privacy_consent_dialog.dart';

final class MethodChannelStartupConsentStore implements StartupConsentStore {
  MethodChannelStartupConsentStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.xmzj.ult.agg/legacy_startup';

  final MethodChannel _channel;

  @override
  Future<bool> hasAcceptedPrivacy() async {
    return await _channel.invokeMethod<bool>('hasAcceptedPrivacy') ?? false;
  }

  @override
  Future<void> acceptPrivacy() {
    return _channel.invokeMethod<void>('acceptPrivacy');
  }
}

final class MethodChannelAgreementOpener {
  MethodChannelAgreementOpener({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel(MethodChannelStartupConsentStore.channelName);

  final MethodChannel _channel;

  Future<void> open(AgreementDocument document) {
    return _channel.invokeMethod<void>('openAgreement', {
      'url': document.uri.toString(),
    });
  }
}
