import 'circuit_node.dart';
import 'matrix_solver.dart';
import '../models/logic_state.dart';

class VoltageSource {
  final CircuitNode? posNode;
  final CircuitNode? negNode;
  final double voltage;

  VoltageSource(this.posNode, this.negNode, this.voltage);
}

class MNASolver {
  final List<CircuitNode> nodes;
  final Map<String, int> _nodeIndex = {};
  
  int _numVoltageSources = 0;
  late List<List<double>> _A;
  late List<double> _z;

  MNASolver(this.nodes) {
    for (int i = 0; i < nodes.length; i++) {
      _nodeIndex[nodes[i].id] = i;
    }
  }

  /// Pass 1: Components must register their voltage sources so we can size the matrices.
  /// Returns the index of the voltage source.
  int registerVoltageSource() {
    return _numVoltageSources++;
  }

  /// Initialize matrices after Pass 1.
  void initMatrices() {
    int n = nodes.length;
    int size = n + _numVoltageSources;
    _A = List.generate(size, (i) => List<double>.filled(size, 0.0));
    _z = List<double>.filled(size, 0.0);

    // Ground fixed nodes (e.g. Ground component)
    for (int i = 0; i < n; i++) {
      if (nodes[i].isFixed) {
        _A[i][i] += 1e9; // Force V = 0
      } else {
        _A[i][i] += 1e-9; // Small conductance to prevent floating singularity
      }
    }
  }

  /// Pass 2: Add conductance between two nodes.
  void addConductance(String? nodeIdA, String? nodeIdB, double conductance) {
    int? idxA = nodeIdA != null ? _nodeIndex[nodeIdA] : null;
    int? idxB = nodeIdB != null ? _nodeIndex[nodeIdB] : null;

    if (idxA != null) {
      _A[idxA][idxA] += conductance;
    }
    if (idxB != null) {
      _A[idxB][idxB] += conductance;
    }
    if (idxA != null && idxB != null) {
      _A[idxA][idxB] -= conductance;
      _A[idxB][idxA] -= conductance;
    }
  }

  /// Pass 2: Stamp a voltage source.
  void addVoltageSource(int vSourceIndex, String? posNodeId, String? negNodeId, double voltage) {
    int n = nodes.length;
    int vIdx = n + vSourceIndex;

    int? idxPos = posNodeId != null ? _nodeIndex[posNodeId] : null;
    int? idxNeg = negNodeId != null ? _nodeIndex[negNodeId] : null;

    if (idxPos != null) {
      _A[idxPos][vIdx] += 1.0;
      _A[vIdx][idxPos] += 1.0;
    }
    if (idxNeg != null) {
      _A[idxNeg][vIdx] -= 1.0;
      _A[vIdx][idxNeg] -= 1.0;
    }
    
    _z[vIdx] = voltage;
  }

  /// Pass 2: Add independent current source.
  void addCurrentSource(String? nodeFromId, String? nodeToId, double current) {
    int? idxFrom = nodeFromId != null ? _nodeIndex[nodeFromId] : null;
    int? idxTo = nodeToId != null ? _nodeIndex[nodeToId] : null;

    if (idxFrom != null) {
      _z[idxFrom] -= current;
    }
    if (idxTo != null) {
      _z[idxTo] += current;
    }
  }

  /// Solve the system and update node voltages.
  void solve() {
    List<double>? x = MatrixSolver.solve(_A, _z);
    if (x != null) {
      for (int i = 0; i < nodes.length; i++) {
        nodes[i].voltage = x[i];
        for (var pin in nodes[i].connectedPins) {
          pin.state.voltage = x[i];
          // For legacy logic compatibility
          pin.state.logic = x[i] > 1.0 ? LogicState.high : LogicState.low;
        }
      }
    }
  }
}
