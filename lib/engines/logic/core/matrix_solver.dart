class MatrixSolver {
  /// Solves the system of linear equations [A] * x = [B]
  /// using Gaussian elimination with partial pivoting.
  /// Returns the solution vector x, or null if singular.
  static List<double>? solve(List<List<double>> A, List<double> B) {
    int n = B.length;

    // Create a working copy of A and B
    List<List<double>> mat = List.generate(n, (i) => List<double>.from(A[i]));
    List<double> vec = List<double>.from(B);

    for (int p = 0; p < n; p++) {
      // Find pivot
      int maxRow = p;
      for (int i = p + 1; i < n; i++) {
        if (mat[i][p].abs() > mat[maxRow][p].abs()) {
          maxRow = i;
        }
      }

      // Swap rows in A and B
      List<double> tempRow = mat[p];
      mat[p] = mat[maxRow];
      mat[maxRow] = tempRow;

      double tempVal = vec[p];
      vec[p] = vec[maxRow];
      vec[maxRow] = tempVal;

      // Singular or nearly singular
      if (mat[p][p].abs() < 1e-10) {
        return null; // or throw Exception
      }

      // Pivot within A and B
      for (int i = p + 1; i < n; i++) {
        double alpha = mat[i][p] / mat[p][p];
        vec[i] -= alpha * vec[p];
        for (int j = p; j < n; j++) {
          mat[i][j] -= alpha * mat[p][j];
        }
      }
    }

    // Back substitution
    List<double> x = List<double>.filled(n, 0.0);
    for (int i = n - 1; i >= 0; i--) {
      double sum = 0.0;
      for (int j = i + 1; j < n; j++) {
        sum += mat[i][j] * x[j];
      }
      x[i] = (vec[i] - sum) / mat[i][i];
    }

    return x;
  }
}
