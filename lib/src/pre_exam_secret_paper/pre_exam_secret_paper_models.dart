import '../main_tabs/main_tabs_models.dart';

final class PreExamSecretPaper {
  const PreExamSecretPaper({required this.id, required this.name});

  final int id;
  final String name;
}

final class PreExamSecretPaperCatalog {
  PreExamSecretPaperCatalog({
    required this.module,
    required List<PreExamSecretPaper> papers,
    required this.isVip,
  }) : papers = List<PreExamSecretPaper>.unmodifiable(papers);

  final HomeModule module;
  final List<PreExamSecretPaper> papers;
  final bool isVip;
}

final class PreExamSecretPaperCardCopy {
  const PreExamSecretPaperCardCopy({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}

const preExamSecretPaperCardCopies = <PreExamSecretPaperCardCopy>[
  PreExamSecretPaperCardCopy(
    title: '密卷A: 新规智能预测卷',
    description: '动态追踪政策变化, AI预测重点考题',
  ),
  PreExamSecretPaperCardCopy(
    title: '密卷B: 单元强化提分卷',
    description: '针对性强化训练, 快速提升薄弱模块',
  ),
  PreExamSecretPaperCardCopy(
    title: '密卷C: 高频易错冲刺卷',
    description: '直击历年失分率最高题型, 考前精准加固',
  ),
];

List<PreExamSecretPaper> parsePreExamSecretPapers(Object? body) {
  if (body is! List) {
    throw const FormatException('最后密押卷书架树 body 不是数组');
  }
  final papers = <PreExamSecretPaper>[];
  for (final rawNode in body) {
    _collectLeafPapers(rawNode, papers);
  }
  return List<PreExamSecretPaper>.unmodifiable(papers);
}

void _collectLeafPapers(Object? rawNode, List<PreExamSecretPaper> papers) {
  if (rawNode is! Map) return;
  final node = Map<String, dynamic>.from(rawNode);
  final rawChildren = node['children'];
  if (rawChildren != null && rawChildren is! List) {
    throw const FormatException('最后密押卷书架节点 children 不是数组');
  }
  final children = rawChildren as List?;
  if (children != null && children.isNotEmpty) {
    for (final child in children) {
      _collectLeafPapers(child, papers);
    }
    return;
  }
  final id = _integer(node['id']);
  final name = _text(node['name']).trim();
  if (id <= 0 || name.isEmpty) return;
  papers.add(PreExamSecretPaper(id: id, name: name));
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
