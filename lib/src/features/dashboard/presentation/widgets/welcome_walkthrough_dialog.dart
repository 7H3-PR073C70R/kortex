import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class _WalkthroughSlide {
  const _WalkthroughSlide({
    required this.icon,
    required this.badge,
    required this.badgeColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String badge;
  final Color badgeColor;
  final String title;
  final String description;
}

/// Interactive welcome walkthrough dialog displayed when a new user arrives
/// at the Dashboard after account creation.
class WelcomeWalkthroughDialog extends StatefulWidget {
  const WelcomeWalkthroughDialog({
    super.key,
    this.onDismissed,
  });

  final VoidCallback? onDismissed;

  @override
  State<WelcomeWalkthroughDialog> createState() =>
      _WelcomeWalkthroughDialogState();
}

class _WelcomeWalkthroughDialogState extends State<WelcomeWalkthroughDialog> {
  late final PageController _pageController;
  int _currentIndex = 0;

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

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _handleNext(int totalSlides) {
    unawaited(HapticFeedback.lightImpact());
    if (_currentIndex < totalSlides - 1) {
      unawaited(
        _pageController.nextPage(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        ),
      );
    } else {
      _close();
    }
  }

  void _handlePrevious() {
    unawaited(HapticFeedback.lightImpact());
    if (_currentIndex > 0) {
      unawaited(
        _pageController.previousPage(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  void _close() {
    widget.onDismissed?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final slides = [
      _WalkthroughSlide(
        icon: Icons.auto_awesome_rounded,
        badge: 'ACTIVE RECALL',
        badgeColor: colors.primary,
        title: l10n.welcomeWalkthroughSlide1Title,
        description: l10n.welcomeWalkthroughSlide1Desc,
      ),
      _WalkthroughSlide(
        icon: Icons.psychology_rounded,
        badge: 'AI TUTOR',
        badgeColor: colors.syllabotAccent,
        title: l10n.welcomeWalkthroughSlide2Title,
        description: l10n.welcomeWalkthroughSlide2Desc,
      ),
      _WalkthroughSlide(
        icon: Icons.repeat_rounded,
        badge: 'SPACED REPETITION',
        badgeColor: colors.warning,
        title: l10n.welcomeWalkthroughSlide3Title,
        description: l10n.welcomeWalkthroughSlide3Desc,
      ),
      _WalkthroughSlide(
        icon: Icons.groups_rounded,
        badge: 'STUDY HUB',
        badgeColor: colors.success,
        title: l10n.welcomeWalkthroughSlide4Title,
        description: l10n.welcomeWalkthroughSlide4Desc,
      ),
    ];

    final isLast = _currentIndex == slides.length - 1;

    return Dialog(
      backgroundColor: colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: colors.surfacePrimary,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colors.surfaceBorderHighlight.withAlpha(isDark ? 80 : 120),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withAlpha(isDark ? 40 : 25),
              blurRadius: 32,
              spreadRadius: 4,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Header Bar with Welcome & Skip
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '🎉 ',
                              style: typography.title2.bold,
                            ),
                            Text(
                              l10n.welcomeWalkthroughTitle,
                              style: typography.title3.bold.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.welcomeWalkthroughSubtitle,
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: colors.textSecondary,
                        size: 20,
                      ),
                      tooltip: l10n.welcomeWalkthroughSkip,
                      onPressed: _close,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: colors.surfaceBorder.withAlpha(isDark ? 60 : 100),
              ),

              // Carousel PageView
              SizedBox(
                height: 270,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: slides.length,
                  itemBuilder: (context, index) {
                    final slide = slides[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Glowing Icon Container
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: slide.badgeColor.withAlpha(isDark ? 45 : 30),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: slide.badgeColor.withAlpha(isDark ? 120 : 80),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              slide.icon,
                              color: slide.badgeColor,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: slide.badgeColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              slide.badge,
                              style: typography.caption.bold.copyWith(
                                color: slide.badgeColor,
                                fontSize: 10.5,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Slide Title
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: typography.body.bold.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Slide Description
                          Text(
                            slide.description,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                              height: 1.4,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom Indicator & Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Step Dots Indicator
                    Row(
                      children: List.generate(slides.length, (idx) {
                        final isSelected = idx == _currentIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 6),
                          width: isSelected ? 22 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.primary
                                : colors.surfaceBorderHighlight,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),

                    // Navigation Action Buttons
                    Row(
                      children: [
                        if (_currentIndex > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: TextButton(
                              onPressed: _handlePrevious,
                              child: Text(
                                l10n.welcomeWalkthroughPrevious,
                                style: typography.caption.bold.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ShrinkableButton(
                          onTap: () => _handleNext(slides.length),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary.withAlpha(60),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isLast
                                      ? l10n.welcomeWalkthroughGetStarted
                                      : l10n.welcomeWalkthroughNext,
                                  style: typography.caption.bold.copyWith(
                                    color: colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  isLast
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.arrow_forward_rounded,
                                  color: colors.white,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
