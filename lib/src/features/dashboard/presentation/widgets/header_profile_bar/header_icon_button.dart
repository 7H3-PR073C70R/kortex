import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Top header icon button with animated hover border and notification badge.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.borderHighlightColor,
    this.badgeCount = 0,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final Color? borderHighlightColor;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            return ShrinkableButton(
              onTap: onTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: AppMotion.snappy,
                    curve: AppMotion.easeOutCubic,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: neural.obsidian850.withAlpha(
                        isHovered ? 255 : 230,
                      ),
                      border: Border.all(
                        color: isHovered
                            ? (borderHighlightColor ?? neural.emerald)
                                  .withAlpha(
                                    110,
                                  )
                            : neural.hairlineStrong,
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 16,
                      color: color,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        decoration: BoxDecoration(
                          color: neural.amber400,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: neural.obsidian950,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: neural.amber400.withAlpha(140),
                              blurRadius: 6,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            badgeCount > 99 ? '99+' : '$badgeCount',
                            style: TextStyle(
                              color: neural.obsidian950,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
