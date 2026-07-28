import '../main_tabs/main_tabs_models.dart';

final class TeacherCourseItem {
  const TeacherCourseItem({
    required this.id,
    required this.subject,
    required this.courseType,
    required this.title,
    required this.coverUrl,
    required this.mediaUrl,
  });

  final int id;
  final String subject;
  final String courseType;
  final String title;
  final String coverUrl;
  final String mediaUrl;

  bool get hasPlayableMedia => Uri.tryParse(mediaUrl)?.hasScheme == true;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TeacherCourseItem &&
            other.id == id &&
            other.subject == subject &&
            other.courseType == courseType &&
            other.title == title &&
            other.coverUrl == coverUrl &&
            other.mediaUrl == mediaUrl;
  }

  @override
  int get hashCode =>
      Object.hash(id, subject, courseType, title, coverUrl, mediaUrl);
}

final class TeacherCourseSession {
  TeacherCourseSession({
    required this.module,
    required this.subject,
    required List<TeacherCourseItem> items,
  }) : items = List<TeacherCourseItem>.unmodifiable(items);

  final HomeModule module;
  final String subject;
  final List<TeacherCourseItem> items;
}
