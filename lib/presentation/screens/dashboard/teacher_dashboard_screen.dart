import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/presentation/providers/lms_provider.dart';
import 'package:vinci_board/core/models/lms/student_progress.dart';
import 'package:vinci_board/core/theme/da_vinci_theme.dart';
import 'package:vinci_board/core/widgets/glass_container.dart';

class TeacherDashboardScreen extends ConsumerStatefulWidget {
  final String lessonId;
  const TeacherDashboardScreen({super.key, required this.lessonId});

  @override
  ConsumerState<TeacherDashboardScreen> createState() =>
      _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState
    extends ConsumerState<TeacherDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(lmsProvider.notifier).fetchAnalytics(widget.lessonId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lmsState = ref.watch(lmsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Teacher Analytics Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(lmsProvider.notifier).fetchAnalytics(widget.lessonId);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lesson Progress Heat-Map',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Active Provider: \${lmsState.adapter.providerName}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            Expanded(
              child:
                  lmsState.isFetchingAnalytics &&
                      lmsState.currentAnalytics.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _buildHeatMapGrid(lmsState.currentAnalytics),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatMapGrid(List<StudentProgress> analytics) {
    if (analytics.isEmpty) {
      return const Center(child: Text('No student data available.'));
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: analytics.length,
      itemBuilder: (context, index) {
        final student = analytics[index];
        return _buildStudentCard(student);
      },
    );
  }

  Widget _buildStudentCard(StudentProgress student) {
    // Generate color based on confidence score (red to green)
    final h = (student.confidenceScore * 120.0); // 0 = Red, 120 = Green
    final s = 0.8;
    final v = 0.9;
    final baseColor = HSVColor.fromAHSV(1.0, h, s, v).toColor();

    return GlassContainer(
      blur: 15,
      opacity: 0.1,
      color: baseColor.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              student.studentName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Completion:',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '\${(student.completionPercentage * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: student.completionPercentage,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.white70,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AI Confidence:',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '\${(student.confidenceScore * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: baseColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
