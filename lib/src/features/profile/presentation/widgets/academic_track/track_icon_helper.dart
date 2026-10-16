import 'package:flutter/material.dart';

/// Helper mapping course track icon strings to Material icons.
IconData getTrackIconData(String iconName) {
  switch (iconName) {
    case 'school':
      return Icons.school_rounded;
    case 'assignment_turned_in':
      return Icons.assignment_turned_in_rounded;
    case 'timer':
      return Icons.timer_outlined;
    case 'history_edu':
      return Icons.history_edu_rounded;
    case 'workspace_premium':
      return Icons.workspace_premium_rounded;
    case 'psychology':
      return Icons.psychology_rounded;
    case 'menu_book':
      return Icons.menu_book_rounded;
    case 'auto_stories':
      return Icons.auto_stories_rounded;
    case 'handyman':
      return Icons.handyman_rounded;
    case 'verified':
      return Icons.verified_rounded;
    case 'calculate':
      return Icons.calculate_outlined;
    case 'biotech':
      return Icons.biotech_outlined;
    case 'medical_services':
      return Icons.medical_services_outlined;
    case 'gavel':
      return Icons.gavel_rounded;
    case 'engineering':
      return Icons.engineering_outlined;
    case 'trending_up':
      return Icons.trending_up_rounded;
    case 'terminal':
      return Icons.terminal_rounded;
    case 'record_voice_over':
      return Icons.record_voice_over_outlined;
    case 'translate':
      return Icons.translate_rounded;
    default:
      return Icons.auto_stories_rounded;
  }
}
