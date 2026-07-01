import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/gamification_provider.dart';

class QuizOverlay extends ConsumerStatefulWidget {
  final Map<String, dynamic> quizData;
  final VoidCallback onComplete;

  const QuizOverlay({super.key, required this.quizData, required this.onComplete});

  @override
  ConsumerState<QuizOverlay> createState() => _QuizOverlayState();
}

class _QuizOverlayState extends ConsumerState<QuizOverlay> {
  String? _selectedAnswer;
  bool _isChecked = false;

  @override
  Widget build(BuildContext context) {
    final question = widget.quizData['question'] ?? 'No question provided';
    final options = List<String>.from(widget.quizData['options'] ?? []);
    final correctAnswer = widget.quizData['correct_answer'] ?? '';

    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school, size: 48, color: Colors.blueAccent),
              const SizedBox(height: 16),
              Text(
                question,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ...options.map((opt) {
                final isCorrect = opt == correctAnswer;
                final isSelected = opt == _selectedAnswer;

                Color tileColor = Colors.grey.shade100;
                Color textColor = Colors.black87;

                if (_isChecked) {
                  if (isCorrect) {
                    tileColor = Colors.green.shade100;
                    textColor = Colors.green.shade900;
                  } else if (isSelected) {
                    tileColor = Colors.red.shade100;
                    textColor = Colors.red.shade900;
                  }
                } else if (isSelected) {
                  tileColor = Colors.blue.shade100;
                  textColor = Colors.blue.shade900;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: _isChecked ? null : () => setState(() => _selectedAnswer = opt),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: tileColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected && !_isChecked ? Colors.blueAccent : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(opt, style: TextStyle(fontSize: 16, color: textColor))),
                          if (_isChecked && isCorrect) const Icon(Icons.check_circle, color: Colors.green),
                          if (_isChecked && isSelected && !isCorrect) const Icon(Icons.cancel, color: Colors.red),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              if (!_isChecked)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _selectedAnswer == null
                      ? null
                      : () {
                          setState(() => _isChecked = true);
                          if (_selectedAnswer == correctAnswer) {
                            ref.read(gamificationProvider.notifier).addXp(20);
                          }
                        },
                  child: const Text('Check Answer', style: TextStyle(fontSize: 18)),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.grey.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: widget.onComplete,
                  child: const Text('Continue', style: TextStyle(fontSize: 18)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
