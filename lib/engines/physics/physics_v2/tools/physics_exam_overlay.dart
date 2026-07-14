// ignore_for_file: unused_field
import 'package:flutter/material.dart';
import 'package:vinci_board/engines/physics/physics_engine.dart';
import 'package:vinci_board/engines/physics/physics_v2/world/body.dart';
import 'package:vinci_board/engines/physics/physics_v2/tools/formula_engine.dart';

/// Layer 6: Exam Mode
/// Challenges the student to calculate physics values based on the live simulation.
class PhysicsExamOverlay extends StatefulWidget {
  const PhysicsExamOverlay({super.key});

  @override
  State<PhysicsExamOverlay> createState() => _PhysicsExamOverlayState();
}

class _PhysicsExamOverlayState extends State<PhysicsExamOverlay> {
  double? _expectedAnswer;
  final TextEditingController _answerController = TextEditingController();
  String? _feedback;
  late FormulaEngine _formulaEngine;
  String? _targetBodyId;
  bool _isSolved = false;

  @override
  void initState() {
    super.initState();
    _formulaEngine = FormulaEngine(PhysicsEngine().world);
    _generateQuestion();
  }

  void _generateQuestion() {
    final world = PhysicsEngine().world;
    final bodies = world.getAllBodies();

    if (bodies.isEmpty) {
      setState(() {
        _feedback = "Draw a shape and apply gravity first!";
      });
      return;
    }

    final target = bodies.values.firstWhere(
      (b) => b.type == BodyType.dynamicBody,
      orElse: () => bodies.values.first,
    );
    _targetBodyId = target.id;

    // Ask for Potential Energy
    _expectedAnswer = _formulaEngine.calculatePotentialEnergy(target.id);

    setState(() {
      _isSolved = false;
      _answerController.clear();
      _feedback = null;
    });
  }

  void _checkAnswer() {
    final userAnswer = double.tryParse(_answerController.text);
    if (userAnswer == null) {
      setState(() => _feedback = "Please enter a valid number.");
      return;
    }

    // Recalculate based on current state, but typically in a real exam the physics would be paused
    // Here we just allow a margin of error
    final currentAnswer = _formulaEngine.calculatePotentialEnergy(
      _targetBodyId!,
    );
    final diff = (userAnswer - currentAnswer).abs();

    if (diff < 100.0) {
      // Large margin for live simulation
      setState(() {
        _isSolved = true;
        _feedback = "Correct! Outstanding calculation. 🎉";
      });
    } else {
      setState(() {
        _feedback =
            "Incorrect. Try again! Expected ~${currentAnswer.toStringAsFixed(1)} Joules.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_targetBodyId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school, color: Colors.purple, size: 24),
              const SizedBox(width: 8),
              Text(
                'PHYSICS EXAM MODE',
                style: TextStyle(
                  color: Colors.purple[800],
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Question:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Calculate the approximate Potential Energy (P.E) of the moving object relative to the ground.',
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _answerController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter Joules (J)',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isSolved ? _generateQuestion : _checkAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSolved ? Colors.green : Colors.purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                child: Text(
                  _isSolved ? 'Next' : 'Submit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 16),
            Text(
              _feedback!,
              style: TextStyle(
                color: _isSolved ? Colors.green[700] : Colors.red[600],
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
