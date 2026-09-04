import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';
import 'package:kortex/src/features/decks/presentation/widgets/deck_list_tile_card.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_empty_state.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class DecksPage extends HookWidget {
  const DecksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DecksBloc>.value(
      value: locator<DecksBloc>()..add(const DecksStarted()),
      child: const _DecksView(),
    );
  }
}

class _DecksView extends HookWidget {
  const _DecksView();

  void _showDeckCreationSheet(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: isDark
            ? colors.surfaceSecondary
            : colors.surfacePrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (bottomSheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 18),
                  Text(
                    context.l10n.decksCreateSheetTitle,
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.decksCreateSheetSubtitle,
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Option 1: AI Generation
                  _ActionOptionTile(
                    icon: Icons.auto_awesome_rounded,
                    iconColor: colors.syllabotAccent,
                    title: context.l10n.decksGenerateWithAiTitle,
                    subtitle: context.l10n.decksGenerateWithAiSubtitle,
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      unawaited(
                        context.router.push(
                          SyllabotChatRoute(
                            initialPrompt: context.l10n.decksAiPromptDefault,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Option 2: Upload Documents
                  _ActionOptionTile(
                    icon: Icons.document_scanner_rounded,
                    iconColor: colors.primary,
                    title: context.l10n.decksUploadDocTitle,
                    subtitle: context.l10n.decksUploadDocSubtitle,
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      unawaited(
                        context.router.push(
                          const DocumentIngestionRoute(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Option 3: Import from LMS
                  _ActionOptionTile(
                    icon: Icons.school_rounded,
                    iconColor: colors.warning,
                    title: context.l10n.decksImportLmsTitle,
                    subtitle: context.l10n.decksImportLmsSubtitle,
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      unawaited(
                        context.router.push(
                          const DocumentIngestionRoute(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
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

    final searchController = useTextEditingController();

    useEffect(() {
      context.read<DecksBloc>().add(const DecksRefreshed());
      try {
        final tabsRouter = AutoTabsRouter.of(context);
        void onTabChange() {
          if (tabsRouter.activeIndex == 1) {
            context.read<DecksBloc>().add(const DecksRefreshed());
          }
        }

        tabsRouter.addListener(onTabChange);
        return () => tabsRouter.removeListener(onTabChange);
      } on Object catch (_) {
        return null;
      }
    }, const []);

    return Scaffold(
      backgroundColor: colors.transparent,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<DecksBloc, DecksState>(
          builder: (context, state) {
            if (state.isLoading && state.allDecks.isEmpty) {
              return _buildDecksShimmerSkeleton(colors, isDark);
            }

            return RefreshIndicator(
              onRefresh: () async {
                final completer = Completer<void>();
                context.read<DecksBloc>().add(const DecksRefreshed());
                Timer(const Duration(milliseconds: 600), completer.complete);
                return completer.future;
              },
              color: colors.primary,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  // 1. Header Title & Create Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.decksTitle,
                              style: typography.largeTitle.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 26,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.decksSubtitle,
                              style: typography.footnote.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ShrinkableButton(
                        onTap: () {
                          unawaited(HapticFeedback.lightImpact());
                          _showDeckCreationSheet(context);
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary,
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withAlpha(
                                  isDark ? 90 : 60,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. Search Field - Unified full-width text field
                  TextField(
                    controller: searchController,
                    style: typography.body.medium.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14,
                    ),
                    cursorColor: colors.primary,
                    decoration: InputDecoration(
                      hintText: l10n.decksSearchHint,
                      hintStyle: typography.body.regular.copyWith(
                        color: colors.textMuted,
                        fontSize: 13.5,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: colors.textSecondary,
                        size: 20,
                      ),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: colors.textSecondary,
                                size: 18,
                              ),
                              onPressed: () {
                                searchController.clear();
                                context.read<DecksBloc>().add(
                                  const DecksSearchQueryChanged(''),
                                );
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? colors.surfaceSecondary.withAlpha(200)
                          : colors.surfacePrimary,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark
                              ? colors.surfaceBorderHighlight.withAlpha(90)
                              : colors.surfaceBorder,
                          width: 1.2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark
                              ? colors.surfaceBorderHighlight.withAlpha(90)
                              : colors.surfaceBorder,
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: colors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (query) {
                      context.read<DecksBloc>().add(
                        DecksSearchQueryChanged(query),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // 3. Filter Category Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _FilterChip(
                          label: l10n.decksFilterAll,
                          count: state.allDecks.length,
                          isSelected: state.activeFilter == 'all',
                          onTap: () {
                            context.read<DecksBloc>().add(
                              const DecksFilterChanged('all'),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: l10n.decksFilterDue,
                          count: state.allDecks
                              .where((d) => d.dueCards > 0)
                              .fold<int>(0, (sum, d) => sum + d.dueCards),
                          isDueBadge: true,
                          isSelected: state.activeFilter == 'due',
                          onTap: () {
                            context.read<DecksBloc>().add(
                              const DecksFilterChanged('due'),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: l10n.decksFilterMastered,
                          isSelected: state.activeFilter == 'mastered',
                          onTap: () {
                            context.read<DecksBloc>().add(
                              const DecksFilterChanged('mastered'),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Decks List / Empty State
                  if (state.filteredDecks.isEmpty)
                    AppEmptyState(
                      title: l10n.decksEmptyStateTitle,
                      subtitle: l10n.decksEmptyStateSubtitle,
                      primaryActionLabel: l10n.decksCreateDeckButton,
                      onPrimaryAction: () => _showDeckCreationSheet(context),
                      secondaryActionLabel: l10n.decksUploadDocTitle,
                      onSecondaryAction: () => unawaited(
                        context.router.push(const DocumentIngestionRoute()),
                      ),
                    )
                  else
                    ...state.filteredDecks.map((deck) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: DeckListTileCard(deck: deck),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDecksShimmerSkeleton(
    AppThemeColorsExtension colors,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Shimmer
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerPlaceholder(width: 140, height: 26, borderRadius: 8),
                  SizedBox(height: 6),
                  ShimmerPlaceholder(width: 220, height: 14, borderRadius: 6),
                ],
              ),
              ShimmerPlaceholder(width: 40, height: 40, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Search Bar Shimmer
          const ShimmerPlaceholder(
            width: double.infinity,
            height: 48,
            borderRadius: 16,
          ),
          const SizedBox(height: 16),

          // 3. Filter Category Pills Shimmer
          const Row(
            children: [
              ShimmerPlaceholder(width: 80, height: 32, borderRadius: 16),
              SizedBox(width: 8),
              ShimmerPlaceholder(width: 95, height: 32, borderRadius: 16),
              SizedBox(width: 8),
              ShimmerPlaceholder(width: 85, height: 32, borderRadius: 16),
            ],
          ),
          const SizedBox(height: 24),

          // 4. Deck Card List Skeletons
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (_, _) => const ShimmerPlaceholder(
                width: double.infinity,
                height: 120,
                borderRadius: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionOptionTile extends StatelessWidget {
  const _ActionOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ShrinkableButton(
      onTap: () {
        unawaited(HapticFeedback.lightImpact());
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark
              ? colors.surfaceSecondary.withAlpha(150)
              : colors.surfacePrimary.withAlpha(200),
          border: Border.all(
            color: isDark
                ? colors.surfaceBorderHighlight.withAlpha(50)
                : colors.surfaceBorder.withAlpha(100),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: iconColor.withAlpha(isDark ? 40 : 25),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.count,
    this.isDueBadge = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;
  final bool isDueBadge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ShrinkableButton(
      onTap: () {
        unawaited(HapticFeedback.lightImpact());
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary
              : (isDark
                    ? colors.surfaceSecondary.withAlpha(150)
                    : colors.surfacePrimary.withAlpha(200)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colors.primary
                : (isDark
                      ? colors.surfaceBorderHighlight.withAlpha(70)
                      : colors.surfaceBorder.withAlpha(120)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: typography.caption.bold.copyWith(
                color: isSelected ? colors.white : colors.textPrimary,
                fontSize: 12,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDueBadge
                      ? colors.error
                      : (isSelected
                            ? colors.white.withAlpha(40)
                            : colors.primary.withAlpha(30)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: typography.footnote.bold.copyWith(
                    color: colors.white,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
