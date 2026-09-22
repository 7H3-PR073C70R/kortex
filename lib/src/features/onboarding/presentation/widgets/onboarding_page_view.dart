import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_badge.dart';

/// Data model representing a single localized onboarding slide.
class OnboardingSlideData {
  const OnboardingSlideData({
    required this.badge,
    required this.badgeVariant,
    required this.tagline,
    required this.description,
    required this.illustrationBuilder,
    this.floatingPillTop,
    this.floatingPillBottom,
  });

  final String badge;
  final AppBadgeVariant badgeVariant;
  final String tagline;
  final String description;
  final Widget Function(BuildContext context) illustrationBuilder;
  final String? floatingPillTop;
  final String? floatingPillBottom;
}

/// Decoupled gesture canvas handling PageView swiping with a single
/// coherent parallax rig: the hero artwork drifts against the swipe,
/// the copy lags behind it, and everything settles on one deceleration
/// curve. Only transform/opacity are animated, and the ambient float
/// re-renders just the moving wrappers — never the card subtree.
class OnboardingPageView extends StatefulWidget {
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
  State<OnboardingPageView> createState() => _OnboardingPageViewState();
}

class _OnboardingPageViewState extends State<OnboardingPageView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    unawaited(_pulseController.repeat(reverse: true));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Bouncing physics only pay off on wide layouts where the neighbor
    // page peeks past the content constraint; on phones they just add
    // rubber-band overshoot, so clamp there.
    final canPeekNextPage = MediaQuery.sizeOf(context).width > 720;
    return PageView.builder(
      controller: widget.controller,
      itemCount: widget.slides.length,
      onPageChanged: widget.onPageChanged,
      physics: canPeekNextPage
          ? const ClampingScrollPhysics()
          : const ClampingScrollPhysics(),
      itemBuilder: (context, index) {
        return _OnboardingSlideItem(
          data: widget.slides[index],
          index: index,
          pageController: widget.controller,
          pulseAnimation: _pulseController,
        );
      },
    );
  }
}

/// Per-slide trajectory character. All slides now share one motion
/// language (horizontal parallax + depth scale); the slight variations
/// keep each slide from feeling like a copy of the last.
class _TrajectoryVector {
  const _TrajectoryVector({
    required this.parallax,
    required this.depth,
    this.rise = 0,
  });

  /// How far the artwork drifts against the swipe, in logical pixels.
  final double parallax;

  /// How much the artwork shrinks as it slides away (0–1).
  final double depth;

  /// Extra upward drift while off-center, in logical pixels.
  final double rise;
}

class _OnboardingSlideItem extends StatelessWidget {
  const _OnboardingSlideItem({
    required this.data,
    required this.index,
    required this.pageController,
    required this.pulseAnimation,
  });

  final OnboardingSlideData data;
  final int index;
  final PageController pageController;
  final Animation<double> pulseAnimation;

  static const List<_TrajectoryVector> _vectors = [
    _TrajectoryVector(parallax: 34, depth: 0.10),
    _TrajectoryVector(parallax: 26, depth: 0.12, rise: 8),
    _TrajectoryVector(parallax: 34, depth: 0.10),
    _TrajectoryVector(parallax: 28, depth: 0.14, rise: 10),
  ];

  /// Deceleration-shaped falloff: movement leaves quickly and eases
  /// into place, so settling never snaps.
  static double _settle(double t) => 1 - math.pow(1 - t, 3).toDouble();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final vector = _vectors[index % _vectors.length];

    // Static hero card — built once per theme change, passed through
    // as `child` so per-frame rebuilds never touch it or the artwork.
    // A calm, flat well (no colored gradient bloom, no drop-shadow glow)
    // keeps focus on the motion graphics and lets the elevated cards
    // inside each scene read with real depth.
    final heroCard = RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.radiusDialog,
          color: colors.surfaceSecondary,
          border: Border.all(
            color: colors.surfaceBorder.withAlpha(isDark ? 90 : 130),
          ),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.radiusDialog,
          child: FittedBox(
            child: SizedBox(
              width: 360,
              height: 280,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: data.illustrationBuilder(context),
              ),
            ),
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final topViewportHeight = (availableHeight * 0.54).clamp(160.0, 380.0);

        return AnimatedBuilder(
          animation: Listenable.merge([pageController, pulseAnimation]),
          builder: (context, child) {
            var pageOffset = 0.0;
            if (pageController.hasClients &&
                pageController.position.haveDimensions) {
              final currentPage =
                  pageController.page ?? pageController.initialPage.toDouble();
              pageOffset = index - currentPage;
            }

            final clampedOffset = pageOffset.clamp(-1.0, 1.0);
            final magnitude = _settle(clampedOffset.abs());

            // Hero artwork: drifts against the swipe (parallax), eases
            // upward slightly and recedes with depth. Clamped well above
            // scale-zero so nothing ever teleports or collapses.
            final graphicTranslateX = disableAnimations
                ? 0.0
                : clampedOffset * vector.parallax;
            final graphicTranslateY = disableAnimations
                ? 0.0
                : -magnitude * vector.rise;
            final graphicScale = disableAnimations
                ? 1.0
                : 1.0 - magnitude * vector.depth;

            // Gentle floating breath, applied to the wrapper only.
            final floatOffset = disableAnimations || clampedOffset.abs() > 0.4
                ? 0.0
                : math.sin(pulseAnimation.value * math.pi) * 3.0;

            // Copy dock: lags the artwork by a smaller offset so the
            // two layers separate, then reunite as the page settles.
            final titleTranslateY = disableAnimations ? 0.0 : magnitude * 14.0;
            final titleOpacity = disableAnimations
                ? 1.0
                : (1.0 - magnitude * 0.55).clamp(0.0, 1.0);
            final bodyTranslateY = disableAnimations ? 0.0 : magnitude * 22.0;
            final bodyOpacity = disableAnimations
                ? 1.0
                : (1.0 - magnitude * 0.75).clamp(0.0, 1.0);

            return RepaintBoundary(
              child: Column(
                children: [
                  // ==========================================
                  // 1. TOP VIEWPORT: Hero Canvas with artwork
                  // ==========================================
                  SizedBox(
                    height: topViewportHeight,
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Transform.translate(
                        offset: Offset(
                          graphicTranslateX,
                          graphicTranslateY + floatOffset,
                        ),
                        child: Transform.scale(
                          scale: graphicScale,
                          child: child,
                        ),
                      ),
                    ),
                  ),

                  // ==========================================
                  // 2. BOTTOM VIEWPORT: Content Dock Area
                  // ==========================================
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Badge & Headline
                            Transform.translate(
                              offset: Offset(0, titleTranslateY),
                              child: Opacity(
                                opacity: titleOpacity,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AppBadge(
                                      label: data.badge,
                                      variant: data.badgeVariant,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      data.tagline,
                                      style: typography.title1.bold.copyWith(
                                        color: colors.textPrimary,
                                        letterSpacing: -0.6,
                                        fontSize: 24,
                                        height: 1.15,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Body Text — deeper lag for a staggered feel
                            Transform.translate(
                              offset: Offset(0, bodyTranslateY),
                              child: Opacity(
                                opacity: bodyOpacity,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 480,
                                  ),
                                  child: Text(
                                    data.description,
                                    style: typography.callout.regular.copyWith(
                                      color: colors.textSecondary,
                                      height: 1.4,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          child: heroCard,
        );
      },
    );
  }
}
