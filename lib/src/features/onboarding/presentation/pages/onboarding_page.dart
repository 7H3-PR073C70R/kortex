import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/onboarding/data/datasources/onboarding_local_data_source.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/animated_page_indicator.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/onboarding_page_view.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

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
    await context.router.replace(const MainRoute());
  }

  void _onNext(int totalSlides) {
    if (_currentIndex < totalSlides - 1) {
      unawaited(
        _pageController.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        ),
      );
    } else {
      unawaited(_completeOnboarding());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final slides = _dataSource.getOnboardingSlides(context);
    final isLastPage = _currentIndex == slides.length - 1;

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: l10n.onboardingCarouselSemantics,
      child: Scaffold(
        backgroundColor: colors.surfacePrimary,
        body: SafeArea(
          child: Column(
            children: [
              // Top Action Bar with Skip button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Identity Pill
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.appName,
                          style: typography.caption.bold.copyWith(
                            letterSpacing: 1.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    // Skip button
                    if (!isLastPage)
                      Semantics(
                        button: true,
                        label: l10n.onboardingSkipSemantics,
                        child: TextButton(
                          onPressed: () => unawaited(_completeOnboarding()),
                          style: TextButton.styleFrom(
                            foregroundColor: colors.textMuted,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            l10n.onboardingSkip,
                            style: typography.subhead.semiBold.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 36),
                  ],
                ),
              ),

              // Carousel Page View
              Expanded(
                child: OnboardingPageView(
                  controller: _pageController,
                  slides: slides,
                  onPageChanged: (index) => _onPageChanged(index, slides),
                ),
              ),

              // Bottom Navigation Controller Area
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated Page Indicator
                    AnimatedPageIndicator(
                      count: slides.length,
                      currentIndex: _currentIndex,
                      activeColor: colors.primary,
                      onTap: (index) {
                        unawaited(
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Primary Action Button
                    SizedBox(
                      width: double.infinity,
                      child: AppButton.primary(
                        text: isLastPage
                            ? l10n.onboardingGetStarted
                            : l10n.onboardingNext,
                        size: AppButtonSize.large,
                        suffixIcon: Icon(
                          isLastPage
                              ? Icons.rocket_launch_outlined
                              : Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                        semanticLabel: isLastPage
                            ? l10n.onboardingGetStartedSemantics
                            : l10n.onboardingNextSemantics,
                        onPressed: () => _onNext(slides.length),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
