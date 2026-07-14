import 'dart:math';
import 'package:vinci_board/core/models/lms/lesson.dart';
import 'package:vinci_board/core/models/lms/student_progress.dart';
import 'package:vinci_board/core/ports/i_lms_adapter.dart';

class MockLmsAdapter implements ILmsAdapter {
  @override
  String get providerName => 'Mock LMS (Local Testing)';

  final List<StudentProgress> _mockData = [];
  final Random _random = Random();

  @override
  Future<String> distributeLesson(Lesson lesson) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Generate mock students
    _mockData.clear();
    final names = [
      'Alice Smith',
      'Bob Jones',
      'Charlie Brown',
      'Diana Prince',
      'Evan Wright',
      'Fiona Gallagher',
      'George Costanza',
      'Hannah Abbott',
      'Ian Malcolm',
      'Jessica Day',
      'Kevin Malone',
      'Leslie Knope',
      'Michael Scott',
      'Nina Sharp',
      'Oscar Martinez',
      'Pam Beesly',
      'Quinn Fabray',
      'Ron Swanson',
      'Sarah Connor',
      'Tom Haverford',
      'Ursula Buffay',
      'Victor Fries',
      'Walter White',
      'Xena Warrior',
      'Yoshi Dinosaur',
      'Zelda Princess',
    ];

    for (int i = 0; i < 20; i++) {
      _mockData.add(
        StudentProgress(
          studentId: 'stu_${i.toString().padLeft(3, '0')}',
          studentName: names[i % names.length],
          lessonId: lesson.id,
          completionPercentage: _random.nextDouble(),
          confidenceScore: _random.nextDouble(),
          lastUpdated: DateTime.now().subtract(
            Duration(minutes: _random.nextInt(60)),
          ),
        ),
      );
    }

    return 'mock_dist_id_${lesson.id}';
  }

  @override
  Future<List<StudentProgress>> fetchAnalytics(String lessonId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Simulate students making progress over time
    for (int i = 0; i < _mockData.length; i++) {
      final current = _mockData[i];
      if (current.completionPercentage < 1.0 && _random.nextDouble() > 0.7) {
        _mockData[i] = StudentProgress(
          studentId: current.studentId,
          studentName: current.studentName,
          lessonId: current.lessonId,
          completionPercentage: min(
            1.0,
            current.completionPercentage + (_random.nextDouble() * 0.2),
          ),
          confidenceScore: min(
            1.0,
            current.confidenceScore + (_random.nextDouble() * 0.1),
          ),
          lastUpdated: DateTime.now(),
        );
      }
    }

    return List.from(_mockData);
  }
}
