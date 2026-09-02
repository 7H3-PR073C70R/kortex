import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/syllabot/presentation/pages/syllabot_chat_page.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

/// A global floating expandable & collapsible Syllabot AI overlay.
///
/// Features:
/// - Floats conveniently above the bottom navigation dock.
/// - Expandable into full-screen Syllabot AI workspace on tap.
/// - Collapsible with a single tap to return to the unobtrusive floating pill.
/// - Retains ongoing conversation context across minimize/maximize cycles.
class FloatingSyllabotOverlay extends StatefulWidget {
  const FloatingSyllabotOverlay({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<FloatingSyllabotOverlay> createState() =>
      _FloatingSyllabotOverlayState();
}

class _FloatingSyllabotOverlayState extends State<FloatingSyllabotOverlay>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;

  // Position tracking for floating button
  double? _customBottomOffset;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _expand() {
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _isExpanded = true;
    });
    unawaited(_expandController.forward());
  }

  void _collapse() {
    unawaited(HapticFeedback.lightImpact());
    unawaited(
      _expandController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isExpanded = false;
          });
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final defaultBottom = math.max(84, (bottomInset + 72).toInt()).toDouble();
    final bottomPosition = _customBottomOffset ?? defaultBottom;

    return Stack(
      children: [
        // 1. Underlying Application Pages
        widget.child,

        // 2. Collapsed Floating Syllabot Action Pill (When not expanded)
        if (!_isExpanded || _expandAnimation.value < 1.0)
          Positioned(
            right: 18,
            bottom: bottomPosition,
            child: FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0).animate(
                _expandAnimation,
              ),
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  setState(() {
                    final size = MediaQuery.sizeOf(context);
                    final newBottom = (size.height - details.globalPosition.dy)
                        .clamp(defaultBottom, size.height - 140);
                    _customBottomOffset = newBottom;
                  });
                },
                child: Semantics(
                  button: true,
                  label: 'Ask Syllabot AI Assistant',
                  child: ShrinkableButton(
                    onTap: _expand,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.surfacePrimary,
                            colors.surfaceSecondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: colors.primary.withAlpha(isDark ? 90 : 70),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withAlpha(isDark ? 55 : 30),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.black.withAlpha(isDark ? 80 : 15),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SyllabotAvatar(size: 32),
                          const SizedBox(width: 8),
                          Text(
                            'Ask Syllabot',
                            style: typography.caption.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 12.5,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: colors.syllabotAccent,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // 3. Full-Screen Expanded Syllabot Chat Sheet Overlay (Persists state)
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_isExpanded,
            child: AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                final isHidden = !_isExpanded && _expandAnimation.value == 0;
                return Offstage(
                  offstage: isHidden,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(_expandAnimation),
                    child: FadeTransition(
                      opacity: _expandAnimation,
                      child: child,
                    ),
                  ),
                );
              },
              child: Material(
                color: colors.backgroundPrimary,
                child: SyllabotChatPage(
                  onCollapse: _collapse,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
