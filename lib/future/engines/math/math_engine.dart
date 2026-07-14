import 'package:vinci_board/engines/math/core/symbolic_solver.dart';
import 'package:vinci_board/engines/math/core/equation_evaluator.dart';
import 'package:vinci_board/engines/math/core/calculus_engine.dart';

/// The central engine for mathematical computation and simulation.
class MathEngine {
  static final SymbolicSolver symbolicSolver = SymbolicSolver();
  static final EquationEvaluator equationEvaluator = EquationEvaluator();
  static final CalculusEngine calculusEngine = CalculusEngine();

  // Initialization logic if any
  static void initialize() {
    // Prep plugins or advanced CAS (Computer Algebra System) logic
  }
}
