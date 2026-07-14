import 'dart:io';

import 'package:ultcpa_flutter/src/migration/activity_coverage.dart';

const _manifestPaths = <String>[
  'ultCPA/src/main/AndroidManifest.xml',
  'ModuleLoginAndPay/AndroidManifest.xml',
  'QnmLibrary/AndroidManifest.xml',
  'lib_http_capture/src/main/AndroidManifest.xml',
];

void main(List<String> arguments) {
  final androidRoot = _argument(arguments, '--android-root');
  final outputPath = _argument(arguments, '--out');
  if (androidRoot == null || outputPath == null) {
    stderr.writeln(
      'Usage: dart run tool/migration/source_manifest.dart '
      '--android-root <path> --out <csv>',
    );
    exitCode = 64;
    return;
  }

  final rows = <ActivityRegistration>[];
  for (final relativePath in _manifestPaths) {
    final file = File(_join(androidRoot, relativePath));
    if (!file.existsSync()) {
      stderr.writeln('Missing manifest: ${file.path}');
      exitCode = 66;
      return;
    }
    rows.addAll(
      parseActivityRegistrations(
        source: relativePath,
        xml: file.readAsStringSync(),
      ),
    );
  }
  rows.sort((left, right) => left.activityName.compareTo(right.activityName));

  final counts = <ActivityDisposition, int>{
    for (final disposition in ActivityDisposition.values) disposition: 0,
  };
  for (final row in rows) {
    counts[row.disposition] = counts[row.disposition]! + 1;
  }

  const expected = <ActivityDisposition, int>{
    ActivityDisposition.flutterPage: 69,
    ActivityDisposition.pluginCallback: 3,
    ActivityDisposition.sdkManaged: 3,
    ActivityDisposition.removed: 2,
  };
  if (rows.length != 77 ||
      expected.entries.any((entry) => counts[entry.key] != entry.value)) {
    stderr.writeln(
      'Manifest scope drift: total=${rows.length}, counts=$counts',
    );
    exitCode = 65;
    return;
  }

  final output = File(outputPath)..parent.createSync(recursive: true);
  output.writeAsStringSync(
    <String>[
      'source,activity,disposition',
      ...rows.map((row) => row.toCsv()),
      '',
    ].join('\n'),
  );
  stdout.writeln(
    'total=77 flutterPage=69 pluginCallback=3 sdkManaged=3 removed=2',
  );
}

String? _argument(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) return null;
  return arguments[index + 1];
}

String _join(String root, String relativePath) {
  final normalized = relativePath.replaceAll('/', Platform.pathSeparator);
  return '${root.replaceAll(RegExp(r'[\\/]+$'), '')}'
      '${Platform.pathSeparator}$normalized';
}
