import 'dart:async';

import 'package:flutter/material.dart';

import 'category_selector_page.dart';
import 'main_tabs_models.dart';
import 'main_tabs_repository.dart';

typedef CategorySelectorLauncher =
    Future<CategoryOption?> Function(
      BuildContext context,
      List<CategoryGroup> groups,
      String selectedKey,
    );

typedef HomeModuleLauncher =
    Future<void> Function(
      BuildContext context,
      HomeModule module,
      HomeModule? bigSkillCircleModule,
    );

typedef LearningMaterialsSectionBuilder =
    Widget Function(BuildContext context, HomeModule module);

final class HomeTabPage extends StatefulWidget {
  const HomeTabPage({
    required this.dataSource,
    this.onSelectionChanged,
    this.categorySelectorLauncher,
    this.moduleLauncher,
    this.learningMaterialsSectionBuilder,
    super.key,
  });

  final MainTabsDataSource dataSource;
  final VoidCallback? onSelectionChanged;
  final CategorySelectorLauncher? categorySelectorLauncher;
  final HomeModuleLauncher? moduleLauncher;
  final LearningMaterialsSectionBuilder? learningMaterialsSectionBuilder;

  @override
  State<HomeTabPage> createState() => _HomeTabPageState();
}

final class _HomeTabPageState extends State<HomeTabPage> {
  HomeTabData? _data;
  Object? _error;
  bool _loading = true;
  bool _selectionLoading = false;
  int _requestNumber = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({
    String? preferredCategoryKey,
    int? preferredSubjectId,
    bool notifySelectionChanged = false,
  }) async {
    final requestNumber = ++_requestNumber;
    if (mounted) {
      setState(() {
        _loading = _data == null;
        _selectionLoading = _data != null && notifySelectionChanged;
        _error = null;
      });
    }
    try {
      final data = await widget.dataSource.loadHome(
        preferredCategoryKey: preferredCategoryKey,
        preferredSubjectId: preferredSubjectId,
      );
      if (!mounted || requestNumber != _requestNumber) return;
      setState(() {
        _data = data;
        _loading = false;
        _selectionLoading = false;
      });
      if (notifySelectionChanged) widget.onSelectionChanged?.call();
    } catch (error) {
      if (!mounted || requestNumber != _requestNumber) return;
      setState(() {
        _error = error;
        _loading = false;
        _selectionLoading = false;
      });
      if (_data != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(notifySelectionChanged ? '切换失败，请重试' : '加载失败，请重试'),
            ),
          );
      }
    }
  }

  Future<void> _selectCategory() async {
    final data = _data;
    if (data == null) return;
    final launcher = widget.categorySelectorLauncher ?? _openCategorySelector;
    final option = await launcher(
      context,
      data.categoryGroups,
      data.selection.category.key,
    );
    if (!mounted ||
        option == null ||
        option.key == data.selection.category.key) {
      return;
    }
    final currentSubjectId = data.selectedSubject.id;
    CategorySubject? subject;
    for (final candidate in option.subjects) {
      if (candidate.id == currentSubjectId) {
        subject = candidate;
        break;
      }
    }
    await _load(
      preferredCategoryKey: option.key,
      preferredSubjectId: (subject ?? option.subjects.first).id,
      notifySelectionChanged: true,
    );
  }

  Future<CategoryOption?> _openCategorySelector(
    BuildContext context,
    List<CategoryGroup> groups,
    String selectedKey,
  ) {
    return Navigator.of(context).push<CategoryOption>(
      MaterialPageRoute(
        builder: (_) =>
            CategorySelectorPage(groups: groups, selectedKey: selectedKey),
      ),
    );
  }

  void _selectSubject(CategorySubject subject) {
    final data = _data;
    if (data == null || subject.id == data.selectedSubject.id) {
      return;
    }
    _load(
      preferredCategoryKey: data.selection.category.key,
      preferredSubjectId: subject.id,
      notifySelectionChanged: true,
    );
  }

  void _launchModule(HomeModule module) {
    final launcher = widget.moduleLauncher;
    final data = _data;
    if (launcher != null && data != null) {
      unawaited(launcher(context, module, data.bigSkillCircleModule));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_data == null) {
      return _LoadFailure(onRetry: _load, error: _error);
    }
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          color: const Color(0xFF237DED),
          child: _HomeContent(
            data: _data!,
            onCategorySelected: _selectCategory,
            onSubjectSelected: _selectSubject,
            onModuleSelected: widget.moduleLauncher == null
                ? null
                : _launchModule,
            learningMaterialsSectionBuilder:
                widget.learningMaterialsSectionBuilder,
          ),
        ),
        if (_selectionLoading)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              color: Color(0xFF237DED),
              backgroundColor: Color(0xFFE5EAF0),
            ),
          ),
      ],
    );
  }
}

final class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.data,
    required this.onCategorySelected,
    required this.onSubjectSelected,
    required this.onModuleSelected,
    required this.learningMaterialsSectionBuilder,
  });

  final HomeTabData data;
  final VoidCallback onCategorySelected;
  final ValueChanged<CategorySubject> onSubjectSelected;
  final ValueChanged<HomeModule>? onModuleSelected;
  final LearningMaterialsSectionBuilder? learningMaterialsSectionBuilder;

  @override
  Widget build(BuildContext context) {
    final heroModules = data.modules.take(2).toList(growable: false);
    final gridModules = data.modules.skip(2).toList(growable: false);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: _CategoryHeader(
            label: data.categoryLabel,
            onSelected: onCategorySelected,
          ),
        ),
        if (data.bannerUrl case final url?) _HomeBanner(url: url),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
          child: _SubjectHeader(data: data, onSelected: onSubjectSelected),
        ),
        if (heroModules.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var index = 0; index < heroModules.length; index++)
                  Expanded(
                    child: Align(
                      child: _HeroModule(
                        module: heroModules[index],
                        index: index,
                        onTap: onModuleSelected == null
                            ? null
                            : () => onModuleSelected!(heroModules[index]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (gridModules.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / 4;
                return Wrap(
                  children: [
                    for (final module in gridModules)
                      SizedBox(
                        width: itemWidth,
                        height: 92,
                        child: _GridModule(
                          module: module,
                          onTap: onModuleSelected == null
                              ? null
                              : () => onModuleSelected!(module),
                        ),
                      ),
                  ],
                );
              },
            ),
          )
        else if (data.modules.isEmpty && data.learningMaterialsModule == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 72),
            child: Center(
              child: Text('暂无可用模块', style: TextStyle(color: Color(0xFF9CA3AF))),
            ),
          ),
        if (data.learningMaterialsModule case final module?)
          if (learningMaterialsSectionBuilder case final builder?)
            builder(context, module),
      ],
    );
  }
}

final class _HomeBanner extends StatelessWidget {
  const _HomeBanner({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const ColoredBox(
          color: Color(0xFFF1F5F9),
          child: Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              color: Color(0xFF94A3B8),
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}

final class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.label, required this.onSelected});

  final String label;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('home-category-selector'),
          onTap: onSelected,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(
                  Icons.menu_rounded,
                  size: 22,
                  color: Color(0xFF4B5563),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _SubjectHeader extends StatelessWidget {
  const _SubjectHeader({required this.data, required this.onSelected});

  final HomeTabData data;
  final ValueChanged<CategorySubject> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final subject in data.subjects)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onSelected(subject),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: Text(
                            subject.name,
                            style: TextStyle(
                              color: subject.id == data.selectedSubject.id
                                  ? const Color(0xFF33333D)
                                  : const Color(0xFF848489),
                              fontSize: 15,
                              fontWeight: subject.id == data.selectedSubject.id
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (data.examCountdownDays case final days?)
          Text(
            '距离考试还有$days天',
            style: const TextStyle(
              color: Color(0xFF33333D),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

final class _HeroModule extends StatelessWidget {
  const _HeroModule({
    required this.module,
    required this.index,
    required this.onTap,
  });

  final HomeModule module;
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = index.isEven
        ? const Color(0xFFF6830D)
        : const Color(0xFF237DED);
    return SizedBox(
      width: 132,
      height: 133,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: color,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('home-module-${module.id}'),
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_moduleIcon(module), size: 40, color: Colors.white),
                    const SizedBox(height: 7),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        module.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (module.isHot)
            const Positioned(right: 4, top: 5, child: _HotBadge()),
        ],
      ),
    );
  }
}

final class _GridModule extends StatelessWidget {
  const _GridModule({required this.module, required this.onTap});

  final HomeModule module;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('home-module-${module.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _moduleColor(module).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _moduleIcon(module),
                    size: 24,
                    color: _moduleColor(module),
                  ),
                ),
                if (module.isHot)
                  const Positioned(right: -12, top: -8, child: _HotBadge()),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                module.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF33333D), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _HotBadge extends StatelessWidget {
  const _HotBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEC563D),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'HOT',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

final class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry, required this.error});

  final Future<void> Function() onRetry;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFF94A3B8),
              size: 36,
            ),
            const SizedBox(height: 12),
            const Text(
              '加载失败',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text(
                error.toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新加载'),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _moduleIcon(HomeModule module) {
  final text = '${module.page} ${module.name}'.toLowerCase();
  if (text.contains('mnemonic') || text.contains('口诀')) {
    return Icons.lightbulb_outline_rounded;
  }
  if (text.contains('practice') || text.contains('练题')) {
    return Icons.edit_note_rounded;
  }
  if (text.contains('chapter') || text.contains('章节')) {
    return Icons.menu_book_rounded;
  }
  if (text.contains('exam') || text.contains('真题') || text.contains('密押')) {
    return Icons.assignment_rounded;
  }
  if (text.contains('card') || text.contains('卡片')) {
    return Icons.style_rounded;
  }
  if (text.contains('video') || text.contains('讲解')) {
    return Icons.play_circle_outline_rounded;
  }
  if (text.contains('error') || text.contains('错题')) {
    return Icons.fact_check_outlined;
  }
  return Icons.school_outlined;
}

Color _moduleColor(HomeModule module) {
  const colors = [
    Color(0xFF237DED),
    Color(0xFFF6830D),
    Color(0xFF18A765),
    Color(0xFFEC563D),
  ];
  return colors[module.id.abs() % colors.length];
}
