import 'package:flutter/material.dart';

/// Central key registry and geometry locator for Kortex interactive app tour.
class AppTourKeys {
  const AppTourKeys._();

  // --- SECTION CONTAINER KEYS ---

  /// Key for the top header profile bar (greeting, streak, neural scholar tier).
  static final GlobalKey headerProfileKey = GlobalKey(
    debugLabel: 'tour_header_profile',
  );

  /// Key for the exam countdown card / banner.
  static final GlobalKey countdownKey = GlobalKey(debugLabel: 'tour_countdown');

  /// Key for today's active recall review queue card.
  static final GlobalKey reviewQueueKey = GlobalKey(
    debugLabel: 'tour_review_queue',
  );

  /// Key for Dashboard quick actions grid (AI Upload, Q-Bank, Quiz Duel).
  static final GlobalKey quickActionsKey = GlobalKey(
    debugLabel: 'tour_quick_actions',
  );

  /// Key for the collapsed floating Syllabot AI action pill.
  static final GlobalKey syllabotFabKey = GlobalKey(
    debugLabel: 'tour_syllabot_fab',
  );

  /// Key for Decks page main header / OCR scanner section.
  static final GlobalKey decksHeaderKey = GlobalKey(
    debugLabel: 'tour_decks_header',
  );

  /// Key for Decks page today's hero revision card.
  static final GlobalKey decksTodayHeroKey = GlobalKey(
    debugLabel: 'tour_decks_today_hero',
  );

  /// Key for Decks sprint chips row (Quick 10, Power 20, Speed Run).
  static final GlobalKey decksSprintChipsKey = GlobalKey(
    debugLabel: 'tour_decks_sprint_chips',
  );

  /// Key for Community Hub top header / live study rooms.
  static final GlobalKey communityHeroKey = GlobalKey(
    debugLabel: 'tour_community_hero',
  );

  /// Key for Community Hub create post action button.
  static final GlobalKey communityPostBtnKey = GlobalKey(
    debugLabel: 'tour_community_post_btn',
  );

  /// Key for Study Hub liquid glass tab bar & Pomodoro launcher.
  static final GlobalKey pomodoroCardKey = GlobalKey(
    debugLabel: 'tour_pomodoro_card',
  );

  /// Key for Study Hub live focus rooms section.
  static final GlobalKey liveRoomsCardKey = GlobalKey(
    debugLabel: 'tour_live_rooms_card',
  );

  /// Key for Study Hub marketplace section.
  static final GlobalKey marketplaceCardKey = GlobalKey(
    debugLabel: 'tour_marketplace_card',
  );

  /// Key for Profile Scholar Hub header card.
  static final GlobalKey profileCardKey = GlobalKey(
    debugLabel: 'tour_profile_card',
  );

  /// Key for the bottom navigation dock.
  static final GlobalKey dockKey = GlobalKey(debugLabel: 'tour_bottom_dock');

  // --- GRANULAR SUB-CONTROL KEYS ---

  /// Key for Header Streak counter pill.
  static final GlobalKey headerStreakKey = GlobalKey(
    debugLabel: 'tour_header_streak',
  );

  /// Key for Header Neural Scholar tier badge.
  static final GlobalKey headerLevelKey = GlobalKey(
    debugLabel: 'tour_header_level',
  );

  /// Key for Countdown target badge/action button.
  static final GlobalKey countdownBadgeKey = GlobalKey(
    debugLabel: 'tour_countdown_badge',
  );

  /// Key for Review Queue FSRS due counter badge.
  static final GlobalKey reviewQueueCountKey = GlobalKey(
    debugLabel: 'tour_review_queue_count',
  );

  /// Key for AI OCR note scanner trigger in quick actions.
  static final GlobalKey quickActionOcrKey = GlobalKey(
    debugLabel: 'tour_quick_action_ocr',
  );

  /// Key for Q-Bank past questions launcher in quick actions.
  static final GlobalKey quickActionQBankKey = GlobalKey(
    debugLabel: 'tour_quick_action_qbank',
  );

  /// Key for 1v1 Quiz Duel launcher in quick actions.
  static final GlobalKey quickActionDuelKey = GlobalKey(
    debugLabel: 'tour_quick_action_duel',
  );

  /// Key for Decks hero card "Start Revision" button.
  static final GlobalKey decksHeroStartBtnKey = GlobalKey(
    debugLabel: 'tour_decks_hero_start_btn',
  );

  /// Key for 10-card Quick Sprint chip.
  static final GlobalKey decksSprintChip10Key = GlobalKey(
    debugLabel: 'tour_decks_sprint_chip_10',
  );

  /// Key for 20-card Power Sprint chip.
  static final GlobalKey decksSprintChip20Key = GlobalKey(
    debugLabel: 'tour_decks_sprint_chip_20',
  );

  /// Key for Decks subject filter chip row.
  static final GlobalKey decksFilterChipKey = GlobalKey(
    debugLabel: 'tour_decks_filter_chip',
  );

  /// Key for Pomodoro sync timer launcher button.
  static final GlobalKey pomodoroStartBtnKey = GlobalKey(
    debugLabel: 'tour_pomodoro_start_btn',
  );

  /// Key for Live Focus Room "Join Room" button.
  static final GlobalKey liveRoomJoinBtnKey = GlobalKey(
    debugLabel: 'tour_live_room_join_btn',
  );

  /// Key for Marketplace "Clone Deck" action.
  static final GlobalKey marketplaceCloneBtnKey = GlobalKey(
    debugLabel: 'tour_marketplace_clone_btn',
  );

  /// Key for Syllabot AI prompt input bar.
  static final GlobalKey syllabotPromptInputKey = GlobalKey(
    debugLabel: 'tour_syllabot_prompt_input',
  );

  /// Key for Syllabot AI preset suggestion chip.
  static final GlobalKey syllabotChipPresetKey = GlobalKey(
    debugLabel: 'tour_syllabot_chip_preset',
  );

  /// Key for Forum subject tag filter bar.
  static final GlobalKey communityTagFilterKey = GlobalKey(
    debugLabel: 'tour_community_tag_filter',
  );

  /// Key for Profile retention heatmap card.
  static final GlobalKey profileHeatmapKey = GlobalKey(
    debugLabel: 'tour_profile_heatmap',
  );

  /// Returns the stable [GlobalKey].
  /// Kept for backward compatibility while preventing destructive key recreation.
  static GlobalKey safeKey(GlobalKey currentKey, String debugLabel) {
    return currentKey;
  }

  /// Callback registered by StudyHubPage to switch its inner sub-tabs during the app tour.
  static void Function(int subTabIndex)? onSelectStudyHubSubTab;

  /// Safely resolves the bounding box of a [GlobalKey] in global window coordinates.
  static Rect? getTargetRect(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return null;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached || !renderBox.hasSize) {
      return null;
    }
    final offset = renderBox.localToGlobal(Offset.zero);
    return offset & renderBox.size;
  }

  /// Ensures the target widget is scrolled into view (if inside a Scrollable)
  /// and returns its updated global bounding rectangle.
  static Future<Rect?> ensureVisibleAndGetRect(
    GlobalKey key, {
    double alignment = 0.5,
    Duration duration = const Duration(milliseconds: 320),
    Curve curve = Curves.easeOutCubic,
  }) async {
    final context = key.currentContext;
    if (context == null) return null;

    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != null) {
      await Scrollable.ensureVisible(
        context,
        alignment: alignment,
        duration: duration,
        curve: curve,
      );
      // Short delay for scroll animation to settle before measuring
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    return getTargetRect(key);
  }
}
