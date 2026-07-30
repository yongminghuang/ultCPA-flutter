import 'dart:async';

import 'package:flutter/material.dart';

import '../main_tabs/main_tabs_models.dart';
import 'learning_materials_feed_page.dart';
import 'learning_materials_models.dart';
import 'learning_materials_navigation.dart';
import 'learning_materials_repository.dart';

final class LearningMaterialsHomeSection extends StatefulWidget {
  const LearningMaterialsHomeSection({
    required this.module,
    required this.dataSource,
    this.loginLauncher,
    this.feedLauncher,
    this.detailLauncher,
    this.htmlContentBuilder,
    this.videoContentBuilder,
    this.onPayment,
    this.onShare,
    this.onBannerTap,
    this.pageSize = 20,
    this.viewportHeight = 336,
    super.key,
  });

  final HomeModule module;
  final LearningMaterialsDataSource dataSource;
  final LearningMaterialsLoginLauncher? loginLauncher;
  final LearningMaterialsFeedLauncher? feedLauncher;
  final LearningMaterialsDetailLauncher? detailLauncher;
  final LearningMaterialsHtmlContentBuilder? htmlContentBuilder;
  final LearningMaterialsVideoContentBuilder? videoContentBuilder;
  final LearningMaterialsPaymentCallback? onPayment;
  final LearningMaterialsShareCallback? onShare;
  final LearningMaterialsBannerCallback? onBannerTap;
  final int pageSize;
  final double viewportHeight;

  @override
  State<LearningMaterialsHomeSection> createState() =>
      _LearningMaterialsHomeSectionState();
}

final class _LearningMaterialsHomeSectionState
    extends State<LearningMaterialsHomeSection>
    with SingleTickerProviderStateMixin {
  LearningMaterialsAppSnapshot? _snapshot;
  List<LearningMaterialsShelf>? _shelves;
  TabController? _tabController;
  Object? _error;
  bool _loading = true;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(LearningMaterialsHomeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module.id != widget.module.id ||
        oldWidget.dataSource != widget.dataSource) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<Object>([
        widget.dataSource.readSnapshot(),
        widget.dataSource.loadShelfTabs(moduleId: widget.module.id),
      ]);
      if (!mounted || generation != _loadGeneration) return;
      final snapshot = results[0] as LearningMaterialsAppSnapshot;
      final shelves = results[1] as List<LearningMaterialsShelf>;
      final oldController = _tabController;
      _tabController = shelves.isEmpty
          ? null
          : TabController(length: shelves.length, vsync: this);
      oldController?.dispose();
      setState(() {
        _snapshot = snapshot;
        _shelves = List.unmodifiable(shelves);
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      _tabController?.dispose();
      _tabController = null;
      setState(() {
        _loading = false;
        _error = error;
        _shelves = null;
      });
    }
  }

  Future<void> _openFromHome({
    required int tabIndex,
    required int clickedIndex,
    required LearningMaterialsItem item,
    required List<LearningMaterialsItem> items,
  }) async {
    final cachedSnapshot = _snapshot;
    final shelves = _shelves;
    if (cachedSnapshot == null || shelves == null || shelves.isEmpty) return;
    var snapshot = cachedSnapshot;

    // This section can stay alive in the home IndexedStack while the user
    // signs in from Mine or another guarded feature. Do not make an auth
    // decision from the snapshot captured when the section was first loaded.
    // The native state store is the source of truth and is updated before the
    // login page returns.
    try {
      snapshot = await widget.dataSource.readSnapshot();
      if (!mounted) return;
      _snapshot = snapshot;
    } catch (_) {
      if (!mounted) return;
      // Keep the already loaded snapshot as a safe fallback. A failed local
      // state read must never grant access that the cached state denied.
    }
    if (!snapshot.isLoggedIn) {
      final launcher = widget.loginLauncher;
      if (launcher == null) {
        _message('请先登录');
        return;
      }
      final result = await launcher(context);
      if (!mounted || result == null) return;
      snapshot = snapshot.copyWith(isLoggedIn: true);
      setState(() => _snapshot = snapshot);
    }
    final request = LearningMaterialsFeedRequest(
      module: widget.module,
      shelves: shelves,
      initialTabIndex: tabIndex,
      clickedIndex: clickedIndex,
      snapshotItems: items,
      appSnapshot: snapshot,
      autoOpenItem: item.shouldAutoOpenDetail ? item : null,
    );
    final launcher = widget.feedLauncher;
    if (launcher != null) {
      await launcher(context, request);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LearningMaterialsFeedPage(
          request: request,
          dataSource: widget.dataSource,
          detailLauncher: widget.detailLauncher,
          htmlContentBuilder: widget.htmlContentBuilder,
          videoContentBuilder: widget.videoContentBuilder,
          onPayment: widget.onPayment,
          onShare: widget.onShare,
          onBannerTap: widget.onBannerTap,
          pageSize: widget.pageSize,
        ),
      ),
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final shelves = _shelves;
    final snapshot = _snapshot;
    final controller = _tabController;
    if (shelves == null || snapshot == null) {
      return _HomeSectionFailure(error: _error, onRetry: _load);
    }
    if (shelves.isEmpty || controller == null) return const SizedBox.shrink();
    final title = widget.module.name.trim().isEmpty
        ? '备考情报局'
        : widget.module.name.trim();
    return ColoredBox(
      color: const Color(0xFFF1F5F9),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ColoredBox(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                child: Text(
                  title,
                  key: const ValueKey('learning-material-home-title'),
                  style: const TextStyle(
                    color: Color(0xFF33333D),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TabBar(
                key: const ValueKey('learning-material-home-tabs'),
                controller: controller,
                isScrollable: true,
                dividerColor: Colors.transparent,
                indicatorColor: const Color(0xFF237DED),
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 3,
                labelColor: const Color(0xFF33333D),
                unselectedLabelColor: const Color(0xFF848489),
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 14),
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tabs: [
                  for (var index = 0; index < shelves.length; index++)
                    Tab(
                      key: ValueKey('learning-material-home-tab-$index'),
                      text: shelves[index].name.trim().isEmpty
                          ? '未命名'
                          : shelves[index].name,
                    ),
                ],
              ),
              SizedBox(
                height: widget.viewportHeight,
                child: TabBarView(
                  controller: controller,
                  children: [
                    for (var index = 0; index < shelves.length; index++)
                      _LearningMaterialsHomeShelfPane(
                        key: ValueKey(
                          'learning-material-home-pane-${shelves[index].id}',
                        ),
                        dataSource: widget.dataSource,
                        moduleId: widget.module.id,
                        shelf: shelves[index],
                        pageSize: widget.pageSize,
                        ossDomain: snapshot.ossDomain,
                        onItemTap: (item, clickedIndex, items) => unawaited(
                          _openFromHome(
                            tabIndex: index,
                            clickedIndex: clickedIndex,
                            item: item,
                            items: items,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _HomeItemTap =
    void Function(
      LearningMaterialsItem item,
      int index,
      List<LearningMaterialsItem> items,
    );

final class _LearningMaterialsHomeShelfPane extends StatefulWidget {
  const _LearningMaterialsHomeShelfPane({
    required this.dataSource,
    required this.moduleId,
    required this.shelf,
    required this.pageSize,
    required this.ossDomain,
    required this.onItemTap,
    super.key,
  });

  final LearningMaterialsDataSource dataSource;
  final int moduleId;
  final LearningMaterialsShelf shelf;
  final int pageSize;
  final String ossDomain;
  final _HomeItemTap onItemTap;

  @override
  State<_LearningMaterialsHomeShelfPane> createState() =>
      _LearningMaterialsHomeShelfPaneState();
}

final class _LearningMaterialsHomeShelfPaneState
    extends State<_LearningMaterialsHomeShelfPane>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final List<LearningMaterialsItem> _items = [];
  int _nextPage = 1;
  bool _loading = false;
  bool _endReached = false;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadNextPage());
  }

  @override
  void didUpdateWidget(_LearningMaterialsHomeShelfPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moduleId != widget.moduleId ||
        oldWidget.shelf.id != widget.shelf.id) {
      _items.clear();
      _nextPage = 1;
      _endReached = false;
      _error = null;
      unawaited(_loadNextPage());
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || _endReached) return;
    if (_scrollController.position.extentAfter < 160) {
      unawaited(_loadNextPage());
    }
  }

  Future<void> _loadNextPage() async {
    if (_loading || _endReached) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final requestedPage = _nextPage;
    try {
      final page = await widget.dataSource.loadPage(
        moduleId: widget.moduleId,
        shelfId: widget.shelf.id,
        pageNumber: requestedPage,
        pageSize: widget.pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.records);
        _nextPage = page.hasMore ? page.current + 1 : requestedPage;
        _endReached = !page.hasMore;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
      if (_items.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('网络开小差了，请稍后重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty && _error != null) {
      return _HomePaneFailure(error: _error, onRetry: _loadNextPage);
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text('暂无学习资料', style: TextStyle(color: Color(0xFF94A3B8))),
      );
    }
    final showFooter = _loading || !_endReached || _error != null;
    return ListView.separated(
      key: ValueKey('learning-material-home-list-${widget.shelf.id}'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
      itemCount: _items.length + (showFooter ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        indent: 12,
        endIndent: 16,
        color: Color(0xFFEEEEEE),
      ),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          if (_loading) {
            return const SizedBox(
              height: 44,
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return SizedBox(
            height: 44,
            child: TextButton(
              key: ValueKey('learning-material-home-more-${widget.shelf.id}'),
              onPressed: _loadNextPage,
              child: Text(_error == null ? '加载更多' : '加载失败，点击重试'),
            ),
          );
        }
        final item = _items[index];
        return _LearningMaterialsCompactRow(
          key: ValueKey(
            'learning-material-home-item-${widget.shelf.id}-${item.id ?? index}',
          ),
          item: item,
          ossDomain: widget.ossDomain,
          onTap: () => widget.onItemTap(
            item,
            index,
            List<LearningMaterialsItem>.unmodifiable(_items),
          ),
        );
      },
    );
  }
}

final class _LearningMaterialsCompactRow extends StatelessWidget {
  const _LearningMaterialsCompactRow({
    required this.item,
    required this.ossDomain,
    required this.onTap,
    super.key,
  });

  final LearningMaterialsItem item;
  final String ossDomain;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = item.resolvedListCover(ossDomain);
    final tags = item.tagsLabel;
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
          child: Row(
            children: [
              if (cover.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    cover,
                    width: 51,
                    height: 51,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 51,
                      height: 51,
                      child: ColoredBox(
                        color: Color(0xFFE5E7EB),
                        child: Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (tags.isNotEmpty) ...[
                          Flexible(
                            child: Text(
                              tags,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF3487F9),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: SizedBox(
                              width: 1,
                              height: 10,
                              child: ColoredBox(color: Color(0xFFDCDCDC)),
                            ),
                          ),
                        ],
                        Text(
                          formatLearningMaterialsHomeViews(item.viewCount),
                          style: const TextStyle(
                            color: Color(0xFFA4A4A4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _HomeSectionFailure extends StatelessWidget {
  const _HomeSectionFailure({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('学习资料加载失败', style: TextStyle(color: Color(0xFF64748B))),
            if (error != null)
              Text(
                error.toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            TextButton(onPressed: onRetry, child: const Text('重新加载')),
          ],
        ),
      ),
    );
  }
}

final class _HomePaneFailure extends StatelessWidget {
  const _HomePaneFailure({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('资料列表加载失败'),
          if (error != null)
            Text(
              error.toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
          TextButton(onPressed: onRetry, child: const Text('重新加载')),
        ],
      ),
    );
  }
}
