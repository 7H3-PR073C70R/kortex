import 'dart:async';
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class CourseModuleDecksSection extends StatelessWidget {
  const CourseModuleDecksSection({
    required this.decks,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.mappedSubject,
    required this.isDark,
    super.key,
  });

  final List<DeckEntity> decks;
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String mappedSubject;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Associated Study Decks',
                style: typography.callout.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            ShrinkableButton(
              onTap: () {
                AppFeedback.light();
                unawaited(
                  context.router.push(
                    CreateDeckRoute(
                      courseId: courseId,
                      courseCode: courseCode,
                      courseTitle: courseTitle,
                      mappedSubject: mappedSubject,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                  border: Border.all(
                    color: colors.primary.withAlpha(40),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 13,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'New Deck',
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (decks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(100)
                  : colors.surfacePrimary.withAlpha(180),
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(
                color: colors.surfaceBorder.withAlpha(100),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.layers_clear_outlined,
                  size: 32,
                  color: colors.textMuted,
                ),
                const SizedBox(height: 8),
                Text(
                  'No study decks created yet for this course',
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload study materials above to automatically generate flashcards.',
                  textAlign: TextAlign.center,
                  style: typography.footnote.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          )
        else
          ...decks.map((deck) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.panel),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary.withAlpha(130)
                          : colors.surfacePrimary.withAlpha(200),
                      borderRadius: BorderRadius.circular(AppRadius.panel),
                      border: Border.all(
                        color: deck.hasDueCards
                            ? colors.primary.withAlpha(isDark ? 90 : 60)
                            : (isDark
                                ? colors.surfaceBorderHighlight.withAlpha(50)
                                : colors.surfaceBorder.withAlpha(120)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              AppFeedback.light();
                              unawaited(
                                context.router.push(
                                  StudySessionRoute(deckId: deck.id),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    deck.title,
                                    style: typography.caption.bold.copyWith(
                                      color: colors.textPrimary,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '${deck.totalCards} cards',
                                        style: typography.footnote.regular
                                            .copyWith(
                                              color: colors.textSecondary,
                                              fontSize: 11.5,
                                            ),
                                      ),
                                      if (deck.dueCards > 0) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.error.withAlpha(30),
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.micro,
                                            ),
                                          ),
                                          child: Text(
                                            '${deck.dueCards} due',
                                            style: typography.caption.bold
                                                .copyWith(
                                                  color: colors.error,
                                                  fontSize: 10,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ShrinkableButton(
                          onTap: () {
                            AppFeedback.light();
                            unawaited(
                              context.router.push(
                                StudySessionRoute(deckId: deck.id),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  size: 15,
                                  color: colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Study',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.white,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
