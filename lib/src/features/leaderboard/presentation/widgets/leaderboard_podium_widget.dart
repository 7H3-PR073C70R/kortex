import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/leaderboard/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/features/leaderboard/presentation/widgets/leaderboard_scholar_sheet.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';

/// High-impact 3D gamified podium for top 3 scholars on the leaderboard.
class LeaderboardPodiumWidget extends StatelessWidget {
  const LeaderboardPodiumWidget({
    required this.entries,
    super.key,
  });

  final List<LeaderboardEntryEntity> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final isDark = context.isDarkMode;

    // Metallic palette tokens
    const goldPrimary = Color(0xFFFFB300);
    const goldLight = Color(0xFFFFE082);
    const goldDark = Color(0xFFFF8F00);

    const silverPrimary = Color(0xFFB0BEC5);
    const silverLight = Color(0xFFECEFF1);
    const silverDark = Color(0xFF78909C);

    const bronzePrimary = Color(0xFFBCAAA4);
    const bronzeLight = Color(0xFFD7CCC8);
    const bronzeDark = Color(0xFF8D6E63);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.fromLTRB(14, 28, 14, 16),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceElevated.withAlpha(180)
            : colors.surfacePrimary.withAlpha(220),
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 45 : 25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? goldPrimary.withAlpha(20)
                : colors.primary.withAlpha(15),
            blurRadius: 32,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Ambient champion gold aura behind #1
          if (entries.isNotEmpty)
            Positioned(
              top: 0,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: goldPrimary.withAlpha(isDark ? 40 : 25),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── Rank 2 (Silver) ──────────────────────────────────────────
              if (entries.length >= 2)
                Expanded(
                  child: _PodiumPedestal(
                    entry: entries[1],
                    place: 2,
                    romanNumeral: 'II',
                    primaryColor: silverPrimary,
                    lightColor: silverLight,
                    darkColor: silverDark,
                    pedestalHeight: 96,
                    avatarSize: 52,
                    delay: const Duration(milliseconds: 120),
                  ),
                )
              else
                const Expanded(child: SizedBox.shrink()),

              // ── Rank 1 (Gold Champion) ───────────────────────────────────
              if (entries.isNotEmpty)
                Expanded(
                  child: _PodiumPedestal(
                    entry: entries[0],
                    place: 1,
                    romanNumeral: 'I',
                    primaryColor: goldPrimary,
                    lightColor: goldLight,
                    darkColor: goldDark,
                    pedestalHeight: 132,
                    avatarSize: 66,
                    delay: Duration.zero,
                    isFirst: true,
                  ),
                )
              else
                const Expanded(child: SizedBox.shrink()),

              // ── Rank 3 (Bronze) ──────────────────────────────────────────
              if (entries.length >= 3)
                Expanded(
                  child: _PodiumPedestal(
                    entry: entries[2],
                    place: 3,
                    romanNumeral: 'III',
                    primaryColor: bronzePrimary,
                    lightColor: bronzeLight,
                    darkColor: bronzeDark,
                    pedestalHeight: 76,
                    avatarSize: 48,
                    delay: const Duration(milliseconds: 220),
                  ),
                )
              else
                const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ],
      ),
    );
  }
}

class _PodiumPedestal extends StatefulWidget {
  const _PodiumPedestal({
    required this.entry,
    required this.place,
    required this.romanNumeral,
    required this.primaryColor,
    required this.lightColor,
    required this.darkColor,
    required this.pedestalHeight,
    required this.avatarSize,
    required this.delay,
    this.isFirst = false,
  });

  final LeaderboardEntryEntity entry;
  final int place;
  final String romanNumeral;
  final Color primaryColor;
  final Color lightColor;
  final Color darkColor;
  final double pedestalHeight;
  final double avatarSize;
  final Duration delay;
  final bool isFirst;

  @override
  State<_PodiumPedestal> createState() => _PodiumPedestalState();
}

class _PodiumPedestalState extends State<_PodiumPedestal> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final entry = widget.entry;
    final streakDays = entry.streakDays > 0 ? entry.streakDays : 1;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        unawaited(HapticFeedback.selectionClick());
        unawaited(
          LeaderboardScholarSheet.show(context, entry: entry),
        );
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Avatar + Crown + Badge Stack
            Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                // Crown for #1
                if (widget.isFirst)
                  Positioned(
                    top: -24,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.primaryColor.withAlpha(120),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Text(
                        '👑',
                        style: typography.title2.bold.copyWith(fontSize: 26),
                      ),
                    )
                        .animate(
                          onPlay: (controller) =>
                              controller.repeat(reverse: true),
                        )
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.08, 1.08),
                          duration: const Duration(milliseconds: 1500),
                          curve: Curves.easeInOut,
                        )
                        .shimmer(
                          duration: const Duration(seconds: 2),
                          color: widget.lightColor.withAlpha(150),
                        ),
                  ),

                // Avatar with metallic halo border
                Container(
                  padding: EdgeInsets.all(widget.isFirst ? 3.5 : 2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [widget.lightColor, widget.darkColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.primaryColor.withAlpha(isDark ? 70 : 40),
                        blurRadius: widget.isFirst ? 16 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: AppAvatar(
                    customDimension: widget.avatarSize,
                    imageUrl: entry.avatarUrl,
                    name: entry.userName,
                    backgroundColor: widget.primaryColor.withAlpha(30),
                    foregroundColor: colors.textPrimary,
                  ),
                ),

                // Place Number Pill
                Positioned(
                  bottom: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [widget.lightColor, widget.darkColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? colors.backgroundPrimary : colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.darkColor.withAlpha(100),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '#${widget.place}',
                      style: typography.caption.bold.copyWith(
                        fontSize: 10,
                        color: Colors.black87,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            )
                .animate(delay: widget.delay)
                .scale(
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutQuint,
                  duration: AppMotion.expressive,
                )
                .fadeIn(),

            const SizedBox(height: 14),

            // Scholar Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                entry.userName.split(' ').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.footnote.bold.copyWith(
                  color: entry.isCurrentUser ? colors.primary : colors.textPrimary,
                  fontSize: widget.isFirst ? 13 : 12,
                ),
              ),
            ).animate(delay: widget.delay).fadeIn(),

            const SizedBox(height: 4),

            // ── Interactive Streak & XP Pills on Podium! ─────────────────
            // 1. Streak Flame Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF5722).withAlpha(isDark ? 60 : 35),
                    const Color(0xFFFF9800).withAlpha(isDark ? 40 : 20),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFF9800).withAlpha(isDark ? 100 : 70),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🔥',
                    style: typography.caption.regular.copyWith(fontSize: 10),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${streakDays}d',
                    style: typography.caption.bold.copyWith(
                      color: const Color(0xFFFF9800),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ).animate(delay: widget.delay).fadeIn(),

            const SizedBox(height: 3),

            // 2. XP Pill
            Text(
              '${entry.weeklyXp} XP',
              style: typography.caption.bold.copyWith(
                color: widget.primaryColor,
                fontSize: widget.isFirst ? 12 : 11,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ).animate(delay: widget.delay).fadeIn(),

            const SizedBox(height: 10),

            // ── 3D Pedestal Pillar ────────────────────────────────────────
            Container(
              width: widget.isFirst ? 76 : 64,
              height: widget.pedestalHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.primaryColor.withAlpha(isDark ? 110 : 75),
                    widget.primaryColor.withAlpha(isDark ? 40 : 20),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border.all(
                  color: widget.lightColor.withAlpha(isDark ? 140 : 90),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withAlpha(isDark ? 40 : 20),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // Top reflective bevel rim
                  Positioned(
                    top: 0,
                    left: 4,
                    right: 4,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: widget.lightColor.withAlpha(200),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Engraved Roman Numeral
                  Positioned(
                    top: 14,
                    child: Text(
                      widget.romanNumeral,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: widget.isFirst ? 28 : 22,
                        fontWeight: FontWeight.w900,
                        color: widget.lightColor.withAlpha(isDark ? 80 : 50),
                        shadows: [
                          Shadow(
                            color: Colors.black.withAlpha(isDark ? 80 : 30),
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
                .animate(delay: widget.delay)
                .slideY(
                  begin: 1,
                  end: 0,
                  curve: Curves.easeOutQuint,
                  duration: AppMotion.expressive,
                ),
          ],
        ),
      ),
    );
  }
}
