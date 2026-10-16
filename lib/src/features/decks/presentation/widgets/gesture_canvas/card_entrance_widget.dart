import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

/// Brief "rising from the deck" entrance (scale 0.96 + fade), replayed
/// whenever the parent hands in a new card via [ValueKey].
class CardEntranceWidget extends StatefulWidget {
  const CardEntranceWidget({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<CardEntranceWidget> createState() => _CardEntranceWidgetState();
}

class _CardEntranceWidgetState extends State<CardEntranceWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  bool _entranceQueued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceQueued) return;
    _entranceQueued = true;
    if (!context.reduceMotion) {
      unawaited(_controller.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuint,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
        child: widget.child,
      ),
    );
  }
}
