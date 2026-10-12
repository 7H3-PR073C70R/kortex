import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/shared/widgets/app_tour_keys.dart';
import 'package:kortex/src/shared/widgets/guided_tour/tour_step_model.dart';

/// Builds the complete list of 15 guided walkthrough steps for Kortex.
List<TourStep> buildTourSteps(AppThemeColorsExtension colors) {
  return [
    // 1. Streak & Neural Scholar Tier
    TourStep(
      badge: 'STEP 1 OF 15 • DASHBOARD HQ',
      title: 'Daily Streak & Neural Scholar Tier',
      subtitle: 'Streak multiplier & rank elevation',
      description:
          'Track your daily revision consistency. Complete reviews every day to watch your Scholar Tier elevate from Bronze to Diamond and unlock double XP multipliers.',
      proTip:
          'A 7+ day streak unlocks automatic rank promotions and exclusive study room badges.',
      icon: Icons.local_fire_department_rounded,
      accentColor: colors.primary,
      targetTabIndex: 0,
      targetKey: AppTourKeys.headerStreakKey,
      fallbackKey: AppTourKeys.headerProfileKey,
    ),

    // 2. Custom Exam Clock & Track Selector
    TourStep(
      badge: 'STEP 2 OF 15 • EXAM COUNTDOWN',
      title: 'Exam Clock & Target Syllabus Track',
      subtitle: 'WAEC, NECO, JAMB, SAT & Degree targets',
      description:
          'Set your upcoming exam date. Kortex automatically computes your daily target velocity and tunes practice question difficulty to your track.',
      proTip:
          'Tap your exam badge to manage exam dates and auto-prioritize syllabus topics.',
      icon: Icons.timer_rounded,
      accentColor: colors.warning,
      targetTabIndex: 0,
      targetKey: AppTourKeys.countdownBadgeKey,
      fallbackKey: AppTourKeys.countdownKey,
    ),

    // 3. FSRS Active Recall Memory Queue
    TourStep(
      badge: 'STEP 3 OF 15 • SPACED REPETITION',
      title: 'Daily Memory Review Queue',
      subtitle: 'FSRS memory retention algorithm',
      description:
          'Cards due for review appear here every morning. Our smart FSRS memory engine schedules cards right before you forget them for 95%+ long-term retention.',
      proTip:
          'Clearing 10-15 due cards each morning keeps your review queue manageable.',
      icon: Icons.alarm_on_rounded,
      accentColor: colors.success,
      targetTabIndex: 0,
      targetKey: AppTourKeys.reviewQueueCountKey,
      fallbackKey: AppTourKeys.reviewQueueKey,
    ),

    // 4. AI Camera OCR Scanner
    TourStep(
      badge: 'STEP 4 OF 15 • AI OCR SCANNER',
      title: 'AI OCR Note Importer',
      subtitle: 'Convert physical notes to flashcards',
      description:
          'Snap textbook pages, handwriting, or PDF notes with your camera. Syllabot AI automatically extracts key concepts and generates interactive Q&A flashcards.',
      proTip:
          'You can upload multiple pages at once — AI handles diagram labels and formulas.',
      icon: Icons.camera_enhance_rounded,
      accentColor: colors.syllabotAccent,
      targetTabIndex: 0,
      targetKey: AppTourKeys.quickActionOcrKey,
      fallbackKey: AppTourKeys.quickActionsKey,
    ),

    // 5. 1v1 Quiz Duels & Past Question Bank
    TourStep(
      badge: 'STEP 5 OF 15 • QUIZ DUELS',
      title: 'Live 1v1 Duels & Past Questions',
      subtitle: 'Challenge scholars & test past papers',
      description:
          'Practice past questions grouped by topic, or jump into live 1v1 speed duels with fellow scholars studying the same syllabus track.',
      proTip:
          'Winning quiz duels earns instant XP bonuses and climbs the global leaderboard.',
      icon: Icons.sports_esports_rounded,
      accentColor: colors.primary,
      targetTabIndex: 0,
      targetKey: AppTourKeys.quickActionDuelKey,
      fallbackKey: AppTourKeys.quickActionsKey,
    ),

    // 6. Today's Priority Revision Session
    TourStep(
      badge: 'STEP 6 OF 15 • REVISION HERO',
      title: "Today's Priority Revision Deck",
      subtitle: 'One-tap active recall launcher',
      description:
          'Kortex selects your highest-yield review deck for today. One tap launches active recall mode with immediate AI feedback on incorrect answers.',
      proTip:
          'Tap "Start Revision" first thing in your morning study session for maximum efficiency.',
      icon: Icons.play_circle_fill_rounded,
      accentColor: colors.primary,
      targetTabIndex: 1,
      targetKey: AppTourKeys.decksHeroStartBtnKey,
      fallbackKey: AppTourKeys.decksTodayHeroKey,
    ),

    // 7. Rapid Study Sprints
    TourStep(
      badge: 'STEP 7 OF 15 • STUDY SPRINTS',
      title: 'Rapid Sprints (Quick 10 & Power 20)',
      subtitle: 'Bite-sized revision for busy schedules',
      description:
          'Short on time? Choose a 10-card Quick Sprint or a 20-card Power Sprint for fast, focused review sessions during breaks or commutes.',
      proTip:
          'Sprints use smart card weighting to focus on your weakest memory tags first.',
      icon: Icons.bolt_rounded,
      accentColor: colors.warning,
      targetTabIndex: 1,
      targetKey: AppTourKeys.decksSprintChip10Key,
      fallbackKey: AppTourKeys.decksSprintChipsKey,
    ),

    // 8. Subject Track Filter Bar
    TourStep(
      badge: 'STEP 8 OF 15 • DECK FILTERS',
      title: 'Subject & Syllabus Filter Bar',
      subtitle: 'Organize decks by subject & difficulty',
      description:
          'Filter your deck library by subject (Math, Physics, Biology, Chemistry, Literature) or syllabus track for structured exam revision.',
      proTip:
          'Custom tags let you group decks by chapter or upcoming school test dates.',
      icon: Icons.filter_alt_rounded,
      accentColor: colors.latexHighlight,
      targetTabIndex: 1,
      targetKey: AppTourKeys.decksFilterChipKey,
      fallbackKey: AppTourKeys.decksHeaderKey,
    ),

    // 9. Syllabot 24/7 Socratic AI Tutor
    TourStep(
      badge: 'STEP 9 OF 15 • AI COPILOT',
      title: 'Ask Syllabot 24/7 AI Tutor',
      subtitle: 'Socratic tutor — floating on every screen',
      description:
          'Stuck on a complex equation or past-paper solution? Tap the floating Syllabot pill on any screen for step-by-step explanations and hint prompts.',
      proTip:
          'Syllabot stays accessible on every page so you never have to leave your session for help.',
      icon: Icons.psychology_rounded,
      accentColor: colors.secondary,
      targetTabIndex: 1,
      targetKey: AppTourKeys.syllabotFabKey,
    ),

    // 10. Study Hub & Liquid Tabs
    TourStep(
      badge: 'STEP 10 OF 15 • STUDY HUB',
      title: 'Study Hub & Liquid Glass Bar',
      subtitle: 'Focus rooms, Study Circles & Marketplace',
      description:
          'Access all deep-work productivity tools in one command center — live co-working rooms, Pomodoro timers, and deck sharing.',
      proTip:
          'Swipe horizontally across the liquid glass bar to switch hub sections smoothly.',
      icon: Icons.device_hub_rounded,
      accentColor: colors.syllabotAccent,
      targetTabIndex: 3,
      targetKey: AppTourKeys.pomodoroCardKey,
      onStepActivated: () => AppTourKeys.onSelectStudyHubSubTab?.call(0),
    ),

    // 11. Synchronized Live Focus Rooms
    TourStep(
      badge: 'STEP 11 OF 15 • FOCUS ROOMS',
      title: 'Synchronized Live Focus Rooms',
      subtitle: 'Shared Pomodoro & ambient lo-fi audio',
      description:
          'Join virtual study rooms with scholars worldwide. Sync 25-minute Pomodoro cycles, stream ambient study beats, and share focus goals.',
      proTip:
          'Studying in live focus rooms boosts accountability and awards bonus group XP.',
      icon: Icons.groups_rounded,
      accentColor: colors.primary,
      targetTabIndex: 3,
      targetKey: AppTourKeys.liveRoomJoinBtnKey,
      fallbackKey: AppTourKeys.liveRoomsCardKey,
      onStepActivated: () => AppTourKeys.onSelectStudyHubSubTab?.call(0),
    ),

    // 12. Scholar Deck Marketplace
    TourStep(
      badge: 'STEP 12 OF 15 • MARKETPLACE',
      title: 'Scholar Deck Marketplace',
      subtitle: 'Community decks & past question sets',
      description:
          'Explore high-yield flashcard decks curated by top scholars and verified educators for your exact exam track.',
      proTip:
          'Tap "Clone Deck" to save any community deck instantly into your library.',
      icon: Icons.storefront_rounded,
      accentColor: colors.warning,
      targetTabIndex: 3,
      targetKey: AppTourKeys.marketplaceCloneBtnKey,
      fallbackKey: AppTourKeys.marketplaceCardKey,
      onStepActivated: () => AppTourKeys.onSelectStudyHubSubTab?.call(2),
    ),

    // 13. Scholar Forum Tag Filters
    TourStep(
      badge: 'STEP 13 OF 15 • FORUM FILTERS',
      title: 'Scholar Forum & Subject Tags',
      subtitle: 'Track-specific Q&A discussions',
      description:
          'Discuss past question solutions with peers. Filter forum threads by subject tag, exam track (WAEC, NECO, JAMB, SAT), or status.',
      proTip:
          'Filter discussions by "Unanswered" to help fellow scholars and earn reputation points.',
      icon: Icons.forum_rounded,
      accentColor: colors.latexHighlight,
      targetTabIndex: 2,
      targetKey: AppTourKeys.communityTagFilterKey,
      fallbackKey: AppTourKeys.communityHeroKey,
    ),

    // 14. Post Question Button
    TourStep(
      badge: 'STEP 14 OF 15 • ASK COMMUNITY',
      title: 'Post Questions & Share Solutions',
      subtitle: 'Get answers from scholars & educators',
      description:
          'Post tricky questions, attach paper photos, or discuss exam strategies with students preparing for the same syllabus.',
      proTip:
          'Tag your posts accurately so top scholars in your subject get notified.',
      icon: Icons.post_add_rounded,
      accentColor: colors.primary,
      targetTabIndex: 2,
      targetKey: AppTourKeys.communityPostBtnKey,
    ),

    // 15. Analytics, Settings & Profile
    TourStep(
      badge: 'STEP 15 OF 15 • PROFILE & HEATMAP',
      title: 'Retention Analytics & Settings',
      subtitle: 'Memory heatmaps, theme swatches & security',
      description:
          'Monitor long-term memory retention heatmaps, view XP progress curves, customize your color palette, and configure AI tutor settings.',
      proTip:
          'Review your weekly retention heatmap every Sunday to target weak topics early.',
      icon: Icons.person_rounded,
      accentColor: colors.primary,
      targetTabIndex: 4,
      targetKey: AppTourKeys.profileHeatmapKey,
      fallbackKey: AppTourKeys.profileCardKey,
    ),
  ];
}
