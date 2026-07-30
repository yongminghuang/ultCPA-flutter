import 'package:flutter/services.dart';

import 'promotion_sharing_models.dart';

abstract interface class PromotionShareGateway {
  Future<PromotionProfile> readProfile(PromotionProfile fallback);

  Future<void> saveProfile(PromotionProfile profile);

  Future<PromotionPosterPreference?> readSelectedPoster();

  Future<void> saveSelectedPoster(PromotionPoster poster);

  Future<Uint8List> createQrCode(String content, {int size = 360});

  Future<void> shareWechatImage(Uint8List pngBytes, {required bool timeline});

  Future<void> shareWechatWebpage({
    required String url,
    required String title,
    required String description,
    required bool timeline,
  });

  Future<void> saveImage(Uint8List pngBytes);
}

final class MethodChannelPromotionShareGateway
    implements PromotionShareGateway {
  MethodChannelPromotionShareGateway({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.xmzj.ult.agg/promotion_sharing';
  final MethodChannel _channel;

  @override
  Future<PromotionProfile> readProfile(PromotionProfile fallback) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'readPromotionProfile',
      {'fallbackName': fallback.name, 'fallbackPhone': fallback.phone},
    );
    return PromotionProfile(
      name: raw?['name']?.toString() ?? fallback.name,
      phone: raw?['phone']?.toString() ?? fallback.phone,
    );
  }

  @override
  Future<void> saveProfile(PromotionProfile profile) {
    return _channel.invokeMethod<void>('savePromotionProfile', {
      'name': profile.name,
      'phone': profile.phone,
    });
  }

  @override
  Future<PromotionPosterPreference?> readSelectedPoster() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'readSelectedPromotionPoster',
    );
    if (raw == null) return null;
    return PromotionPosterPreference(
      posterId: raw['posterId']?.toString() ?? '',
      templateUrl: raw['templateUrl']?.toString() ?? '',
    );
  }

  @override
  Future<void> saveSelectedPoster(PromotionPoster poster) {
    return _channel.invokeMethod<void>('saveSelectedPromotionPoster', {
      'posterId': poster.id,
      'templateUrl': poster.templateUrl,
    });
  }

  @override
  Future<Uint8List> createQrCode(String content, {int size = 360}) async {
    final bytes = await _channel.invokeMethod<Uint8List>(
      'createPromotionQrCode',
      {'content': content, 'size': size},
    );
    if (bytes == null || bytes.isEmpty) {
      throw PlatformException(code: 'qr_failed', message: '二维码生成失败');
    }
    return bytes;
  }

  @override
  Future<void> shareWechatImage(Uint8List pngBytes, {required bool timeline}) {
    return _channel.invokeMethod<void>('shareWechatImage', {
      'bytes': pngBytes,
      'timeline': timeline,
    });
  }

  @override
  Future<void> shareWechatWebpage({
    required String url,
    required String title,
    required String description,
    required bool timeline,
  }) {
    return _channel.invokeMethod<void>('shareWechatWebpage', {
      'url': url,
      'title': title,
      'description': description,
      'timeline': timeline,
    });
  }

  @override
  Future<void> saveImage(Uint8List pngBytes) {
    return _channel.invokeMethod<void>('savePromotionImage', {
      'bytes': pngBytes,
    });
  }
}
