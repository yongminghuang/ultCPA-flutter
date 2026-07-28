enum AppUpdateTarget { applicationMarket, externalUrl, apkDownload }

sealed class AppUpdateCheckResult {
  const AppUpdateCheckResult();
}

final class AppUpdateLatest extends AppUpdateCheckResult {
  const AppUpdateLatest();
}

final class AppUpdateAvailable extends AppUpdateCheckResult {
  const AppUpdateAvailable(this.info);

  final AppUpdateInfo info;
}

final class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.description,
    required this.isForceUpdate,
    required this.rawUrl,
    required this.ossDomain,
  });

  final String latestVersion;
  final String description;
  final bool isForceUpdate;
  final String rawUrl;
  final String ossDomain;

  AppUpdateTarget get target {
    if (rawUrl.isEmpty) return AppUpdateTarget.applicationMarket;
    if (rawUrl.contains('app.qq.com') ||
        rawUrl.contains('fir.im/') ||
        rawUrl.contains('myapp.com')) {
      return AppUpdateTarget.externalUrl;
    }
    final path = Uri.tryParse(rawUrl)?.path ?? '';
    if (path.toLowerCase().endsWith('.apk')) {
      return AppUpdateTarget.apkDownload;
    }
    return AppUpdateTarget.applicationMarket;
  }

  String get downloadUrl =>
      resolveAppUpdateDownloadUrl(rawUrl, ossDomain: ossDomain);
}

AppUpdateCheckResult parseAppUpdateCheckBody(
  Object? body, {
  required String ossDomain,
}) {
  if (body is! Map) throw const FormatException('版本更新响应不是对象');
  final map = Map<String, dynamic>.from(body);
  final shouldUpdate = _boolean(map['isUpdatePrompt']);
  if (shouldUpdate == null) {
    throw const FormatException('版本更新标志无效');
  }
  if (!shouldUpdate) return const AppUpdateLatest();

  final force = _boolean(map['isForceUpdates']);
  if (map.containsKey('isForceUpdates') && force == null) {
    throw const FormatException('强制更新标志无效');
  }
  return AppUpdateAvailable(
    AppUpdateInfo(
      latestVersion: _text(map['version']),
      description: _text(map['updateDescription']),
      isForceUpdate: force ?? false,
      rawUrl: _text(map['url']),
      ossDomain: ossDomain,
    ),
  );
}

String resolveAppUpdateDownloadUrl(String url, {required String ossDomain}) {
  if (url.isEmpty || url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }
  var domain = ossDomain.isEmpty ? 'https://file.xmzhujing.com/' : ossDomain;
  if (!domain.endsWith('/')) domain = '$domain/';
  final path = url.startsWith('/') ? url.substring(1) : url;
  return '$domain$path';
}

bool? _boolean(Object? value) => switch (value) {
  bool flag => flag,
  int number when number == 1 => true,
  int number when number == 0 => false,
  String text when text.toLowerCase() == 'true' || text == '1' => true,
  String text when text.toLowerCase() == 'false' || text == '0' => false,
  _ => null,
};

String _text(Object? value) => value?.toString() ?? '';
