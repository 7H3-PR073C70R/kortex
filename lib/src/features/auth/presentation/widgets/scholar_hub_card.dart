import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/auth/presentation/widgets/avatar_picker_dialog.dart';
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
        profile?.displayName ?? state.user?.displayName ?? 'toxicbishop01';
    final email =
        profile?.email ?? state.user?.email ?? 'toxicbishop01@gmail.com';

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
        final calcLevel = (xp / 300).floor() + 1;
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
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Blurred Halo
                              Container(
                                    width: 108,
                                    height: 108,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomLeft,
                                        end: Alignment.topRight,
                                        colors: [
                                          Color.fromRGBO(245, 158, 11, 0.3), // amber-500/30
                                          Color.fromRGBO(16, 185, 129, 0.2), // emerald-500/20
                                          Color.fromRGBO(99, 102, 241, 0.3), // indigo-500/30
                                        ],
                                      ),
                                    ),
                                  )
                                  .animate(target: isHovered ? 1 : 0.8)
                                  .blurXY(begin: 8, end: 12)
                                  .fade(begin: 0.8, end: 1),

                              // Avatar Circle
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFFD5CAA8),
                                      Color(0xFFA3977C),
                                      Color(0xFF6D6451),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color.fromRGBO(253, 230, 138, 0.4), // amber-200/40
                                    width: 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 15,
                                      offset: Offset(0, 8),
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
                                    fontSize: 32,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(24, 24, 27, 0.9), // zinc-900/90
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color.fromRGBO(63, 63, 70, 0.8), // zinc-700/80
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                size: 14,
                                color: colors.textSecondary,
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
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(39, 39, 42, 0.9), // zinc-800/90
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color.fromRGBO(63, 63, 70, 0.7), // zinc-700/70
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                profile?.isPro == true ? 'PRO' : 'Free Tier',
                                style: typography.caption.bold.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.edit_outlined,
                                size: 10,
                                color: colors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
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
                icon: '🧠',
                colors: colors,
                typography: typography,
                isDark: isDark,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Streak Shield Protection Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color.fromRGBO(2, 44, 34, 0.2), // emerald-950/20
                Color.fromRGBO(18, 21, 28, 1), // cardBg
                Color.fromRGBO(24, 24, 27, 0.6), // zinc-900/60
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color.fromRGBO(6, 78, 59, 0.4), // emerald-900/40
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(16, 185, 129, 0.1), // emerald-500/10
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: Color.fromRGBO(52, 211, 153, 1), // emerald-400
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        streakFreezes > 0
                            ? 'Your streak is protected'
                            : 'Study tomorrow to keep your streak going',
                        style: typography.caption.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(2, 44, 34, 0.6), // emerald-950/60
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color.fromRGBO(4, 120, 87, 0.5), // emerald-700/50
                  ),
                ),
                child: Text(
                  streakFreezes > 0 ? '$streakFreezes ready' : 'No shield',
                  style: typography.caption.bold.copyWith(
                    color: const Color.fromRGBO(52, 211, 153, 1), // emerald-400
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
  }) {
    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return AnimatedContainer(
          duration: AppMotion.snappy,
          curve: AppMotion.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(18, 21, 28, 0.9), // cardBg/90
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovered 
                  ? const Color.fromRGBO(245, 158, 11, 0.3) // amber-500/30
                  : const Color.fromRGBO(63, 63, 70, 0.7), // zinc-800/70
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: context.typography.body.regular.copyWith(fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                value,
                style: typography.body.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: typography.caption.bold.copyWith(
                  color: colors.textSecondary,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarContent({
    required String? photoUrl,
    required String displayName,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    double size = 56,
    double fontSize = 22,
  }) {
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
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'K',
                style: typography.title3.bold.copyWith(
                  color: colors.black,
                  fontSize: fontSize,
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
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'K',
              style: typography.title3.bold.copyWith(
                color: colors.black,
                fontSize: fontSize,
              ),
            ),
          ),
        );
      }
    }

    return Text(
      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'T',
      style: typography.title3.bold.copyWith(
        color: colors.black,
        fontSize: fontSize,
      ),
    );
  }
}
