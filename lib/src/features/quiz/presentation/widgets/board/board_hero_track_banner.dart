import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_duel_matchmaking_sheet.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Hero track banner for switching between user-enrolled track scope and the full question bank.
class BoardHeroTrackBanner extends StatelessWidget {
  const BoardHeroTrackBanner({
    required this.userTrack,
    super.key,
  });

  final String userTrack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
      builder: (context, state) {
        final exam = state.selectedExam;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.dialog),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary.withAlpha(isDark ? 55 : 30),
                    colors.surfaceSecondary.withAlpha(isDark ? 180 : 230),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.dialog),
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 80 : 45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.black.withAlpha(isDark ? 40 : 15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Track Scope Toggle Segment
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? colors.surfaceSecondary.withAlpha(200)
                                : colors.surfaceSecondary.withAlpha(120),
                            borderRadius: BorderRadius.circular(AppRadius.badge),
                            border: Border.all(
                              color: colors.surfaceBorder.withAlpha(isDark ? 80 : 120),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  AppFeedback.selection();
                                  context.read<PastQuestionsBloc>().add(
                                    const SetTrackScopeEvent(isScopedToUserTrack: true),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: state.isScopedToUserTrack
                                        ? colors.primary
                                        : colors.transparent,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.badge - 2),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.tune_rounded,
                                        size: 12,
                                        color: state.isScopedToUserTrack
                                            ? colors.white
                                            : colors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'My Track Scope',
                                        style: typography.caption.bold.copyWith(
                                          color: state.isScopedToUserTrack
                                              ? colors.white
                                              : colors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  AppFeedback.selection();
                                  context.read<PastQuestionsBloc>().add(
                                    const SetTrackScopeEvent(isScopedToUserTrack: false),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !state.isScopedToUserTrack
                                        ? colors.primary
                                        : colors.transparent,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.badge - 2),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.public_rounded,
                                        size: 12,
                                        color: !state.isScopedToUserTrack
                                            ? colors.white
                                            : colors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Explore All Tracks',
                                        style: typography.caption.bold.copyWith(
                                          color: !state.isScopedToUserTrack
                                              ? colors.white
                                              : colors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.isScopedToUserTrack
                                  ? 'My Track: ${exam.displayName} ($userTrack)'
                                  : 'Explore ${exam.displayName} Question Bank',
                              style: typography.title3.bold.copyWith(
                                color: colors.textPrimary,
                                letterSpacing: -0.2,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              state.isScopedToUserTrack
                                  ? 'Showing questions customized for your track & enrolled courses.'
                                  : 'Browsing all available questions across tracks & institutions.',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!state.isScopedToUserTrack) ...[
                        const SizedBox(width: 8),
                        PopupMenuButton<ExamCategory>(
                          color: isDark
                              ? colors.surfaceSecondary
                              : colors.surfacePrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.panel),
                            side: BorderSide(
                              color: colors.surfaceBorder.withAlpha(isDark ? 80 : 120),
                            ),
                          ),
                          onSelected: (category) {
                            AppFeedback.selection();
                            context.read<PastQuestionsBloc>().add(
                              ChangeExamCategoryEvent(category),
                            );
                          },
                          itemBuilder: (context) {
                            return ExamCategory.values.map((cat) {
                              final isSelected = state.selectedExam == cat;
                              return PopupMenuItem<ExamCategory>(
                                value: cat,
                                child: Text(
                                  cat.displayName,
                                  style: typography.caption.bold.copyWith(
                                    color: isSelected
                                        ? colors.primary
                                        : colors.textPrimary,
                                  ),
                                ),
                              );
                            }).toList();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(isDark ? 50 : 25),
                              borderRadius: BorderRadius.circular(AppRadius.card),
                              border: Border.all(
                                color: colors.primary.withAlpha(isDark ? 80 : 50),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  exam.displayName,
                                  style: typography.caption.bold.copyWith(
                                    color: colors.primary,
                                    fontSize: 11.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_drop_down_rounded,
                                  size: 18,
                                  color: colors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ShrinkableButton(
                          onTap: () async {
                            AppFeedback.light();
                            await QuizDuelMatchmakingSheet.show(
                              context,
                              initialSubject: state.selectedSubject != 'All'
                                  ? state.selectedSubject
                                  : 'Physics',
                              initialExamBoard: state.selectedExam.displayName,
                            );
                          },
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [colors.secondary, colors.primary],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.black.withAlpha(
                                    isDark ? 50 : 20,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.flash_on_rounded,
                                  color: colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Duel a classmate',
                                  style: typography.callout.bold.copyWith(
                                    color: colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
