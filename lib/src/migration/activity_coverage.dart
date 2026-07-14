enum ActivityDisposition { flutterPage, pluginCallback, sdkManaged, removed }

final class ActivityRegistration {
  const ActivityRegistration({
    required this.source,
    required this.activityName,
    required this.disposition,
  });

  final String source;
  final String activityName;
  final ActivityDisposition disposition;

  String toCsv() =>
      <String>[_csv(source), _csv(activityName), disposition.name].join(',');
}

const _removed = <String>{
  'com.jx885.lrjk.cg.ui.activity.BigSkillPaperPdfListActivity',
  'com.jx885.lrjk.cg.ui.activity.BigSkillPaperPdfListEntryActivity',
};

const _pluginCallbacks = <String>{
  'com.jx885.lrjk.cg.ui.BackFromAlipayActivity',
  'com.xmzj.ult.agg.wxapi.WXEntryActivity',
  'com.xmzj.ult.agg.wxapi.WXPayEntryActivity',
};

const _sdkManaged = <String>{
  'com.mobile.auth.gatewayauth.LoginAuthActivity',
  'com.mobile.auth.gatewayauth.activity.AuthWebVeiwActivity',
  'com.cmic.sso.sdk.activity.LoginAuthActivity',
};

ActivityDisposition classifyActivity(String activityName) {
  if (_removed.contains(activityName)) return ActivityDisposition.removed;
  if (_pluginCallbacks.contains(activityName)) {
    return ActivityDisposition.pluginCallback;
  }
  if (_sdkManaged.contains(activityName)) {
    return ActivityDisposition.sdkManaged;
  }
  return ActivityDisposition.flutterPage;
}

List<ActivityRegistration> parseActivityRegistrations({
  required String source,
  required String xml,
}) {
  final withoutValidComments = xml.replaceAll(
    RegExp(r'<!--[\s\S]*?-->', multiLine: true),
    '',
  );
  final packageMatch = RegExp(
    r'package\s*=\s*"([^"]+)"',
  ).firstMatch(withoutValidComments);
  final packageName = packageMatch?.group(1) ?? '';
  final activityPattern = RegExp(
    r'<activity(?=\s)[\s\S]*?android:name\s*=\s*"([^"]+)"',
    multiLine: true,
  );

  return activityPattern
      .allMatches(withoutValidComments)
      .map((match) {
        final rawName = match.group(1)!;
        final fullName = switch (rawName) {
          final name when name.startsWith('.') => '$packageName$name',
          final name when name.contains('.') => name,
          final name => '$packageName.$name',
        };
        return ActivityRegistration(
          source: source,
          activityName: fullName,
          disposition: classifyActivity(fullName),
        );
      })
      .toList(growable: false);
}

String _csv(String value) {
  if (!value.contains(RegExp('[,"\\n\\r]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}
