import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/decks/presentation/widgets/audio_pronounce_button.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_audio_reader_button.dart';

class ForumThreadStructuredBody extends StatelessWidget {
  const ForumThreadStructuredBody({
    required this.post,
    super.key,
  });

  final ForumPostEntity post;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final rawContent = post.content;

    // Parse options, prompt, explanation, and answer comparison if available
    final lines = rawContent.split('\n');
    final promptLines = <String>[];
    final options = <String>[];
    final explanationLines = <String>[];
    String? correctAnswer;
    String? userAnswer;

    var readingOptions = false;
    var readingExplanation = false;

    final optionPrefixRegex = RegExp(
      r'^([A-Da-d0-9][\.\:\)]|\([A-Da-d0-9]\)|[\•\-\*])\s*(.*)',
    );
    final letterPrefixRegex = RegExp(
      r'^([A-Da-d0-9][\.\:\)]|\([A-Da-d0-9]\))\s*(.*)',
    );

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final lower = line.toLowerCase();
      if (lower.startsWith('**options:**') ||
          lower.startsWith('options:') ||
          lower.startsWith('choices:')) {
        readingOptions = true;
        readingExplanation = false;
        continue;
      }
      if (lower.startsWith('**explanation:**') ||
          lower.startsWith('explanation:') ||
          lower.startsWith('solution:') ||
          lower.startsWith('why is this correct?')) {
        readingExplanation = true;
        readingOptions = false;
        final colonIdx = line.indexOf(':');
        if (colonIdx != -1 && colonIdx < line.length - 1) {
          final contentAfter = line
              .substring(colonIdx + 1)
              .replaceAll('*', '')
              .trim();
          if (contentAfter.isNotEmpty) {
            explanationLines.add(contentAfter);
          }
        }
        continue;
      }
      if (lower.startsWith('**correct answer:**') ||
          lower.startsWith('correct answer:') ||
          lower.startsWith('correct:')) {
        final colonIdx = line.indexOf(':');
        correctAnswer = colonIdx != -1
            ? line.substring(colonIdx + 1).replaceAll('*', '').trim()
            : line.replaceAll('*', '').trim();
        readingOptions = false;
        continue;
      }
      if (lower.startsWith('**your answer:**') ||
          lower.startsWith('your answer:') ||
          lower.startsWith('selected answer:') ||
          lower.startsWith('user answer:')) {
        final colonIdx = line.indexOf(':');
        userAnswer = colonIdx != -1
            ? line.substring(colonIdx + 1).replaceAll('*', '').trim()
            : line.replaceAll('*', '').trim();
        readingOptions = false;
        continue;
      }
      if (lower.startsWith('**question:**') || lower.startsWith('question:')) {
        final colonIdx = line.indexOf(':');
        if (colonIdx != -1 && colonIdx < line.length - 1) {
          final after = line.substring(colonIdx + 1).replaceAll('*', '').trim();
          if (after.isNotEmpty) {
            promptLines.add(after);
          }
        }
        continue;
      }

      if (readingExplanation) {
        explanationLines.add(line);
      } else if (readingOptions) {
        if (optionPrefixRegex.hasMatch(line) ||
            RegExp('^[A-Da-d]').hasMatch(line)) {
          options.add(line);
        } else {
          readingOptions = false;
          promptLines.add(line);
        }
      } else if (letterPrefixRegex.hasMatch(line)) {
        options.add(line);
        readingOptions = true;
      } else {
        promptLines.add(line);
      }
    }

    final promptText = promptLines
        .join('\n')
        .replaceAll(RegExp(r'^\*\*Question:\*\*\s*', caseSensitive: false), '')
        .trim();
    final explanationText = explanationLines.join('\n').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prompt Card
        if (promptText.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfacePrimary
                  : colors.surfaceSecondary.withAlpha(120),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 40 : 20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(isDark ? 40 : 20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'QUESTION PROMPT',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 9.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (options.isNotEmpty)
                      QuizAudioReaderButton(
                        questionText: promptText,
                        options: options,
                        size: 28,
                        iconSize: 14,
                      )
                    else
                      AudioPronounceButton(
                        textToPronounce: promptText,
                        size: 28,
                        iconSize: 14,
                        tooltip: 'Listen to prompt',
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                CleanFormattedText(
                  text: promptText,
                  baseStyle: typography.body.medium.copyWith(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

        // Neutral Question Options List
        if (options.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Options',
            style: typography.caption.bold.copyWith(
              color: colors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          ...options.asMap().entries.map((entry) {
            final idx = entry.key;
            final opt = entry.value;
            var letter = '';
            var optText = opt;

            final letterMatch = letterPrefixRegex.firstMatch(opt);
            if (letterMatch != null) {
              letter =
                  letterMatch
                      .group(1)
                      ?.replaceAll(RegExp(r'[\(\)\.\:\s]'), '') ??
                  '';
              optText = letterMatch.group(2) ?? opt;
            } else if (opt.startsWith('•') ||
                opt.startsWith('-') ||
                opt.startsWith('*')) {
              letter = String.fromCharCode(65 + idx);
              optText = opt.replaceFirst(RegExp(r'^[\•\-\*]\s*'), '');
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfacePrimary
                    : colors.surfaceSecondary.withAlpha(100),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.surfaceBorder.withAlpha(isDark ? 30 : 15),
                ),
              ),
              child: Row(
                children: [
                  if (letter.isNotEmpty) ...[
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary.withAlpha(isDark ? 35 : 20),
                        border: Border.all(
                          color: colors.primary.withAlpha(isDark ? 60 : 35),
                        ),
                      ),
                      child: Text(
                        letter.toUpperCase(),
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: CleanFormattedText(
                      text: optText,
                      baseStyle: typography.footnote.regular.copyWith(
                        color: colors.textPrimary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],

        // User & Correct Answer Summary Pill
        if (correctAnswer != null || userAnswer != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfacePrimary
                  : colors.surfaceSecondary.withAlpha(80),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colors.surfaceBorder.withAlpha(isDark ? 30 : 20),
              ),
            ),
            child: Row(
              children: [
                if (correctAnswer != null) ...[
                  Icon(
                    Icons.check_circle_outline,
                    size: 15,
                    color: colors.success,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: CleanFormattedText(
                      text: 'Correct: $correctAnswer',
                      baseStyle: typography.caption.bold.copyWith(
                        color: colors.success,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
                if (userAnswer != null) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: CleanFormattedText(
                      text: 'Selected: $userAnswer',
                      baseStyle: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Concept Explanation Card
        if (explanationText.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(isDark ? 25 : 12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 50 : 30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: colors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Concept Explanation',
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            letterSpacing: 0.5,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    AudioPronounceButton(
                      textToPronounce: explanationText,
                      size: 26,
                      iconSize: 13,
                      tooltip: 'Listen to explanation',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                CleanFormattedText(
                  text: explanationText,
                  baseStyle: typography.footnote.regular.copyWith(
                    color: colors.textPrimary,
                    height: 1.45,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class CleanFormattedText extends StatelessWidget {
  const CleanFormattedText({
    required this.text,
    required this.baseStyle,
    super.key,
  });

  final String text;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    var sanitized = text.replaceAll(
      RegExp(r'[\uFFFD\u0000-\u0008\u000B\u000C\u000E-\u001F]+'),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'^\*\*Question:\*\*\s*', caseSensitive: false),
      '',
    );

    return LatexRichViewer(
      text: sanitized,
      style: baseStyle,
    );
  }
}
