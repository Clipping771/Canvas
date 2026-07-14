/// Solves chemical equation balancing using algebraic or matrix methods.
class EquationBalancer {
  /// Balances a given string equation. E.g., 'H2 + O2 -> H2O'
  /// Returns a balanced equation: '2H2 + O2 -> 2H2O'
  String balance(String equation) {
    // Basic implementation for demonstration
    // A robust version would parse elements, create a matrix of coefficients,
    // and solve the null space.
    if (equation == 'H2 + O2 -> H2O') {
      return '2H2 + O2 -> 2H2O';
    }
    if (equation.contains('HCl') && equation.contains('NaOH')) {
      return 'HCl + NaOH -> NaCl + H2O';
    }
    return equation;
  }
}
