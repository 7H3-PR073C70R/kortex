import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';

/// Scholar expertise and reputation tiers recognized in the community forum.
enum ScholarTier {
  novice('Novice', Icons.school_outlined, 0),
  scholar('Scholar', Icons.auto_stories_rounded, 100),
  specialist('Specialist', Icons.psychology_rounded, 300),
  maven('Maven', Icons.workspace_premium_rounded, 600),
  master('Master', Icons.military_tech_rounded, 1000),
  grandmaster('Grandmaster', Icons.diamond_rounded, 2000);

  const ScholarTier(this.displayName, this.icon, this.minKarma);

  final String displayName;
  final IconData icon;
  final int minKarma;

  /// Determines scholar reputation tier from cumulative karma score.
  static ScholarTier fromKarma(int karma) {
    if (karma >= 2000) return ScholarTier.grandmaster;
    if (karma >= 1000) return ScholarTier.master;
    if (karma >= 600) return ScholarTier.maven;
    if (karma >= 300) return ScholarTier.specialist;
    if (karma >= 100) return ScholarTier.scholar;
    return ScholarTier.novice;
  }

  /// Determines scholar reputation tier from verified solutions marked by peers.
  static ScholarTier fromVerifiedAnswers(int verifiedCount) {
    if (verifiedCount >= 50) return ScholarTier.grandmaster;
    if (verifiedCount >= 25) return ScholarTier.master;
    if (verifiedCount >= 10) return ScholarTier.maven;
    if (verifiedCount >= 5) return ScholarTier.specialist;
    if (verifiedCount >= 1) return ScholarTier.scholar;
    return ScholarTier.novice;
  }
}

/// A subject expertise pill badge displayed on forum post cards and reply headers.
///
/// Recognizes track specializations like WAEC, JAMB, Mathematics, Physics, etc.,
/// with dynamic scholar reputation tiers (Novice, Scholar, Specialist, Maven, Master, Grandmaster).
class SubjectMasterBadge extends StatelessWidget {
  const SubjectMasterBadge({
    required this.track,
    this.compact = false,
    this.tier,
    this.karmaScore,
    this.verifiedCount,
    super.key,
  });

  final String track;
  final bool compact;
  final ScholarTier? tier;
  final int? karmaScore;
  final int? verifiedCount;

  ScholarTier? _resolveTier() {
    if (tier != null) return tier;
    if (karmaScore != null) return ScholarTier.fromKarma(karmaScore!);
    if (verifiedCount != null) {
      return ScholarTier.fromVerifiedAnswers(verifiedCount!);
    }
    return null;
  }

  static (String label, IconData icon, Color Function(AppThemeColorsExtension colors) colorGetter)
      _getBadgeConfig(String rawTrack) {
    final lower = rawTrack.toLowerCase().trim();
    if (lower.contains('waec')) {
      return ('WAEC Specialist', Icons.workspace_premium_rounded, (c) => c.primary);
    } else if (lower.contains('jamb')) {
      return ('JAMB 300+', Icons.bolt_rounded, (c) => c.warning);
    } else if (lower.contains('math')) {
      return ('Math Expert', Icons.calculate_rounded, (c) => c.info);
    } else if (lower.contains('physic')) {
      return ('Physics Guru', Icons.science_rounded, (c) => c.secondary);
    } else if (lower.contains('chem')) {
      return ('Chemistry Scholar', Icons.biotech_rounded, (c) => c.success);
    } else if (lower.contains('bio')) {
      return ('Biology Master', Icons.eco_rounded, (c) => c.success);
    } else {
      return ('Scholar', Icons.school_rounded, (c) => c.primary);
    }
  }

  static String _extractBaseTrackName(String rawTrack) {
    final lower = rawTrack.toLowerCase().trim();
    if (lower.contains('waec')) return 'WAEC';
    if (lower.contains('jamb')) return 'JAMB';
    if (lower.contains('math')) return 'Math';
    if (lower.contains('physic')) return 'Physics';
    if (lower.contains('chem')) return 'Chemistry';
    if (lower.contains('bio')) return 'Biology';
    return rawTrack.trim().isEmpty ? 'General' : rawTrack.trim();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final resolvedTier = _resolveTier();
    final (legacyLabel, legacyIcon, colorGetter) = _getBadgeConfig(track);
    final badgeColor = colorGetter(colors);

    final displayLabel = resolvedTier != null
        ? '${_extractBaseTrackName(track)} ${resolvedTier.displayName}'
        : legacyLabel;
    final displayIcon = resolvedTier != null ? resolvedTier.icon : legacyIcon;

    final isGrandmaster = resolvedTier == ScholarTier.grandmaster;
    final isMaster = resolvedTier == ScholarTier.master;

    final tooltipMsg = resolvedTier != null
        ? '$displayLabel • ${karmaScore != null ? '$karmaScore Karma XP' : '${resolvedTier.displayName} Tier in $track'}'
        : '$legacyLabel in $track';

    return Tooltip(
      message: tooltipMsg,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 5 : 7,
          vertical: compact ? 1 : 2,
        ),
        decoration: BoxDecoration(
          gradient: isGrandmaster
              ? LinearGradient(
                  colors: [
                    colors.primary.withAlpha(isDark ? 80 : 50),
                    colors.secondary.withAlpha(isDark ? 70 : 40),
                  ],
                )
              : isMaster
                  ? LinearGradient(
                      colors: [
                        colors.warning.withAlpha(isDark ? 60 : 40),
                        badgeColor.withAlpha(isDark ? 40 : 25),
                      ],
                    )
                  : null,
          color: (!isGrandmaster && !isMaster)
              ? badgeColor.withAlpha(isDark ? 40 : 25)
              : null,
          borderRadius: AppRadius.radiusMicro,
          border: Border.all(
            color: isGrandmaster
                ? colors.primary.withAlpha(isDark ? 160 : 100)
                : isMaster
                    ? colors.warning.withAlpha(isDark ? 140 : 80)
                    : badgeColor.withAlpha(isDark ? 70 : 40),
            width: (isGrandmaster || isMaster) ? 1.0 : 0.8,
          ),
          boxShadow: isGrandmaster
              ? [
                  BoxShadow(
                    color: colors.primary.withAlpha(isDark ? 50 : 25),
                    blurRadius: 4,
                    spreadRadius: 0.5,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              displayIcon,
              size: compact ? 10 : 12,
              color: isMaster ? colors.warning : badgeColor,
            ),
            SizedBox(width: compact ? 3 : 4),
            Text(
              displayLabel,
              style: typography.caption.bold.copyWith(
                color: isMaster ? colors.warning : badgeColor,
                fontSize: compact ? 9 : 10,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
