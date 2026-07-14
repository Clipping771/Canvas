import 'package:vinci_board/core/models/lms/lesson.dart';
import 'package:vinci_board/core/models/lms/student_progress.dart';
import 'package:vinci_board/core/ports/i_lms_adapter.dart';

class GoogleClassroomAdapter implements ILmsAdapter {
  @override
  String get providerName => 'Google Classroom';

  @override
  Future<String> distributeLesson(Lesson lesson) async {
    // TODO: Implement Google Classroom API integration
    throw UnimplementedError(
      'GoogleClassroomAdapter.distributeLesson is not yet implemented',
    );
  }

  @override
  Future<List<StudentProgress>> fetchAnalytics(String lessonId) async {
    // TODO: Implement Google Classroom API integration
    throw UnimplementedError(
      'GoogleClassroomAdapter.fetchAnalytics is not yet implemented',
    );
  }
}
