import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/auth/presentation/widgets/avatar_picker_dialog.dart';
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
        profile?.displayName ?? state.user?.displayName ?? 'Kortexify Scholar';
    final email =
        profile?.email ?? state.user?.email ?? 'scholar@kortexify.com';

    var streakDays = profile?.streakDays ?? 0;
    var level = profile?.level ?? 1;
    var retentionPct = ((profile?.retentionBenchmark ?? 0.85) * 100).toInt();

    try {
      final userActivity = locator<UserActivityService>();
      final localStreak = userActivity.getCurrentStreak();
      streakDays = math.max(streakDays, localStreak);

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

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(isDark ? 100 : 70),
        ),
      ),
      child: Column(
        children: [
          // Upper Identity Strip
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Interactive Avatar with gradient glow and edit badge
                ShrinkableButton(
                  onTap: () => showAvatarPickerDialog(
                    context,
                    colors,
                    typography,
                  ),
                  child: Stack(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.primary,
                              colors.syllabotAccent,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withAlpha(isDark ? 80 : 40),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _buildAvatarContent(
                            photoUrl: photoUrl,
                            displayName: displayName,
                            colors: colors,
                            typography: typography,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: colors.surfacePrimary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.surfaceBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 11,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: typography.body.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: profile?.isPro == true
                                  ? colors.warning.withAlpha(35)
                                  : colors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              profile?.isPro == true ? 'PRO' : 'Free Tier',
                              style: typography.caption.bold.copyWith(
                                color: profile?.isPro == true
                                    ? colors.warning
                                    : colors.primary,
                                fontSize: 10,
                              ),
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
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    color: colors.textSecondary,
                    size: 20,
                  ),
                  tooltip: 'Edit Profile Name',
                  onPressed: onEditName,
                ),
              ],
            ),
          ),

          // Divider
          Divider(
            height: 1,
            color: colors.surfaceBorder.withAlpha(60),
          ),

          // Integrated 3-Stat Metric Strip
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricCol(
                    label: 'Daily Streak',
                    value: '$streakDays Days 🔥',
                    colors: colors,
                    typography: typography,
                  ),
                ),
                Container(
                  height: 28,
                  width: 1,
                  color: colors.surfaceBorder.withAlpha(70),
                ),
                Expanded(
                  child: _buildMetricCol(
                    label: 'Scholar Rank',
                    value: 'Level $level 🎯',
                    colors: colors,
                    typography: typography,
                  ),
                ),
                Container(
                  height: 28,
                  width: 1,
                  color: colors.surfaceBorder.withAlpha(70),
                ),
                Expanded(
                  child: _buildMetricCol(
                    label: 'Retention',
                    value: '$retentionPct% 🧠',
                    colors: colors,
                    typography: typography,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCol({
    required String label,
    required String value,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: typography.caption.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: typography.caption.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarContent({
    required String? photoUrl,
    required String displayName,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('emoji:')) {
        return Text(
          photoUrl.replaceFirst('emoji:', ''),
          style: const TextStyle(fontSize: 26),
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
              width: 54,
              height: 54,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'K',
                style: typography.title3.bold.copyWith(
                  color: colors.white,
                  fontSize: 20,
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
            width: 54,
            height: 54,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'K',
              style: typography.title3.bold.copyWith(
                color: colors.white,
                fontSize: 20,
              ),
            ),
          ),
        );
      }
    }

    return Text(
      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'K',
      style: typography.title3.bold.copyWith(
        color: colors.white,
        fontSize: 20,
      ),
    );
  }
}
