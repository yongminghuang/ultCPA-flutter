import 'dart:async';

import 'package:flutter/material.dart';

import '../main_tabs/main_tabs_models.dart';
import '../media/html5_video_player.dart';
import 'teacher_course_models.dart';
import 'teacher_course_progress_store.dart';
import 'teacher_course_repository.dart';

final class TeacherCoursePage extends StatefulWidget {
  const TeacherCoursePage({
    required this.module,
    required this.dataSource,
    required this.progressStore,
    this.videoContentBuilder,
    super.key,
  });

  final HomeModule module;
  final TeacherCourseDataSource dataSource;
  final TeacherCourseProgressStore progressStore;
  final Html5VideoContentBuilder? videoContentBuilder;

  @override
  State<TeacherCoursePage> createState() => _TeacherCoursePageState();
}

final class _TeacherCoursePageState extends State<TeacherCoursePage> {
  TeacherCourseSession? _session;
  Object? _error;
  bool _loading = true;
  int _selectedIndex = 0;
  Duration _initialPosition = Duration.zero;
  int _selectionGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_selectionGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await widget.dataSource.load(widget.module);
      final savedIndex = await widget.progressStore.readCourseIndex(
        session.subject,
      );
      final index = session.items.isEmpty
          ? 0
          : savedIndex.clamp(0, session.items.length - 1).toInt();
      final position = session.items.isEmpty
          ? Duration.zero
          : await widget.progressStore.readMediaPosition(
              session.items[index].id,
            );
      if (!mounted || generation != _selectionGeneration) return;
      setState(() {
        _session = session;
        _selectedIndex = index;
        _initialPosition = position;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _selectionGeneration) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _selectCourse(int index) async {
    final session = _session;
    if (session == null ||
        index < 0 ||
        index >= session.items.length ||
        index == _selectedIndex) {
      return;
    }
    final generation = ++_selectionGeneration;
    await widget.progressStore.writeCourseIndex(session.subject, index);
    final position = await widget.progressStore.readMediaPosition(
      session.items[index].id,
    );
    if (!mounted || generation != _selectionGeneration) return;
    setState(() {
      _selectedIndex = index;
      _initialPosition = position;
    });
  }

  void _savePosition(Duration position) {
    final session = _session;
    if (session == null ||
        _selectedIndex < 0 ||
        _selectedIndex >= session.items.length) {
      return;
    }
    unawaited(
      widget.progressStore.writeMediaPosition(
        session.items[_selectedIndex].id,
        position,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.module.name.trim().isEmpty ? '技巧讲解' : widget.module.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final session = _session;
    if (session == null) {
      return _TeacherCourseFailure(error: _error, onRetry: _load);
    }
    if (session.items.isEmpty) {
      return _TeacherCourseEmpty(onRetry: _load);
    }
    final current = session.items[_selectedIndex];
    return Column(
      children: [
        Html5VideoPlayer(
          key: ValueKey('teacher-course-player-${current.id}'),
          item: current,
          initialPosition: _initialPosition,
          onPositionChanged: _savePosition,
          contentBuilder: widget.videoContentBuilder,
        ),
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                current.title,
                key: const ValueKey('teacher-course-current-title'),
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Text(
                    current.subject,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '首页免费课程',
                      style: TextStyle(
                        color: Color(0xFF237DED),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '课程列表',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            itemCount: session.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = session.items[index];
              return _TeacherCourseRow(
                item: item,
                selected: index == _selectedIndex,
                onTap: () => _selectCourse(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

final class _TeacherCourseRow extends StatelessWidget {
  const _TeacherCourseRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final TeacherCourseItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEAF3FF) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: ValueKey('teacher-course-item-${item.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 96,
                  height: 56,
                  child: item.coverUrl.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFFE5E7EB),
                          child: Icon(
                            Icons.play_circle_outline_rounded,
                            color: Color(0xFF237DED),
                          ),
                        )
                      : Image.network(
                          item.coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFFE5E7EB),
                            child: Icon(
                              Icons.play_circle_outline_rounded,
                              color: Color(0xFF237DED),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF1559A5)
                        : const Color(0xFF374151),
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.equalizer_rounded : Icons.play_arrow_rounded,
                color: selected
                    ? const Color(0xFF237DED)
                    : const Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _TeacherCourseFailure extends StatelessWidget {
  const _TeacherCourseFailure({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 38,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          const Text('课程数据加载失败'),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
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

final class _TeacherCourseEmpty extends StatelessWidget {
  const _TeacherCourseEmpty({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.video_library_outlined,
            size: 40,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          const Text('暂无视频'),
          TextButton(onPressed: onRetry, child: const Text('重新加载')),
        ],
      ),
    );
  }
}
