/// Represents a 3D crystal lattice structure.
class CrystalLattice {
  final String system; // e.g. Cubic, Tetragonal, Hexagonal
  final String bravaisLattice; // e.g. Primitive (P), Body-centered (I)
  final double a; // Lattice parameter a (Angstroms)
  final double b; // Lattice parameter b (Angstroms)
  final double c; // Lattice parameter c (Angstroms)
  final double alpha; // Angle alpha (Degrees)
  final double beta; // Angle beta (Degrees)
  final double gamma; // Angle gamma (Degrees)

  const CrystalLattice({
    required this.system,
    required this.bravaisLattice,
    required this.a,
    required this.b,
    required this.c,
    required this.alpha,
    required this.beta,
    required this.gamma,
  });

  /// Factory for a simple Cubic lattice
  factory CrystalLattice.simpleCubic(double a) {
    return CrystalLattice(
      system: 'Cubic',
      bravaisLattice: 'P',
      a: a,
      b: a,
      c: a,
      alpha: 90,
      beta: 90,
      gamma: 90,
    );
  }
}

/// Evaluates symmetry operations for a crystal lattice.
class CrystalSymmetry {
  /// Basic evaluation of whether the lattice has a center of inversion.
  bool hasCenterOfInversion(CrystalLattice lattice) {
    // In a full implementation, this evaluates the space group.
    // For now, if it's cubic, we'll assume standard highly-symmetric space groups (e.g. Fm-3m) have it.
    if (lattice.system == 'Cubic') return true;
    return false;
  }
}
