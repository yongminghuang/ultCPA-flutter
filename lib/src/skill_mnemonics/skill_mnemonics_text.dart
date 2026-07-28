import 'package:flutter/material.dart';

final class SkillMnemonicHighlightedText extends StatelessWidget {
  const SkillMnemonicHighlightedText({
    required this.text,
    required this.terms,
    required this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.textAlign = TextAlign.start,
    super.key,
  });

  final String text;
  final List<String> terms;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      text: TextSpan(
        style: style,
        children: skillMnemonicHighlightedSpans(text, terms),
      ),
    );
  }
}

List<TextSpan> skillMnemonicHighlightedSpans(String text, List<String> terms) {
  if (text.isEmpty || terms.isEmpty) return [TextSpan(text: text)];
  final spans = <TextSpan>[];
  var cursor = 0;
  while (cursor < text.length) {
    var nextIndex = -1;
    var nextTerm = '';
    for (final term in terms) {
      final index = text.indexOf(term, cursor);
      if (index >= 0 &&
          (nextIndex < 0 ||
              index < nextIndex ||
              (index == nextIndex && term.length > nextTerm.length))) {
        nextIndex = index;
        nextTerm = term;
      }
    }
    if (nextIndex < 0) {
      spans.add(TextSpan(text: text.substring(cursor)));
      break;
    }
    if (nextIndex > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, nextIndex)));
    }
    spans.add(
      TextSpan(
        text: nextTerm,
        style: const TextStyle(
          color: Color(0xFFFF2200),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    cursor = nextIndex + nextTerm.length;
  }
  return spans;
}
