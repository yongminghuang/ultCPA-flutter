import 'dart:convert';

const preExamSixPaperFallbackOssOrigin = 'https://file.xmzhujing.com/';

enum PreExamSixPaperEntryDestination { landing, preview, unavailable, empty }

final class PreExamSixPaperEntry {
  const PreExamSixPaperEntry(this.destination, {this.file});

  final PreExamSixPaperEntryDestination destination;
  final PreExamSixPaperFile? file;
}

final class PreExamSixPaperFile {
  const PreExamSixPaperFile({
    required this.name,
    required this.text,
    required this.textUrl,
    required this.fileUrl,
    required this.htmlBaseUrl,
  });

  final String name;
  final String text;
  final String textUrl;
  final String fileUrl;
  final String htmlBaseUrl;
}

PreExamSixPaperFile? parsePreExamSixPaperFileBody(Object? body) {
  if (body == null) return null;
  if (body is! Map) {
    throw const FormatException('考前6页纸响应 body 不是对象');
  }
  final map = Map<String, dynamic>.from(body);
  final rawRecords = map['records'];
  if (rawRecords != null && rawRecords is! List) {
    throw const FormatException('考前6页纸响应 records 不是数组');
  }
  final records = rawRecords as List? ?? const <Object?>[];
  if (records.isEmpty || records.first is! Map) return null;
  final record = Map<String, dynamic>.from(records.first as Map);
  if (_text(record['type']).trim() != '文件') return null;

  var text = _text(record['text']);
  if (text.trim().isEmpty) {
    text = _extendText(record['extend']);
  }
  return PreExamSixPaperFile(
    name: _text(record['name']),
    text: text,
    textUrl: _text(record['textUrl']),
    fileUrl: _text(record['fileUrl']),
    htmlBaseUrl: preExamSixPaperFallbackOssOrigin,
  );
}

String limitPreExamSixPaperTitle(String title, {int maxChars = 10}) {
  final normalized = title.trim().isEmpty ? '考前6页纸' : title.trim();
  if (maxChars <= 0 || normalized.length <= maxChars) return normalized;
  return '${normalized.substring(0, maxChars)}..';
}

String resolvePreExamSixPaperUrl(String value, {required String ossDomain}) {
  final path = value.trim();
  if (path.isEmpty) return '';
  final uri = Uri.tryParse(path);
  if (uri?.hasScheme == true) return path;
  final origin = preExamSixPaperOssOrigin(ossDomain);
  return '$origin${path.replaceFirst(RegExp(r'^/+'), '')}';
}

String preExamSixPaperOssOrigin(String rawDomain) {
  final domain = rawDomain.trim();
  final uri = Uri.tryParse(domain);
  if (domain.isEmpty ||
      uri == null ||
      !uri.hasScheme ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return preExamSixPaperFallbackOssOrigin;
  }
  return '${domain.replaceFirst(RegExp(r'/+$'), '')}/';
}

String buildPreExamSixPaperHtml(String content, {required String ossDomain}) {
  final normalized = content.trim().isEmpty
      ? '<div class=\'empty-text\'>题库更新中</div>'
      : _resolveImageSources(content, ossDomain);
  return "<html><head>"
      "<meta name='viewport' content='width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'>"
      "<style>"
      "html,body{width:100%;max-width:100%;overflow-x:hidden;margin:0;padding:0;background:#fff;}"
      "*,*::before,*::after{box-sizing:border-box;}"
      ".content{padding:12px;font-size:15px;line-height:1.8;color:#333;word-break:break-word;}"
      ".empty-text{min-height:70vh;display:flex;align-items:center;justify-content:center;color:#999;font-size:14px;}"
      "p{margin:8px 0;}strong{font-weight:bold;}img{max-width:100%!important;height:auto!important;}"
      "table{max-width:100%!important;width:auto!important;}pre{white-space:pre-wrap;word-wrap:break-word;}"
      "</style></head><body><div class='content'>$normalized</div></body></html>";
}

String preExamSixPaperDownloadFileName(
  PreExamSixPaperFile file, {
  DateTime Function()? now,
}) {
  final suffix = _urlFileSuffix(file.fileUrl);
  final base = file.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  if (base.isEmpty) {
    final timestamp = (now ?? DateTime.now)().millisecondsSinceEpoch;
    return 'pre_exam_six_paper_$timestamp$suffix';
  }
  final dot = base.lastIndexOf('.');
  final hasExtension = dot > 0 && dot < base.length - 1;
  return hasExtension ? base : '$base$suffix';
}

String preExamSixPaperShareMimeType(String filePath) {
  return filePath.trim().toLowerCase().endsWith('.pdf')
      ? 'application/pdf'
      : '*/*';
}

String _extendText(Object? rawExtend) {
  if (rawExtend is Map) {
    return _text(rawExtend['text']);
  }
  final value = _text(rawExtend).trim();
  if (value.isEmpty) return '';
  try {
    final decoded = jsonDecode(value);
    return decoded is Map ? _text(decoded['text']) : '';
  } on FormatException {
    return '';
  }
}

String _resolveImageSources(String html, String ossDomain) {
  final pattern = RegExp(
    r'''(<img\b[^>]*?\bsrc\s*=\s*)(['"])(.*?)\2''',
    caseSensitive: false,
  );
  return html.replaceAllMapped(pattern, (match) {
    final source = match.group(3) ?? '';
    final lower = source.trim().toLowerCase();
    final resolvable =
        lower.isNotEmpty &&
        !lower.startsWith('http://') &&
        !lower.startsWith('https://') &&
        !lower.startsWith('data:') &&
        !lower.startsWith('file:') &&
        !lower.startsWith('content:');
    final resolved = resolvable
        ? resolvePreExamSixPaperUrl(source, ossDomain: ossDomain)
        : source;
    return '${match.group(1)}${match.group(2)}$resolved${match.group(2)}';
  });
}

String _urlFileSuffix(String value) {
  try {
    final uri = Uri.parse(value.trim());
    final segment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final dot = segment.lastIndexOf('.');
    if (dot >= 0 && dot < segment.length - 1) {
      return segment.substring(dot);
    }
  } on FormatException {
    // Android falls back to PDF for malformed or extensionless URLs.
  }
  return '.pdf';
}

String _text(Object? value) {
  if (value == null) return '';
  final text = value.toString();
  return text.trim().toLowerCase() == 'null' ? '' : text;
}
