import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/auth/presentation/widgets/avatar_picker_dialog.dart';
import 'package:kortex/src/shared/widgets/app_animated_entrance.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class ScholarHubCard extends StatelessWidget {
  const ScholarHubCard({
    required this.state,
    required this.profile,
    required this.onEditName,
    super.key,
  });

  final AuthState state;
  final UserProfileEntity? profile;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final displayName =
        profile?.displayName ?? state.user?.displayName ?? '';
    final email =
        profile?.email ?? state.user?.email ?? '';

    var streakDays = profile?.streakDays ?? 0;
    var level = profile?.level ?? 1;
    var retentionPct = ((profile?.retentionBenchmark ?? 0.85) * 100).toInt();
    var streakFreezes = profile?.streakFreezeCount ?? 1;

    try {
      final userActivity = locator<UserActivityService>();
      final localStreak = userActivity.getCurrentStreak();
      streakDays = math.max(streakDays, localStreak);
      streakFreezes = math.max(streakFreezes, userActivity.getStreakFreezes());

      final liveRetention = userActivity.getOverallRetentionRate();
      if (liveRetention > 0) {
        retentionPct = (liveRetention * 100).toInt();
      }

      final xp = userActivity.getXpPoints();
      if (xp > 0) {
        final calcLevel = userActivity.getLevelForXp(xp);
        level = math.max(level, calcLevel);
      }
    } on Object catch (_) {}

    final photoUrl = profile?.photoUrl;

    return Column(
      children: [
        // Upper Identity Strip (Large, organic, centered)
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          child: Column(
            children: [
              // Interactive Avatar with ambient halo
              PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return ShrinkableButton(
                    onTap: () => showAvatarPickerDialog(
                      context,
                      colors,
                      typography,
                    ),
                    child: AnimatedScale(
                      scale: isHovered ? 1.02 : 1.0,
                      duration: AppMotion.snappy,
                      curve: AppMotion.easeOutCubic,
                      child: Stack(
                        children: [
                          // Avatar Circle
                          Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: isDark
                                        ? const [
                                            Color(0xFFD5CAA8),
                                            Color(0xFFA3977C),
                                            Color(0xFF6D6451),
                                          ]
                                        : const [
                                            Color(0xFFE8DFCA),
                                            Color(0xFFD5CAA8),
                                            Color(0xFFA3977C),
                                          ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? const Color.fromRGBO(253, 230, 138, 0.4)
                                        : const Color.fromRGBO(217, 119, 6, 0.25),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.black.withValues(
                                        alpha: isDark ? 0.3 : 0.08,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _buildAvatarContent(
                                    photoUrl: photoUrl,
                                    displayName: displayName,
                                    colors: colors,
                                    typography: typography,
                                    size: 96,
                                    fontSize: 28,
                                  ),
                                ),
                              ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color.fromRGBO(24, 24, 27, 0.9)
                                    : colors.surfacePrimary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? const Color.fromRGBO(63, 63, 70, 0.8)
                                      : colors.surfaceBorder,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.black.withValues(
                                      alpha: isDark ? 0.3 : 0.08,
                                    ),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                size: 14,
                                color: isDark
                                    ? colors.textSecondary
                                    : colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // Name and Email (Centered)
              ShrinkableButton(
                onTap: onEditName,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: typography.title2.bold.copyWith(
                              color: colors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: profile?.isPro == true
                                ? (isDark
                                    ? const Color.fromRGBO(217, 119, 6, 0.2)
                                    : const Color.fromRGBO(245, 158, 11, 0.12))
                                : (isDark
                                    ? const Color.fromRGBO(39, 39, 42, 0.9)
                                    : colors.surfaceSecondary),
                            borderRadius: AppRadius.radiusBadge,
                            border: Border.all(
                              color: profile?.isPro == true
                                  ? (isDark
                                      ? const Color.fromRGBO(245, 158, 11, 0.4)
                                      : const Color.fromRGBO(245, 158, 11, 0.3))
                                  : colors.surfaceBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                profile?.isPro == true ? 'PRO' : 'Free Tier',
                                style: typography.caption.bold.copyWith(
                                  color: profile?.isPro == true
                                      ? (isDark
                                          ? const Color.fromRGBO(252, 211, 77, 1)
                                          : const Color.fromRGBO(180, 83, 9, 1))
                                      : colors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.edit_outlined,
                                size: 10,
                                color: colors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 3-Stat Metric Strip
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _buildGlassMetric(
                label: 'Day Streak',
                value: '$streakDays',
                numericValue: streakDays,
                icon: '🔥',
                colors: colors,
                typography: typography,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildGlassMetric(
                label: 'Current Level',
                value: '$level',
                numericValue: level,
                icon: '🎯',
                colors: colors,
                typography: typography,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildGlassMetric(
                label: 'Memory Rate',
                value: '$retentionPct%',
                numericValue: retentionPct,
                suffix: '%',
                icon: '🧠',
                colors: colors,
                typography: typography,
                isDark: isDark,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Streak Shield Protection Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [
                      Color.fromRGBO(6, 78, 59, 0.3), // emerald-950/30
                      Color.fromRGBO(18, 21, 28, 0.95), // cardBg
                    ]
                  : [
                      const Color.fromRGBO(16, 185, 129, 0.08), // emerald-500/8
                      colors.surfacePrimary,
                    ],
            ),
            borderRadius: AppRadius.radiusCard,
            border: Border.all(
              color: isDark
                  ? const Color.fromRGBO(16, 185, 129, 0.35)
                  : const Color.fromRGBO(16, 185, 129, 0.25),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color.fromRGBO(16, 185, 129, 0.15)
                            : const Color.fromRGBO(16, 185, 129, 0.1),
                        borderRadius: AppRadius.radiusBadge,
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: isDark
                            ? const Color.fromRGBO(52, 211, 153, 1)
                            : const Color.fromRGBO(5, 150, 105, 1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        streakFreezes > 0
                            ? 'Your streak is protected'
                            : 'Study tomorrow to keep your streak going',
                        style: typography.body.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 12.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color.fromRGBO(6, 78, 59, 0.5)
                      : const Color.fromRGBO(16, 185, 129, 0.12),
                  borderRadius: AppRadius.radiusBadge,
                  border: Border.all(
                    color: isDark
                        ? const Color.fromRGBO(16, 185, 129, 0.4)
                        : const Color.fromRGBO(16, 185, 129, 0.3),
                  ),
                ),
                child: Text(
                  streakFreezes > 0 ? '$streakFreezes ready' : 'No shield',
                  style: typography.caption.bold.copyWith(
                    color: isDark
                        ? const Color.fromRGBO(52, 211, 153, 1)
                        : const Color.fromRGBO(4, 120, 87, 1),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlassMetric({
    required String label,
    required String value,
    required String icon,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    required bool isDark,
    int? numericValue,
    String suffix = '',
  }) {
    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return AnimatedContainer(
          duration: AppMotion.snappy,
          curve: AppMotion.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark
                ? (isHovered
                    ? colors.surfaceSecondary
                    : const Color.fromRGBO(18, 21, 28, 0.9))
                : (isHovered
                    ? colors.surfaceSecondary
                    : colors.surfacePrimary),
            borderRadius: AppRadius.radiusPanel,
            border: Border.all(
              color: isHovered
                  ? context.neural.amber400.withValues(alpha: 0.5)
                  : colors.surfaceBorder,
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: colors.black.withValues(alpha: 0.02),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                icon,
                style: typography.body.regular.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 6),
              if (numericValue != null)
                AppAnimatedCounter(
                  targetValue: numericValue,
                  suffix: suffix,
                  style: typography.title3.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                )
              else
                Text(
                  value,
                  style: typography.title3.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                label,
                style: typography.caption.bold.copyWith(
                  color: colors.textSecondary,
                  fontSize: 10.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  static String extractTwoLetterInitials(String? text) {
    if (text == null) return 'KO';
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'KO';

    final parts =
        trimmed.split(RegExp(r'[\s_.\-]+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final firstChar =
          parts[0].characters.isNotEmpty ? parts[0].characters.first : '';
      final secondChar =
          parts[1].characters.isNotEmpty ? parts[1].characters.first : '';
      final combined = '$firstChar$secondChar'.toUpperCase();
      if (combined.isNotEmpty) return combined;
    }

    final clean = trimmed.replaceAll(RegExp('[^a-zA-Z0-9]'), '');
    if (clean.characters.length >= 2) {
      return clean.characters.take(2).toString().toUpperCase();
    } else if (clean.characters.length == 1) {
      return clean.toUpperCase();
    } else if (trimmed.characters.length >= 2) {
      return trimmed.characters.take(2).toString().toUpperCase();
    } else if (trimmed.characters.length == 1) {
      return trimmed.toUpperCase();
    }
    return 'KO';
  }

  Widget _buildAvatarContent({
    required String? photoUrl,
    required String displayName,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    double size = 56,
    double fontSize = 22,
  }) {
    final initials = extractTwoLetterInitials(displayName);

    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('emoji:')) {
        return Text(
          photoUrl.replaceFirst('emoji:', ''),
          style: typography.body.regular.copyWith(fontSize: size * 0.5),
        );
      } else if (photoUrl.startsWith('data:image')) {
        try {
          final base64String = photoUrl.contains(',')
              ? photoUrl.split(',').last
              : photoUrl;
          final bytes = base64Decode(base64String);
          return ClipOval(
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Text(
                initials,
                style: typography.title3.bold.copyWith(
                  color: colors.black,
                  fontSize: fontSize,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        } on Object catch (_) {}
      } else if (photoUrl.startsWith('http://') ||
          photoUrl.startsWith('https://')) {
        return ClipOval(
          child: Image.network(
            photoUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Text(
              initials,
              style: typography.title3.bold.copyWith(
                color: colors.black,
                fontSize: fontSize,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      }
    }

    return Text(
      initials,
      style: typography.title3.bold.copyWith(
        color: colors.black,
        fontSize: fontSize,
        letterSpacing: 0.5,
      ),
    );
  }
}
