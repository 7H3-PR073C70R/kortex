import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Modal dialog displaying simulated peer crowd polling distribution for Millionaire Mode.
class MillionaireAudiencePollDialog extends StatelessWidget {
  const MillionaireAudiencePollDialog({
    required this.distribution,
    required this.options,
    required this.onClose,
    super.key,
  });

  final Map<String, int> distribution;
  final List<String> options;
  final VoidCallback onClose;

  static void show(
    BuildContext context, {
    required Map<String, int> distribution,
    required List<String> options,
  }) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => MillionaireAudiencePollDialog(
          distribution: distribution,
          options: options,
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    const optionLetters = ['A', 'B', 'C', 'D'];

    // Find the highest voted option
    var maxPercentage = -1;
    var maxLetter = '';
    for (final entry in distribution.entries) {
      if (entry.value > maxPercentage) {
        maxPercentage = entry.value;
        maxLetter = entry.key;
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colors.surfaceBorder.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ask the Crowd',
                        style: typography.headline.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Peer consensus & confidence polling',
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: Icon(
                    Icons.close_rounded,
                    color: colors.textMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Distribution Bars
            ...List.generate(options.length, (i) {
              final letter = i < optionLetters.length ? optionLetters[i] : '${i + 1}';
              final pct = distribution[letter] ?? 0;
              final isMax = letter == maxLetter;
              final label = options[i];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isMax
                                ? const Color(0xFF10B981)
                                : (isDark ? Colors.white12 : Colors.black12),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            letter,
                            style: typography.caption.bold.copyWith(
                              color: isMax ? Colors.white : colors.textPrimary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.footnote.medium.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$pct%',
                          style: typography.footnote.bold.copyWith(
                            color: isMax ? const Color(0xFF10B981) : colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          Container(
                            height: 10,
                            width: double.infinity,
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                          ),
                          FractionallySizedBox(
                            widthFactor: (pct / 100.0).clamp(0.0, 1.0),
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isMax
                                      ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                      : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.tips_and_updates_rounded,
                    color: Color(0xFFF59E0B),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Crowd confidence reflects peer data. Trust your reasoning!',
                      style: typography.caption.regular.copyWith(
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Button
            ShrinkableButton(
              onTap: onClose,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Resume Ascent',
                  style: typography.headline.bold.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
