import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/pre_exam_six_paper/pre_exam_six_paper_models.dart';

void main() {
  test('parses only the first file record and every direct field', () {
    final file = parsePreExamSixPaperFileBody(const {
      'records': [
        {
          'type': '文件',
          'name': '考前重点.pdf',
          'text': '<p>重点</p>',
          'textUrl': 'https://example.com/preview',
          'fileUrl': '/papers/key.pdf',
        },
        {'type': '文件', 'name': '不应读取'},
      ],
    });

    expect(file?.name, '考前重点.pdf');
    expect(file?.text, '<p>重点</p>');
    expect(file?.textUrl, 'https://example.com/preview');
    expect(file?.fileUrl, '/papers/key.pdf');
  });

  test('falls back to extend text and tolerates decoded extend maps', () {
    final encoded = parsePreExamSixPaperFileBody(const {
      'records': [
        {
          'type': '文件',
          'text': '',
          'extend': '{"text":"<strong>encoded</strong>"}',
        },
      ],
    });
    final decoded = parsePreExamSixPaperFileBody(const {
      'records': [
        {
          'type': '文件',
          'extend': {'text': '<p>decoded</p>'},
        },
      ],
    });

    expect(encoded?.text, '<strong>encoded</strong>');
    expect(decoded?.text, '<p>decoded</p>');
  });

  test('returns null for absent or non-file first records', () {
    expect(parsePreExamSixPaperFileBody(null), isNull);
    expect(parsePreExamSixPaperFileBody(const {'records': []}), isNull);
    expect(
      parsePreExamSixPaperFileBody(const {
        'records': [
          {'type': '题目'},
          {'type': '文件', 'name': '第二条'},
        ],
      }),
      isNull,
    );
  });

  test('rejects malformed page containers', () {
    expect(() => parsePreExamSixPaperFileBody(const []), throwsFormatException);
    expect(
      () => parsePreExamSixPaperFileBody(const {'records': 'bad'}),
      throwsFormatException,
    );
  });

  test('defines immutable landing preview unavailable and empty entries', () {
    const file = PreExamSixPaperFile(
      name: '六页纸',
      text: '',
      textUrl: '',
      fileUrl: '',
      htmlBaseUrl: 'https://file.xmzhujing.com/',
    );
    const values = [
      PreExamSixPaperEntry(PreExamSixPaperEntryDestination.landing),
      PreExamSixPaperEntry(PreExamSixPaperEntryDestination.preview, file: file),
      PreExamSixPaperEntry(PreExamSixPaperEntryDestination.unavailable),
      PreExamSixPaperEntry(PreExamSixPaperEntryDestination.empty),
    ];

    expect(
      values.map((value) => value.destination),
      PreExamSixPaperEntryDestination.values,
    );
    expect(values[1].file, same(file));
  });

  test('limits Android titles to ten characters plus two dots', () {
    expect(limitPreExamSixPaperTitle(''), '考前6页纸');
    expect(limitPreExamSixPaperTitle('1234567890'), '1234567890');
    expect(limitPreExamSixPaperTitle('12345678901'), '1234567890..');
  });

  test('resolves relative URLs with persisted and fallback OSS origins', () {
    expect(
      resolvePreExamSixPaperUrl(
        '/papers/key.pdf',
        ossDomain: 'https://cdn.example.com/base/',
      ),
      'https://cdn.example.com/base/papers/key.pdf',
    );
    expect(
      resolvePreExamSixPaperUrl('papers/key.pdf', ossDomain: ''),
      'https://file.xmzhujing.com/papers/key.pdf',
    );
    expect(
      resolvePreExamSixPaperUrl(
        'https://other.example/key.pdf',
        ossDomain: 'https://cdn.example.com',
      ),
      'https://other.example/key.pdf',
    );
  });

  test('wraps rich HTML and resolves relative image sources', () {
    final html = buildPreExamSixPaperHtml(
      '<p>重点<img src="images/a.png"></p>',
      ossDomain: 'https://cdn.example.com/root/',
    );

    expect(html, contains("<meta name='viewport'"));
    expect(html, contains('class=\'content\''));
    expect(html, contains('src="https://cdn.example.com/root/images/a.png"'));
    expect(html, contains('<p>重点'));
    expect(buildPreExamSixPaperHtml('', ossDomain: ''), contains('题库更新中'));
  });

  test('builds sanitized Android download names and URL suffixes', () {
    const file = PreExamSixPaperFile(
      name: '考前/重点',
      text: '',
      textUrl: '',
      fileUrl: 'https://example.com/files/key.pdf?token=1',
      htmlBaseUrl: 'https://file.xmzhujing.com/',
    );
    const named = PreExamSixPaperFile(
      name: '已命名.docx',
      text: '',
      textUrl: '',
      fileUrl: 'https://example.com/key.pdf',
      htmlBaseUrl: 'https://file.xmzhujing.com/',
    );
    final now = DateTime(2026, 7, 17, 8, 30);
    const unnamed = PreExamSixPaperFile(
      name: '',
      text: '',
      textUrl: '',
      fileUrl: 'https://example.com/no-extension',
      htmlBaseUrl: 'https://file.xmzhujing.com/',
    );

    expect(preExamSixPaperDownloadFileName(file, now: () => now), '考前_重点.pdf');
    expect(preExamSixPaperDownloadFileName(named, now: () => now), '已命名.docx');
    expect(
      preExamSixPaperDownloadFileName(unnamed, now: () => now),
      'pre_exam_six_paper_${now.millisecondsSinceEpoch}.pdf',
    );
  });

  test('selects the Android share MIME from the completed path', () {
    expect(preExamSixPaperShareMimeType('FILE.PDF'), 'application/pdf');
    expect(preExamSixPaperShareMimeType('notes.docx'), '*/*');
    expect(preExamSixPaperShareMimeType(''), '*/*');
  });
}
