import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../main_tabs/main_tabs_models.dart';
import 'pre_exam_six_paper_file_transfer.dart';
import 'pre_exam_six_paper_models.dart';
import 'pre_exam_six_paper_repository.dart';

typedef PreExamSixPaperContentBuilder =
    Widget Function(
      BuildContext context, {
      required String? url,
      required String? html,
      required String baseUrl,
    });

final class PreExamSixPaperPreviewPage extends StatefulWidget {
  const PreExamSixPaperPreviewPage({
    required this.module,
    required this.dataSource,
    required this.fileTransfer,
    this.initialFile,
    this.contentBuilder,
    this.fileExists,
    this.now,
    super.key,
  });

  final HomeModule module;
  final PreExamSixPaperDataSource dataSource;
  final PreExamSixPaperFileTransfer fileTransfer;
  final PreExamSixPaperFile? initialFile;
  final PreExamSixPaperContentBuilder? contentBuilder;
  final bool Function(String path)? fileExists;
  final DateTime Function()? now;

  @override
  State<PreExamSixPaperPreviewPage> createState() =>
      _PreExamSixPaperPreviewPageState();
}

final class _PreExamSixPaperPreviewPageState
    extends State<PreExamSixPaperPreviewPage> {
  late PreExamSixPaperFile? _file = widget.initialFile;
  late bool _loading = widget.initialFile == null;
  Object? _loadError;
  String? _downloadedPath;
  bool _downloading = false;
  bool _sharing = false;
  int _loadGeneration = 0;
  int _transferGeneration = 0;
  final ValueNotifier<_DownloadProgress> _downloadProgress = ValueNotifier(
    const _DownloadProgress(0, 0),
  );

  @override
  void initState() {
    super.initState();
    if (_file == null) _loadFile();
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    _transferGeneration += 1;
    widget.fileTransfer.cancel();
    _downloadProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          limitPreExamSixPaperTitle(_file?.name ?? ''),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        actions: [
          TextButton(
            key: const ValueKey('pre-exam-six-preview-download'),
            onPressed: _download,
            child: const Text('下载', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        key: ValueKey('pre-exam-six-preview-loading'),
        child: CircularProgressIndicator(),
      );
    }
    final content = _resolveContent(_file);
    if (content == null) {
      return Center(
        key: const ValueKey('pre-exam-six-preview-empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '题库更新中',
              style: TextStyle(color: Color(0xFF999999), fontSize: 14),
            ),
            if (_loadError != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: _loadFile, child: const Text('重试')),
            ],
          ],
        ),
      );
    }
    final builder = widget.contentBuilder;
    return KeyedSubtree(
      key: const ValueKey('pre-exam-six-preview-content'),
      child: builder != null
          ? builder(
              context,
              url: content.url,
              html: content.html,
              baseUrl: content.baseUrl,
            )
          : _PreExamSixPaperWebContent(
              key: ValueKey(
                '${content.url}|${content.html.hashCode}|${content.baseUrl}',
              ),
              url: content.url,
              html: content.html,
              baseUrl: content.baseUrl,
            ),
    );
  }

  Future<void> _loadFile() async {
    final generation = ++_loadGeneration;
    if (!_loading && mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final file = await widget.dataSource.loadFile(widget.module);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _file = file;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _file = null;
        _loading = false;
        _loadError = error;
        _downloadedPath = null;
      });
      _showMessage('网络开小差了，请稍后重试');
    }
  }

  _ResolvedContent? _resolveContent(PreExamSixPaperFile? file) {
    if (file == null) return null;
    final rawUrl = file.textUrl.trim();
    if (rawUrl.isNotEmpty) {
      final uri = Uri.tryParse(rawUrl);
      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        return null;
      }
      return _ResolvedContent(
        url: rawUrl,
        html: null,
        baseUrl: file.htmlBaseUrl,
      );
    }
    if (file.text.trim().isEmpty) return null;
    return _ResolvedContent(
      url: null,
      html: buildPreExamSixPaperHtml(file.text, ossDomain: file.htmlBaseUrl),
      baseUrl: file.htmlBaseUrl,
    );
  }

  Future<void> _download() async {
    if (_downloading || _sharing) return;
    final file = _file;
    if (file == null || file.fileUrl.trim().isEmpty) {
      _showMessage('暂无可用文件下载');
      return;
    }

    final cachedPath = _downloadedPath;
    if (cachedPath != null) {
      final exists = _fileExists(cachedPath);
      if (exists) {
        await _showDownloadedDialog(cachedPath);
        return;
      }
      _downloadedPath = null;
    }

    final generation = ++_transferGeneration;
    setState(() => _downloading = true);
    _downloadProgress.value = const _DownloadProgress(0, 0);
    final progressDialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            key: const ValueKey('pre-exam-six-download-progress'),
            title: const Text('下载文件'),
            content: ValueListenableBuilder<_DownloadProgress>(
              valueListenable: _downloadProgress,
              builder: (_, progress, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: progress.fraction),
                    const SizedBox(height: 12),
                    Text(progress.label),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    try {
      final path = await widget.fileTransfer.download(
        url: file.fileUrl,
        fileName: preExamSixPaperDownloadFileName(file, now: widget.now),
        onProgress: (received, total) {
          if (!mounted || generation != _transferGeneration) return;
          _downloadProgress.value = _DownloadProgress(received, total);
        },
      );
      if (!mounted || generation != _transferGeneration) return;
      await _dismissProgressDialog(progressDialog);
      if (!mounted || generation != _transferGeneration) return;
      setState(() {
        _downloading = false;
        _downloadedPath = path;
      });
      await _showDownloadedDialog(path);
    } catch (_) {
      if (!mounted || generation != _transferGeneration) return;
      await _dismissProgressDialog(progressDialog);
      if (!mounted || generation != _transferGeneration) return;
      setState(() => _downloading = false);
      _showMessage('下载失败，请稍后重试');
    }
  }

  Future<void> _dismissProgressDialog(Future<void> dialogFuture) async {
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      await dialogFuture;
    }
  }

  Future<void> _showDownloadedDialog(String path) {
    if (!mounted) return Future<void>.value();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: const ValueKey('pre-exam-six-download-complete'),
          title: const Text('下载完成'),
          content: Text(path, maxLines: 2, overflow: TextOverflow.ellipsis),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
            FilledButton(
              key: const ValueKey('pre-exam-six-download-share'),
              onPressed: () => _share(path, dialogContext),
              child: const Text('分享'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _share(String path, BuildContext dialogContext) async {
    if (_sharing || _downloading) return;
    _sharing = true;
    try {
      await widget.fileTransfer.share(
        path: path,
        mimeType: preExamSixPaperShareMimeType(path),
      );
      if (mounted && dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }
    } catch (_) {
      if (mounted) _showMessage('分享失败');
    } finally {
      _sharing = false;
    }
  }

  bool _fileExists(String path) {
    try {
      final checker = widget.fileExists;
      return checker == null ? File(path).existsSync() : checker(path);
    } catch (_) {
      return false;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _ResolvedContent {
  const _ResolvedContent({
    required this.url,
    required this.html,
    required this.baseUrl,
  });

  final String? url;
  final String? html;
  final String baseUrl;
}

final class _DownloadProgress {
  const _DownloadProgress(this.received, this.total);

  final int received;
  final int total;

  double? get fraction {
    if (total <= 0) return null;
    return (received / total).clamp(0, 1).toDouble();
  }

  String get label {
    if (total <= 0) return '准备下载';
    return '${((received / total) * 100).clamp(0, 100).round()}%';
  }
}

final class _PreExamSixPaperWebContent extends StatefulWidget {
  const _PreExamSixPaperWebContent({
    required this.url,
    required this.html,
    required this.baseUrl,
    super.key,
  });

  final String? url;
  final String? html;
  final String baseUrl;

  @override
  State<_PreExamSixPaperWebContent> createState() =>
      _PreExamSixPaperWebContentState();
}

final class _PreExamSixPaperWebContentState
    extends State<_PreExamSixPaperWebContent> {
  late final WebViewController _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
        ),
      );
    final url = widget.url;
    if (url != null) {
      _controller.loadRequest(Uri.parse(url));
    } else {
      _controller.loadHtmlString(widget.html ?? '', baseUrl: widget.baseUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: WebViewWidget(controller: _controller)),
        if (_progress < 100)
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 2,
              child: LinearProgressIndicator(value: _progress / 100),
            ),
          ),
      ],
    );
  }
}
