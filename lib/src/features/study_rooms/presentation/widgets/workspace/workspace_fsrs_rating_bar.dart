import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Bottom recall grading bar for InRoomDeckStudyWorkspace (Again, Hard, Good, Easy).
class WorkspaceFsrsRatingBar extends StatelessWidget {
  const WorkspaceFsrsRatingBar({
    required this.onRateCard,
    this.isRatingLocked = false,
    super.key,
  });

  final ValueChanged<int> onRateCard;
  final bool isRatingLocked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: WorkspaceFsrsGradeButton(
              label: 'Again',
              grade: 1,
              icon: Icons.replay_rounded,
              color: colors.error,
              onTap: isRatingLocked ? null : () => onRateCard(1),
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: WorkspaceFsrsGradeButton(
              label: 'Hard',
              grade: 2,
              icon: Icons.bolt_rounded,
              color: colors.recallHard,
              onTap: isRatingLocked ? null : () => onRateCard(2),
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: WorkspaceFsrsGradeButton(
              label: 'Good',
              grade: 3,
              icon: Icons.thumb_up_rounded,
              color: colors.recallGood,
              onTap: isRatingLocked ? null : () => onRateCard(3),
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: WorkspaceFsrsGradeButton(
              label: 'Easy',
              grade: 4,
              icon: Icons.rocket_launch_rounded,
              color: colors.recallEasy,
              onTap: isRatingLocked ? null : () => onRateCard(4),
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single grade button in the FSRS recall rating bar.
class WorkspaceFsrsGradeButton extends StatelessWidget {
  const WorkspaceFsrsGradeButton({
    required this.label,
    required this.grade,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.isDark,
    super.key,
  });

  final String label;
  final int grade;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final colors = context.colors;

    return ShrinkableButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(isDark ? 42 : 25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withAlpha(isDark ? 100 : 75),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.black.withAlpha(isDark ? 30 : 10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: typography.caption.bold.copyWith(
                color: color,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
