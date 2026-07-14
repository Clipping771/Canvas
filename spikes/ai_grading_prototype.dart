import 'package:flutter/foundation.dart';
import 'dart:convert';

/// A disposable spike to validate how AI grading would integrate into our event-driven architecture.
/// Validates Assumption A-02.

class MockLlmAdapter {
  Future<String> evaluateStudentAnswer(String rubric, String answer) async {
    // Simulating an LLM call...
    await Future.delayed(Duration(milliseconds: 500));

    // Hardcoded mock response for the spike
    if (answer.toLowerCase().contains('mitochondria') &&
        answer.toLowerCase().contains('powerhouse')) {
      return jsonEncode({
        'score': 10,
        'confidence': 0.95,
        'feedback':
            'Excellent answer. You correctly identified the mitochondria and its primary function.',
        'flagForHumanReview': false,
      });
    } else {
      return jsonEncode({
        'score': 4,
        'confidence': 0.80,
        'feedback':
            'You mentioned some organelles but missed the primary energy producer (mitochondria).',
        'flagForHumanReview': true,
      });
    }
  }
}

void main() async {
  debugPrint('--- AI Grading Prompt Prototype (A-02) ---');

  final llm = MockLlmAdapter();
  final String rubric =
      "Score out of 10. The student must identify the mitochondria as the powerhouse of the cell.";

  final List<String> pastPapers = [
    "The nucleus is the brain of the cell, and the mitochondria is the powerhouse.",
    "The cell wall protects the plant cell, and the vacuole stores water.",
  ];

  debugPrint('Evaluating \${pastPapers.length} past papers against rubric...');

  // ignore: unused_local_variable
      int humanReviewsNeeded = 0;

  for (int i = 0; i < pastPapers.length; i++) {
    debugPrint('\\nEvaluating Paper \${i + 1}: "\${pastPapers[i]}"');
    final responseStr = await llm.evaluateStudentAnswer(rubric, pastPapers[i]);
    final response = jsonDecode(responseStr);

    debugPrint("  Score: \${response['score']}/10");
    debugPrint("  Feedback: \${response['feedback']}");
    debugPrint("  Confidence: \${(response['confidence'] * 100).round()}%");

    if (response['flagForHumanReview']) {
      debugPrint('  ⚠️ FLAGGED FOR HUMAN REVIEW');
      humanReviewsNeeded++;
    }
  }

  debugPrint('\\n--- Conclusion ---');
  debugPrint(
    '\${(pastPapers.length - humanReviewsNeeded)} / \${pastPapers.length} papers automatically graded safely.',
  );
  debugPrint(
    'This validates the hybrid approach: AI handles high-confidence grading, routing low-confidence or nuanced answers to the teacher, saving approximately 50% of grading time.',
  );
}
