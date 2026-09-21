import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/bloc/live_room_cubit.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/logic/deck_title_resolver.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Modal bottom sheet allowing users to search and select a deck
/// to study within a Live Collaboration / Study Room.
class InRoomDeckPickerModal extends StatefulWidget {
  const InRoomDeckPickerModal({super.key});

  static Future<void> show(BuildContext context) {
    final liveRoomCubit = context.read<LiveRoomCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.transparent,
      builder: (_) => BlocProvider.value(
        value: liveRoomCubit,
        child: const InRoomDeckPickerModal(),
      ),
    );
  }

  @override
  State<InRoomDeckPickerModal> createState() => _InRoomDeckPickerModalState();
}

class _InRoomDeckPickerModalState extends State<InRoomDeckPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    if (locator.isRegistered<DecksBloc>()) {
      final decksBloc = locator<DecksBloc>();
      if (decksBloc.state.allDecks.isEmpty ||
          decksBloc.state.status == DecksStatus.initial) {
        decksBloc.add(const DecksStarted());
      } else {
        decksBloc.add(const DecksRefreshed());
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    if (!locator.isRegistered<DecksBloc>()) {
      return _buildModalBody(
        context,
        const [],
        false,
        colors,
        typography,
        isDark,
      );
    }

    return BlocBuilder<DecksBloc, DecksState>(
      bloc: locator<DecksBloc>(),
      builder: (context, decksState) {
        final isLoading = decksState.status == DecksStatus.loading;
        final allDecks = decksState.allDecks;

        final filteredDecks = allDecks.where((deck) {
          if (_searchQuery.isEmpty) return true;
          final resolvedTitle = DeckTitleResolver.resolveTitle(
            deckId: deck.id,
            currentTitle: deck.title,
            subject: deck.subject,
            courseCode: deck.courseCode,
          ).toLowerCase();
          final subject = deck.subject.toLowerCase();
          return resolvedTitle.contains(_searchQuery) ||
              subject.contains(_searchQuery);
        }).toList()
          ..sort((a, b) {
            final aDue = a.dueCards > 0;
            final bDue = b.dueCards > 0;
            if (aDue && !bDue) return -1;
            if (!aDue && bDue) return 1;
            if (aDue && bDue) {
              final countCmp = b.dueCards.compareTo(a.dueCards);
              if (countCmp != 0) return countCmp;
            }
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });

        return _buildModalBody(
          context,
          filteredDecks,
          isLoading,
          colors,
          typography,
          isDark,
        );
      },
    );
  }

  Widget _buildModalBody(
    BuildContext context,
    List<DeckEntity> filteredDecks,
    bool isLoading,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 45 : 25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: colors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Study Deck',
                      style: typography.callout.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Choose a flashcard deck to study in this room',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Refresh decks',
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: () {
                    unawaited(HapticFeedback.lightImpact());
                    if (locator.isRegistered<DecksBloc>()) {
                      locator<DecksBloc>().add(const DecksRefreshed());
                    }
                  },
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Search Field
          AppTextField(
            controller: _searchController,
            hintText: 'Search decks or subjects...',
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    onPressed: _searchController.clear,
                  )
                : null,
          ),

          const SizedBox(height: 12),

          // Decks List
          Expanded(
            child: isLoading && filteredDecks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppLogoLoader(size: 36),
                        const SizedBox(height: 14),
                        Text(
                          'Fetching study decks...',
                          style: typography.caption.medium.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : filteredDecks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 40,
                              color: colors.textMuted,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No decks matching "$_searchQuery"'
                                  : 'No study decks available yet',
                              style: typography.caption.medium.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ShrinkableButton(
                              onTap: () {
                                unawaited(HapticFeedback.mediumImpact());
                                if (locator.isRegistered<DecksBloc>()) {
                                  locator<DecksBloc>().add(const DecksStarted());
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Fetch Decks',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          if (locator.isRegistered<DecksBloc>()) {
                            locator<DecksBloc>().add(const DecksRefreshed());
                          }
                          await Future<void>.delayed(
                            const Duration(milliseconds: 500),
                          );
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          itemCount: filteredDecks.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final deck = filteredDecks[index];
                            final resolvedTitle =
                                DeckTitleResolver.resolveTitle(
                              deckId: deck.id,
                              currentTitle: deck.title,
                              subject: deck.subject,
                              courseCode: deck.courseCode,
                            );
                            final isDue = deck.dueCards > 0;

                            return _DeckPickerItem(
                              deck: deck,
                              resolvedTitle: resolvedTitle,
                              isDue: isDue,
                              colors: colors,
                              typography: typography,
                              isDark: isDark,
                              onTap: () {
                                unawaited(HapticFeedback.mediumImpact());
                                context.read<LiveRoomCubit>().selectActiveDeck(
                                      deck.id,
                                      resolvedTitle,
                                    );
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _DeckPickerItem extends StatelessWidget {
  const _DeckPickerItem({
    required this.deck,
    required this.resolvedTitle,
    required this.isDue,
    required this.colors,
    required this.typography,
    required this.isDark,
    required this.onTap,
  });

  final DeckEntity deck;
  final String resolvedTitle;
  final bool isDue;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ShrinkableButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? colors.surfaceTertiary : colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDue
                ? colors.recallHard.withAlpha(isDark ? 90 : 65)
                : colors.surfaceBorder.withAlpha(isDark ? 60 : 40),
            width: isDue ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(isDark ? 40 : 20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  Icons.style_rounded,
                  size: 20,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resolvedTitle,
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${deck.totalCards} cards • ${deck.subject}',
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isDue) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.recallHard.withAlpha(isDark ? 40 : 25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${deck.dueCards} Due',
                  style: typography.caption.bold.copyWith(
                    color: colors.recallHard,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
