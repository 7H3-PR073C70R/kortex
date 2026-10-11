import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Rich text formatting toolbar for discussion composer.
class CreateDiscussionToolbar extends StatelessWidget {
  const CreateDiscussionToolbar({
    required this.onApplyFormatting,
    required this.onShowMathFormulas,
    required this.onShowSymbols,
    required this.onRunAiFormatAssist,
    super.key,
  });

  final void Function(String prefix, [String suffix]) onApplyFormatting;
  final VoidCallback onShowMathFormulas;
  final VoidCallback onShowSymbols;
  final VoidCallback onRunAiFormatAssist;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primary.withAlpha(isDark ? 15 : 8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
        border: Border(
          bottom: BorderSide(
            color: colors.primary.withAlpha(isDark ? 25 : 15),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            DiscussionFormatActionBtn(
              icon: Icons.format_bold_rounded,
              tooltip: l10n.tooltipBold,
              onTap: () => onApplyFormatting('**', '**'),
            ),
            DiscussionFormatActionBtn(
              icon: Icons.format_italic_rounded,
              tooltip: l10n.tooltipItalic,
              onTap: () => onApplyFormatting('*', '*'),
            ),
            DiscussionFormatActionBtn(
              icon: Icons.strikethrough_s_rounded,
              tooltip: l10n.tooltipStrikethrough,
              onTap: () => onApplyFormatting('~~', '~~'),
            ),
            const DiscussionFormatDivider(),
            DiscussionFormatActionBtn(
              icon: Icons.title_rounded,
              tooltip: l10n.tooltipHeading,
              onTap: () => onApplyFormatting('### '),
            ),
            DiscussionFormatActionBtn(
              icon: Icons.code_rounded,
              tooltip: l10n.tooltipCodeBlock,
              onTap: () => onApplyFormatting('```\n', '\n```'),
            ),
            DiscussionFormatActionBtn(
              icon: Icons.format_list_bulleted_rounded,
              tooltip: l10n.tooltipBulletList,
              onTap: () => onApplyFormatting('- '),
            ),
            DiscussionFormatActionBtn(
              icon: Icons.format_list_numbered_rounded,
              tooltip: l10n.tooltipNumberedList,
              onTap: () => onApplyFormatting('1. '),
            ),
            DiscussionFormatActionBtn(
              icon: Icons.format_quote_rounded,
              tooltip: l10n.tooltipQuote,
              onTap: () => onApplyFormatting('> '),
            ),
            const DiscussionFormatDivider(),
            DiscussionFormatActionBtn(
              icon: Icons.functions_rounded,
              tooltip: l10n.tooltipLatexMath,
              label: 'Σ',
              onTap: onShowMathFormulas,
            ),
            DiscussionFormatActionBtn(
              icon: Icons.pie_chart_outline_rounded,
              tooltip: l10n.tooltipMathSymbols,
              label: 'π',
              onTap: onShowSymbols,
            ),
            DiscussionFormatActionBtn(
              icon: Icons.auto_awesome_rounded,
              tooltip: l10n.tooltipAiFormatAssist,
              isAccent: true,
              onTap: onRunAiFormatAssist,
            ),
          ],
        ),
      ),
    );
  }
}

class DiscussionFormatActionBtn extends StatelessWidget {
  const DiscussionFormatActionBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.label,
    this.isAccent = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final String? label;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final color = isAccent ? colors.primary : colors.textSecondary;

    return Tooltip(
      message: tooltip,
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) => AnimatedScale(
          scale: isHovered ? 1.08 : 1.0,
          duration: AppMotion.snappy,
          curve: AppMotion.easeOutCubic,
          child: ShrinkableButton(
            onTap: onTap,
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: isAccent
                    ? color.withAlpha(
                        isDark ? (isHovered ? 55 : 35) : (isHovered ? 35 : 20),
                      )
                    : (isHovered
                          ? colors.primary.withAlpha(isDark ? 25 : 15)
                          : colors.transparent),
                borderRadius: AppRadius.radiusBadge,
              ),
              child: label != null
                  ? Text(
                      label!,
                      style: typography.caption.bold.copyWith(
                        color: color,
                        fontSize: 13,
                      ),
                    )
                  : Icon(icon, size: 17, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class DiscussionFormatDivider extends StatelessWidget {
  const DiscussionFormatDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: colors.primary.withAlpha(30),
    );
  }
}
