import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_draft_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_flow_panel.dart';
import 'package:kortex/src/features/onboarding/data/datasources/onboarding_local_data_source.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/animated_page_indicator.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/interactive_rocket_launch_overlay.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/onboarding_page_view.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/onboarding_top_bar.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  /// Viewports at or above this width get the split showcase + auth layout
  /// instead of the full-screen mobile carousel (same breakpoint the Auth
  /// page and the main navigation rail use for desktop/web).
  static const double wideBreakpoint = 1024;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final PageController _pageController;
  late final OnboardingLocalDataSource _dataSource;
  int _currentIndex = 0;
  bool _isLaunching = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _dataSource = locator<OnboardingLocalDataSource>();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index, List<OnboardingSlideData> slides) {
    setState(() {
      _currentIndex = index;
    });
    final announcement = context.l10n.onboardingPageAnnouncement(
      index + 1,
      slides.length,
      slides[index].tagline,
    );
    unawaited(
      // ignore: deprecated_member_use, backward-compatible a11y announcement
      SemanticsService.announce(
        announcement,
        TextDirection.ltr,
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    await _dataSource.markOnboardingCompleted();
    if (!mounted) return;
    await context.router.replace(const AuthRoute());
  }

  void _onNext(int totalSlides, {required bool useRocketFinale}) {
    unawaited(HapticFeedback.lightImpact());
    if (_currentIndex < totalSlides - 1) {
      unawaited(
        _pageController.nextPage(
          duration: AppMotion.expressive,
          curve: AppMotion.easeOutCubic,
        ),
      );
    } else if (useRocketFinale) {
      setState(() {
        _isLaunching = true;
      });
    } else {
      // On wide screens the live auth flow already sits beside the
      // carousel, so the finale would only teleport the user to the same
      // form full-screen. Mark completion and move on quietly.
      unawaited(_completeOnboarding());
    }
  }

  void _onBack() {
    if (_currentIndex == 0) return;
    unawaited(HapticFeedback.lightImpact());
    unawaited(
      _pageController.previousPage(
        duration: AppMotion.expressive,
        curve: AppMotion.easeOutCubic,
      ),
    );
  }

  void _onIndicatorTap(int index) {
    unawaited(HapticFeedback.lightImpact());
    unawaited(
      _pageController.animateToPage(
        index,
        duration: AppMotion.expressive,
        curve: AppMotion.easeOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final slides = _dataSource.getOnboardingSlides(context);
    final isLastPage = _currentIndex == slides.length - 1;
    final isWide =
        MediaQuery.sizeOf(context).width >= OnboardingPage.wideBreakpoint;

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: l10n.onboardingCarouselSemantics,
      child: isWide
          ? _buildWideLayout(slides, isLastPage)
          : _buildCompactLayout(slides, isLastPage),
    );
  }

  // ==========================================================================
  // COMPACT (PHONE / SMALL TABLET): full-screen carousel, unchanged
  // ==========================================================================

  Widget _buildCompactLayout(
    List<OnboardingSlideData> slides,
    bool isLastPage,
  ) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final forwardActionLabel = isLastPage
        ? l10n.onboardingGetStarted
        : l10n.onboardingNext;
    final forwardActionSemantics = isLastPage
        ? l10n.onboardingGetStartedSemantics
        : l10n.onboardingNextSemantics;

    return Scaffold(
      backgroundColor: colors.surfacePrimary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ==============================================
          //    BASE LAYER: Onboarding Carousel
          // ==============================================
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  children: [
                    // ==========================================
                    // 1. FIXED TOP BAR (Kortex Logo + Skip CTA)
                    // ==========================================
                    OnboardingTopBar(
                      isLastPage: isLastPage,
                      onSkip: () => unawaited(_completeOnboarding()),
                    ),

                    // Breathing room between the app bar and the hero card.
                    const SizedBox(height: 10),

                    // ==========================================
                    // 2. DECOUPLED GESTURE CANVAS (PageView)
                    // ==========================================
                    Expanded(
                      child: OnboardingPageView(
                        controller: _pageController,
                        slides: slides,
                        onPageChanged: (index) => _onPageChanged(index, slides),
                      ),
                    ),

                    // ==========================================
                    // 3. FIXED BOTTOM DOCK (Indicator + Forward Circle)
                    // ==========================================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Dynamic Morphing Page Indicator
                          AnimatedPageIndicator(
                            count: slides.length,
                            currentIndex: _currentIndex,
                            activeColor: colors.primary,
                            onTap: _onIndicatorTap,
                          ),

                          // Tactile Circular Forward Action Trigger
                          _buildForwardTrigger(
                            label: forwardActionLabel,
                            semanticsLabel: forwardActionSemantics,
                            isLastPage: isLastPage,
                            isDark: isDark,
                            onTap: () => _onNext(
                              slides.length,
                              useRocketFinale: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ==============================================
          //    LAUNCH LAYER: Rocket overlay warps in over the
          //    carousel instead of teleporting the whole screen.
          // ==============================================
          if (_isLaunching)
            Positioned.fill(
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  key: const ValueKey('rocket-launch-entrance'),
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: AppMotion.standard,
                  curve: AppMotion.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.scale(
                      // Settles from a slightly warped-forward scale.
                      scale: 1.06 - (0.06 * value),
                      child: child,
                    ),
                  ),
                  child: InteractiveRocketLaunchOverlay(
                    onLaunchComplete: () => unawaited(_completeOnboarding()),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // WIDE (TABLET-LANDSCAPE / DESKTOP / WEB): showcase carousel on the left,
  // the live Auth/Signup workspace on the right — no dead-centered mobile
  // carousel, and no blocking step between discovering the product and
  // creating an account.
  // ==========================================================================

  Widget _buildWideLayout(
    List<OnboardingSlideData> slides,
    bool isLastPage,
  ) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final forwardActionLabel = isLastPage
        ? l10n.onboardingGetStarted
        : l10n.onboardingNext;
    final forwardActionSemantics = isLastPage
        ? l10n.onboardingGetStartedSemantics
        : l10n.onboardingNextSemantics;

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(
          value: locator<AuthBloc>(),
        ),
        BlocProvider<AuthModeCubit>.value(
          value: locator<AuthModeCubit>(),
        ),
        BlocProvider<AuthDraftCubit>(
          create: (_) => AuthDraftCubit(),
        ),
      ],
      // A sign-in completed from this pane routes exactly like it does on
      // the Auth page (Main vs Calibration), so the carousel never strands
      // the user on a half-funnel.
      child: AuthNavigationListener(
        // Desktop and web users expect keyboard paging alongside clicking.
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): _onBack,
            const SingleActivator(LogicalKeyboardKey.arrowRight): () => _onNext(
              slides.length,
              useRocketFinale: false,
            ),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              backgroundColor: colors.surfacePrimary,
              body: SafeArea(
                child: Row(
                  children: [
                    // ==========================================
                    // LEFT SHOWCASE PANE (Carousel)
                    // ==========================================
                    Expanded(
                      flex: 5,
                      child: Container(
                        decoration: BoxDecoration(
                          // A calm tonal wash separates the showcase side
                          // from the crisp form surface without a hard cut.
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colors.surfacePrimary,
                              colors.surfaceSecondary.withAlpha(
                                isDark ? 140 : 90,
                              ),
                            ],
                          ),
                        ),
                        child: Column(
                          children: [
                            OnboardingTopBar(
                              isLastPage: isLastPage,
                              onSkip: () => unawaited(_completeOnboarding()),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: OnboardingPageView(
                                  controller: _pageController,
                                  slides: slides,
                                  onPageChanged: (index) =>
                                      _onPageChanged(index, slides),
                                ),
                              ),
                            ),

                            // Bottom dock: indicator, Previous (once past
                            // the first slide), and the forward trigger.
                            Padding(
                              padding: const EdgeInsets.fromLTRB(36, 8, 36, 20),
                              child: Row(
                                children: [
                                  AnimatedPageIndicator(
                                    count: slides.length,
                                    currentIndex: _currentIndex,
                                    activeColor: colors.primary,
                                    onTap: _onIndicatorTap,
                                  ),
                                  const Spacer(),
                                  AnimatedSize(
                                    duration: AppMotion.standard,
                                    curve: AppMotion.easeOutCubic,
                                    child: _currentIndex > 0
                                        ? _buildPreviousButton(
                                            isDark: isDark,
                                          )
                                        : const SizedBox(height: 36),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildForwardTrigger(
                                    label: forwardActionLabel,
                                    semanticsLabel: forwardActionSemantics,
                                    isLastPage: isLastPage,
                                    isDark: isDark,
                                    onTap: () => _onNext(
                                      slides.length,
                                      useRocketFinale: false,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Structural seam between the two panes.
                    Container(
                      width: 1,
                      color: colors.surfaceBorder.withAlpha(
                        isDark ? 90 : 130,
                      ),
                    ),

                    // ==========================================
                    // RIGHT AUTH WORKSPACE (Live Signup / Sign In)
                    // ==========================================
                    Expanded(
                      flex: 4,
                      child: Container(
                        color: colors.surfacePrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 28,
                        ),
                        child: const AuthWorkspacePanel(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // Shared dock pieces
  // ==========================================================================

  /// Tactile circular forward action, identical on both layouts so the
  /// carousel reads as one product surface across breakpoints.
  Widget _buildForwardTrigger({
    required String label,
    required String semanticsLabel,
    required bool isLastPage,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Tooltip(
        message: label,
        child: PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            return ShrinkableButton(
              onTap: onTap,
              child: AnimatedContainer(
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                width: isHovered ? 58 : 56,
                height: isHovered ? 58 : 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary,
                      if (isHovered)
                        colors.primary.withAlpha(245)
                      else
                        colors.primary.withAlpha(220),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.black.withAlpha(
                        isDark ? (isHovered ? 60 : 40) : (isHovered ? 35 : 20),
                      ),
                      blurRadius: isHovered ? 12 : 8,
                      offset: Offset(
                        0,
                        isHovered ? 4 : 3,
                      ),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: AppMotion.snappy,
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                  child: Icon(
                    isLastPage
                        ? Icons.rocket_launch_outlined
                        : Icons.arrow_forward_rounded,
                    key: ValueKey<bool>(isLastPage),
                    color: colors.white,
                    size: 22,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Ghost back control for pointer users on the wide layout (keyboard
  /// arrows are bound as well). Appears with an AnimatedSize slot so the
  /// dock never jumps.
  Widget _buildPreviousButton({required bool isDark}) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Semantics(
      button: true,
      label: l10n.onboardingPreviousSlideSemantics,
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return TextButton(
            onPressed: _onBack,
            style: TextButton.styleFrom(
              foregroundColor: colors.textSecondary,
              backgroundColor: isHovered
                  ? colors.surfaceSecondary.withAlpha(isDark ? 140 : 180)
                  : context.colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.radiusBadge,
              ),
              minimumSize: const Size(48, 36),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_rounded, size: 16),
                const SizedBox(width: 6),
                Text(
                  l10n.onboardingPreviousSlide,
                  style: typography.subhead.semiBold.copyWith(
                    color: isHovered
                        ? colors.textPrimary
                        : colors.textSecondary,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
