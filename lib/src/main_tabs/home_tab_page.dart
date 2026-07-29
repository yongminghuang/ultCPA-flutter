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
    this.onVipSelected,
    this.categorySelectorLauncher,
    this.moduleLauncher,
    this.learningMaterialsSectionBuilder,
    super.key,
  });

  final MainTabsDataSource dataSource;
  final VoidCallback? onSelectionChanged;
  final VoidCallback? onVipSelected;
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
            onVipSelected: widget.onVipSelected,
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

final class _HomeContent extends StatefulWidget {
  const _HomeContent({
    required this.data,
    required this.onCategorySelected,
    required this.onVipSelected,
    required this.onSubjectSelected,
    required this.onModuleSelected,
    required this.learningMaterialsSectionBuilder,
  });

  final HomeTabData data;
  final VoidCallback onCategorySelected;
  final VoidCallback? onVipSelected;
  final ValueChanged<CategorySubject> onSubjectSelected;
  final ValueChanged<HomeModule>? onModuleSelected;
  final LearningMaterialsSectionBuilder? learningMaterialsSectionBuilder;

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

final class _HomeContentState extends State<_HomeContent> {
  static const _headerSwitchOffset = 120.0;
  bool _useWhiteHeader = false;

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final shouldUseWhiteHeader =
        notification.metrics.pixels >= _headerSwitchOffset;
    if (shouldUseWhiteHeader != _useWhiteHeader && mounted) {
      setState(() => _useWhiteHeader = shouldUseWhiteHeader);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final heroModules = data.modules.take(2).toList(growable: false);
    final gridModules = data.modules.skip(2).take(8).toList(growable: false);
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _handleScroll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _HomeBanner(url: data.bannerUrl),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                child: _SubjectHeader(
                  data: data,
                  onSelected: widget.onSubjectSelected,
                ),
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
                              onTap: widget.onModuleSelected == null
                                  ? null
                                  : () => widget.onModuleSelected!(
                                      heroModules[index],
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (gridModules.isNotEmpty)
                _HomeModuleGrid(
                  modules: gridModules,
                  onModuleSelected: widget.onModuleSelected,
                )
              else if (data.modules.isEmpty &&
                  data.learningMaterialsModule == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 72),
                  child: Center(
                    child: Text(
                      '暂无可用模块',
                      style: TextStyle(color: Color(0xFF9CA3AF)),
                    ),
                  ),
                ),
              if (data.learningMaterialsModule case final module?)
                if (widget.learningMaterialsSectionBuilder case final builder?)
                  builder(context, module),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _CategoryHeader(
            label: data.categoryLabel,
            useWhiteBackground: _useWhiteHeader,
            onSelected: widget.onCategorySelected,
            onVipSelected: widget.onVipSelected,
          ),
        ),
      ],
    );
  }
}

final class _HomeBanner extends StatelessWidget {
  const _HomeBanner({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: url == null || url!.isEmpty
          ? Image.asset(_MainTabAssets.homeBanner, fit: BoxFit.cover)
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Image.asset(_MainTabAssets.homeBanner, fit: BoxFit.cover),
            ),
    );
  }
}

final class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.label,
    required this.useWhiteBackground,
    required this.onSelected,
    required this.onVipSelected,
  });

  final String label;
  final bool useWhiteBackground;
  final VoidCallback onSelected;
  final VoidCallback? onVipSelected;

  @override
  Widget build(BuildContext context) {
    final foreground = useWhiteBackground
        ? const Color(0xFF1F2937)
        : Colors.white;
    return AnimatedContainer(
      key: const ValueKey('home-category-header'),
      duration: const Duration(milliseconds: 140),
      color: useWhiteBackground ? Colors.white : Colors.transparent,
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.paddingOf(context).top + 20,
        12,
        10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              key: const ValueKey('home-category-selector'),
              color: Colors.transparent,
              child: InkWell(
                onTap: onSelected,
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    Image.asset(
                      _MainTabAssets.heroMenu,
                      width: 25,
                      height: 25,
                      color: foreground,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 20,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            key: const ValueKey('home-vip-purchase'),
            color: const Color(0xFFE51C24),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: onVipSelected,
              borderRadius: BorderRadius.circular(18),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  '开通会员',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _HomeModuleGrid extends StatelessWidget {
  const _HomeModuleGrid({
    required this.modules,
    required this.onModuleSelected,
  });

  final List<HomeModule> modules;
  final ValueChanged<HomeModule>? onModuleSelected;

  @override
  Widget build(BuildContext context) {
    final firstRow = modules.take(4).toList(growable: false);
    final secondRow = modules.skip(4).take(4).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 20),
      child: Column(
        children: [
          _ModuleRow(
            modules: firstRow,
            slotOffset: 0,
            compact: false,
            onModuleSelected: onModuleSelected,
          ),
          if (secondRow.isNotEmpty) ...[
            const SizedBox(height: 21),
            _ModuleRow(
              modules: secondRow,
              slotOffset: 4,
              compact: true,
              onModuleSelected: onModuleSelected,
            ),
          ],
        ],
      ),
    );
  }
}

final class _ModuleRow extends StatelessWidget {
  const _ModuleRow({
    required this.modules,
    required this.slotOffset,
    required this.compact,
    required this.onModuleSelected,
  });

  final List<HomeModule> modules;
  final int slotOffset;
  final bool compact;
  final ValueChanged<HomeModule>? onModuleSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < 4; index++)
          Expanded(
            child: index < modules.length
                ? _GridModule(
                    module: modules[index],
                    slotIndex: slotOffset + index,
                    compact: compact,
                    onTap: onModuleSelected == null
                        ? null
                        : () => onModuleSelected!(modules[index]),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}

abstract final class _MainTabAssets {
  static const _root = 'assets/images/main_tabs';
  static const homeBanner = '$_root/home_banner_default.png';
  static const heroMenu = '$_root/ic_hero_menu_white.png';
  static const heroTips = '$_root/ic_home_r1c1_tips.png';
  static const heroPractice = '$_root/ic_home_r1c2_practice.png';
  static const hot = '$_root/ic_home_fire.png';
  static const gridIcons = [
    '$_root/ic_home_r2c1_quick300.png',
    '$_root/ic_home_r2c4_card.png',
    '$_root/ic_home_r3c1_exam.png',
    '$_root/ic_home_r2c2_chapter.png',
    '$_root/ic_home_r3c2_wrong.png',
    '$_root/ic_home_r3c3.png',
    '$_root/ic_home_r3c4_daily.png',
    '$_root/ic_home_r3c5_video.png',
  ];
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
        ? const Color(0xFFF49D3D)
        : const Color(0xFF2E7CF6);
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
                    Image.asset(
                      index.isEven
                          ? _MainTabAssets.heroTips
                          : _MainTabAssets.heroPractice,
                      width: 40,
                      height: 42,
                      fit: BoxFit.contain,
                    ),
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
          if (module.tag.trim().isNotEmpty)
            Positioned(
              right: -2,
              top: -3,
              child: _ModuleBadge(tag: module.tag, hero: true),
            ),
        ],
      ),
    );
  }
}

final class _GridModule extends StatelessWidget {
  const _GridModule({
    required this.module,
    required this.slotIndex,
    required this.compact,
    required this.onTap,
  });

  final HomeModule module;
  final int slotIndex;
  final bool compact;
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
                Image.asset(
                  _MainTabAssets.gridIcons[slotIndex],
                  width: compact ? 24 : 40,
                  height: compact ? 24 : 40,
                  fit: BoxFit.contain,
                ),
                if (module.tag.trim().isNotEmpty)
                  Positioned(
                    right: compact ? -1 : -2,
                    top: compact ? -2 : -3,
                    child: _ModuleBadge(tag: module.tag, compact: compact),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                module.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF33333D),
                  fontSize: compact ? 11 : 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ModuleBadge extends StatelessWidget {
  const _ModuleBadge({
    required this.tag,
    this.compact = false,
    this.hero = false,
  });

  final String tag;
  final bool compact;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    if (tag.trim().toLowerCase() == 'hot') {
      return Image.asset(_MainTabAssets.hot, width: 11, height: 12);
    }
    return Container(
      constraints: const BoxConstraints(maxWidth: 42),
      padding: EdgeInsets.symmetric(
        horizontal: 2,
        vertical: hero ? 2 : (compact ? 0 : 0.5),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEC563D),
        borderRadius: BorderRadius.circular(hero ? 6 : 3),
      ),
      child: Text(
        tag.trim(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: hero ? 11 : (compact ? 7 : 8),
          height: 1,
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
