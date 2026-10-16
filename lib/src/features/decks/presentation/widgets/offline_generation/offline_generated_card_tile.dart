import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';

/// Individual card tile presenting an offline synthesized flashcard with LaTeX and explanation.
class OfflineGeneratedCardTile extends StatelessWidget {
  const OfflineGeneratedCardTile({
    required this.card,
    super.key,
  });

  final GeneratedFlashcard card;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary
            : colors.surfaceSecondary.withAlpha(120),
        borderRadius: AppRadius.radiusCard,
        border: Border.all(
          color: card.isLocalInference
              ? colors.primary.withAlpha(80)
              : colors.syllabotAccent.withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'QUESTION',
                style: typography.caption.bold.copyWith(
                  color: colors.textMuted,
                  fontSize: 11.sp,
                  letterSpacing: 1.1,
                ),
              ),
              if (card.isLocalInference)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(50),
                    borderRadius: AppRadius.radiusBadge,
                  ),
                  child: Text(
                    'Local Engine',
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 10.sp,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            card.front,
            style: typography.body.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 14.sp,
            ),
          ),
          Divider(color: colors.surfaceBorder, height: 20.h),
          Text(
            'ANSWER & DERIVATION',
            style: typography.caption.bold.copyWith(
              color: colors.textMuted,
              fontSize: 11.sp,
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: 6.h),
          LatexRichViewer(
            text: card.back,
            style: typography.body.regular.copyWith(
              fontSize: 13.sp,
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          if (card.explanation.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              card.explanation,
              style: typography.footnote.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 12.sp,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
