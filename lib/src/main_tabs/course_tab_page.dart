import 'package:flutter/material.dart';

import 'main_tabs_models.dart';
import 'main_tabs_repository.dart';

final class CourseTabPage extends StatefulWidget {
  const CourseTabPage({
    required this.dataSource,
    this.selectionRevision = 0,
    super.key,
  });

  final MainTabsDataSource dataSource;
  final int selectionRevision;

  @override
  State<CourseTabPage> createState() => _CourseTabPageState();
}

final class _CourseTabPageState extends State<CourseTabPage> {
  CourseType _selectedType = CourseType.intensive;
  String? _selectedSubject;
  CourseTabData? _data;
  Object? _error;
  bool _loading = true;
  int _requestNumber = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CourseTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionRevision != widget.selectionRevision) {
      _selectedSubject = null;
      _load();
    }
  }

  Future<void> _load() async {
    final requestNumber = ++_requestNumber;
    if (mounted) {
      setState(() {
        _loading = _data == null;
        _error = null;
      });
    }
    try {
      final data = await widget.dataSource.loadCourses(
        courseType: _selectedType,
        subject: _selectedSubject,
      );
      if (!mounted || requestNumber != _requestNumber) return;
      setState(() {
        _data = data;
        _selectedSubject = data.selectedSubject.name;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestNumber != _requestNumber) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _selectType(CourseType type) {
    if (_selectedType == type) return;
    setState(() {
      _selectedType = type;
      _data = null;
    });
    _load();
  }

  void _selectSubject(String subject) {
    if (_selectedSubject == subject) return;
    setState(() {
      _selectedSubject = subject;
      _data = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              15,
              MediaQuery.paddingOf(context).top + 20,
              15,
              8,
            ),
            child: const Text(
              '跟名师学习',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 5, 15, 0),
            child: _CourseTypeSelector(
              selected: _selectedType,
              onSelected: _selectType,
            ),
          ),
          if (_data case final data?)
            _SubjectSelector(
              subjects: data.subjects,
              selected: data.selectedSubject,
              onSelected: _selectSubject,
            )
          else
            const SizedBox(height: 50),
          const SizedBox(height: 2),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_data == null) {
      return _CourseLoadFailure(error: _error, onRetry: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF237DED),
      child: _CourseList(data: _data!),
    );
  }
}

final class _CourseTypeSelector extends StatelessWidget {
  const _CourseTypeSelector({required this.selected, required this.onSelected});

  final CourseType selected;
  final ValueChanged<CourseType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7F9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          for (final type in CourseType.values)
            Expanded(
              child: InkWell(
                onTap: () => onSelected(type),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      type.label,
                      style: TextStyle(
                        color: selected == type
                            ? const Color(0xFF1F2937)
                            : const Color(0xFF7C8795),
                        fontSize: 14,
                        fontWeight: selected == type
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    if (selected == type)
                      const Positioned(
                        bottom: 0,
                        child: SizedBox(
                          width: 36,
                          height: 3,
                          child: ColoredBox(color: Color(0xFF237DED)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class _SubjectSelector extends StatelessWidget {
  const _SubjectSelector({
    required this.subjects,
    required this.selected,
    required this.onSelected,
  });

  final List<CategorySubject> subjects;
  final CategorySubject selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: subjects.length,
        separatorBuilder: (context, index) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          final subject = subjects[index];
          final isSelected = subject.id == selected.id;
          return InkWell(
            onTap: () => onSelected(subject.name),
            child: Center(
              child: Text(
                subject.name,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF33333D)
                      : const Color(0xFF848489),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

final class _CourseList extends StatelessWidget {
  const _CourseList({required this.data});

  final CourseTabData data;

  @override
  Widget build(BuildContext context) {
    if (data.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 96),
          Icon(
            Icons.video_library_outlined,
            color: Color(0xFF94A3B8),
            size: 36,
          ),
          SizedBox(height: 12),
          Center(
            child: Text('暂无课程', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(15, 4, 15, 24),
      itemCount: data.items.length,
      separatorBuilder: (context, index) => const Divider(height: 25),
      itemBuilder: (context, index) => _CourseRow(item: data.items[index]),
    );
  }
}

final class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.item});

  final CourseMedia item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 136,
              height: 78,
              child: item.coverUrl.isEmpty
                  ? const _CourseCoverFallback()
                  : Image.network(
                      item.coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const _CourseCoverFallback(),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
        ],
      ),
    );
  }
}

final class _CourseCoverFallback extends StatelessWidget {
  const _CourseCoverFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFEFF4FA),
      child: Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: Color(0xFF237DED),
          size: 34,
        ),
      ),
    );
  }
}

final class _CourseLoadFailure extends StatelessWidget {
  const _CourseLoadFailure({required this.error, required this.onRetry});

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
            color: Color(0xFF94A3B8),
            size: 36,
          ),
          const SizedBox(height: 12),
          const Text('课程加载失败'),
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
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新加载'),
          ),
        ],
      ),
    );
  }
}
