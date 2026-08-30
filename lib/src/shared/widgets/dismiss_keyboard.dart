import 'package:flutter/material.dart';

/// Layout wrapper using [GestureDetector] to unfocus active text inputs.
///
/// Wrapped in [ExcludeSemantics] so screen readers (VoiceOver/TalkBack)
/// ignore the background hit-detection surface during swipe navigation.
class DismissKeyboard extends StatelessWidget {
  const DismissKeyboard({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
      ),
    );
  }
}
