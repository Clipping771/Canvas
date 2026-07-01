import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/gamification_provider.dart';

class GamificationDialog extends ConsumerWidget {
  const GamificationDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gamificationProvider);
    final notifier = ref.read(gamificationProvider.notifier);

    // Calculate XP progress to next level
    final currentLevelBaseXp = (state.level - 1) * 100;
    final nextLevelXp = state.level * 100;
    final progress = (state.xp - currentLevelBaseXp) / (nextLevelXp - currentLevelBaseXp);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your Learner Profile',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
                  ),
                ),
                Text(
                  'Lvl ${state.level}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4A90E2)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('${state.xp} XP / $nextLevelXp XP', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Skill Tree',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: GamificationNotifier.skillLevelRequirements.entries.map((entry) {
                  final skillId = entry.key;
                  final reqLvl = entry.value;
                  final isUnlocked = state.unlockedSkills.contains(skillId);
                  final canUnlock = notifier.canUnlockSkill(skillId);

                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isUnlocked ? Icons.check_circle : Icons.lock,
                        color: isUnlocked ? Colors.green : Colors.grey,
                      ),
                      title: Text(skillId.replaceAll('_', ' ').toUpperCase()),
                      subtitle: Text('Requires Level $reqLvl'),
                      trailing: isUnlocked
                          ? const Text('UNLOCKED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                          : canUnlock
                              ? ElevatedButton(
                                  onPressed: () {
                                    notifier.unlockSkill(skillId);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4A90E2),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('UNLOCK'),
                                )
                              : const Text('LOCKED', style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
