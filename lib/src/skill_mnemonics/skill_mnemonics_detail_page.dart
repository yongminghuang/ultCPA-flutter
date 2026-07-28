import 'dart:async';

import 'package:flutter/material.dart';

import '../main_tabs/main_tabs_models.dart';
import 'skill_mnemonics_models.dart';
import 'skill_mnemonics_text.dart';

typedef SkillMnemonicPracticeLauncher =
    Future<void> Function(
      BuildContext context,
      SkillMnemonic item,
      int position,
      HomeModule module,
    );

final class SkillMnemonicsDetailPage extends StatefulWidget {
  const SkillMnemonicsDetailPage({
    required this.item,
    required this.position,
    required this.module,
    this.practiceLauncher,
    this.tickDuration = const Duration(seconds: 1),
    super.key,
  });

  final SkillMnemonic item;
  final int position;
  final HomeModule module;
  final SkillMnemonicPracticeLauncher? practiceLauncher;
  final Duration tickDuration;

  @override
  State<SkillMnemonicsDetailPage> createState() =>
      _SkillMnemonicsDetailPageState();
}

final class _SkillMnemonicsDetailPageState
    extends State<SkillMnemonicsDetailPage> {
  Timer? _timer;
  int _remainingSeconds = 30;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.tickDuration, (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        _timer?.cancel();
        setState(() => _remainingSeconds = 0);
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _openPractice() {
    final launcher = widget.practiceLauncher;
    if (launcher == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('关联做题功能仍在迁移中')));
      return;
    }
    unawaited(launcher(context, widget.item, widget.position, widget.module));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '技巧记忆',
              style: TextStyle(color: Colors.black, fontSize: 18),
            ),
            const SizedBox(width: 8),
            Text(
              _formattedTime(_remainingSeconds),
              style: const TextStyle(color: Color(0xFF0BA0E9), fontSize: 18),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
        children: [
          const _SectionLabel(label: '技巧口诀'),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9EFD9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SkillMnemonicHighlightedText(
              key: const ValueKey('mnemonic-detail-text'),
              text: widget.item.displayText,
              terms: widget.item.keywordTerms,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF515B65),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F7F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFC340),
                      size: 20,
                    ),
                    SizedBox(width: 2),
                    Text(
                      '技巧解析',
                      style: TextStyle(color: Color(0xFF36414D), fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SkillMnemonicHighlightedText(
                  key: const ValueKey('mnemonic-detail-explanation'),
                  text: widget.item.note,
                  terms: widget.item.keywordTerms,
                  style: const TextStyle(
                    color: Color(0xFF515B65),
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Material(
          color: const Color(0xFF0BA0E9),
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('mnemonic-practice-action'),
            onTap: _openPractice,
            child: SizedBox(
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      children: [
                        const TextSpan(text: '掌握该技巧能做 '),
                        TextSpan(
                          text: '${widget.item.questionCount}',
                          style: const TextStyle(
                            color: Color(0xFFFFE0B2),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const TextSpan(text: ' 题'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFFFE7C2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFFC28B3E), fontSize: 18),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFFFE7C2))),
      ],
    );
  }
}

String _formattedTime(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${remainder.toString().padLeft(2, '0')}';
}
