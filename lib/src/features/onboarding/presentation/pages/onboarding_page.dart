import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/onboarding/data/datasources/onboarding_local_data_source.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/animated_page_indicator.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/onboarding_page_view.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/onboarding_top_bar.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final PageController _pageController;
  late final OnboardingLocalDataSource _dataSource;
  int _currentIndex = 0;

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

  void _onNext(int totalSlides) {
    unawaited(HapticFeedback.lightImpact());
    if (_currentIndex < totalSlides - 1) {
      unawaited(
        _pageController.nextPage(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        ),
      );
    } else {
      unawaited(_completeOnboarding());
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
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final slides = _dataSource.getOnboardingSlides(context);
    final isLastPage = _currentIndex == slides.length - 1;

    final forwardActionLabel = isLastPage
        ? l10n.onboardingGetStarted
        : l10n.onboardingNext;
    final forwardActionSemantics = isLastPage
        ? l10n.onboardingGetStartedSemantics
        : l10n.onboardingNextSemantics;

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: l10n.onboardingCarouselSemantics,
      child: Scaffold(
        backgroundColor: colors.surfacePrimary,
        body: SafeArea(
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
                        Semantics(
                          button: true,
                          label: forwardActionSemantics,
                          child: Tooltip(
                            message: forwardActionLabel,
                            child: ShrinkableButton(
                              onTap: () => _onNext(slides.length),
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      colors.primary,
                                      colors.primary.withAlpha(220),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.primary.withAlpha(
                                        isDark ? 110 : 75,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 260),
                                  transitionBuilder: (child, animation) =>
                                      ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                                  child: Icon(
                                    isLastPage
                                        ? Icons.rocket_launch_outlined
                                        : Icons.arrow_forward_rounded,
                                    key: ValueKey<bool>(isLastPage),
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
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
      ),
    );
  }
}
