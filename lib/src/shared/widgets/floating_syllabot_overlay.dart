import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/features/syllabot/presentation/pages/syllabot_chat_page.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

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
      duration: AppMotion.expressive,
      reverseDuration: AppMotion.standard,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: AppMotion.easeOutCubic,
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
    final neural = context.neural;
    final colors = context.colors;
    final typography = context.typography;
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
            right: 16,
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
                  child: Material(
                    type: MaterialType.transparency,
                    child: PlatformHoverBuilder(
                      builder: (context, isHovered, child) {
                        return AnimatedScale(
                          scale: isHovered ? 1.04 : 1.0,
                          duration: AppMotion.snappy,
                          curve: AppMotion.easeOutCubic,
                          child: child,
                        );
                      },
                      child: ShrinkableButton(
                        onTap: _expand,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                neural.obsidian850,
                                neural.obsidian800,
                                neural.obsidian850,
                              ],
                            ),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(99),
                            ),
                            border: Border.fromBorderSide(
                              BorderSide(
                                color: neural.purple500.withAlpha(102),
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: neural.glowCyan,
                                blurRadius: 20,
                                spreadRadius: -5,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Bot avatar with neon cyan→indigo→fuchsia ring
                              Container(
                                width: 32,
                                height: 32,
                                padding: const EdgeInsets.all(1.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomLeft,
                                    end: Alignment.topRight,
                                    colors: [
                                      neural.cyan,
                                      neural.indigo500,
                                      neural.fuchsia500,
                                    ],
                                  ),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: neural.obsidian950,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.smart_toy_rounded,
                                      size: 16,
                                      color: neural.cyan300,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Ask Syllabot',
                                style: typography.caption.semiBold.copyWith(
                                  color: neural.slate100,
                                  fontSize: 12,
                                  letterSpacing: 0.2,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: neural.amber400,
                                size: 12,
                              ),
                            ],
                          ),
                        ),
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
