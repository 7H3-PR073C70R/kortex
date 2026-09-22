import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/logic/deck_title_resolver.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_deck_cards_use_case.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/export/presentation/widgets/export_deck_modal_sheet.dart';
import 'package:kortex/src/shared/widgets/app_dialog.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Actions surfaced in the tile's overflow menu. Keeping destructive and
/// secondary commands behind the menu protects the card body from accidental
/// taps and gives every action a full-height hit target.
enum _DeckTileAction { details, millionaire, export, delete }

class DeckListTileCard extends StatelessWidget {
  const DeckListTileCard({
    required this.deck,
    super.key,
  });

  final DeckEntity deck;

  void _confirmDelete(BuildContext context) {
    final l10n = context.l10n;
    final decksBloc = context.read<DecksBloc>();
    unawaited(
      AppDialog.show<bool>(
        context: context,
        title: l10n.deleteStudyDeckTitle,
        description: l10n.deleteStudyDeckDesc(deck.title, deck.totalCards),
        primaryActionText: l10n.deleteDeckAction,
        isDestructive: true,
        onPrimaryAction: () {
          decksBloc.add(DecksDeckDeleted(deck.id));
        },
        secondaryActionText: l10n.cancelAction,
      ).then((didDelete) {
        if (didDelete == true && context.mounted) {
          context.showSnackBar(
            message: 'Deck "${deck.title}" deleted successfully',
            type: SnackBarType.success,
          );
        }
      }),
    );
  }

  Future<void> _exportDeck(BuildContext context) async {
    var populatedDeck = deck;
    if (populatedDeck.cards.isEmpty &&
        locator.isRegistered<GetDeckCardsUseCase>()) {
      final res = await locator<GetDeckCardsUseCase>()(deck.id);
      res.fold(
        (_) {},
        (cards) {
          populatedDeck = populatedDeck.copyWith(cards: cards);
        },
      );
    }
    if (context.mounted) {
      await ExportDeckModalSheet.show(context, deck: populatedDeck);
    }
  }

  void _handleAction(
    BuildContext context,
    _DeckTileAction action,
    String effectiveTitle,
  ) {
    unawaited(HapticFeedback.lightImpact());
    switch (action) {
      case _DeckTileAction.details:
        unawaited(context.router.push(DeckDetailRoute(deckId: deck.id)));
      case _DeckTileAction.millionaire:
        unawaited(HapticFeedback.mediumImpact());
        unawaited(
          context.router.push(
            QuizWorkspaceRoute(
              deckId: deck.id,
              deckTitle: effectiveTitle,
              assessmentMode: AssessmentMode.millionaireMode,
            ),
          ),
        );
      case _DeckTileAction.export:
        unawaited(_exportDeck(context));
      case _DeckTileAction.delete:
        _confirmDelete(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final effectiveDeck = DeckTitleResolver.enrichDeckEntity(deck);
    final masteryPercent = (effectiveDeck.masteryRate * 100).toInt().clamp(
      0,
      100,
    );

    return Semantics(
      button: true,
      label:
          '${effectiveDeck.title}. ${effectiveDeck.subject}. '
          '${l10n.decksTotalCards(effectiveDeck.totalCards)}. '
          '${l10n.decksDueBadge(effectiveDeck.dueCards)}. '
          '${l10n.decksMasteryPercent(masteryPercent)}.',
      hint: l10n.decksStartSession,
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return AnimatedScale(
            duration: AppMotion.snappy,
            curve: AppMotion.snappyCurve,
            scale: isHovered ? 1.008 : 1.0,
            child: ShrinkableButton(
              onTap: () {
                unawaited(HapticFeedback.lightImpact());
                unawaited(
                  context.router.push(
                    StudySessionRoute(deckId: effectiveDeck.id),
                  ),
                );
              },
              onLongPress: () {
                unawaited(HapticFeedback.mediumImpact());
                unawaited(
                  context.router.push(
                    DeckDetailRoute(deckId: effectiveDeck.id),
                  ),
                );
              },
              child: AnimatedContainer(
                duration: AppMotion.snappy,
                curve: AppMotion.snappyCurve,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.panel),
                  color: isDark
                      ? (isHovered
                            ? colors.surfaceSecondary.withAlpha(200)
                            : colors.surfaceSecondary.withAlpha(160))
                      : (isHovered
                            ? colors.surfacePrimary.withAlpha(240)
                            : colors.surfacePrimary.withAlpha(215)),
                  border: Border.all(
                    color: effectiveDeck.hasDueCards
                        ? (isHovered
                              ? colors.primary
                              : colors.primary.withAlpha(isDark ? 110 : 70))
                        : (isHovered
                              ? colors.primary.withAlpha(140)
                              : (isDark
                                    ? colors.surfaceBorderHighlight.withAlpha(
                                        70,
                                      )
                                    : colors.surfaceBorder.withAlpha(130))),
                    width: effectiveDeck.hasDueCards ? 1.4 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.black.withAlpha(
                        isDark ? (isHovered ? 60 : 40) : (isHovered ? 25 : 10),
                      ),
                      blurRadius: isHovered ? 14 : 10,
                      offset: Offset(0, isHovered ? 4 : 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Subject & course tags + overflow menu
                    Row(
                      children: [
                        Flexible(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary.withAlpha(
                                    isDark ? 50 : 25,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.badge,
                                  ),
                                ),
                                child: Text(
                                  effectiveDeck.subject.toUpperCase(),
                                  style: typography.caption.bold.copyWith(
                                    color: colors.primary,
                                    fontSize: 10.5,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              if (effectiveDeck.courseCode != null &&
                                  effectiveDeck.courseCode!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? colors.surfaceSecondary.withAlpha(150)
                                        : colors.surfacePrimary,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.badge,
                                    ),
                                    border: Border.all(
                                      color: colors.surfaceBorder.withAlpha(
                                        120,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    effectiveDeck.courseCode!,
                                    style: typography.caption.bold.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        _OverflowMenu(
                          onAction: (action) => _handleAction(
                            context,
                            action,
                            effectiveDeck.title,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Row 2: Title block (left) and dominant due signal (right)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                effectiveDeck.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: typography.callout.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 15.5,
                                  height: 1.3,
                                ),
                              ),
                              if (effectiveDeck.description != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  effectiveDeck.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: typography.footnote.regular.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _DueSignal(deck: effectiveDeck),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Row 3: Mastery progress bar — scannable growth signal
                    ClipRRect(
                      borderRadius: AppRadius.concentricBorderRadius(
                        AppRadius.card,
                        2.5,
                      ),
                      child: Container(
                        height: 5,
                        color: isDark
                            ? colors.surfaceBorderHighlight.withAlpha(60)
                            : colors.surfaceBorder.withAlpha(120),
                        child: AnimatedFractionallySizedBox(
                          duration: AppMotion.standard,
                          curve: AppMotion.easeOutCubic,
                          alignment: Alignment.centerLeft,
                          widthFactor: masteryPercent / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colors.primary,
                                  colors.syllabotAccent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Row 4: Caption + explicit start affordance
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${l10n.decksMasteryPercent(masteryPercent)} · '
                            '${l10n.decksTotalCards(effectiveDeck.totalCards)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.footnote.regular.copyWith(
                              color: colors.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StartSessionPill(
                          onTap: () {
                            unawaited(HapticFeedback.lightImpact());
                            unawaited(
                              context.router.push(
                                StudySessionRoute(deckId: effectiveDeck.id),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Right-aligned "how much is waiting for me" block. The due count is the
/// single most actionable number on the tile, so it reads at a glance.
class _DueSignal extends StatelessWidget {
  const _DueSignal({required this.deck});

  final DeckEntity deck;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    if (!deck.hasDueCards) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: colors.success.withAlpha(180),
            ),
            const SizedBox(width: 4),
            Text(
              l10n.deckTileUpToDate,
              style: typography.caption.regular.copyWith(
                color: colors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${deck.dueCards}',
          style: typography.title2.bold.copyWith(
            color: colors.error,
            fontSize: 22,
            height: 1.1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          l10n.deckTileDueLabel,
          style: typography.caption.bold.copyWith(
            color: colors.textMuted,
            fontSize: 10.5,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

/// Explicit entry into deck management (cards, metadata, hierarchy) without
/// leaving the one-handed "tap to study" habit intact.
class _StartSessionPill extends StatelessWidget {
  const _StartSessionPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Semantics(
      button: true,
      label: l10n.decksStartSession,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.badge),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(context.isDarkMode ? 45 : 22),
              borderRadius: BorderRadius.circular(AppRadius.badge),
              border: Border.all(
                color: colors.primary.withAlpha(context.isDarkMode ? 110 : 70),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.decksStartSession,
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                // Optical nudge: arrow reads better 0.5px right of center
                Transform.translate(
                  offset: const Offset(0.5, 0),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 13,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Overflow menu consolidating secondary and destructive deck commands.
class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.onAction});

  final void Function(_DeckTileAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return PopupMenuButton<_DeckTileAction>(
      tooltip: l10n.deckTileOptionsMenu,
      offset: const Offset(0, 44),
      position: PopupMenuPosition.under,
      color: colors.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      onSelected: onAction,
      itemBuilder: (menuContext) => [
        PopupMenuItem(
          value: _DeckTileAction.details,
          child: _MenuRow(
            icon: Icons.folder_open_rounded,
            color: colors.textSecondary,
            label: l10n.decksMenuDetails,
            typography: typography,
            textColors: colors,
          ),
        ),
        PopupMenuItem(
          value: _DeckTileAction.millionaire,
          child: _MenuRow(
            icon: Icons.military_tech_rounded,
            color: colors.warning,
            label: l10n.decksMenuMillionaire,
            typography: typography,
            textColors: colors,
          ),
        ),
        PopupMenuItem(
          value: _DeckTileAction.export,
          child: _MenuRow(
            icon: Icons.ios_share_rounded,
            color: colors.textSecondary,
            label: l10n.decksMenuExport,
            typography: typography,
            textColors: colors,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _DeckTileAction.delete,
          child: _MenuRow(
            icon: Icons.delete_outline_rounded,
            color: colors.error,
            label: l10n.decksMenuDelete,
            typography: typography,
            textColors: colors,
          ),
        ),
      ],
      child: Semantics(
        button: true,
        label: l10n.deckTileOptionsMenu,
        child: Container(
          width: 44,
          height: 36,
          alignment: Alignment.center,
          child: Icon(
            Icons.more_vert_rounded,
            size: 19,
            color: colors.textMuted.withAlpha(200),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.typography,
    required this.textColors,
  });

  final IconData icon;
  final Color color;
  final String label;
  final TypographyThemeExtension typography;
  final AppThemeColorsExtension textColors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.body.medium.copyWith(
              color: color == textColors.error ? textColors.error : null,
            ),
          ),
        ),
      ],
    );
  }
}
