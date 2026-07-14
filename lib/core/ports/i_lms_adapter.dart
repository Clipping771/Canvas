import 'package:vinci_board/core/models/lms/lesson.dart';
import 'package:vinci_board/core/models/lms/student_progress.dart';

abstract class ILmsAdapter {
  String get providerName;

  /// Distributes a lesson to the class and returns the unique distribution ID.
  Future<String> distributeLesson(Lesson lesson);

  /// Fetches the current progress of all students for a specific lesson.
  Future<List<StudentProgress>> fetchAnalytics(String lessonId);
}
