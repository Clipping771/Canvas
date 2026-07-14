import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/presentation/providers/lms_provider.dart';

class LmsIntegrationScreen extends ConsumerWidget {
  const LmsIntegrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lmsState = ref.watch(lmsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('LMS Integration')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Current Adapter: ${lmsState.adapter.runtimeType}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(lmsProvider.notifier).distributeCurrentLesson(
                      'lesson_123',
                      'Introduction to Gravity',
                    );
              },
              child: const Text('Distribute Demo Lesson'),
            ),
          ],
        ),
      ),
    );
  }
}
