import 'package:flutter/material.dart';

import 'main_tabs_models.dart';

final class CategorySelectorPage extends StatefulWidget {
  const CategorySelectorPage({
    required this.groups,
    required this.selectedKey,
    super.key,
  });

  final List<CategoryGroup> groups;
  final String selectedKey;

  @override
  State<CategorySelectorPage> createState() => _CategorySelectorPageState();
}

final class _CategorySelectorPageState extends State<CategorySelectorPage> {
  static const _accent = Color(0xFF237DED);

  late int _selectedGroupIndex = _initialGroupIndex();

  int _initialGroupIndex() {
    final index = widget.groups.indexWhere(
      (group) =>
          group.options.any((option) => option.key == widget.selectedKey),
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          key: const ValueKey('category-selector-close'),
          tooltip: '关闭',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text(
          '切换分类',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: widget.groups.isEmpty
          ? const Center(
              child: Text('暂无分类', style: TextStyle(color: Color(0xFF9CA3AF))),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 92,
                  child: ColoredBox(
                    color: const Color(0xFFF6F7F9),
                    child: ListView.builder(
                      itemCount: widget.groups.length,
                      itemBuilder: (context, index) {
                        final group = widget.groups[index];
                        final selected = index == _selectedGroupIndex;
                        return InkWell(
                          key: ValueKey('category-group-${group.label}'),
                          onTap: () => setState(() {
                            _selectedGroupIndex = index;
                          }),
                          child: SizedBox(
                            height: 56,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 3,
                                  height: 24,
                                  child: ColoredBox(
                                    color: selected
                                        ? _accent
                                        : Colors.transparent,
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      group.label,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: selected
                                            ? const Color(0xFF1F2937)
                                            : const Color(0xFF737B87),
                                        fontSize: 14,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: _CategoryGrid(
                    options: widget.groups[_selectedGroupIndex].options,
                    selectedKey: widget.selectedKey,
                    onSelected: (option) {
                      Navigator.of(context).pop<CategoryOption>(option);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

final class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.options,
    required this.selectedKey,
    required this.onSelected,
  });

  static const _accent = Color(0xFF237DED);

  final List<CategoryOption> options;
  final String selectedKey;
  final ValueChanged<CategoryOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 48,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        final selected = option.key == selectedKey;
        return Semantics(
          key: ValueKey('category-option-${option.key}'),
          selected: selected,
          button: true,
          label: option.label,
          child: Material(
            color: selected ? const Color(0xFFEAF3FF) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(
                color: selected ? _accent : const Color(0xFFDDE2E8),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelected(option),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    option.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? _accent : const Color(0xFF3F4650),
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
