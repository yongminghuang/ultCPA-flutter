import 'dart:async';
import 'dart:math' as math;

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
  static const _accent = Color(0xFF4A8FF7);
  static const _divider = Color(0xFFE7EBF0);

  final _rightListKey = GlobalKey();
  late final List<GlobalKey> _sectionKeys;
  late final List<GlobalKey> _leftNavKeys;
  late int _selectedGroupIndex;
  bool _programmaticScroll = false;

  @override
  void initState() {
    super.initState();
    _selectedGroupIndex = _initialGroupIndex();
    _sectionKeys = List.generate(widget.groups.length, (_) => GlobalKey());
    _leftNavKeys = List.generate(widget.groups.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selectedGroupIndex > 0) {
        _scrollToGroup(_selectedGroupIndex, animated: false);
      }
    });
  }

  int _initialGroupIndex() {
    final index = widget.groups.indexWhere(
      (group) =>
          group.options.any((option) => option.key == widget.selectedKey),
    );
    return index < 0 ? 0 : index;
  }

  Future<void> _scrollToGroup(int index, {bool animated = true}) async {
    if (index < 0 || index >= _sectionKeys.length) return;
    if (_selectedGroupIndex != index) {
      setState(() => _selectedGroupIndex = index);
    }
    final leftContext = _leftNavKeys[index].currentContext;
    if (leftContext != null) {
      unawaited(
        Scrollable.ensureVisible(
          leftContext,
          duration: animated
              ? const Duration(milliseconds: 250)
              : Duration.zero,
          alignment: 0.5,
        ),
      );
    }
    final sectionContext = _sectionKeys[index].currentContext;
    if (sectionContext == null) return;
    _programmaticScroll = true;
    await Scrollable.ensureVisible(
      sectionContext,
      duration: animated ? const Duration(milliseconds: 250) : Duration.zero,
      curve: Curves.easeOutCubic,
      alignment: 0,
    );
    _programmaticScroll = false;
  }

  bool _handleRightScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical || _programmaticScroll) {
      return false;
    }
    final viewport = _rightListKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return false;

    var visibleGroup = 0;
    for (var index = 0; index < _sectionKeys.length; index++) {
      final section = _sectionKeys[index].currentContext?.findRenderObject();
      if (section is! RenderBox || !section.hasSize) continue;
      final top = viewport.globalToLocal(section.localToGlobal(Offset.zero)).dy;
      if (top <= 1) {
        visibleGroup = index;
      } else {
        break;
      }
    }
    if (visibleGroup != _selectedGroupIndex) {
      setState(() => _selectedGroupIndex = visibleGroup);
      final leftContext = _leftNavKeys[visibleGroup].currentContext;
      if (leftContext != null) {
        Scrollable.ensureVisible(leftContext, alignment: 0.5);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 56,
        centerTitle: true,
        leadingWidth: 76,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                key: const ValueKey('category-selector-close'),
                tooltip: '返回',
                padding: const EdgeInsets.all(12),
                onPressed: () => Navigator.of(context).pop(),
                icon: Image.asset(
                  'assets/images/authentication/icon_back_gray.png',
                  width: 20,
                  height: 20,
                ),
              ),
            ),
          ),
        ),
        title: const Text(
          '请选择考试类目',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: SizedBox(
            height: 0.5,
            width: double.infinity,
            child: ColoredBox(color: _divider),
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
                  width: 100,
                  child: ColoredBox(
                    color: const Color(0xFFF5F5F5),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: widget.groups.length,
                      itemBuilder: (context, index) {
                        final group = widget.groups[index];
                        final selected = index == _selectedGroupIndex;
                        return KeyedSubtree(
                          key: _leftNavKeys[index],
                          child: Material(
                            key: ValueKey('category-group-${group.label}'),
                            color: selected
                                ? Colors.white
                                : const Color(0xFFF5F5F5),
                            child: InkWell(
                              onTap: () => _scrollToGroup(index),
                              child: SizedBox(
                                height: 56,
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 3,
                                      height: double.infinity,
                                      child: ColoredBox(
                                        color: selected
                                            ? _accent
                                            : Colors.transparent,
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Text(
                                          group.label,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: selected
                                                ? _accent
                                                : const Color(0xFF333333),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 0.5, child: ColoredBox(color: _divider)),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final lastGroup = widget.groups.last;
                      final lastRows = (lastGroup.options.length + 1) ~/ 2;
                      final lastGroupHeight = 56.0 + lastRows * 54.0;
                      final bottomSpace = math.max(
                        16.0,
                        constraints.maxHeight - lastGroupHeight,
                      );
                      return NotificationListener<ScrollNotification>(
                        onNotification: _handleRightScroll,
                        child: ListView(
                          key: _rightListKey,
                          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomSpace),
                          children: [
                            for (
                              var index = 0;
                              index < widget.groups.length;
                              index++
                            )
                              _CategorySection(
                                key: _sectionKeys[index],
                                group: widget.groups[index],
                                selectedKey: widget.selectedKey,
                                onSelected: (option) {
                                  Navigator.of(
                                    context,
                                  ).pop<CategoryOption>(option);
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

final class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.group,
    required this.selectedKey,
    required this.onSelected,
    super.key,
  });

  final CategoryGroup group;
  final String selectedKey;
  final ValueChanged<CategoryOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Text(
            group.label,
            key: ValueKey('category-section-${group.label}'),
            style: const TextStyle(
              color: Color(0xFF222222),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (group.options.isNotEmpty)
          GridView.builder(
            padding: const EdgeInsets.only(top: 10),
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 44,
              crossAxisSpacing: 6,
              mainAxisSpacing: 10,
            ),
            itemCount: group.options.length,
            itemBuilder: (context, index) {
              final option = group.options[index];
              return _CategoryOptionTile(
                option: option,
                selected: option.key == selectedKey,
                onSelected: onSelected,
              );
            },
          ),
      ],
    );
  }
}

final class _CategoryOptionTile extends StatelessWidget {
  const _CategoryOptionTile({
    required this.option,
    required this.selected,
    required this.onSelected,
  });

  static const _accent = Color(0xFF4A8FF7);

  final CategoryOption option;
  final bool selected;
  final ValueChanged<CategoryOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey('category-option-${option.key}'),
      selected: selected,
      button: true,
      label: option.label,
      child: Material(
        color: selected ? const Color(0xFFECF4FF) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? const Color(0xFF7CB6FF) : const Color(0xFFE7EBF0),
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
                  color: selected ? _accent : const Color(0xFF222222),
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
