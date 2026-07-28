import '../main_tabs/main_tabs_models.dart';

const pastExamFreePaperCount = 2;

final class PastExamPaper {
  const PastExamPaper({
    required this.id,
    required this.name,
    required this.type,
    required this.locked,
  });

  final int id;
  final String name;
  final String type;
  final bool locked;
}

final class PastExamsCatalog {
  PastExamsCatalog({
    required this.module,
    required List<PastExamPaper> papers,
    required this.hasFullAccess,
  }) : papers = List<PastExamPaper>.unmodifiable(papers);

  final HomeModule module;
  final List<PastExamPaper> papers;
  final bool hasFullAccess;
}

List<PastExamPaper> parsePastExamPapers(
  Object? body, {
  required bool hasFullAccess,
}) {
  if (body is! List) {
    throw const FormatException('历年真题书架树 body 不是数组');
  }
  final papers = <PastExamPaper>[];
  for (final rawNode in body) {
    if (rawNode is! Map) {
      throw const FormatException('历年真题书架节点不是对象');
    }
    final node = Map<String, dynamic>.from(rawNode);
    final type = _text(node['type']).trim();
    if (type != '扁平化') continue;
    final id = _integer(node['id']);
    final name = _text(node['name']).trim();
    if (id <= 0 || name.isEmpty) continue;
    papers.add(
      PastExamPaper(
        id: id,
        name: name,
        type: type,
        locked: !hasFullAccess && papers.length >= pastExamFreePaperCount,
      ),
    );
  }
  return List<PastExamPaper>.unmodifiable(papers);
}

String _text(Object? value) {
  if (value == null) return '';
  final text = value.toString();
  return text.trim().toLowerCase() == 'null' ? '' : text;
}

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
