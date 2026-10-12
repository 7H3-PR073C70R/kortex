import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';

/// Keyboard listener dispatching study shortcuts (undo, flip, exit, rate).
class StudySessionKeyboardListener extends StatelessWidget {
  const StudySessionKeyboardListener({
    required this.focusNode,
    required this.canUndo,
    required this.isFlipped,
    required this.onUndo,
    required this.onToggleFlip,
    required this.onSaveCheckpointAndExit,
    required this.onRateCard,
    required this.child,
    super.key,
  });

  final FocusNode focusNode;
  final bool canUndo;
  final bool isFlipped;
  final VoidCallback onUndo;
  final VoidCallback onToggleFlip;
  final Future<void> Function() onSaveCheckpointAndExit;
  final void Function(int) onRateCard;
  final Widget child;

  void _handleKeyEvent(BuildContext context, KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyZ) {
      if (canUndo) {
        onUndo();
        context.showSnackBar(message: 'Rating undone ↩️');
      }
    } else if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter) {
      onToggleFlip();
    } else if (key == LogicalKeyboardKey.escape) {
      unawaited(onSaveCheckpointAndExit());
    } else if (isFlipped) {
      if (key == LogicalKeyboardKey.digit1 ||
          key == LogicalKeyboardKey.numpad1) {
        onRateCard(0);
      } else if (key == LogicalKeyboardKey.digit2 ||
          key == LogicalKeyboardKey.numpad2) {
        onRateCard(3);
      } else if (key == LogicalKeyboardKey.digit3 ||
          key == LogicalKeyboardKey.numpad3) {
        onRateCard(4);
      } else if (key == LogicalKeyboardKey.digit4 ||
          key == LogicalKeyboardKey.numpad4) {
        onRateCard(5);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: focusNode,
      autofocus: true,
      onKeyEvent: (event) => _handleKeyEvent(context, event),
      child: child,
    );
  }
}
