import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_to_text_handler.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class FeynmanActiveRecallSheet extends HookWidget {
  const FeynmanActiveRecallSheet({
    required this.card,
    required this.onRevealCard,
    super.key,
  });

  final FlashcardEntity card;
  final VoidCallback onRevealCard;

  static Future<void> show(
    BuildContext context, {
    required FlashcardEntity card,
    required VoidCallback onRevealCard,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FeynmanActiveRecallSheet(
        card: card,
        onRevealCard: onRevealCard,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final isListening = useState<bool>(false);
    final transcript = useState<String>('');
    final errorMessage = useState<String?>(null);

    final speechHandler = useMemoized(
      () => SpeechToTextHandler(
        onResult: (text) {
          transcript.value = text;
        },
        onListeningChanged: (listening) {
          isListening.value = listening;
        },
        onError: (err) {
          errorMessage.value = err;
        },
      ),
    );

    // Calculate keyword match percentage between transcript and card answer
    final keywordCoverage = useMemoized(() {
      if (transcript.value.trim().isEmpty) return 0.0;
      final answerWords = card.back
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 3)
          .toSet();

      if (answerWords.isEmpty) return 1.0;

      final spokenWords = transcript.value
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .split(RegExp(r'\s+'))
          .toSet();

      final matches = answerWords.intersection(spokenWords).length;
      return (matches / answerWords.length).clamp(0.0, 1.0);
    }, [transcript.value, card.back]);

    useEffect(() {
      unawaited(speechHandler.initialize());
      return () {
        if (speechHandler.isListening) {
          unawaited(speechHandler.stopListening());
        }
      };
    }, []);

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 80 : 30),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: colors.textMuted.withAlpha(80),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 40 : 20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.record_voice_over_rounded,
                  color: colors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Feynman Active Recall Mode',
                      style: typography.subhead.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Explain the concept out loud before flipping',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
                color: colors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Flashcard Front Prompt Preview
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfacePrimary.withAlpha(isDark ? 80 : 220),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: colors.primary.withAlpha(40),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QUESTION PROMPT',
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  card.front,
                  style: typography.body.medium.copyWith(
                    color: colors.textPrimary,
                    fontSize: 14,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live Spoken Transcript Display & Pulse Indicator
          Container(
            height: 120,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isListening.value
                  ? colors.primary.withAlpha(isDark ? 25 : 12)
                  : colors.surfaceSecondary.withAlpha(120),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: isListening.value
                    ? colors.primary.withAlpha(100)
                    : colors.surfaceBorder.withAlpha(60),
              ),
            ),
            child: transcript.value.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isListening.value
                              ? Icons.graphic_eq_rounded
                              : Icons.mic_none_rounded,
                          color: isListening.value
                              ? colors.primary
                              : colors.textMuted,
                          size: 28,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isListening.value
                              ? 'Listening... Speak your explanation now!'
                              : 'Tap the microphone below to start speaking',
                          textAlign: TextAlign.center,
                          style: typography.footnote.regular.copyWith(
                            color: isListening.value
                                ? colors.primary
                                : colors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Text(
                      transcript.value,
                      style: typography.body.regular.copyWith(
                        color: colors.textPrimary,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 12),

          // Keyword Recall Coverage Bar (When transcript exists)
          if (transcript.value.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Keyword Recall Match',
                  style: typography.caption.medium.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '${(keywordCoverage * 100).round()}%',
                  style: typography.caption.bold.copyWith(
                    color: keywordCoverage > 0.6
                        ? colors.recallGood
                        : (keywordCoverage > 0.3
                            ? colors.warning
                            : colors.textSecondary),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: keywordCoverage,
                backgroundColor: colors.surfaceBorder.withAlpha(60),
                valueColor: AlwaysStoppedAnimation<Color>(
                  keywordCoverage > 0.6
                      ? colors.recallGood
                      : (keywordCoverage > 0.3
                          ? colors.warning
                          : colors.primary),
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (errorMessage.value != null) ...[
            Text(
              errorMessage.value!,
              style: typography.caption.regular.copyWith(
                color: colors.warning,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
          ],

          // Controls Row: Mic Button & Reveal Answer Button
          Row(
            children: [
              // Mic Toggle Button
              ShrinkableButton(
                onTap: () async {
                  AppFeedback.selection();
                  if (isListening.value) {
                    await speechHandler.stopListening();
                  } else {
                    await speechHandler.startListening();
                  }
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isListening.value
                        ? colors.warning
                        : colors.primary.withAlpha(isDark ? 60 : 30),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isListening.value
                          ? colors.warning
                          : colors.primary.withAlpha(100),
                    ),
                  ),
                  child: Icon(
                    isListening.value ? Icons.stop_rounded : Icons.mic_rounded,
                    color: isListening.value ? colors.white : colors.primary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Primary Action: Reveal & Rate Card
              Expanded(
                child: ShrinkableButton(
                  onTap: () {
                    AppFeedback.medium();
                    if (isListening.value) {
                      unawaited(speechHandler.stopListening());
                    }
                    Navigator.of(context).pop();
                    onRevealCard();
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primary,
                          colors.syllabotAccent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      boxShadow: [
                        BoxShadow(
                          color: colors.black.withAlpha(isDark ? 40 : 20),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.flip_to_back_rounded,
                          color: colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Reveal & Verify Answer',
                          style: typography.subhead.bold.copyWith(
                            color: colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
