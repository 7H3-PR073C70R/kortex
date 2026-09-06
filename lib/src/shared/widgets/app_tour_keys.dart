import 'package:flutter/material.dart';

/// Central key registry and geometry locator for Kortex interactive app tour.
class AppTourKeys {
  const AppTourKeys._();

  /// Key for the top header profile bar (greeting, streak, neural scholar tier).
  static final GlobalKey headerProfileKey =
      GlobalKey(debugLabel: 'tour_header_profile');

  /// Key for the exam countdown card / banner.
  static final GlobalKey countdownKey =
      GlobalKey(debugLabel: 'tour_countdown');

  /// Key for today's active recall review queue card.
  static final GlobalKey reviewQueueKey =
      GlobalKey(debugLabel: 'tour_review_queue');

  /// Key for the collapsed floating Syllabot AI action pill.
  static final GlobalKey syllabotFabKey =
      GlobalKey(debugLabel: 'tour_syllabot_fab');

  /// Key for the bottom navigation dock.
  static final GlobalKey dockKey =
      GlobalKey(debugLabel: 'tour_bottom_dock');

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
