import 'package:vinci_board/core/models/lms/lesson.dart';
import 'package:vinci_board/core/models/lms/student_progress.dart';
import 'package:vinci_board/core/ports/i_lms_adapter.dart';

class CanvasLmsAdapter implements ILmsAdapter {
  @override
  String get providerName => 'Canvas LMS';

  @override
  Future<String> distributeLesson(Lesson lesson) async {
    // TODO: Implement Canvas LMS API integration
    throw UnimplementedError(
      'CanvasLmsAdapter.distributeLesson is not yet implemented',
    );
  }

  @override
  Future<List<StudentProgress>> fetchAnalytics(String lessonId) async {
    // TODO: Implement Canvas LMS API integration
    throw UnimplementedError(
      'CanvasLmsAdapter.fetchAnalytics is not yet implemented',
    );
  }
}
