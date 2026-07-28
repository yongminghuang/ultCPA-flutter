import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import 'app_update_file_transfer.dart';
import 'app_update_models.dart';

Future<void> showAppUpdateDialog({
  required BuildContext context,
  required AppUpdateInfo info,
  required AppUpdateFileTransfer fileTransfer,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: !info.isForceUpdate,
    builder: (_) => AppUpdateDialog(info: info, fileTransfer: fileTransfer),
  );
}

final class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({
    required this.info,
    required this.fileTransfer,
    super.key,
  });

  final AppUpdateInfo info;
  final AppUpdateFileTransfer fileTransfer;

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

final class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _working = false;
  bool _downloading = false;
  bool _downloadFailed = false;
  int _received = 0;
  int _total = 0;
  String? _downloadedPath;

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final width = math.min(360.0, math.max(240.0, mediaSize.width - 48));
    final height = math.min(480.0, math.max(320.0, mediaSize.height - 48));
    return PopScope<void>(
      canPop: !widget.info.isForceUpdate,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: width,
          height: height,
          child: Column(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      children: [
                        const _UpdateHeader(),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                            child: _UpdateDetails(info: widget.info),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          child: _buildAction(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!widget.info.isForceUpdate) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    key: const ValueKey('app-update-close'),
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xCC1F2937),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAction() {
    if (_downloading) {
      final ratio = _total > 0 ? (_received / _total).clamp(0.0, 1.0) : null;
      final label = ratio == null ? '准备中...' : '${(ratio * 100).floor()}%';
      return SizedBox(
        width: 180,
        height: 40,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              LinearProgressIndicator(
                key: const ValueKey('app-update-progress'),
                value: ratio,
                backgroundColor: const Color(0xFFDDE8F8),
                color: const Color(0xFF237DED),
              ),
              Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      width: 180,
      height: 40,
      child: FilledButton(
        key: const ValueKey('app-update-action'),
        onPressed: _working ? null : _handleAction,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF237DED),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          _downloadFailed
              ? '下载失败'
              : _downloadedPath == null
              ? '立即更新'
              : '立即安装',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _handleAction() async {
    if (_working) return;
    if (_downloadFailed) {
      Navigator.of(context).pop();
      return;
    }
    final downloadedPath = _downloadedPath;
    if (downloadedPath != null) {
      await _install(downloadedPath);
      return;
    }
    switch (widget.info.target) {
      case AppUpdateTarget.applicationMarket:
        await _openAndDismiss(widget.fileTransfer.openMarket);
      case AppUpdateTarget.externalUrl:
        await _openAndDismiss(
          () => widget.fileTransfer.openExternal(widget.info.rawUrl),
        );
      case AppUpdateTarget.apkDownload:
        await _downloadAndInstall();
    }
  }

  Future<void> _openAndDismiss(Future<void> Function() open) async {
    setState(() => _working = true);
    try {
      await open();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _downloadAndInstall() async {
    setState(() {
      _working = true;
      _downloading = true;
      _downloadFailed = false;
      _received = 0;
      _total = 0;
    });
    late final String path;
    try {
      path = await widget.fileTransfer.download(
        url: widget.info.downloadUrl,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _received = received;
            _total = total;
          });
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _working = false;
          _downloading = false;
          _downloadFailed = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _downloadedPath = path;
        _downloading = false;
      });
    }
    await _install(path, preserveWorkingState: true);
  }

  Future<void> _install(
    String path, {
    bool preserveWorkingState = false,
  }) async {
    if (mounted && !preserveWorkingState) setState(() => _working = true);
    try {
      await widget.fileTransfer.install(path);
    } catch (_) {
      // The visible install action remains available for another attempt.
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}

final class _UpdateHeader extends StatelessWidget {
  const _UpdateHeader();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF237DED),
      child: SizedBox(
        width: double.infinity,
        height: 76,
        child: Center(
          child: Text(
            '发现新版本',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

final class _UpdateDetails extends StatelessWidget {
  const _UpdateDetails({required this.info});

  final AppUpdateInfo info;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _VersionLine(label: '最新版本：', value: 'v${info.latestVersion}'),
        const SizedBox(height: 8),
        const _VersionLine(
          label: '当前版本：',
          value: 'v${AppIdentity.versionName}',
        ),
        const SizedBox(height: 18),
        const Text(
          '更新内容：',
          style: TextStyle(color: Color(0xFF237DED), fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          info.description,
          style: const TextStyle(
            color: Color(0xFF4B5563),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

final class _VersionLine extends StatelessWidget {
  const _VersionLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF237DED), fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14),
          ),
        ),
      ],
    );
  }
}
