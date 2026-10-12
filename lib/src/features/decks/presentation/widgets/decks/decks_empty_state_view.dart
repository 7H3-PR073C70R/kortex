import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_empty_state.dart';

/// Context-sensitive empty state view for the decks list.
class DecksEmptyStateView extends StatelessWidget {
  const DecksEmptyStateView({
    required this.activeFilter,
    required this.allDecks,
    required this.onCreateDeckTap,
    required this.onResetFilterToAll,
    super.key,
  });

  final String activeFilter;
  final List<DeckEntity> allDecks;
  final VoidCallback onCreateDeckTap;
  final VoidCallback onResetFilterToAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (activeFilter == 'due') {
      return AppEmptyState(
        isHappy: true,
        title: 'All Caught Up! 🎉',
        subtitle: allDecks.isEmpty
            ? 'You have no due study decks for today. Create a new deck or import course materials to start practicing!'
            : "Awesome job! You've crushed all your spaced repetition reviews scheduled for today. Keep up the streak!",
        primaryActionLabel: allDecks.isEmpty
            ? l10n.decksCreateDeckButton
            : 'Review All Decks',
        onPrimaryAction: () {
          if (allDecks.isEmpty) {
            onCreateDeckTap();
          } else {
            onResetFilterToAll();
          }
        },
        secondaryActionLabel: allDecks.isEmpty
            ? l10n.decksUploadDocTitle
            : 'Practice with Syllabot AI',
        onSecondaryAction: () {
          if (allDecks.isEmpty) {
            unawaited(
              context.router.push(
                DocumentIngestionRoute(),
              ),
            );
          } else {
            unawaited(
              context.router.push(
                SyllabotChatRoute(
                  initialPrompt:
                      'Give me a 5-question Socratic review drill across my active subjects.',
                  initialMode: SocraticMode.examSim,
                ),
              ),
            );
          }
        },
      );
    }

    if (activeFilter == 'mastered') {
      return AppEmptyState(
        title: 'No Mastered Decks Yet 🎯',
        subtitle:
            'Keep reviewing your flashcards with smart spaced repetition. As your memory retention reaches 90%+, mastered decks will appear here.',
        primaryActionLabel: 'Review All Decks',
        onPrimaryAction: onResetFilterToAll,
        secondaryActionLabel: l10n.decksCreateDeckButton,
        onSecondaryAction: onCreateDeckTap,
      );
    }

    return AppEmptyState(
      title: l10n.decksEmptyStateTitle,
      subtitle: l10n.decksEmptyStateSubtitle,
      primaryActionLabel: l10n.decksCreateDeckButton,
      onPrimaryAction: onCreateDeckTap,
      secondaryActionLabel: l10n.decksUploadDocTitle,
      onSecondaryAction: () => unawaited(
        context.router.push(
          DocumentIngestionRoute(),
        ),
      ),
    );
  }
}
