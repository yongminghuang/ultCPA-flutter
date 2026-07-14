import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/migration/activity_coverage.dart';

void main() {
  test(
    'parses relative and absolute activities and ignores valid comments',
    () {
      const xml = '''
      <manifest package="com.jx885.lrjk"
          xmlns:android="http://schemas.android.com/apk/res/android">
        <application>
          <!-- <activity android:name=".DeletedCommentActivity" /> -->
          <activity android:name=".cg.ui.MainActivity" />
          <activity android:name="com.xmzj.ult.agg.wxapi.WXEntryActivity" />
        </application>
      </manifest>
    ''';

      final rows = parseActivityRegistrations(source: 'main.xml', xml: xml);

      expect(rows.map((row) => row.activityName), <String>[
        'com.jx885.lrjk.cg.ui.MainActivity',
        'com.xmzj.ult.agg.wxapi.WXEntryActivity',
      ]);
      expect(rows.first.disposition, ActivityDisposition.flutterPage);
      expect(rows.last.disposition, ActivityDisposition.pluginCallback);
    },
  );

  test('classifies approved PDF removals and SDK-owned login pages', () {
    expect(
      classifyActivity(
        'com.jx885.lrjk.cg.ui.activity.BigSkillPaperPdfListActivity',
      ),
      ActivityDisposition.removed,
    );
    expect(
      classifyActivity('com.mobile.auth.gatewayauth.LoginAuthActivity'),
      ActivityDisposition.sdkManaged,
    );
  });

  test('escapes CSV values', () {
    const row = ActivityRegistration(
      source: 'a,b.xml',
      activityName: 'com.example.Activity',
      disposition: ActivityDisposition.flutterPage,
    );
    expect(row.toCsv(), '"a,b.xml",com.example.Activity,flutterPage');
  });
}
