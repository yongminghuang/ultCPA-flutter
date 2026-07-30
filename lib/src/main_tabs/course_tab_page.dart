import 'package:flutter/material.dart';

import 'main_tabs_models.dart';
import 'main_tabs_repository.dart';

typedef CourseMediaLauncher =
    Future<void> Function(
      BuildContext context,
      CourseMedia media,
      CourseTabData data,
    );

final class CourseTabPage extends StatefulWidget {
  const CourseTabPage({
    required this.dataSource,
    this.selectionRevision = 0,
    this.mediaLauncher,
    this.now,
    super.key,
  });

  final MainTabsDataSource dataSource;
  final int selectionRevision;
  final CourseMediaLauncher? mediaLauncher;
  final DateTime Function()? now;

  @override
  State<CourseTabPage> createState() => _CourseTabPageState();
}

final class _CourseTabPageState extends State<CourseTabPage> {
  // Android 初级课程默认停在「技巧密押」。中级会计会在拿到分类后切回
  // 「技巧精讲」，因为 MainTabsDataSource 当前没有独立的同步分类快照。
  CourseType _selectedType = CourseType.secret;
  String? _selectedSubject;
  CourseTabData? _data;
  Object? _error;
  bool _loading = true;
  bool _resolvedInitialCourseType = false;
  int _requestNumber = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CourseTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataSource != widget.dataSource ||
        oldWidget.selectionRevision != widget.selectionRevision) {
      _selectedSubject = null;
      _load();
    }
  }

  Future<void> _load() async {
    final requestNumber = ++_requestNumber;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await widget.dataSource.loadCourses(
        courseType: _selectedType,
        subject: _selectedSubject,
      );
      if (!mounted || requestNumber != _requestNumber) return;

      final isIntermediate = _isIntermediateAccounting(data.categoryLabel);
      CourseType? correctedType;
      if (!_resolvedInitialCourseType) {
        _resolvedInitialCourseType = true;
        final initialType = isIntermediate
            ? CourseType.intensive
            : CourseType.secret;
        if (_selectedType != initialType) correctedType = initialType;
      } else if (isIntermediate && _selectedType == CourseType.emergency) {
        correctedType = CourseType.intensive;
      }
      if (correctedType != null) {
        setState(() {
          _selectedType = correctedType!;
          _selectedSubject = null;
          _loading = true;
        });
        await _load();
        return;
      }

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
      _showMessage('加载失败');
    }
  }

  void _selectType(CourseType type) {
    if (_selectedType == type) return;
    if (_isCourseTypeLocked(type)) {
      _showMessage('课程未开始');
      return;
    }
    setState(() {
      _selectedType = type;
      _loading = true;
    });
    _load();
  }

  void _selectSubject(String subject) {
    if (_selectedSubject == subject) return;
    setState(() {
      _selectedSubject = subject;
      _loading = true;
    });
    _load();
  }

  bool _isCourseTypeLocked(CourseType type) {
    return type == CourseType.emergency &&
        _isIntermediateAccounting(_data?.categoryLabel ?? '');
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final schedules = data == null
        ? const <_LiveScheduleItem>[]
        : _liveSchedules(
            categoryLabel: data.categoryLabel,
            now: (widget.now ?? DateTime.now)(),
          );
    final topPadding = MediaQuery.paddingOf(context).top;
    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (schedules.isNotEmpty)
            _LiveCourseSection(items: schedules, safeTop: topPadding),
          Padding(
            padding: EdgeInsets.fromLTRB(
              15,
              schedules.isEmpty ? topPadding + 14 : 14,
              15,
              8,
            ),
            child: const Text(
              '跟名师学习',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 5, 15, 0),
            child: _CourseTypeSelector(
              selected: _selectedType,
              isLocked: _isCourseTypeLocked,
              onSelected: _selectType,
            ),
          ),
          const SizedBox(height: 10),
          if (data != null)
            _SubjectSelector(
              subjects: data.subjects,
              selectedName: _selectedSubject ?? data.selectedSubject.name,
              onSelected: _selectSubject,
            )
          else
            const SizedBox(height: 40),
          const SizedBox(height: 10),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final data = _data;
    if (_loading || _error != null || data == null) {
      return const SizedBox.expand();
    }
    return _CourseList(
      data: data,
      onItemTap: widget.mediaLauncher == null
          ? null
          : (media) => widget.mediaLauncher!(context, media, data),
    );
  }
}

final class _CourseTypeSelector extends StatelessWidget {
  const _CourseTypeSelector({
    required this.selected,
    required this.isLocked,
    required this.onSelected,
  });

  final CourseType selected;
  final bool Function(CourseType type) isLocked;
  final ValueChanged<CourseType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final type in CourseType.values)
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey('course-type-${type.name}'),
                  onTap: () => onSelected(type),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    key: selected == type
                        ? ValueKey('course-type-selected-${type.name}')
                        : null,
                    decoration: selected == type
                        ? BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          )
                        : null,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLocked(type)) ...[
                          Icon(
                            Icons.lock,
                            key: ValueKey('course-type-lock-${type.name}'),
                            size: 12,
                            color: const Color(0xFFD1D5DB),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          type.label,
                          style: TextStyle(
                            color: selected == type
                                ? const Color(0xFF111827)
                                : const Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
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
    required this.selectedName,
    required this.onSelected,
  });

  final List<CategorySubject> subjects;
  final String selectedName;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 12),
        itemCount: subjects.length,
        itemBuilder: (context, index) {
          final subject = subjects[index];
          final selected = subject.name == selectedName;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('course-subject-${subject.id}'),
              onTap: () => onSelected(subject.name),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          subject.name,
                          style: TextStyle(
                            color: selected
                                ? const Color(0xFF111827)
                                : const Color(0xFF6B7280),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 24,
                      height: 3,
                      child: selected
                          ? const ColoredBox(color: Color(0xFF2E7CF6))
                          : null,
                    ),
                  ],
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
  const _CourseList({required this.data, this.onItemTap});

  final CourseTabData data;
  final Future<void> Function(CourseMedia media)? onItemTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(15, 0, 15, 24),
      itemCount: data.items.length,
      itemBuilder: (context, index) {
        final item = data.items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CourseRow(
            item: item,
            onTap: onItemTap == null ? null : () => onItemTap!(item),
          ),
        );
      },
    );
  }
}

final class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.item, this.onTap});

  final CourseMedia item;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        key: ValueKey('course-media-${item.id}'),
        onTap: onTap,
        child: SizedBox(
          height: 109,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  key: ValueKey('course-cover-${item.id}'),
                  width: 130,
                  height: 85,
                  child: item.coverUrl.isEmpty
                      ? const ColoredBox(color: Color(0xFFF5F5F5))
                      : Image.network(
                          item.coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const ColoredBox(color: Color(0xFFF5F5F5)),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          key: ValueKey('course-enter-study-${item.id}'),
                          height: 28,
                          child: TextButton(
                            onPressed: onTap,
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: const Color(0xFF237DED),
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: const Text('进入学习'),
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
      ),
    );
  }
}

final class _LiveCourseSection extends StatelessWidget {
  const _LiveCourseSection({required this.items, required this.safeTop});

  final List<_LiveScheduleItem> items;
  final double safeTop;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(15, safeTop < 44 ? 44 : safeTop, 15, 0),
          child: const Text(
            '直播日历',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) =>
                _LiveScheduleCard(item: items[index], index: index),
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(
          height: 10,
          width: double.infinity,
          child: ColoredBox(color: Color(0xFFF2F7F9)),
        ),
      ],
    );
  }
}

final class _LiveScheduleCard extends StatelessWidget {
  const _LiveScheduleCard({required this.item, required this.index});

  final _LiveScheduleItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final secondary = item.selected
        ? const Color(0xFF4A90E2)
        : const Color(0xFFA1A9B2);
    return Container(
      key: ValueKey('live-schedule-$index'),
      width: 100,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: item.selected ? const Color(0xFFEBF3FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.selected
              ? const Color(0xFFD1E4FF)
              : const Color(0xFFE3E3E4),
        ),
      ),
      child: Column(
        children: [
          Text(item.week, style: TextStyle(color: secondary, fontSize: 14)),
          const SizedBox(height: 4),
          Text(item.date, style: TextStyle(color: secondary, fontSize: 14)),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: item.selected
                      ? const Color(0xFF4A90E2)
                      : const Color(0xFF36414D),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(item.time, style: TextStyle(color: secondary, fontSize: 11)),
        ],
      ),
    );
  }
}

final class _LiveScheduleRaw {
  const _LiveScheduleRaw(this.date, this.week, this.time, this.title);

  final DateTime date;
  final String week;
  final String time;
  final String title;
}

final class _LiveScheduleItem {
  const _LiveScheduleItem({
    required this.week,
    required this.date,
    required this.time,
    required this.title,
    required this.selected,
  });

  final String week;
  final String date;
  final String time;
  final String title;
  final bool selected;
}

List<_LiveScheduleItem> _liveSchedules({
  required String categoryLabel,
  required DateTime now,
}) {
  final raw = categoryLabel.contains('会计')
      ? _accountingSchedules
      : _socialWorkSchedules;
  final today = DateTime(now.year, now.month, now.day);
  final upcoming = raw
      .where((item) => !item.date.isBefore(today))
      .toList(growable: false);
  if (upcoming.isEmpty) return const [];

  var nearestIndex = 0;
  var nearestDifference = upcoming.first.date.difference(today);
  for (var index = 1; index < upcoming.length; index++) {
    final difference = upcoming[index].date.difference(today);
    if (difference < nearestDifference) {
      nearestDifference = difference;
      nearestIndex = index;
    }
  }
  return [
    for (var index = 0; index < upcoming.length; index++)
      _LiveScheduleItem(
        week: upcoming[index].week,
        date:
            '${upcoming[index].date.month.toString().padLeft(2, '0')}.'
            '${upcoming[index].date.day.toString().padLeft(2, '0')}',
        time: upcoming[index].time,
        title: upcoming[index].title,
        selected: index == nearestIndex,
      ),
  ];
}

bool _isIntermediateAccounting(String label) => label.trim() == '中级会计';

final _accountingSchedules = <_LiveScheduleRaw>[
  _LiveScheduleRaw(DateTime(2026, 4, 15), '星期三', '19:00-21:00', '【大招急救】急救阶段5'),
  _LiveScheduleRaw(DateTime(2026, 4, 20), '星期一', '19:00-21:00', '【大招急救】急救阶段6'),
  _LiveScheduleRaw(DateTime(2026, 4, 22), '星期三', '19:00-21:00', '【大招急救】急救阶段7'),
  _LiveScheduleRaw(DateTime(2026, 4, 27), '星期一', '19:00-21:00', '【大招急救】急救阶段8'),
  _LiveScheduleRaw(DateTime(2026, 4, 29), '星期三', '19:00-21:00', '【大招急救】急救阶段9'),
  _LiveScheduleRaw(DateTime(2026, 5, 4), '星期一', '19:00-21:00', '【大招急救】急救阶段10'),
  _LiveScheduleRaw(DateTime(2026, 5, 9), '星期六', '15:00-17:00', '【压轴6小时】'),
  _LiveScheduleRaw(DateTime(2026, 5, 11), '星期一', '19:00-21:00', '【压轴6小时】'),
  _LiveScheduleRaw(DateTime(2026, 5, 11), '星期一', '19:00-21:00', '【压轴6小时】'),
];

final _socialWorkSchedules = <_LiveScheduleRaw>[
  _LiveScheduleRaw(
    DateTime(2026, 4, 17),
    '星期五',
    '15:00-16:30',
    '【初级能力-大招密押班】专题八',
  ),
  _LiveScheduleRaw(
    DateTime(2026, 4, 21),
    '星期二',
    '15:00-16:30',
    '【初级能力-大招密押班】专题九',
  ),
  _LiveScheduleRaw(
    DateTime(2026, 4, 24),
    '星期五',
    '15:00-16:30',
    '【初级能力-大招密押班】专题十',
  ),
  _LiveScheduleRaw(
    DateTime(2026, 4, 28),
    '星期二',
    '15:00-16:30',
    '【初级能力-大招密押班】专题十一',
  ),
  _LiveScheduleRaw(
    DateTime(2026, 5, 1),
    '星期五',
    '15:00-16:30',
    '【初级能力-大招密押班】专题十二',
  ),
  _LiveScheduleRaw(
    DateTime(2026, 5, 3),
    '星期日',
    '15:00-16:30',
    '【初级能力-VIP密训班】专题五',
  ),
  _LiveScheduleRaw(
    DateTime(2026, 5, 5),
    '星期二',
    '15:00-16:30',
    '【初级能力-大招急救班】专题一',
  ),
  _LiveScheduleRaw(
    DateTime(2026, 5, 8),
    '星期五',
    '15:00-16:30',
    '【初级能力-大招急救班】专题二',
  ),
  _LiveScheduleRaw(
    DateTime(2026, 5, 12),
    '星期二',
    '15:00-16:30',
    '【初级能力-大招急救班】专题三',
  ),
  _LiveScheduleRaw(
    DateTime(2026, 5, 15),
    '星期五',
    '15:00-16:30',
    '【初级能力-大招急救班】专题四',
  ),
];
