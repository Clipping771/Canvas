import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/presentation/providers/gamification_provider.dart';

class GamificationDialog extends ConsumerWidget {
  const GamificationDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gamificationProvider);
    final notifier = ref.read(gamificationProvider.notifier);

    // Calculate XP progress to next level
    final currentLevelBaseXp = (state.level - 1) * 100;
    final nextLevelXp = state.level * 100;
    final progress =
        (state.xp - currentLevelBaseXp) / (nextLevelXp - currentLevelBaseXp);

    final skillsData = [
      {
        'id': 'quiz_engine',
        'title': 'Quiz engine',
        'subtitle': 'Turn any page into a practice quiz',
        'icon': Icons.assignment_outlined,
      },
      {
        'id': 'physics_mode',
        'title': 'Physics mode',
        'subtitle': 'Simulate motion and forces on canvas',
        'icon': Icons.adjust,
      },
      {
        'id': 'magic_styles',
        'title': 'Magic styles',
        'subtitle': 'Extra brush effects and textures',
        'icon': Icons.auto_fix_high,
      },
      {
        'id': 'chaos_mode',
        'title': 'Chaos mode',
        'subtitle': 'Randomizes layout for creative prompts',
        'icon': Icons.shuffle,
      },
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your learner profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2A3A5E),
              ),
            ),
            const SizedBox(height: 32),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 10,
                    backgroundColor: const Color(0xFFF0F4F8),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF3B82F6),
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lvl ${state.level}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2A3A5E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${state.xp} / $nextLevelXp XP',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8B9EB7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(color: Color(0xFFF0F4F8), thickness: 1.5),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SKILL TREE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8B9EB7),
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemCount: skillsData.length,
                itemBuilder: (context, index) {
                  final skill = skillsData[index];
                  final skillId = skill['id'] as String;
                  final reqLvl =
                      GamificationNotifier.skillLevelRequirements[skillId] ??
                      99;
                  final isUnlocked =
                      state.unlockedSkills.contains(skillId) ||
                      state.level >= reqLvl;
                  final isNext =
                      reqLvl > state.level && (reqLvl - state.level) == 1;

                  return _buildSkillItem(
                    title: skill['title'] as String,
                    subtitle: skill['subtitle'] as String,
                    icon: skill['icon'] as IconData,
                    reqLvl: reqLvl,
                    currentLvl: state.level,
                    isUnlocked: isUnlocked,
                    isNext: isNext,
                    onTap: isUnlocked && !state.unlockedSkills.contains(skillId)
                        ? () => notifier.unlockSkill(skillId)
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: Color(0xFF3B82F6),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required int reqLvl,
    required int currentLvl,
    required bool isUnlocked,
    required bool isNext,
    VoidCallback? onTap,
  }) {
    final bool isHighlight = isNext || isUnlocked;
    final bgColor = isHighlight ? const Color(0xFFEFF6FF) : Colors.transparent;
    final iconBgColor = isHighlight ? Colors.white : const Color(0xFFF3F6F9);
    final iconColor = isHighlight
        ? const Color(0xFF3B82F6)
        : const Color(0xFFCBD5E1);
    final titleColor = isHighlight
        ? const Color(0xFF2A3A5E)
        : const Color(0xFF4A6078);
    final subtitleColor = isHighlight
        ? const Color(0xFF4A6078)
        : const Color(0xFF8B9EB7);

    String trailingText = 'Lvl $reqLvl';
    if (isUnlocked) trailingText = 'Unlocked';
    if (isNext) trailingText = '${reqLvl - currentLvl} level away';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                if (!isUnlocked)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        size: 10,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              trailingText,
              style: TextStyle(
                color: isHighlight
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFF8B9EB7),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
