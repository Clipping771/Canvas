import 'package:flutter_test/flutter_test.dart';
import 'package:vinci_board/engines/biology/core/genetics_simulator.dart';
import 'package:vinci_board/engines/biology/core/cellular_simulator.dart';
import 'package:vinci_board/engines/math/core/graphing_engine.dart';

void main() {
  group('Biology Engine Tests', () {
    test('Genetics Simulator: Transcription and Translation', () {
      final sim = GeneticsSimulator();
      final dna = 'TACGGCATTA';
      final mrna = sim.transcribe(dna);
      expect(mrna, 'UACGGCAUUA'); // T replaced by U

      // A simple standard sequence starting with AUG (Start) and ending with UAA (Stop)
      final sequence = 'AUGUUUUAA';
      final protein = sim.translate(sequence);
      expect(protein, 'Met-Phe');
    });

    test('Cellular Simulator: ATP Production', () {
      final sim = CellularSimulator();
      // 1 Glucose + 6 Oxygen -> 38 ATP
      final atp1 = sim.calculateATPProduction(1, 6);
      expect(atp1, 38);

      // 1 Glucose + 0 Oxygen -> 2 ATP (Anaerobic)
      final atp2 = sim.calculateATPProduction(1, 0);
      expect(atp2, 2);
    });
  });

  group('Math Engine Tests', () {
    test('Graphing Engine Evaluation', () {
      final engine = GraphingEngine();
      final points = engine.generatePoints(
        functionExpression: 'x^2',
        startX: -10,
        endX: 10,
        resolution: 101,
      );
      expect(points.isNotEmpty, true);

      // The point at x=0 should be y=0
      final zeroPoint = points.firstWhere((p) => p.dx.abs() < 0.1);
      expect(zeroPoint.dy.abs() < 0.1, true);

      // The point at x=2 should be y=4
      final twoPoint = points.firstWhere((p) => (p.dx - 2.0).abs() < 0.1);
      expect((twoPoint.dy - 4.0).abs() < 0.1, true);
    });
  });
}
