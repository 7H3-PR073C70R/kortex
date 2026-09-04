import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/onboarding_content/domain/entities/recommended_content_item.dart';
import 'package:kortex/src/features/onboarding_content/presentation/widgets/floating_formula_chip.dart';

/// Canvas composition rendering dynamic character and floating formula nodes.
class ContentIllustrationCanvas extends StatelessWidget {
  const ContentIllustrationCanvas({
    required this.item,
    required this.pulseValue,
    super.key,
  });

  final RecommendedContentItem item;
  final double pulseValue;

  @override
  Widget build(BuildContext context) {
    final float1 = math.sin(pulseValue * math.pi * 2) * 2.5;
    final float2 = math.cos(pulseValue * math.pi * 2) * 2.5;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Central Iconic Vector Composition
        Center(
          child: _buildCentralHero(context, item.type),
        ),

        // Floating Formula Node 1 (Top-Left)
        if (item.formulaChips.isNotEmpty)
          Positioned(
            top: 16 + float1,
            left: 16,
            child: FloatingFormulaChip(
              label: item.formulaChips[0],
              icon: Icons.auto_awesome_rounded,
            ),
          ),

        // Floating Formula Node 2 (Top-Right)
        if (item.formulaChips.length > 1)
          Positioned(
            top: 16 + float2,
            right: 16,
            child: FloatingFormulaChip(
              label: item.formulaChips[1],
              icon: Icons.functions_rounded,
            ),
          ),

        // Floating Formula Node 3 (Bottom-Left)
        if (item.formulaChips.length > 2)
          Positioned(
            bottom: 16 + float2,
            left: 16,
            child: FloatingFormulaChip(
              label: item.formulaChips[2],
              icon: Icons.speed_rounded,
            ),
          ),

        // Floating Formula Node 4 (Bottom-Right)
        if (item.formulaChips.length > 3)
          Positioned(
            bottom: 16 + float1,
            right: 16,
            child: FloatingFormulaChip(
              label: item.formulaChips[3],
              icon: Icons.verified_rounded,
            ),
          ),
      ],
    );
  }

  Widget _buildCentralHero(BuildContext context, RecommendationType type) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    switch (type) {
      case RecommendationType.pastPapers:
        return _HeroGraphicContainer(
          icon: Icons.assignment_turned_in_rounded,
          gradientColors: [
            colors.primary,
            colors.primary.withAlpha(200),
          ],
          title: 'VERIFIED EXAM Q-BANK',
          badgeText: 'Instant Past Papers',
          isDark: isDark,
        );
      case RecommendationType.flashcards:
        return _HeroGraphicContainer(
          icon: Icons.style_rounded,
          gradientColors: [
            colors.syllabotAccent,
            colors.syllabotAccent.withAlpha(200),
          ],
          title: 'SM-2 SPACED REPETITION',
          badgeText: 'Curated Topic Decks',
          isDark: isDark,
        );
      case RecommendationType.socraticAi:
        return _HeroGraphicContainer(
          icon: Icons.psychology_rounded,
          gradientColors: [
            colors.secondary,
            colors.syllabotAccent,
          ],
          title: 'SOCRATIC AI ENGINE',
          badgeText: 'Personalized Tutoring',
          isDark: isDark,
        );
    }
  }
}

class _HeroGraphicContainer extends StatelessWidget {
  const _HeroGraphicContainer({
    required this.icon,
    required this.gradientColors,
    required this.title,
    required this.badgeText,
    required this.isDark,
  });

  final IconData icon;
  final List<Color> gradientColors;
  final String title;
  final String badgeText;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 170,
      height: 170,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            gradientColors[0].withAlpha(isDark ? 100 : 60),
            gradientColors[1].withAlpha(isDark ? 40 : 20),
            colors.transparent,
          ],
          stops: const [0.0, 0.65, 1.0],
        ),
      ),
      child: Center(
        child: Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withAlpha(isDark ? 120 : 80),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 52,
            color: colors.white,
          ),
        ),
      ),
    );
  }
}
