import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class StepByStepSolverView extends StatelessWidget {
  final String originalLatex;
  final List<String> stepsLatex;

  const StepByStepSolverView({
    super.key,
    required this.originalLatex,
    required this.stepsLatex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Step-by-Step Solution',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          const Text(
            'Original Equation:',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Center(
            child: Math.tex(
              originalLatex,
              textStyle: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Steps:', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          ...stepsLatex.asMap().entries.map((entry) {
            int index = entry.key;
            String stepLatex = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. ',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  Expanded(
                    child: Math.tex(
                      stepLatex,
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
