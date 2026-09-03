import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tactile interactive wrapper scaling children down (0.96x) on press down.
///
/// Fully accessible:
/// - Enforces minimum 48x48 dp touch target.
/// - Respects `prefersReducedMotion` / `disableAnimations` from OS settings.
/// - Supports keyboard focus traversal and assistive technology semantics.
class ShrinkableButton extends StatefulWidget {
  const ShrinkableButton({
    required this.child,
    required this.onTap,
    super.key,
    this.shrinkScale = 0.96,
    this.duration = const Duration(milliseconds: 100),
    this.enableHaptics = true,
    this.semanticLabel,
    this.semanticHint,
    this.focusNode,
    this.autofocus = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double shrinkScale;
  final Duration duration;
  final bool enableHaptics;
  final String? semanticLabel;
  final String? semanticHint;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<ShrinkableButton> createState() => _ShrinkableButtonState();
}

class _ShrinkableButtonState extends State<ShrinkableButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final FocusNode _internalFocusNode;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation =
        Tween<double>(
          begin: 1,
          end: widget.shrinkScale,
        ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    }
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    if (widget.enableHaptics) {
      unawaited(HapticFeedback.lightImpact());
    }
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!disableAnimations) {
      unawaited(_controller.forward());
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap == null) return;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!disableAnimations) {
      unawaited(_controller.reverse());
    }
  }

  void _onTapCancel() {
    if (widget.onTap == null) return;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!disableAnimations) {
      unawaited(_controller.reverse());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final result = disableAnimations
        ? widget.child
        : ScaleTransition(
            scale: _scaleAnimation,
            child: widget.child,
          );

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        child: Focus(
          focusNode: _effectiveFocusNode,
          autofocus: widget.autofocus,
          onKeyEvent: (node, event) {
            if (isEnabled &&
                event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.space)) {
              if (widget.enableHaptics) {
                unawaited(HapticFeedback.lightImpact());
              }
              widget.onTap?.call();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: widget.onTap,
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: result,
            ),
          ),
        ),
      ),
    );
  }
}
