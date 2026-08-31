import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/animated_page_indicator.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/aura_mesh_nebula.dart';
import 'package:kortex/src/features/onboarding_content/domain/entities/recommended_content_item.dart';
import 'package:kortex/src/features/onboarding_content/presentation/bloc/content_recommendation_cubit.dart';
import 'package:kortex/src/features/onboarding_content/presentation/widgets/content_chat_view.dart';
import 'package:kortex/src/features/onboarding_content/presentation/widgets/content_recommendation_page_view.dart';
import 'package:kortex/src/features/onboarding_content/presentation/widgets/content_top_bar.dart';
import 'package:kortex/src/gen/assets.gen.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class OnboardingContentPage extends StatelessWidget {
  const OnboardingContentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: locator<AuthModeCubit>()),
        BlocProvider<ContentRecommendationCubit>(
          create: (_) {
            final cubit = locator<ContentRecommendationCubit>();
            unawaited(
              cubit.loadRecommendations(
                localizeHandler: (key, params) {
                  switch (key) {
                    case 'pastPapersTagline':
                      return l10n.contentPastPapersTagline;
                    case 'pastPapersDesc':
                      return l10n.contentPastPapersDesc(
                        params['examType'] as String? ?? '',
                        params['subjects'] as String? ?? '',
                      );
                    case 'flashcardsTagline':
                      return l10n.contentFlashcardsTagline(
                        params['field'] as String? ?? '',
                      );
                    case 'flashcardsDesc':
                      return l10n.contentFlashcardsDesc(
                        params['field'] as String? ?? '',
                      );
                    case 'socraticTagline':
                      return l10n.contentSocraticTagline;
                    case 'socraticDesc':
                      return l10n.contentSocraticDesc(
                        params['level'] as String? ?? '',
                        params['field'] as String? ?? '',
                      );
                    case 'badgeCurated':
                      return l10n.contentBadgeCurated;
                    case 'badgeActiveRecall':
                      return l10n.contentBadgeActiveRecall;
                    case 'badgeSocratic':
                      return l10n.contentBadgeSocratic;
                    default:
                      return '';
                  }
                },
              ),
            );
            return cubit;
          },
        ),
      ],
      child: const _ContentRecommendationView(),
    );
  }
}

class _ContentRecommendationView extends StatefulWidget {
  const _ContentRecommendationView();

  @override
  State<_ContentRecommendationView> createState() =>
      _ContentRecommendationViewState();
}

class _ContentRecommendationViewState
    extends State<_ContentRecommendationView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index, List<RecommendedContentItem> items) {
    context.read<ContentRecommendationCubit>().onPageChanged(index);

    final l10n = context.l10n;
    if (index < items.length) {
      final announcement = l10n.contentRecommendationAnnouncement(
        index + 1,
        items.length,
        items[index].tagline,
      );
      unawaited(
        // ignore: deprecated_member_use, backward-compatible a11y announcement
        SemanticsService.announce(announcement, TextDirection.ltr),
      );
    }
  }

  Future<void> _completeToDashboard() async {
    // Always route through Permissions gate before entering Dashboard.
    await context.router.replaceAll([const PermissionsRoute()]);
  }

  void _onNext(int totalItems) {
    unawaited(HapticFeedback.lightImpact());
    final currentIndex = context
        .read<ContentRecommendationCubit>()
        .state
        .currentIndex;
    if (currentIndex < totalItems - 1) {
      unawaited(
        _pageController.nextPage(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        ),
      );
    } else {
      unawaited(_completeToDashboard());
    }
  }

  void _onIndicatorTap(int index) {
    unawaited(HapticFeedback.lightImpact());
    unawaited(
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authMode = context.watch<AuthModeCubit>().state;
    if (authMode.isChat) {
      return Scaffold(
        body: AuraMeshNebula(
          child: SafeArea(
            child: Column(
              children: [
                ContentTopBar(
                  onSkip: () => unawaited(_completeToDashboard()),
                ),
                const Expanded(
                  child: ContentChatView(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: AuraMeshNebula(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 1024) {
                return _DesktopContentSplitLayout(
                  pageController: _pageController,
                  onPageChanged: _onPageChanged,
                  onSkip: () => unawaited(_completeToDashboard()),
                  onNext: _onNext,
                  onIndicatorTap: _onIndicatorTap,
                );
              } else if (constraints.maxWidth >= 600) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _MobileContentLayout(
                      pageController: _pageController,
                      onPageChanged: _onPageChanged,
                      onSkip: () => unawaited(_completeToDashboard()),
                      onNext: _onNext,
                      onIndicatorTap: _onIndicatorTap,
                    ),
                  ),
                );
              } else {
                return _MobileContentLayout(
                  pageController: _pageController,
                  onPageChanged: _onPageChanged,
                  onSkip: () => unawaited(_completeToDashboard()),
                  onNext: _onNext,
                  onIndicatorTap: _onIndicatorTap,
                );
              }
            },
          ),
        ),
      ),
    );
  }
}

class _DesktopContentSplitLayout extends StatelessWidget {
  const _DesktopContentSplitLayout({
    required this.pageController,
    required this.onPageChanged,
    required this.onSkip,
    required this.onNext,
    required this.onIndicatorTap,
  });

  final PageController pageController;
  final void Function(int, List<RecommendedContentItem>) onPageChanged;
  final VoidCallback onSkip;
  final void Function(int) onNext;
  final void Function(int) onIndicatorTap;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ContentRecommendationCubit>().state;
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Row(
      children: [
        // Left Column: Editorial context & highlights
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    AppAssets.svgs.kortexLogo.svg(
                      width: 28,
                      height: 28,
                      colorFilter: ColorFilter.mode(
                        colors.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'KORTEXIFY',
                      style: typography.headline.bold.copyWith(
                        color: colors.textPrimary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                Text(
                  l10n.contentDesktopHeroTitle,
                  style: typography.largeTitle.bold.copyWith(
                    color: colors.textPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.contentDesktopHeroSubtitle,
                  style: typography.callout.regular.copyWith(
                    color: colors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                _DesktopFeatureItem(
                  icon: Icons.auto_awesome_rounded,
                  text: l10n.contentFeature1,
                  colors: colors,
                  typography: typography,
                ),
                const SizedBox(height: 14),
                _DesktopFeatureItem(
                  icon: Icons.psychology_rounded,
                  text: l10n.contentFeature2,
                  colors: colors,
                  typography: typography,
                ),
                const SizedBox(height: 14),
                _DesktopFeatureItem(
                  icon: Icons.forum_rounded,
                  text: l10n.contentFeature3,
                  colors: colors,
                  typography: typography,
                ),
              ],
            ),
          ),
        ),

        // Right Column: Focused card viewport & navigation dock
        Expanded(
          flex: 5,
          child: Column(
            children: [
              ContentTopBar(onSkip: onSkip),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: ContentRecommendationPageView(
                      controller: pageController,
                      items: state.items,
                      onPageChanged: (index) =>
                          onPageChanged(index, state.items),
                    ),
                  ),
                ),
              ),
              _ContentBottomDock(
                totalItems: state.items.length,
                currentIndex: state.currentIndex,
                onNext: () => onNext(state.items.length),
                onIndicatorTap: onIndicatorTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopFeatureItem extends StatelessWidget {
  const _DesktopFeatureItem({
    required this.icon,
    required this.text,
    required this.colors,
    required this.typography,
  });

  final IconData icon;
  final String text;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.primary.withAlpha(25),
          ),
          child: Icon(icon, color: colors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: typography.footnote.medium.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileContentLayout extends StatelessWidget {
  const _MobileContentLayout({
    required this.pageController,
    required this.onPageChanged,
    required this.onSkip,
    required this.onNext,
    required this.onIndicatorTap,
  });

  final PageController pageController;
  final void Function(int, List<RecommendedContentItem>) onPageChanged;
  final VoidCallback onSkip;
  final void Function(int) onNext;
  final void Function(int) onIndicatorTap;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ContentRecommendationCubit>().state;

    return Column(
      children: [
        ContentTopBar(onSkip: onSkip),
        Expanded(
          child: ContentRecommendationPageView(
            controller: pageController,
            items: state.items,
            onPageChanged: (index) => onPageChanged(index, state.items),
          ),
        ),
        _ContentBottomDock(
          totalItems: state.items.length,
          currentIndex: state.currentIndex,
          onNext: () => onNext(state.items.length),
          onIndicatorTap: onIndicatorTap,
        ),
      ],
    );
  }
}

class _ContentBottomDock extends StatelessWidget {
  const _ContentBottomDock({
    required this.totalItems,
    required this.currentIndex,
    required this.onNext,
    required this.onIndicatorTap,
  });

  final int totalItems;
  final int currentIndex;
  final VoidCallback onNext;
  final void Function(int) onIndicatorTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isLastPage = currentIndex >= totalItems - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AnimatedPageIndicator(
            count: totalItems > 0 ? totalItems : 1,
            currentIndex: currentIndex,
            onTap: onIndicatorTap,
          ),
          Semantics(
            button: true,
            label: isLastPage
                ? l10n.contentGetStartedButton
                : l10n.contentNextButton,
            child: ShrinkableButton(
              onTap: onNext,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: EdgeInsets.symmetric(
                  horizontal: isLastPage ? 24 : 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withAlpha(80),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLastPage
                          ? l10n.contentGetStartedButton
                          : l10n.contentNextButton,
                      style: typography.callout.semiBold.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isLastPage
                          ? Icons.rocket_launch_rounded
                          : Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
