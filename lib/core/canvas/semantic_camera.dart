enum CameraIntent {
  hardFocus, // Snaps to node directly (e.g., new thread creation)
  userAssistedFocus, // Gentle animated guidance while user is actively exploring
  softGuide, // Subtle nudge if node is slightly clipping the edge
  noAction, // Complete user override (if user is intensely panning/zooming)
}

enum UserIntentState {
  explore, // User is panning/zooming around
  follow, // User is waiting for AI
  observe, // User is selecting/reading
  create, // User is actively drawing
}

class SemanticCameraIntelligence {
  static CameraIntent determineIntent({
    required UserIntentState userState,
    required int nodeDepth,
    required bool isRoot,
    required bool isFullyOffscreen,
  }) {
    // 1. If user is actively exploring or creating, do not rip control away.
    if (userState == UserIntentState.explore ||
        userState == UserIntentState.create) {
      if (isRoot) {
        return CameraIntent
            .userAssistedFocus; // Nudge them towards major events
      }
      return CameraIntent.noAction;
    }

    // 2. If user is waiting (follow), we can be more aggressive.
    if (userState == UserIntentState.follow) {
      if (isRoot || nodeDepth < 2) return CameraIntent.hardFocus;
      if (isFullyOffscreen) return CameraIntent.softGuide;
      return CameraIntent.noAction;
    }

    // 3. Default fallback
    return isFullyOffscreen ? CameraIntent.softGuide : CameraIntent.noAction;
  }
}
