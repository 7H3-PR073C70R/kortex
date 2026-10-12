import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/dialogue_state.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/voice_dialogue_response_viewer.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/voice_dialogue_status_headline.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/voice_dialogue_transcript_card.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/voice_sound_ribbon_widget.dart';

/// Center workspace widget supporting both portrait and landscape modal orientations.
class VoiceDialogueWorkspace extends StatelessWidget {
  const VoiceDialogueWorkspace({
    required this.stateColor,
    required this.state,
    required this.soundLevelNotifier,
    required this.ribbonAnimationController,
    required this.liveTranscript,
    required this.latestResponse,
    required this.engineType,
    required this.ttsHandler,
    required this.isLandscape,
    required this.isCompact,
    required this.isDesktop,
    required this.isTranscriptExpanded,
    required this.onInteractionTap,
    required this.onToggleTranscriptExpanded,
    super.key,
  });

  final Color stateColor;
  final DialogueState state;
  final ValueNotifier<double> soundLevelNotifier;
  final AnimationController ribbonAnimationController;
  final String liveTranscript;
  final String latestResponse;
  final ExecutionEngineType engineType;
  final TextToSpeechHandler ttsHandler;
  final bool isLandscape;
  final bool isCompact;
  final bool isDesktop;
  final bool isTranscriptExpanded;
  final VoidCallback onInteractionTap;
  final VoidCallback onToggleTranscriptExpanded;

  @override
  Widget build(BuildContext context) {
    if (isLandscape) {
      return _buildLandscapeWorkspace(context);
    }
    return _buildPortraitWorkspace(context);
  }

  Widget _buildPortraitWorkspace(BuildContext context) {
    final hasResponse = latestResponse.isNotEmpty;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!hasResponse) const Spacer(),

        // Siri / Gemini Glowing Acoustic Sound Ribbon
        GestureDetector(
          onTap: onInteractionTap,
          behavior: HitTestBehavior.opaque,
          child: RepaintBoundary(
            child: VoiceSoundRibbonWidget(
              stateColor: stateColor,
              state: state,
              soundLevelNotifier: soundLevelNotifier,
              animation: ribbonAnimationController,
              height: isCompact ? 96 : (isDesktop ? 130 : 110),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Status Headline
        VoiceDialogueStatusHeadline(
          state: state,
          liveTranscript: liveTranscript,
        ),

        const SizedBox(height: 8),

        // User Live Transcription Pill / Card
        if (liveTranscript.isNotEmpty) ...[
          VoiceDialogueTranscriptCard(
            liveTranscript: liveTranscript,
            isTranscriptExpanded: isTranscriptExpanded,
            state: state,
            onToggleExpanded: onToggleTranscriptExpanded,
          ),
          const SizedBox(height: 8),
        ],

        // Syllabot AI Response Viewer
        if (hasResponse) ...[
          Flexible(
            flex: 3,
            child: VoiceDialogueResponseViewer(
              latestResponse: latestResponse,
              engineType: engineType,
              ttsHandler: ttsHandler,
              isDesktop: isDesktop,
            ),
          ),
        ],

        if (!hasResponse) const Spacer(),
      ],
    );
  }

  Widget _buildLandscapeWorkspace(BuildContext context) {
    return Row(
      children: [
        // Left Column: Sound Ribbon & Status
        SizedBox(
          width: 240,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onInteractionTap,
                behavior: HitTestBehavior.opaque,
                child: RepaintBoundary(
                  child: VoiceSoundRibbonWidget(
                    stateColor: stateColor,
                    state: state,
                    soundLevelNotifier: soundLevelNotifier,
                    animation: ribbonAnimationController,
                    height: 84,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              VoiceDialogueStatusHeadline(
                state: state,
                liveTranscript: liveTranscript,
                isCompact: true,
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // Right Column: Transcripts & Response
        Expanded(
          child: Column(
            children: [
              if (liveTranscript.isNotEmpty) ...[
                VoiceDialogueTranscriptCard(
                  liveTranscript: liveTranscript,
                  isTranscriptExpanded: isTranscriptExpanded,
                  state: state,
                  onToggleExpanded: onToggleTranscriptExpanded,
                ),
                const SizedBox(height: 6),
              ],
              Expanded(
                child: latestResponse.isNotEmpty
                    ? VoiceDialogueResponseViewer(
                        latestResponse: latestResponse,
                        engineType: engineType,
                        ttsHandler: ttsHandler,
                        isDesktop: false,
                      )
                    : Center(
                        child: Text(
                          'Syllabot voice assistant is ready.',
                          style: context.typography.caption.regular.copyWith(
                            color: context.colors.textMuted,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
