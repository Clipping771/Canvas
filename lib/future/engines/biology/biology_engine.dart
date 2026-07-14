import 'package:vinci_board/engines/biology/core/genetics_simulator.dart';
import 'package:vinci_board/engines/biology/core/cellular_simulator.dart';
import 'package:vinci_board/engines/biology/core/anatomy_simulator.dart';

/// Central controller for all biological simulations in Vinci Board.
class BiologyEngine {
  final GeneticsSimulator geneticsSimulator;
  final CellularSimulator cellularSimulator;
  final AnatomySimulator anatomySimulator;

  BiologyEngine()
    : geneticsSimulator = GeneticsSimulator(),
      cellularSimulator = CellularSimulator(),
      anatomySimulator = AnatomySimulator();

  /// Simulates the central dogma of biology: DNA -> RNA -> Protein
  String runCentralDogma(String dnaSequence) {
    String mrna = geneticsSimulator.transcribe(dnaSequence);
    String protein = geneticsSimulator.translate(mrna);
    return "mRNA: $mrna\nProtein: $protein";
  }
}
