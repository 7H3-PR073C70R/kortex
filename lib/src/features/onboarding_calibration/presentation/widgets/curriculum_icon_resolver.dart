import 'package:flutter/material.dart';

/// Helper to resolve icon names provided by the Supabase backend, curriculum metadata,
/// or catalog models into Flutter [IconData].
IconData resolveCurriculumIcon(
  String? iconName, [
  IconData fallback = Icons.school_rounded,
]) {
  if (iconName == null || iconName.isEmpty) return fallback;

  final key = iconName.toLowerCase().replaceAll('_rounded', '').replaceAll('_outlined', '').trim();

  switch (key) {
    case 'calculate':
    case 'math':
      return Icons.calculate_rounded;
    case 'auto_stories':
    case 'book':
      return Icons.auto_stories_rounded;
    case 'policy':
      return Icons.policy_rounded;
    case 'terminal':
      return Icons.terminal_rounded;
    case 'laptop':
    case 'computer':
      return Icons.laptop_chromebook_rounded;
    case 'bolt':
    case 'flash_on':
      return Icons.bolt_rounded;
    case 'biotech':
      return Icons.biotech_rounded;
    case 'eco':
      return Icons.eco_rounded;
    case 'functions':
      return Icons.functions_rounded;
    case 'agriculture':
      return Icons.agriculture_rounded;
    case 'architecture':
      return Icons.architecture_rounded;
    case 'pets':
      return Icons.pets_rounded;
    case 'fitness_center':
      return Icons.fitness_center_rounded;
    case 'trending_up':
      return Icons.trending_up_rounded;
    case 'storefront':
    case 'store':
      return Icons.storefront_rounded;
    case 'receipt_long':
      return Icons.receipt_long_rounded;
    case 'menu_book':
      return Icons.menu_book_rounded;
    case 'campaign':
      return Icons.campaign_rounded;
    case 'shield':
      return Icons.shield_rounded;
    case 'business_center':
      return Icons.business_center_rounded;
    case 'account_balance':
      return Icons.account_balance_rounded;
    case 'public':
      return Icons.public_rounded;
    case 'history_edu':
      return Icons.history_edu_rounded;
    case 'church':
      return Icons.church_rounded;
    case 'mosque':
      return Icons.mosque_rounded;
    case 'translate':
      return Icons.translate_rounded;
    case 'language':
      return Icons.language_rounded;
    case 'palette':
      return Icons.palette_rounded;
    case 'music_note':
      return Icons.music_note_rounded;
    case 'home':
      return Icons.home_rounded;
    case 'restaurant':
      return Icons.restaurant_rounded;
    case 'dinner_dining':
      return Icons.dinner_dining_rounded;
    case 'roofing':
      return Icons.roofing_rounded;
    case 'memory':
      return Icons.memory_rounded;
    case 'medical_services':
      return Icons.medical_services_rounded;
    case 'gavel':
      return Icons.gavel_rounded;
    case 'quiz':
      return Icons.quiz_rounded;
    case 'school':
      return Icons.school_rounded;
    case 'assignment_turned_in':
      return Icons.assignment_turned_in_rounded;
    case 'military_tech':
      return Icons.military_tech_rounded;
    case 'groups':
      return Icons.groups_rounded;
    case 'blur_on':
      return Icons.blur_on_rounded;
    case 'science':
      return Icons.science_rounded;
    case 'precision_manufacturing':
      return Icons.precision_manufacturing_rounded;
    case 'workspace_premium':
      return Icons.workspace_premium_rounded;
    case 'psychology':
    case 'psychology_alt':
      return Icons.psychology_rounded;
    case 'spellcheck':
      return Icons.spellcheck_rounded;
    case 'article':
      return Icons.article_rounded;
    case 'schedule':
      return Icons.schedule_rounded;
    case 'timer':
      return Icons.timer_outlined;
    case 'edit_note':
      return Icons.edit_note_rounded;
    case 'headphones':
      return Icons.headphones_rounded;
    case 'mic':
      return Icons.mic_rounded;
    default:
      return fallback;
  }
}
