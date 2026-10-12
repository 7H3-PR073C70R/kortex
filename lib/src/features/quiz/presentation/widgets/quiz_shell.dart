/// Barrel file and design system primitives for the quiz feature presentation layer.
///
/// Decomposed into focused, modular components adhering to Clean Architecture
/// and strict line limits (< 500 lines per file):
/// - Chrome Primitives: Animation, progress rails, banners, empty states.
/// - Feedback Panel: Inline answer verdict & explanation presentation.
/// - Selector Pills: Topic tags, stat counters, year pills, and count options.
/// - Setup Controls: Mode segment controls, rule descriptions, and choice cards.
library;

export 'shell/quiz_chrome_primitives.dart';
export 'shell/quiz_feedback_panel.dart';
export 'shell/quiz_selector_pills.dart';
export 'shell/quiz_setup_controls.dart';
