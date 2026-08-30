import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
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

/// Decoupled gesture canvas handling PageView swiping with
/// physics-based staggered entry trajectories and 55% screen height
/// image canvas.
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
    return PageView.builder(
      controller: widget.controller,
      itemCount: widget.slides.length,
      onPageChanged: widget.onPageChanged,
      physics: const BouncingScrollPhysics(),
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

class _TrajectoryVector {
  const _TrajectoryVector({
    required this.dxMultiplier,
    required this.dyMultiplier,
    this.scaleMultiplier = 0.15,
  });

  final double dxMultiplier;
  final double dyMultiplier;
  final double scaleMultiplier;
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
    // Slide 0: Enters from Top-Left
    _TrajectoryVector(dxMultiplier: -1.2, dyMultiplier: -1),
    // Slide 1: Enters from Direct Top
    _TrajectoryVector(dxMultiplier: 0, dyMultiplier: -1.2),
    // Slide 2: Enters from Top-Right
    _TrajectoryVector(dxMultiplier: 1.2, dyMultiplier: -1),
    // Slide 3: Enters from Top-Center with scale bounce
    _TrajectoryVector(
      dxMultiplier: 0,
      dyMultiplier: -0.8,
      scaleMultiplier: 0.4,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final vector = _vectors[index % _vectors.length];
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topViewportHeight = screenHeight * 0.55;

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
        final opacity = disableAnimations
            ? 1.0
            : (1.0 - (clampedOffset.abs() * 0.65)).clamp(0.0, 1.0);

        // Top Illustration Physics Trajectory
        final graphicTranslateX = disableAnimations
            ? 0.0
            : clampedOffset * vector.dxMultiplier * 70.0;
        final graphicTranslateY = disableAnimations
            ? 0.0
            : clampedOffset.abs() * vector.dyMultiplier * 60.0;
        final graphicScale = disableAnimations
            ? 1.0
            : (1.0 - (clampedOffset.abs() * vector.scaleMultiplier)).clamp(
                0.6,
                1.0,
              );

        // Floating micro-sine oscillation
        final floatOffset = disableAnimations
            ? 0.0
            : math.sin(pulseAnimation.value * math.pi) * 4.0;

        // Bottom Content Staggered Slide & Fade
        final titleTranslateY =
            disableAnimations ? 0.0 : (clampedOffset.abs() * 26.0);
        final titleOpacity = disableAnimations
            ? 1.0
            : (1.0 - clampedOffset.abs() * 0.85).clamp(0.0, 1.0);

        final bodyTranslateY =
            disableAnimations ? 0.0 : (clampedOffset.abs() * 38.0);
        final bodyOpacity = disableAnimations
            ? 1.0
            : (1.0 - clampedOffset.abs() * 0.92).clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: Column(
            children: [
              // ==========================================
              // 1. TOP VIEWPORT: 55% of the entire screen height
              // ==========================================
              SizedBox(
                height: topViewportHeight,
                width: double.infinity,
                child: RepaintBoundary(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Physics-Driven Dynamic Vector Illustration
                      Transform.translate(
                        offset: Offset(
                          graphicTranslateX,
                          graphicTranslateY + floatOffset,
                        ),
                        child: Transform.scale(
                          scale: graphicScale,
                          child: SizedBox.expand(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: data.illustrationBuilder(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ==========================================
              // 2. BOTTOM VIEWPORT: Content Dock Area
              // ==========================================
              Expanded(
                child: RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Badge & Title Entrance
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
                                    fontSize: 26,
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

                        // Body Text Delayed Entrance
                        Transform.translate(
                          offset: Offset(0, bodyTranslateY),
                          child: Opacity(
                            opacity: bodyOpacity,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 340,
                              ),
                              child: Text(
                                data.description,
                                style: typography.callout.regular.copyWith(
                                  color: colors.textSecondary,
                                  height: 1.4,
                                  fontSize: 14.5,
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
    );
  }
}
