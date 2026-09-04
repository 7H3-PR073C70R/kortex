import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/onboarding_content/domain/entities/recommended_content_item.dart';
import 'package:kortex/src/features/onboarding_content/presentation/widgets/content_illustration_canvas.dart';
import 'package:kortex/src/shared/widgets/app_badge.dart';

/// Dynamic gesture PageView with multi-layer physics parallax
/// and elastic scaling.
class ContentRecommendationPageView extends StatefulWidget {
  const ContentRecommendationPageView({
    required this.controller,
    required this.items,
    required this.onPageChanged,
    super.key,
  });

  final PageController controller;
  final List<RecommendedContentItem> items;
  final ValueChanged<int> onPageChanged;

  @override
  State<ContentRecommendationPageView> createState() =>
      _ContentRecommendationPageViewState();
}

class _ContentRecommendationPageViewState
    extends State<ContentRecommendationPageView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    final disableAnimations = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (!disableAnimations) {
      unawaited(_pulseController.repeat(reverse: true));
    }
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
      onPageChanged: widget.onPageChanged,
      physics: const BouncingScrollPhysics(),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        return _RecommendationSlideItem(
          item: widget.items[index],
          index: index,
          pageController: widget.controller,
          pulseAnimation: _pulseController,
        );
      },
    );
  }
}

class _RecommendationSlideItem extends StatelessWidget {
  const _RecommendationSlideItem({
    required this.item,
    required this.index,
    required this.pageController,
    required this.pulseAnimation,
  });

  final RecommendedContentItem item;
  final int index;
  final PageController pageController;
  final Animation<double> pulseAnimation;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final topViewportHeight = (availableHeight * 0.52).clamp(160.0, 360.0);

        return AnimatedBuilder(
          animation: Listenable.merge([pageController, pulseAnimation]),
          builder: (context, child) {
            var pageOffset = 0.0;
            if (pageController.hasClients &&
                pageController.position.haveDimensions &&
                pageController.position.hasContentDimensions) {
              try {
                final currentPage =
                    pageController.page ??
                    pageController.initialPage.toDouble();
                pageOffset = index - currentPage;
              } on Object catch (_) {
                pageOffset = 0.0;
              }
            }

            final clampedOffset = pageOffset.clamp(-1.0, 1.0);
            final opacity = disableAnimations
                ? 1.0
                : (1.0 - (clampedOffset.abs() * 0.5)).clamp(0.0, 1.0);

            // Subtle, elegant depth scaling without distortion or rotation
            final graphicScale = disableAnimations
                ? 1.0
                : (1.0 - (clampedOffset.abs() * 0.05)).clamp(0.95, 1.0);

            // Staggered text vertical transition
            final textTranslateY = disableAnimations
                ? 0.0
                : (clampedOffset.abs() * 12.0);
            final textOpacity = disableAnimations
                ? 1.0
                : (1.0 - (clampedOffset.abs() * 0.6)).clamp(0.0, 1.0);

            return Opacity(
              opacity: opacity,
              child: Column(
                children: [
                  // ==========================================
                  // 1. TOP GRAPHIC VIEWPORT (Glass Card)
                  // ==========================================
                  SizedBox(
                    height: topViewportHeight,
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                      child: Transform.scale(
                        scale: graphicScale,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                color: isDark
                                    ? colors.surfaceSecondary.withAlpha(120)
                                    : colors.surfacePrimary.withAlpha(200),
                                border: Border.all(
                                  color: isDark
                                      ? colors.surfaceBorderHighlight.withAlpha(
                                          80,
                                        )
                                      : colors.white.withAlpha(220),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primary.withAlpha(
                                      isDark ? 40 : 20,
                                    ),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ContentIllustrationCanvas(
                                item: item,
                                pulseValue: pulseAnimation.value,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ==========================================
                  // 2. BOTTOM CONTENT VIEWPORT (Badge + Headline + Body)
                  // ==========================================
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 6),
                        child: Transform.translate(
                          offset: Offset(0, textTranslateY),
                          child: Opacity(
                            opacity: textOpacity,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 8,
                                      sigmaY: 8,
                                    ),
                                    child: AppBadge(
                                      label: item.badge,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  item.tagline,
                                  style: typography.title1.bold.copyWith(
                                    color: colors.textPrimary,
                                    letterSpacing: -0.5,
                                    fontSize: 24,
                                    height: 1.18,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 340,
                                  ),
                                  child: Text(
                                    item.description,
                                    style: typography.callout.regular.copyWith(
                                      color: colors.textSecondary,
                                      height: 1.45,
                                      fontSize: 14.5,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
