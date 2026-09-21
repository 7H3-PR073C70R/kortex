import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Platform-aware hover handler that provides subtle tactile visual feedback
/// on Desktop and Web while preserving fluid touch gestures on Mobile.
class PlatformHoverBuilder extends StatefulWidget {
  const PlatformHoverBuilder({
    required this.builder,
    super.key,
    this.child,
    this.cursor = SystemMouseCursors.click,
    this.isEnabled = true,
  });

  // Standard Flutter builder callback signature matching ValueWidgetBuilder.
  // ignore: avoid_positional_boolean_parameters
  final Widget Function(BuildContext context, bool isHovered, Widget? child)
  builder;
  final Widget? child;
  final MouseCursor cursor;
  final bool isEnabled;

  /// True if the current platform natively utilizes pointer hover.
  static bool get hasPointerSupport {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  @override
  State<PlatformHoverBuilder> createState() => _PlatformHoverBuilderState();
}

class _PlatformHoverBuilderState extends State<PlatformHoverBuilder> {
  bool _isHovered = false;

  void _onEnter(PointerEnterEvent event) {
    if (!mounted || !widget.isEnabled) return;
    if (_isHovered) return;
    setState(() => _isHovered = true);
  }

  void _onExit(PointerExitEvent event) {
    if (!mounted || !widget.isEnabled) return;
    if (!_isHovered) return;
    setState(() => _isHovered = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformHoverBuilder.hasPointerSupport || !widget.isEnabled) {
      return widget.builder(context, false, widget.child);
    }

    return MouseRegion(
      cursor: widget.cursor,
      onEnter: _onEnter,
      onExit: _onExit,
      hitTestBehavior: HitTestBehavior.translucent,
      child: widget.builder(context, _isHovered, widget.child),
    );
  }
}
