import 'dart:async';

import 'package:flutter/material.dart';

import 'learning_materials_detail_pages.dart';
import 'learning_materials_models.dart';
import 'learning_materials_navigation.dart';
import 'learning_materials_repository.dart';

final class LearningMaterialsFeedPage extends StatefulWidget {
  const LearningMaterialsFeedPage({
    required this.request,
    required this.dataSource,
    this.detailLauncher,
    this.htmlContentBuilder,
    this.videoContentBuilder,
    this.onPayment,
    this.onShare,
    this.onBannerTap,
    this.pageSize = 20,
    super.key,
  });

  final LearningMaterialsFeedRequest request;
  final LearningMaterialsDataSource dataSource;
  final LearningMaterialsDetailLauncher? detailLauncher;
  final LearningMaterialsHtmlContentBuilder? htmlContentBuilder;
  final LearningMaterialsVideoContentBuilder? videoContentBuilder;
  final LearningMaterialsPaymentCallback? onPayment;
  final LearningMaterialsShareCallback? onShare;
  final LearningMaterialsBannerCallback? onBannerTap;
  final int pageSize;

  @override
  State<LearningMaterialsFeedPage> createState() =>
      _LearningMaterialsFeedPageState();
}

final class _LearningMaterialsFeedPageState
    extends State<LearningMaterialsFeedPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _autoOpenConsumed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.request.shelves.length,
      initialIndex: widget.request.safeInitialTabIndex,
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final item = widget.request.autoOpenItem;
      if (!mounted || _autoOpenConsumed || item == null) return;
      _autoOpenConsumed = true;
      unawaited(_openDetail(item));
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openDetail(LearningMaterialsItem item) async {
    final launcher = widget.detailLauncher;
    if (launcher != null) {
      await launcher(context, item, widget.request.appSnapshot);
      return;
    }
    switch (item.kind) {
      case LearningMaterialKind.document:
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => LearningMaterialsDocumentDetailPage(
              item: item,
              appSnapshot: widget.request.appSnapshot,
              htmlContentBuilder: widget.htmlContentBuilder,
              onShare: widget.onShare,
              onBannerTap: widget.onBannerTap,
            ),
          ),
        );
      case LearningMaterialKind.video:
        if (item
            .resolvedVideoUrl(widget.request.appSnapshot.ossDomain)
            .isEmpty) {
          _message('视频地址无效');
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => LearningMaterialsVideoDetailPage(
              item: item,
              appSnapshot: widget.request.appSnapshot,
              htmlContentBuilder: widget.htmlContentBuilder,
              videoContentBuilder: widget.videoContentBuilder,
            ),
          ),
        );
      case LearningMaterialKind.payCard:
      case LearningMaterialKind.unknown:
        return;
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final shelves = widget.request.shelves;
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE3F2F2),
        foregroundColor: const Color(0xFF222222),
        surfaceTintColor: const Color(0xFFE3F2F2),
        elevation: 0,
        title: Text(
          widget.request.appSnapshot.libraryTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        bottom: shelves.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(50),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                    key: const ValueKey('learning-material-feed-tabs'),
                    controller: _tabController,
                    isScrollable: true,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: const Color(0xFF333333),
                    unselectedLabelColor: const Color(0xFF666666),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                    tabs: [
                      for (var index = 0; index < shelves.length; index++)
                        Tab(
                          key: ValueKey('learning-material-feed-tab-$index'),
                          text: shelves[index].name.trim().isEmpty
                              ? 'Tab${index + 1}'
                              : shelves[index].name,
                        ),
                    ],
                  ),
                ),
              ),
      ),
      body: shelves.isEmpty
          ? const _FeedEmpty(message: '暂无学习资料分类')
          : TabBarView(
              controller: _tabController,
              children: [
                for (var index = 0; index < shelves.length; index++)
                  _LearningMaterialsFeedShelfPane(
                    key: ValueKey(
                      'learning-material-feed-pane-${shelves[index].id}',
                    ),
                    dataSource: widget.dataSource,
                    moduleId: widget.request.module.id,
                    shelf: shelves[index],
                    initialItems: widget.request.bootstrapForTab(index),
                    pageSize: widget.pageSize,
                    appSnapshot: widget.request.appSnapshot,
                    videoContentBuilder: widget.videoContentBuilder,
                    onOpenDetail: _openDetail,
                    onPayment: widget.onPayment,
                  ),
              ],
            ),
    );
  }
}

final class _LearningMaterialsFeedShelfPane extends StatefulWidget {
  const _LearningMaterialsFeedShelfPane({
    required this.dataSource,
    required this.moduleId,
    required this.shelf,
    required this.initialItems,
    required this.pageSize,
    required this.appSnapshot,
    required this.onOpenDetail,
    required this.videoContentBuilder,
    required this.onPayment,
    super.key,
  });

  final LearningMaterialsDataSource dataSource;
  final int moduleId;
  final LearningMaterialsShelf shelf;
  final List<LearningMaterialsItem> initialItems;
  final int pageSize;
  final LearningMaterialsAppSnapshot appSnapshot;
  final ValueChanged<LearningMaterialsItem> onOpenDetail;
  final LearningMaterialsVideoContentBuilder? videoContentBuilder;
  final LearningMaterialsPaymentCallback? onPayment;

  @override
  State<_LearningMaterialsFeedShelfPane> createState() =>
      _LearningMaterialsFeedShelfPaneState();
}

final class _LearningMaterialsFeedShelfPaneState
    extends State<_LearningMaterialsFeedShelfPane>
    with AutomaticKeepAliveClientMixin {
  late final PageController _pageController;
  late final List<LearningMaterialsItem> _items;
  late int _nextPage;
  late bool _endReached;
  bool _loading = false;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.84);
    _items = List.of(widget.initialItems);
    _nextPage = _items.isEmpty ? 1 : 2;
    _endReached = _items.isNotEmpty && _items.length < widget.pageSize;
    if (_items.isEmpty) unawaited(_loadNextPage());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
      if (!_endReached && _items.length <= 3) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_loadNextPage());
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
      if (_items.isNotEmpty) _message('网络开小差了，请稍后重试');
    }
  }

  Future<void> _pay(
    LearningMaterialsItem item,
    LearningMaterialsPaymentChannel channel,
  ) async {
    final callback = widget.onPayment;
    if (callback == null) {
      _message('支付能力暂未接入');
      return;
    }
    final paid = await callback(context, item, channel);
    if (!mounted || !paid) return;
    setState(() {
      for (var index = 0; index < _items.length; index++) {
        final candidate = _items[index];
        if (candidate.commodityId == item.commodityId) {
          _items[index] = candidate.copyWith(isShow: false);
        }
      }
    });
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty && _error != null) {
      return _FeedFailure(onRetry: _loadNextPage, error: _error);
    }
    if (_items.isEmpty) {
      return const _FeedEmpty(message: '暂无学习资料');
    }
    return Stack(
      children: [
        PageView.builder(
          key: ValueKey('learning-material-feed-list-${widget.shelf.id}'),
          controller: _pageController,
          scrollDirection: Axis.vertical,
          padEnds: false,
          itemCount: _items.length,
          onPageChanged: (index) {
            if (index >= _items.length - 3) unawaited(_loadNextPage());
          },
          itemBuilder: (context, index) {
            final item = _items[index];
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: switch (item.kind) {
                LearningMaterialKind.video => _LearningFeedVideoCard(
                  item: item,
                  ossDomain: widget.appSnapshot.ossDomain,
                  contentBuilder: widget.videoContentBuilder,
                ),
                LearningMaterialKind.payCard => _LearningFeedPayCard(
                  item: item,
                  ossDomain: widget.appSnapshot.ossDomain,
                  onPay: (channel) => _pay(item, channel),
                ),
                LearningMaterialKind.document ||
                LearningMaterialKind.unknown => _LearningFeedDocumentCard(
                  item: item,
                  onOpen: item.kind == LearningMaterialKind.document
                      ? () => widget.onOpenDetail(item)
                      : null,
                ),
              },
            );
          },
        ),
        if (_loading)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 4,
            child: LinearProgressIndicator(
              minHeight: 2,
              color: Color(0xFF237DED),
              backgroundColor: Colors.transparent,
            ),
          ),
      ],
    );
  }
}

final class _LearningFeedDocumentCard extends StatelessWidget {
  const _LearningFeedDocumentCard({required this.item, required this.onOpen});

  final LearningMaterialsItem item;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final preview = item.documentPreview();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('learning-material-feed-document-${item.id}'),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.displayTitle,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _FeedMeta(item: item),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  preview.isEmpty ? '点击查看完整内容' : preview,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    color: preview.isEmpty
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF374151),
                    fontSize: 15,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  key: ValueKey('learning-material-feed-more-${item.id}'),
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFED3C00),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('查看更多'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _LearningFeedVideoCard extends StatelessWidget {
  const _LearningFeedVideoCard({
    required this.item,
    required this.ossDomain,
    required this.contentBuilder,
  });

  final LearningMaterialsItem item;
  final String ossDomain;
  final LearningMaterialsVideoContentBuilder? contentBuilder;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('learning-material-feed-video-${item.id}'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.displayTitle,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _FeedMeta(item: item, fallbackTag: '视频'),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 10),
            Expanded(
              child: Center(
                child: LearningMaterialsVideoPlayer(
                  item: item,
                  ossDomain: ossDomain,
                  contentBuilder: contentBuilder,
                  aspectRatio: 9 / 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _LearningFeedPayCard extends StatefulWidget {
  const _LearningFeedPayCard({
    required this.item,
    required this.ossDomain,
    required this.onPay,
  });

  final LearningMaterialsItem item;
  final String ossDomain;
  final ValueChanged<LearningMaterialsPaymentChannel> onPay;

  @override
  State<_LearningFeedPayCard> createState() => _LearningFeedPayCardState();
}

final class _LearningFeedPayCardState extends State<_LearningFeedPayCard> {
  LearningMaterialsPaymentChannel _channel =
      LearningMaterialsPaymentChannel.wechat;

  @override
  Widget build(BuildContext context) {
    final image = resolveLearningMaterialsUrl(
      widget.item.imageUrl.trim().isNotEmpty
          ? widget.item.imageUrl
          : widget.item.bannerImage,
      widget.ossDomain,
    );
    return Material(
      key: ValueKey('learning-material-feed-pay-${widget.item.id}'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (image.isNotEmpty)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Color(0xFFE5E7EB),
                      child: Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
              )
            else
              const Expanded(
                child: ColoredBox(
                  color: Color(0xFFF1F5F9),
                  child: Icon(
                    Icons.workspace_premium_outlined,
                    size: 56,
                    color: Color(0xFFED3C00),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              widget.item.displayTitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF33333D),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.item.isShow) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<LearningMaterialsPaymentChannel>(
                      key: const ValueKey('learning-material-pay-wechat'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('微信支付'),
                      value: LearningMaterialsPaymentChannel.wechat,
                      groupValue: _channel,
                      onChanged: (value) {
                        if (value != null) setState(() => _channel = value);
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<LearningMaterialsPaymentChannel>(
                      key: const ValueKey('learning-material-pay-alipay'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('支付宝'),
                      value: LearningMaterialsPaymentChannel.alipay,
                      groupValue: _channel,
                      onChanged: (value) {
                        if (value != null) setState(() => _channel = value);
                      },
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(
              height: 45,
              child: FilledButton(
                key: const ValueKey('learning-material-pay-submit'),
                onPressed: () => widget.onPay(_channel),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFED3C00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  widget.item.payButtonText.trim().isEmpty
                      ? '立即解锁'
                      : widget.item.payButtonText,
                ),
              ),
            ),
            if (widget.item.isShow)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '解锁即表示同意《考有招会员协议》',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9B4928), fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _FeedMeta extends StatelessWidget {
  const _FeedMeta({required this.item, this.fallbackTag = ''});

  final LearningMaterialsItem item;
  final String fallbackTag;

  @override
  Widget build(BuildContext context) {
    final tag = item.tagsLabel.isNotEmpty ? item.tagsLabel : fallbackTag;
    return Row(
      children: [
        if (tag.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFED3C00),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              tag,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
          const SizedBox(width: 10),
        ],
        const Icon(
          Icons.remove_red_eye_outlined,
          size: 16,
          color: Color(0xFF6B7280),
        ),
        const SizedBox(width: 4),
        Text(
          formatLearningMaterialsCompactViews(item.viewCount),
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
        ),
      ],
    );
  }
}

final class _FeedFailure extends StatelessWidget {
  const _FeedFailure({required this.onRetry, required this.error});

  final Future<void> Function() onRetry;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 40,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 10),
          const Text('学习资料加载失败'),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error.toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
            ),
          TextButton(onPressed: onRetry, child: const Text('重新加载')),
        ],
      ),
    );
  }
}

final class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.menu_book_outlined,
            size: 44,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}
