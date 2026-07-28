import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'learning_materials_models.dart';
import 'learning_materials_navigation.dart';

final class LearningMaterialsDocumentDetailPage extends StatelessWidget {
  const LearningMaterialsDocumentDetailPage({
    required this.item,
    required this.appSnapshot,
    this.htmlContentBuilder,
    this.onShare,
    this.onBannerTap,
    super.key,
  });

  final LearningMaterialsItem item;
  final LearningMaterialsAppSnapshot appSnapshot;
  final LearningMaterialsHtmlContentBuilder? htmlContentBuilder;
  final LearningMaterialsShareCallback? onShare;
  final LearningMaterialsBannerCallback? onBannerTap;

  Future<void> _share(BuildContext context) async {
    if (item.id == null) {
      _message(context, '分享信息不完整');
      return;
    }
    final callback = onShare;
    if (callback == null) {
      _message(context, '分享能力暂未接入');
      return;
    }
    await callback(
      context,
      LearningMaterialsShareRequest.fromItem(
        item,
        isTestEnvironment: appSnapshot.isTestEnvironment,
      ),
    );
  }

  Future<void> _openBanner(BuildContext context) async {
    final jumpPage = item.bannerJumpPage.trim();
    if (jumpPage.isEmpty) {
      _message(context, '暂无可跳转页面');
      return;
    }
    final callback = onBannerTap;
    if (callback == null) {
      _message(context, '该功能需要更新支持');
      return;
    }
    await callback(context, jumpPage);
  }

  @override
  Widget build(BuildContext context) {
    final tags = item.tagsLabel;
    final banner = item.resolvedBannerImage(appSnapshot.ossDomain);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF222222),
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          item.displayTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            key: const ValueKey('learning-material-document-share'),
            tooltip: '分享',
            onPressed: () => unawaited(_share(context)),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (tags.isNotEmpty)
                        Container(
                          key: const ValueKey('learning-material-document-tags'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFED3C00),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tags,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      if (tags.isNotEmpty) const SizedBox(width: 10),
                      const Icon(
                        Icons.remove_red_eye_outlined,
                        size: 16,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatLearningMaterialsCompactViews(item.viewCount),
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (banner.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: const ValueKey('learning-material-document-banner'),
                        onTap: () => unawaited(_openBanner(context)),
                        child: Image.network(
                          banner,
                          width: double.infinity,
                          fit: BoxFit.fitWidth,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                  if (item.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    LearningMaterialsRichHtmlView(
                      key: const ValueKey('learning-material-document-html'),
                      html: item.text,
                      ossDomain: appSnapshot.ossDomain,
                      contentBuilder: htmlContentBuilder,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class LearningMaterialsVideoDetailPage extends StatelessWidget {
  const LearningMaterialsVideoDetailPage({
    required this.item,
    required this.appSnapshot,
    this.htmlContentBuilder,
    this.videoContentBuilder,
    super.key,
  });

  final LearningMaterialsItem item;
  final LearningMaterialsAppSnapshot appSnapshot;
  final LearningMaterialsHtmlContentBuilder? htmlContentBuilder;
  final LearningMaterialsVideoContentBuilder? videoContentBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF222222),
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          item.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          LearningMaterialsVideoPlayer(
            key: ValueKey('learning-material-video-detail-${item.id}'),
            item: item,
            ossDomain: appSnapshot.ossDomain,
            contentBuilder: videoContentBuilder,
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.displayTitle,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.remove_red_eye_outlined,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  formatLearningMaterialsCompactViews(item.viewCount),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (item.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LearningMaterialsRichHtmlView(
                    key: const ValueKey('learning-material-video-html'),
                    html: item.text,
                    ossDomain: appSnapshot.ossDomain,
                    contentBuilder: htmlContentBuilder,
                    height: 360,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class LearningMaterialsRichHtmlView extends StatefulWidget {
  const LearningMaterialsRichHtmlView({
    required this.html,
    required this.ossDomain,
    this.contentBuilder,
    this.height = 520,
    super.key,
  });

  final String html;
  final String ossDomain;
  final LearningMaterialsHtmlContentBuilder? contentBuilder;
  final double height;

  @override
  State<LearningMaterialsRichHtmlView> createState() =>
      _LearningMaterialsRichHtmlViewState();
}

final class _LearningMaterialsRichHtmlViewState
    extends State<LearningMaterialsRichHtmlView> {
  WebViewController? _controller;
  int _progress = 100;

  Uri get _baseUri {
    final domain = widget.ossDomain.trim();
    return Uri.tryParse(domain.isEmpty ? 'https://file.xmzhujing.com/' : domain) ??
        Uri.parse('https://file.xmzhujing.com/');
  }

  @override
  void initState() {
    super.initState();
    _createController();
  }

  @override
  void didUpdateWidget(LearningMaterialsRichHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html ||
        oldWidget.ossDomain != widget.ossDomain ||
        oldWidget.contentBuilder != widget.contentBuilder) {
      _createController();
    }
  }

  void _createController() {
    if (widget.contentBuilder != null) {
      _controller = null;
      _progress = 100;
      return;
    }
    _progress = 0;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
        ),
      );
    _controller = controller;
    unawaited(
      controller.loadHtmlString(
        buildLearningMaterialsHtml(widget.html, _baseUri),
        baseUrl: _baseUri.toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final builder = widget.contentBuilder;
    final content = builder != null
        ? builder(context, widget.html, _baseUri)
        : WebViewWidget(controller: _controller!);
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          if (_progress < 100)
            Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(
                value: _progress == 0 ? null : _progress / 100,
                minHeight: 2,
                color: const Color(0xFF237DED),
                backgroundColor: const Color(0xFFE5E7EB),
              ),
            ),
        ],
      ),
    );
  }
}

final class LearningMaterialsVideoPlayer extends StatefulWidget {
  const LearningMaterialsVideoPlayer({
    required this.item,
    required this.ossDomain,
    this.contentBuilder,
    this.aspectRatio = 16 / 9,
    super.key,
  });

  final LearningMaterialsItem item;
  final String ossDomain;
  final LearningMaterialsVideoContentBuilder? contentBuilder;
  final double aspectRatio;

  @override
  State<LearningMaterialsVideoPlayer> createState() =>
      _LearningMaterialsVideoPlayerState();
}

final class _LearningMaterialsVideoPlayerState
    extends State<LearningMaterialsVideoPlayer>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  bool _failed = false;

  String get _url => widget.item.resolvedVideoUrl(widget.ossDomain);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createController();
  }

  @override
  void didUpdateWidget(LearningMaterialsVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item ||
        oldWidget.ossDomain != widget.ossDomain ||
        oldWidget.contentBuilder != widget.contentBuilder) {
      _createController();
    }
  }

  void _createController() {
    _failed = false;
    if (widget.contentBuilder != null || _url.isEmpty) {
      _controller = null;
      return;
    }
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'LearningVideoEvent',
        onMessageReceived: (message) {
          if (message.message == 'error' && mounted) {
            setState(() => _failed = true);
          }
        },
      );
    _controller = controller;
    unawaited(
      controller.loadHtmlString(
        buildLearningMaterialsVideoHtml(widget.item, widget.ossDomain),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(
        _controller?.runJavaScript('document.getElementById("player")?.pause();'),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(
      _controller?.runJavaScript('document.getElementById("player")?.pause();'),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final builder = widget.contentBuilder;
    Widget content;
    if (builder != null) {
      content = builder(context, widget.item);
    } else if (_url.isEmpty) {
      content = const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text('视频地址无效', style: TextStyle(color: Colors.white70)),
        ),
      );
    } else {
      content = Stack(
        fit: StackFit.expand,
        children: [
          WebViewWidget(controller: _controller!),
          if (_failed)
            const ColoredBox(
              color: Color(0xCC000000),
              child: Center(
                child: Text('视频加载失败', style: TextStyle(color: Colors.white)),
              ),
            ),
        ],
      );
    }
    return AspectRatio(aspectRatio: widget.aspectRatio, child: content);
  }
}

String buildLearningMaterialsHtml(String content, Uri baseUri) {
  if (content.trim().isEmpty || content.trim() == '题库更新中') {
    return '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"><style>html,body{height:100%;margin:0;display:flex;align-items:center;justify-content:center;color:#999;font-size:14px;background:#fff}</style></head><body>题库更新中</body></html>''';
  }
  final escapedBase = const HtmlEscape(HtmlEscapeMode.attribute).convert(
    baseUri.toString(),
  );
  return '''<!doctype html><html><head><base href="$escapedBase"><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"><style>html,body{max-width:100%;overflow-x:hidden;margin:0;padding:0}*,*::before,*::after{box-sizing:border-box}.content{font-size:15px;line-height:1.8;color:#333;word-break:break-word}p{margin:8px 0}img{max-width:100%!important;height:auto!important}table{max-width:100%!important;width:auto!important}pre{white-space:pre-wrap;word-wrap:break-word}</style></head><body><div class="content">$content</div></body></html>''';
}

String buildLearningMaterialsVideoHtml(
  LearningMaterialsItem item,
  String ossDomain,
) {
  final escape = const HtmlEscape(HtmlEscapeMode.attribute);
  final video = escape.convert(item.resolvedVideoUrl(ossDomain));
  final cover = escape.convert(item.resolvedVideoCover(ossDomain));
  return '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"><style>html,body{margin:0;width:100%;height:100%;background:#000;overflow:hidden}video{width:100%;height:100%;object-fit:contain;background:#000}</style></head><body><video id="player" controls playsinline webkit-playsinline preload="metadata" poster="$cover" src="$video"></video><script>document.getElementById('player').addEventListener('error',()=>LearningVideoEvent.postMessage('error'));</script></body></html>''';
}

void _message(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
