import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GamificationState {
  final int xp;
  final int level;
  final Set<String> unlockedAchievements;

  GamificationState({
    this.xp = 0,
    this.level = 1,
    this.unlockedAchievements = const {},
  });

  GamificationState copyWith({
    int? xp,
    int? level,
    Set<String>? unlockedAchievements,
  }) {
    return GamificationState(
      xp: xp ?? this.xp,
      level: level ?? this.level,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
    );
  }
}

class GamificationNotifier extends Notifier<GamificationState> {
  static const String _xpKey = 'notesketch_xp';
  static const String _achievementsKey = 'notesketch_achievements';

  @override
  GamificationState build() {
    _loadState();
    return GamificationState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final xp = prefs.getInt(_xpKey) ?? 0;
    final achievements = prefs.getStringList(_achievementsKey)?.toSet() ?? {};

    int level = _calculateLevel(xp);
    state = state.copyWith(
      xp: xp,
      level: level,
      unlockedAchievements: achievements,
    );
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_xpKey, state.xp);
    await prefs.setStringList(
      _achievementsKey,
      state.unlockedAchievements.toList(),
    );
  }

  int _calculateLevel(int xp) {
    // Basic curve: Level 1: 0-100, Level 2: 100-250, Level 3: 250-450...
    return 1 + (xp / 100).floor();
  }

  void addXp(int amount) {
    final newXp = state.xp + amount;
    final newLevel = _calculateLevel(newXp);

    // Optional: trigger a level up effect here if newLevel > state.level

    state = state.copyWith(xp: newXp, level: newLevel);
    _saveState();
  }

  void unlockAchievement(String achievementId) {
    if (!state.unlockedAchievements.contains(achievementId)) {
      final newAchievements = Set<String>.from(state.unlockedAchievements)
        ..add(achievementId);
      state = state.copyWith(unlockedAchievements: newAchievements);

      // Bonus XP for achievements
      addXp(50);
      _saveState();
    }
  }
}

final gamificationProvider =
    NotifierProvider<GamificationNotifier, GamificationState>(
      GamificationNotifier.new,
    );
