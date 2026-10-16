import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';

/// Collapsible verified model solution for theory/essay questions.
class TheoryModelAnswerWidget extends StatefulWidget {
  const TheoryModelAnswerWidget({
    required this.explanation,
    super.key,
  });

  final String? explanation;

  @override
  State<TheoryModelAnswerWidget> createState() =>
      _TheoryModelAnswerWidgetState();
}

class _TheoryModelAnswerWidgetState extends State<TheoryModelAnswerWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final explanation = widget.explanation;

    return Container(
      decoration: BoxDecoration(
        color: colors.primary.withAlpha(isDark ? 28 : 12),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 65 : 35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 50 : 25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: colors.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Model Solution & Verified Answer',
                          style: typography.subhead.bold.copyWith(
                            color: colors.primary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _isExpanded
                              ? 'Tap to hide model answer'
                              : 'Tap to view model solution and detailed reasoning',
                          style: typography.caption.medium.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: colors.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            Divider(
              height: 1,
              color: colors.primary.withAlpha(isDark ? 40 : 25),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: explanation != null && explanation.trim().isNotEmpty
                  ? LatexRichViewer(
                      text: explanation,
                      style: typography.body.regular.copyWith(
                        color: colors.textPrimary,
                        height: 1.5,
                      ),
                    )
                  : Text(
                      'No model solution or detailed explanation available for this question yet.',
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
