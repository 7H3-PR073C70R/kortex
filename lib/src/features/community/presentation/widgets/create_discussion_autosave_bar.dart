import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

/// Bottom bar indicating draft autosave status, character count, and discard button.
class CreateDiscussionAutosaveBar extends StatelessWidget {
  const CreateDiscussionAutosaveBar({
    required this.lastSavedTime,
    required this.characterCount,
    required this.onDiscard,
    super.key,
  });

  final String lastSavedTime;
  final int characterCount;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_done_outlined,
                  size: 16,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Draft saved automatically ($lastSavedTime)',
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$characterCount characters',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onDiscard,
                  child: Text(
                    'Discard',
                    style: typography.caption.bold.copyWith(
                      color: colors.error,
                      fontSize: 11.5,
                    ),
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
