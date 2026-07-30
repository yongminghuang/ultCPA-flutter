import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

const legacyWebFinishChannelName = 'Jx885WebFinish';
const legacyInviteShareChannelName = 'Jx885InviteShare';

@visibleForTesting
String buildLegacyWebApiBootstrap({required bool enableInviteShare}) {
  final inviteShareBridge = enableInviteShare
      ? '''
    window.Jx885WebApi.openInviteShare = function(content) {
      $legacyInviteShareChannelName.postMessage(String(content || ''));
    };'''
      : '';
  return '''
  (function() {
    window.Jx885WebApi = window.Jx885WebApi || {};
    window.Jx885WebApi.WebViewFinish = function() {
      $legacyWebFinishChannelName.postMessage('');
    };$inviteShareBridge
  })();
  ''';
}

final class LegacyWebRequest {
  const LegacyWebRequest({
    required this.url,
    required this.title,
    this.hideTitleBar = false,
  });

  final String url;
  final String title;
  final bool hideTitleBar;

  Uri get uri => Uri.parse(url);
}

typedef LegacyWebContentBuilder =
    Widget Function(BuildContext context, Uri uri);
typedef LegacyInviteShareCallback =
    Future<void> Function(BuildContext context, String content);

final class LegacyWebViewPage extends StatefulWidget {
  const LegacyWebViewPage({
    required this.request,
    this.contentBuilder,
    this.onInviteShare,
    super.key,
  });

  final LegacyWebRequest request;
  final LegacyWebContentBuilder? contentBuilder;
  final LegacyInviteShareCallback? onInviteShare;

  @override
  State<LegacyWebViewPage> createState() => _LegacyWebViewPageState();
}

final class _LegacyWebViewPageState extends State<LegacyWebViewPage> {
  static const _immersiveOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  WebViewController? _controller;
  int _progress = 100;
  bool _handlingBack = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    if (widget.contentBuilder == null) {
      _progress = 0;
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..addJavaScriptChannel(
          legacyWebFinishChannelName,
          onMessageReceived: (_) => _finishPage(),
        );
      if (widget.onInviteShare != null) {
        controller.addJavaScriptChannel(
          legacyInviteShareChannelName,
          onMessageReceived: (message) {
            final callback = widget.onInviteShare;
            if (callback != null && mounted) {
              unawaited(callback(context, message.message));
            }
          },
        );
      }
      controller
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
            onPageFinished: (_) async {
              await controller.runJavaScript(
                buildLegacyWebApiBootstrap(
                  enableInviteShare: widget.onInviteShare != null,
                ),
              );
            },
          ),
        )
        ..loadRequest(widget.request.uri);
      _controller = controller;
    }
  }

  Future<void> _handleBack() async {
    if (_handlingBack) return;
    _handlingBack = true;
    try {
      final controller = _controller;
      if (controller != null && await controller.canGoBack()) {
        await controller.goBack();
        return;
      }
      if (!mounted) return;
      if (controller == null) {
        _finishPage();
        return;
      }
      _finishPage();
    } finally {
      _handlingBack = false;
    }
  }

  void _finishPage() {
    if (!mounted || _allowPop) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final content =
        widget.contentBuilder?.call(context, widget.request.uri) ??
        WebViewWidget(controller: _controller!);
    final page = PopScope<void>(
      canPop: _controller == null || _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_handleBack());
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: widget.request.hideTitleBar
            ? null
            : AppBar(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF222222),
                surfaceTintColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  key: const ValueKey('legacy-web-back'),
                  tooltip: '返回',
                  onPressed: _handleBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                title: Text(
                  widget.request.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                centerTitle: true,
              ),
        body: Stack(
          children: [
            Positioned.fill(child: content),
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
      ),
    );
    if (!widget.request.hideTitleBar) return page;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _immersiveOverlayStyle,
      child: page,
    );
  }
}
