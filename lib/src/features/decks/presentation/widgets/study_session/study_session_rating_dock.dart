import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_post_bottom_sheet.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart';
import 'package:kortex/src/features/decks/presentation/widgets/feynman_active_recall_sheet.dart';
import 'package:kortex/src/features/decks/presentation/widgets/fsrs_rating_action_bar.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Bottom review rating dock and Feynman/Community action bar for active recall sessions.
class StudySessionRatingDock extends StatelessWidget {
  const StudySessionRatingDock({
    required this.currentCard,
    required this.isFlipped,
    required this.intervalPreviews,
    required this.onRateRating,
    required this.onToggleFlip,
    this.communityHubBloc,
    super.key,
  });

  final FlashcardEntity currentCard;
  final bool isFlipped;
  final Map<FsrsRating, int> intervalPreviews;
  final void Function(FsrsRating) onRateRating;
  final VoidCallback onToggleFlip;
  final CommunityHubBloc? communityHubBloc;

  CommunityHubBloc? get _effectiveCommunityBloc =>
      communityHubBloc ??
      (locator.isRegistered<CommunityHubBloc>()
          ? locator<CommunityHubBloc>()
          : null);

  void _onPostBounty(BuildContext context) {
    unawaited(HapticFeedback.lightImpact());
    final firstLinePrompt = currentCard.front.split('\n').first.trim();
    final topicName = currentCard.sourceTopic?.trim().isNotEmpty == true
        ? currentCard.sourceTopic!.trim()
        : 'Flashcard';

    unawaited(
      CreatePostBottomSheet.show(
        context,
        lockedTrack: (currentCard.sourceTopic?.isNotEmpty ?? false)
            ? currentCard.sourceTopic
            : null,
        initialTitle: '[$topicName] Question on: $firstLinePrompt',
        initialContent: '${currentCard.front}\n\n'
            '💡 I am reviewing this flashcard and need help understanding the underlying concept. '
            'Could someone in the cohort explain the step-by-step reasoning or formula derivation?',
        initialLatex: currentCard.frontLatex ?? currentCard.backLatex,
        initialSyllabusTag: topicName,
        initialIsQuestion: true,
        contextBadge: 'Flashcard Bounty • $topicName',
        onSubmit: ({
          required title,
          required content,
          required track,
          latexContent,
          isQuestion = true,
          syllabusTag = 'Flashcards',
          isAnonymous = false,
        }) {
          final bloc = _effectiveCommunityBloc;
          if (bloc != null) {
            bloc.add(
              CreateForumPostEvent(
                title: title,
                content: content,
                track: track,
                latexContent: latexContent,
                isQuestion: true,
                syllabusTag: syllabusTag,
                isAnonymous: isAnonymous,
              ),
            );
            context.showSnackBar(
              message: 'Question bounty posted to class cohort! 🎯',
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutQuint,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOutQuint,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: !isFlipped
            ? Container(
                key: const ValueKey('study-hint'),
                padding: const EdgeInsets.symmetric(vertical: 2),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.studySessionSwipeHint,
                      style: typography.footnote.regular.copyWith(
                        color: colors.textMuted,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    ShrinkableButton(
                      onTap: () {
                        unawaited(
                          FeynmanActiveRecallSheet.show(
                            context,
                            card: currentCard,
                            onRevealCard: onToggleFlip,
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '💡 Pro-Tip: Explain aloud before flipping (Feynman Active Recall)',
                              style: typography.caption.regular.copyWith(
                                color: colors.primary.withAlpha(
                                  isDark ? 210 : 170,
                                ),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.mic_rounded,
                            size: 12,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                key: const ValueKey('study-ratings'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  FsrsRatingActionBar(
                    intervalPreviews: intervalPreviews,
                    onRateRating: onRateRating,
                  ),
                  const SizedBox(height: 6),
                  ShrinkableButton(
                    onTap: () => _onPostBounty(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.help_outline_rounded,
                            size: 13,
                            color: colors.warning,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Stuck on this card? Post Bounty to Cohort',
                            style: typography.caption.bold.copyWith(
                              color: colors.warning,
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
    );
  }
}
