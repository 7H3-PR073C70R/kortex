import 'package:flutter/material.dart';

/// Central key registry and geometry locator for Kortex interactive app tour.
class AppTourKeys {
  const AppTourKeys._();

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
}
