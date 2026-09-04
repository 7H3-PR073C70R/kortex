import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_post_bottom_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Floating Action Button that triggers the [CreatePostBottomSheet]
/// above the bottom navigation dock with a masked, blurred backdrop.
class ExpandableCreatePostFab extends StatelessWidget {
  const ExpandableCreatePostFab({
    required this.onSubmit,
    this.bottomOffset = 152,
    super.key,
  });

  final void Function({
    required String title,
    required String content,
    required String track,
    String? latexContent,
  })
  onSubmit;

  final double bottomOffset;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Positioned(
      right: 18,
      bottom: bottomOffset,
      child: Semantics(
        button: true,
        label: l10n.createPostButton,
        child: ShrinkableButton(
          onTap: () {
            unawaited(HapticFeedback.mediumImpact());
            unawaited(
              CreatePostBottomSheet.show(
                context,
                onSubmit: onSubmit,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primary,
                  colors.primary.withAlpha(220),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withAlpha(isDark ? 90 : 60),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: colors.black.withAlpha(isDark ? 70 : 25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: colors.white.withAlpha(40),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  color: colors.white,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.createPostButton,
                  style: typography.footnote.bold.copyWith(
                    color: colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
