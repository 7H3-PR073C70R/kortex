import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/app_badge.dart';

/// Data model representing a single onboarding slide.
class OnboardingSlideData {
  const OnboardingSlideData({
    required this.badge,
    required this.badgeVariant,
    required this.tagline,
    required this.description,
    required this.illustrationBuilder,
  });

  final String badge;
  final AppBadgeVariant badgeVariant;
  final String tagline;
  final String description;
  final Widget Function(BuildContext context) illustrationBuilder;
}

/// Parallax page carousel widget for Onboarding slides.
class OnboardingPageView extends StatelessWidget {
  const OnboardingPageView({
    required this.controller,
    required this.slides,
    super.key,
    this.onPageChanged,
  });

  final PageController controller;
  final List<OnboardingSlideData> slides;
  final ValueChanged<int>? onPageChanged;

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      itemCount: slides.length,
      onPageChanged: onPageChanged,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        return _OnboardingSlideItem(
          data: slides[index],
          index: index,
          pageController: controller,
        );
      },
    );
  }
}

class _OnboardingSlideItem extends StatelessWidget {
  const _OnboardingSlideItem({
    required this.data,
    required this.index,
    required this.pageController,
  });

  final OnboardingSlideData data;
  final int index;
  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return AnimatedBuilder(
      animation: pageController,
      builder: (context, child) {
        var pageOffset = 0.0;
        if (pageController.hasClients &&
            pageController.position.haveDimensions) {
          final currentPage = pageController.page ??
              pageController.initialPage.toDouble();
          pageOffset = index - currentPage;
        }

        // Staggered parallax & opacity
        final opacity = disableAnimations
            ? 1.0
            : (1.0 - (pageOffset.abs() * 0.75)).clamp(0.0, 1.0);
        final illustrationTranslateY =
            disableAnimations ? 0.0 : (pageOffset * 30);
        final textTranslateY = disableAnimations ? 0.0 : (pageOffset * 50);

        return Opacity(
          opacity: opacity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxIllustrationHeight =
                  (constraints.maxHeight * 0.45).clamp(140.0, 240.0);

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      // Illustration with responsive aspect ratio
                      Transform.translate(
                        offset: Offset(0, illustrationTranslateY),
                        child: SizedBox(
                          height: maxIllustrationHeight,
                          child: FittedBox(
                            child: data.illustrationBuilder(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Textual Content Area with staggered entrance
                      Transform.translate(
                        offset: Offset(0, textTranslateY),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppBadge(
                              label: data.badge,
                              variant: data.badgeVariant,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              data.tagline,
                              style: typography.title1.bold.copyWith(
                                color: colors.textPrimary,
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 340),
                              child: Text(
                                data.description,
                                style:
                                    typography.callout.regular.copyWith(
                                  color: colors.textSecondary,
                                  height: 1.45,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
