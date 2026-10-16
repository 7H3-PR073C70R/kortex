import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/text_to_speech_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/focus_session_cubit.dart';
import 'package:kortex/src/features/decks/presentation/bloc/focus_session_state.dart';
import 'package:kortex/src/features/decks/presentation/widgets/latex_card_content_viewer.dart';
import 'package:kortex/src/features/decks/presentation/widgets/thought_parking_lot_sheet.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_text_normalizer.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Renders either the front or back surface of an interactive flashcard.
class CardFaceWidget extends StatelessWidget {
  CardFaceWidget({
    required this.badgeText,
    required this.badgeColor,
    required this.mainText,
    required this.isBackFace,
    required this.card,
    this.latexFormula,
    this.enableBionicReading = false,
    this.onOpenParkingLot,
    TextToSpeechService? ttsService,
    super.key,
  }) : _ttsService = ttsService ??
            (locator.isRegistered<TextToSpeechService>()
                ? locator<TextToSpeechService>()
                : null);

  final String badgeText;
  final Color badgeColor;
  final String mainText;
  final String? latexFormula;
  final bool isBackFace;
  final FlashcardEntity card;
  final bool enableBionicReading;
  final VoidCallback? onOpenParkingLot;
  final TextToSpeechService? _ttsService;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    FocusSessionState? focusState;
    try {
      focusState = context.watch<FocusSessionCubit?>()?.state;
    } on Object catch (e, st) {
      AppLogger.recordNonFatal(e, st);
    }
    final hasParkedThoughts = focusState?.parkedThoughts.isNotEmpty ?? false;

    return Semantics(
      container: true,
      button: true,
      label: isBackFace
          ? 'Back of card: $mainText. Rate recall or tap to flip.'
          : 'Front of card: $mainText. Tap or spacebar to reveal answer.',
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Faint deck edges peeking behind the active card
          Positioned(
            left: 20,
            right: 20,
            top: 16,
            bottom: -10,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceSecondary.withAlpha(isDark ? 110 : 150),
                borderRadius: BorderRadius.circular(AppRadius.panel),
                border: Border.all(color: colors.surfaceBorder.withAlpha(70)),
              ),
            ),
          ),
          Positioned(
            left: 36,
            right: 36,
            top: 26,
            bottom: -20,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceSecondary.withAlpha(isDark ? 60 : 90),
                borderRadius: BorderRadius.circular(AppRadius.panel),
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 340, maxWidth: 640),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.dialog),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  if (isDark)
                    colors.surfaceSecondary.withAlpha(220)
                  else
                    colors.surfacePrimary.withAlpha(245),
                  if (isDark)
                    colors.surfacePrimary.withAlpha(235)
                  else
                    colors.surfaceSecondary.withAlpha(230),
                ],
              ),
              border: Border.all(
                color: isBackFace
                    ? colors.success.withAlpha(isDark ? 120 : 80)
                    : colors.primary.withAlpha(isDark ? 120 : 70),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.black.withAlpha(isDark ? 60 : 25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Tag Pill & Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withAlpha(isDark ? 45 : 20),
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                        border: Border.all(
                          color: badgeColor.withAlpha(100),
                        ),
                      ),
                      child: Text(
                        badgeText,
                        style: typography.caption.bold.copyWith(
                          color: badgeColor,
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (card.sourceTopic != null &&
                              (isBackFace || card.sourceTopic != mainText)) ...[
                            Flexible(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 120),
                                child: Text(
                                  card.sourceTopic!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: typography.footnote.regular.copyWith(
                                    color: colors.textMuted,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          // Listen button — reads the card text aloud
                          ValueListenableBuilder<bool>(
                            valueListenable: _ttsService?.isSpeakingNotifier ??
                                const ConstantValueListenable<bool>(false),
                            builder: (context, isSpeaking, _) {
                              return IconButton(
                                icon: Icon(
                                  isSpeaking
                                      ? Icons.volume_up_rounded
                                      : Icons.volume_up_outlined,
                                  size: 20,
                                  color: isSpeaking
                                      ? colors.primary
                                      : colors.textMuted,
                                ),
                                onPressed: _ttsService == null
                                    ? null
                                    : () {
                                        final tts = _ttsService;
                                        if (tts.isSpeaking) {
                                          unawaited(tts.stop());
                                        } else {
                                          final spokenText =
                                              SpeechTextNormalizer
                                                  .normalizeFlashcard(
                                            mainText,
                                          );
                                          unawaited(tts.speak(spokenText));
                                        }
                                      },
                                tooltip: 'Listen to card',
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.zero,
                              );
                            },
                          ),
                          // Only show parking lot when FocusSessionCubit is
                          // actually in scope (Focus Workspace) or an explicit
                          // callback was wired up by the parent.
                          if (onOpenParkingLot != null || focusState != null)
                            IconButton(
                              icon: Icon(
                                Icons.psychology_rounded,
                                size: 20,
                                color: hasParkedThoughts
                                    ? colors.primary
                                    : colors.textMuted,
                              ),
                              onPressed: () {
                                if (onOpenParkingLot != null) {
                                  onOpenParkingLot!();
                                } else {
                                  unawaited(
                                    ThoughtParkingLotSheet.show(context),
                                  );
                                }
                              },
                              tooltip: 'Thought Parking Lot',
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Center Content (Text + Image + LaTeX Formula)
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: LatexCardContentViewer(
                        text: mainText,
                        latexFormula: latexFormula,
                        imageUrl: card.imageUrl,
                        isBackFace: isBackFace,
                        enableBionicReading: enableBionicReading,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Bottom Self-Aware Hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isBackFace
                          ? Icons.swap_vert_rounded
                          : Icons.touch_app_rounded,
                      size: 14,
                      color: colors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isBackFace
                          ? context.l10n.studySessionTapToFlipBack
                          : context.l10n.studySessionTapToFlip,
                      style: typography.footnote.regular.copyWith(
                        color: colors.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A lightweight [ValueListenable] that holds a constant value for when
/// optional services are not available.
class ConstantValueListenable<T> implements ValueListenable<T> {
  const ConstantValueListenable(this.value);

  @override
  final T value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
