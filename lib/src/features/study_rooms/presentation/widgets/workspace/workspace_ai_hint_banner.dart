import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Ambient Syllabot AI inactivity hint pill and thought-starter banner in InRoomDeckStudyWorkspace.
class WorkspaceAiHintBanner extends StatelessWidget {
  const WorkspaceAiHintBanner({
    required this.activeAiHint,
    required this.isLoadingHint,
    required this.onGetHintTap,
    super.key,
  });

  final String? activeAiHint;
  final bool isLoadingHint;
  final VoidCallback onGetHintTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    if (activeAiHint != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.warning.withAlpha(isDark ? 35 : 20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.warning.withAlpha(isDark ? 90 : 50),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.smart_toy_rounded, size: 18, color: colors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                activeAiHint!,
                style: typography.caption.regular.copyWith(
                  color: colors.textPrimary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primary.withAlpha(isDark ? 30 : 15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 70 : 35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 16,
            color: colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Stuck on this concept? Syllabot AI can help.',
              style: typography.caption.medium.copyWith(
                color: colors.textPrimary,
                fontSize: 11.5,
              ),
            ),
          ),
          ShrinkableButton(
            onTap: isLoadingHint ? null : onGetHintTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: isLoadingHint
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.white),
                      ),
                    )
                  : Text(
                      'Get Hint',
                      style: typography.caption.bold.copyWith(
                        color: colors.white,
                        fontSize: 11,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
