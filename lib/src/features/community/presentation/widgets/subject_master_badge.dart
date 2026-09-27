import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';

/// A subject expertise pill badge displayed on forum post cards and reply headers.
///
/// Recognizes track specializations like WAEC, JAMB, Mathematics, Physics, etc.,
/// and presents custom iconography and badges.
class SubjectMasterBadge extends StatelessWidget {
  const SubjectMasterBadge({
    required this.track,
    this.compact = false,
    super.key,
  });

  final String track;
  final bool compact;

  static (String label, IconData icon, Color Function(AppThemeColorsExtension colors) colorGetter) _getBadgeConfig(String rawTrack) {
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final (label, icon, colorGetter) = _getBadgeConfig(track);
    final badgeColor = colorGetter(colors);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(isDark ? 40 : 25),
        borderRadius: AppRadius.radiusMicro,
        border: Border.all(
          color: badgeColor.withAlpha(isDark ? 70 : 40),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact ? 10 : 12,
            color: badgeColor,
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            label,
            style: typography.caption.bold.copyWith(
              color: badgeColor,
              fontSize: compact ? 9 : 10,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
