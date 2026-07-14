class WeightConfiguration {
  final double collisionWeight;
  final double distanceWeight;
  final double viewportWeight;
  final double inertiaWeight;

  WeightConfiguration({
    required this.collisionWeight,
    required this.distanceWeight,
    required this.viewportWeight,
    required this.inertiaWeight,
  });
}

enum InteractionContext {
  dense, // Many nodes nearby
  exploring, // User has panned recently
  branching, // Deeply nested node
  newThread, // Root node
}

class ContextAwareWeightController {
  static WeightConfiguration getWeights(Set<InteractionContext> contexts) {
    // Base configuration
    double col = 0.5;
    double dist = 0.2;
    double view = 0.2;
    double inert = 0.1;

    // Adjust based on active contexts
    if (contexts.contains(InteractionContext.dense)) {
      col = 0.8;
      dist = 0.1;
    }

    if (contexts.contains(InteractionContext.exploring)) {
      view = 0.5; // Highly prioritize keeping things in viewport
      dist = 0.1;
    }

    if (contexts.contains(InteractionContext.branching)) {
      inert = 0.4; // Strong inertia to keep branches stable
    }

    if (contexts.contains(InteractionContext.newThread)) {
      inert = 0.0; // No inertia for completely new threads
      dist = 0.0;
    }

    // Normalize weights to sum to 1.0 (optional but good practice)
    double sum = col + dist + view + inert;
    return WeightConfiguration(
      collisionWeight: col / sum,
      distanceWeight: dist / sum,
      viewportWeight: view / sum,
      inertiaWeight: inert / sum,
    );
  }
}
