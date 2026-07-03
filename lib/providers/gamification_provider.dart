import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GamificationState {
  final int xp;
  final int level;
  final Set<String> unlockedAchievements;
  final Set<String> unlockedSkills;
  final bool isLoaded;

  GamificationState({
    this.xp = 0,
    this.level = 1,
    this.unlockedAchievements = const {},
    this.unlockedSkills = const {},
    this.isLoaded = false,
  });

  GamificationState copyWith({
    int? xp,
    int? level,
    Set<String>? unlockedAchievements,
    Set<String>? unlockedSkills,
    bool? isLoaded,
  }) {
    return GamificationState(
      xp: xp ?? this.xp,
      level: level ?? this.level,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      unlockedSkills: unlockedSkills ?? this.unlockedSkills,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class GamificationNotifier extends Notifier<GamificationState> {
  static const String _xpKey = 'notesketch_xp';
  static const String _achievementsKey = 'notesketch_achievements';

  bool _isInitialized = false;

  @override
  GamificationState build() {
    return GamificationState(isLoaded: false);
  }

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    final prefs = await SharedPreferences.getInstance();
    final xp = prefs.getInt(_xpKey) ?? 0;
    final achievements = prefs.getStringList(_achievementsKey)?.toSet() ?? {};
    final skills = prefs.getStringList('notesketch_skills')?.toSet() ?? {};

    int level = _calculateLevel(xp);
    state = state.copyWith(
      xp: xp,
      level: level,
      unlockedAchievements: achievements,
      unlockedSkills: skills,
      isLoaded: true,
    );
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_xpKey, state.xp);
    await prefs.setStringList(
      _achievementsKey,
      state.unlockedAchievements.toList(),
    );
    await prefs.setStringList(
      'notesketch_skills',
      state.unlockedSkills.toList(),
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

  // --- Skill Tree Logic ---
  static const Map<String, int> skillLevelRequirements = {
    'physics_mode': 3,
    'quiz_engine': 2,
    'magic_styles': 5,
    'chaos_mode': 10,
  };

  bool canUnlockSkill(String skillId) {
    final req = skillLevelRequirements[skillId];
    if (req == null) return false;
    return state.level >= req && !state.unlockedSkills.contains(skillId);
  }

  bool unlockSkill(String skillId) {
    if (canUnlockSkill(skillId)) {
      final newSkills = Set<String>.from(state.unlockedSkills)..add(skillId);
      state = state.copyWith(unlockedSkills: newSkills);
      _saveState();
      return true;
    }
    return false;
  }
}

final gamificationProvider =
    NotifierProvider<GamificationNotifier, GamificationState>(
      GamificationNotifier.new,
    );
