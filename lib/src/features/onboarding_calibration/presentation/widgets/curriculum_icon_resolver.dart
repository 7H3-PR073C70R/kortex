import 'package:flutter/material.dart';

/// Helper to resolve icon names provided by the Supabase backend or offline fallback
/// into Flutter [IconData].
IconData resolveCurriculumIcon(
  String? iconName, [
  IconData fallback = Icons.school_rounded,
]) {
  if (iconName == null || iconName.isEmpty) return fallback;

  switch (iconName) {
    case 'quiz_rounded':
      return Icons.quiz_rounded;
    case 'school_rounded':
      return Icons.school_rounded;
    case 'assignment_turned_in_rounded':
      return Icons.assignment_turned_in_rounded;
    case 'public_rounded':
      return Icons.public_rounded;
    case 'military_tech_rounded':
      return Icons.military_tech_rounded;
    case 'translate_rounded':
      return Icons.translate_rounded;
    case 'memory_rounded':
      return Icons.memory_rounded;
    case 'medical_services_rounded':
      return Icons.medical_services_rounded;
    case 'gavel_rounded':
      return Icons.gavel_rounded;
    case 'business_center_rounded':
      return Icons.business_center_rounded;
    case 'menu_book_rounded':
      return Icons.menu_book_rounded;
    case 'groups_rounded':
      return Icons.groups_rounded;
    case 'functions_rounded':
      return Icons.functions_rounded;
    case 'blur_on_rounded':
      return Icons.blur_on_rounded;
    case 'science_rounded':
      return Icons.science_rounded;
    case 'precision_manufacturing_rounded':
      return Icons.precision_manufacturing_rounded;
    case 'history_edu_rounded':
      return Icons.history_edu_rounded;
    case 'workspace_premium_rounded':
      return Icons.workspace_premium_rounded;
    case 'psychology_alt_rounded':
      return Icons.psychology_alt_rounded;
    case 'auto_stories_rounded':
      return Icons.auto_stories_rounded;
    case 'calculate_rounded':
      return Icons.calculate_rounded;
    case 'spellcheck_rounded':
      return Icons.spellcheck_rounded;
    case 'flash_on_rounded':
      return Icons.flash_on_rounded;
    case 'biotech_rounded':
      return Icons.biotech_rounded;
    case 'account_balance_rounded':
      return Icons.account_balance_rounded;
    case 'trending_up_rounded':
      return Icons.trending_up_rounded;
    case 'store_rounded':
      return Icons.store_rounded;
    case 'account_balance_wallet_rounded':
      return Icons.account_balance_wallet_rounded;
    case 'church_rounded':
      return Icons.church_rounded;
    case 'map_rounded':
      return Icons.map_rounded;
    case 'supervised_user_circle_rounded':
      return Icons.supervised_user_circle_rounded;
    case 'article_rounded':
      return Icons.article_rounded;
    case 'psychology_rounded':
      return Icons.psychology_rounded;
    case 'schedule_rounded':
      return Icons.schedule_rounded;
    case 'timer_outlined':
      return Icons.timer_outlined;
    case 'edit_note_rounded':
      return Icons.edit_note_rounded;
    case 'headphones_rounded':
      return Icons.headphones_rounded;
    case 'mic_rounded':
      return Icons.mic_rounded;
    case 'computer_rounded':
      return Icons.computer_rounded;
    default:
      return fallback;
  }
}
