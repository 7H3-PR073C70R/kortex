import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

/// Tab view for entering an invite code to join an existing 1v1 duel room.
class QuizDuelJoinCodeTab extends StatelessWidget {
  const QuizDuelJoinCodeTab({
    required this.enteredCodeController,
    super.key,
  });

  final TextEditingController enteredCodeController;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: colors.surfaceBorder.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pin_rounded,
                color: colors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'ENTER 6-DIGIT ROOM CODE',
                style: typography.caption.bold.copyWith(
                  color: colors.primary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: enteredCodeController,
            hintText: 'e.g. K9X7P2',
            prefixIcon: const Icon(Icons.vpn_key_outlined),
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the code your friend shared to jump directly into their duel arena.',
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
