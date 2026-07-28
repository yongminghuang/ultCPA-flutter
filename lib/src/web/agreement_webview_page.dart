import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../startup/privacy_consent_dialog.dart';

typedef AgreementWebContentBuilder =
    Widget Function(BuildContext context, Uri uri);

final class AgreementWebViewPage extends StatefulWidget {
  const AgreementWebViewPage({
    required this.document,
    this.contentBuilder,
    super.key,
  });

  final AgreementDocument document;
  final AgreementWebContentBuilder? contentBuilder;

  @override
  State<AgreementWebViewPage> createState() => _AgreementWebViewPageState();
}

final class _AgreementWebViewPageState extends State<AgreementWebViewPage> {
  WebViewController? _controller;
  int _progress = 100;

  @override
  void initState() {
    super.initState();
    if (widget.contentBuilder == null) {
      _progress = 0;
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
          ),
        )
        ..loadRequest(widget.document.uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content =
        widget.contentBuilder?.call(context, widget.document.uri) ??
        WebViewWidget(controller: _controller!);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF222222),
        elevation: 0,
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          widget.document.label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
    );
  }
}
