import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/core/models/lms/lesson.dart';
import 'package:vinci_board/core/models/lms/student_progress.dart';
import 'package:vinci_board/core/ports/i_lms_adapter.dart';
import 'package:vinci_board/adapters/lms/mock_lms_adapter.dart';

final lmsProvider = NotifierProvider<LmsNotifier, LmsState>(LmsNotifier.new);

class LmsState {
  final ILmsAdapter adapter;
  final bool isDistributing;
  final String? lastDistributedLessonId;
  final bool isFetchingAnalytics;
  final List<StudentProgress> currentAnalytics;

  LmsState({
    required this.adapter,
    this.isDistributing = false,
    this.lastDistributedLessonId,
    this.isFetchingAnalytics = false,
    this.currentAnalytics = const [],
  });

  LmsState copyWith({
    ILmsAdapter? adapter,
    bool? isDistributing,
    String? lastDistributedLessonId,
    bool? isFetchingAnalytics,
    List<StudentProgress>? currentAnalytics,
  }) {
    return LmsState(
      adapter: adapter ?? this.adapter,
      isDistributing: isDistributing ?? this.isDistributing,
      lastDistributedLessonId:
          lastDistributedLessonId ?? this.lastDistributedLessonId,
      isFetchingAnalytics: isFetchingAnalytics ?? this.isFetchingAnalytics,
      currentAnalytics: currentAnalytics ?? this.currentAnalytics,
    );
  }
}

class LmsNotifier extends Notifier<LmsState> {
  @override
  LmsState build() => LmsState(adapter: MockLmsAdapter());

  void setAdapter(ILmsAdapter adapter) {
    state = state.copyWith(adapter: adapter);
  }

  Future<String> distributeCurrentLesson(
    String title,
    String contentUrl,
  ) async {
    state = state.copyWith(isDistributing: true);

    final lesson = Lesson(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      contentUrl: contentUrl,
      createdAt: DateTime.now(),
    );

    try {
      final id = await state.adapter.distributeLesson(lesson);
      state = state.copyWith(
        isDistributing: false,
        lastDistributedLessonId: id,
      );
      return id;
    } catch (e) {
      state = state.copyWith(isDistributing: false);
      rethrow;
    }
  }

  Future<void> fetchAnalytics(String lessonId) async {
    state = state.copyWith(isFetchingAnalytics: true);
    try {
      final data = await state.adapter.fetchAnalytics(lessonId);
      state = state.copyWith(
        isFetchingAnalytics: false,
        currentAnalytics: data,
      );
    } catch (e) {
      state = state.copyWith(isFetchingAnalytics: false);
      rethrow;
    }
  }
}
