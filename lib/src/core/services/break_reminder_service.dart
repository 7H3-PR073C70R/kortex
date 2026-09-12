import 'dart:async';
import 'package:flutter/foundation.dart';

/// Service implementing the 20-20-20 rule for ADHD & neurodivergent study sessions (ACC-08).
/// Prompts eye rest / movement reminders after 20 minutes of continuous focus.
class BreakReminderService {
  BreakReminderService({
    this.focusInterval = const Duration(minutes: 20),
    this.restDuration = const Duration(seconds: 20),
  });

  final Duration focusInterval;
  final Duration restDuration;

  Timer? _timer;
  final _breakPromptController = StreamController<String>.broadcast();

  Stream<String> get breakPromptStream => _breakPromptController.stream;

  bool _isActive = false;
  bool get isActive => _isActive;

  void startFocusTimer({
    String promptMessage =
        '👀 Time for an Eye Rest! Look at an object 20 feet away for 20 seconds.',
  }) {
    stopFocusTimer();
    _isActive = true;
    _timer = Timer.periodic(focusInterval, (_) {
      if (_isActive) {
        _breakPromptController.add(promptMessage);
        debugPrint('[BreakReminderService] Dispatched 20-20-20 eye rest prompt');
      }
    });
  }

  void stopFocusTimer() {
    _isActive = false;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stopFocusTimer();
    unawaited(_breakPromptController.close());
  }
}
