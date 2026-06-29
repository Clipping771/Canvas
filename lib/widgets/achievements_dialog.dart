import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/gamification_provider.dart';

class AchievementsDialog extends ConsumerWidget {
  const AchievementsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamification = ref.watch(gamificationProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 400,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Achievements',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Level ${gamification.level}',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${gamification.xp} XP Total',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildBadge(
                    gamification,
                    'shape_master',
                    'Geometry Master',
                    'Autocorrect a rough shape into a perfect one.',
                    '📐',
                  ),
                  _buildBadge(
                    gamification,
                    'black_hole',
                    'Singularity',
                    'Draw a spiral inside a circle to create a black hole.',
                    '🕳️',
                  ),
                  _buildBadge(
                    gamification,
                    'fire',
                    'The Pyromancer',
                    'Summon the flames to warm the canvas.',
                    '🔥',
                  ),
                  _buildBadge(
                    gamification,
                    'snow',
                    'Winter is Coming',
                    'Freeze the edges of the canvas.',
                    '❄️',
                  ),
                  _buildBadge(
                    gamification,
                    'rain',
                    'Rain Dance',
                    'Bring the rain.',
                    '🌧️',
                  ),
                  _buildBadge(
                    gamification,
                    'done',
                    'Celebration',
                    'Pop some confetti.',
                    '🎉',
                  ),
                  _buildBadge(
                    gamification,
                    'love',
                    'Spread the Love',
                    'Summon floating hearts.',
                    '❤️',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(
    GamificationState state,
    String id,
    String title,
    String description,
    String emoji,
  ) {
    final unlocked = state.unlockedAchievements.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked
            ? Colors.green.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
        border: Border.all(
          color: unlocked
              ? Colors.green.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: unlocked ? Colors.white : Colors.grey.shade200,
              shape: BoxShape.circle,
              boxShadow: unlocked
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                emoji,
                style: TextStyle(
                  fontSize: 24,
                  color: unlocked ? null : Colors.transparent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: unlocked ? Colors.black87 : Colors.black45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: unlocked ? Colors.black54 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          if (unlocked) const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }
}
