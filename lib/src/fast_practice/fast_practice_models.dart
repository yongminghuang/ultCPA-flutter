import '../main_tabs/main_tabs_models.dart';

enum FastPracticeEntryDestination { catalog, landing, empty }

final class FastPracticeLeaf {
  const FastPracticeLeaf({
    required this.id,
    required this.name,
    required this.type,
  });

  final int id;
  final String name;
  final String type;
}

final class FastPracticeCatalog {
  FastPracticeCatalog({
    required this.module,
    required List<FastPracticeLeaf> leaves,
  }) : leaves = List<FastPracticeLeaf>.unmodifiable(leaves);

  final HomeModule module;
  final List<FastPracticeLeaf> leaves;
}

List<FastPracticeLeaf> parseFastPracticeLeaves(Object? body) {
  if (body is! List) {
    throw const FormatException('速成题单书架树 body 不是数组');
  }
  final leaves = <FastPracticeLeaf>[];
  for (final rawRoot in body) {
    if (rawRoot is! Map) {
      throw const FormatException('速成题单书架节点不是对象');
    }
    _appendLeaves(Map<String, dynamic>.from(rawRoot), leaves);
  }
  return List<FastPracticeLeaf>.unmodifiable(leaves);
}

void _appendLeaves(Map<String, dynamic> node, List<FastPracticeLeaf> leaves) {
  final rawChildren = node['children'];
  if (rawChildren != null && rawChildren is! List) {
    throw const FormatException('速成题单书架节点 children 不是数组');
  }
  final children = rawChildren as List? ?? const <Object?>[];
  if (children.isEmpty) {
    final id = _integer(node['id']);
    final name = _text(node['name']).trim();
    if (id > 0 && name.isNotEmpty) {
      leaves.add(
        FastPracticeLeaf(id: id, name: name, type: _text(node['type']).trim()),
      );
    }
    return;
  }
  for (final rawChild in children) {
    if (rawChild is! Map) {
      throw const FormatException('速成题单书架子节点不是对象');
    }
    _appendLeaves(Map<String, dynamic>.from(rawChild), leaves);
  }
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
