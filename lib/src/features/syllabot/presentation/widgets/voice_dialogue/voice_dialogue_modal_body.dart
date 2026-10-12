import 'package:flutter/material.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/dialogue_state.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/voice_dialogue_action_dock.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/voice_dialogue_header.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/voice_dialogue_workspace.dart';

/// Body composition widget containing header, workspace, and action dock.
class VoiceDialogueModalBody extends StatelessWidget {
  const VoiceDialogueModalBody({
    required this.engineType,
    required this.initialMode,
    required this.selectedGender,
    required this.isDesktop,
    required this.isLandscape,
    required this.isCompact,
    required this.stateColor,
    required this.state,
    required this.soundLevelNotifier,
    required this.ribbonAnimationController,
    required this.liveTranscript,
    required this.latestResponse,
    required this.ttsHandler,
    required this.isTranscriptExpanded,
    required this.isMuted,
    required this.onToggleGender,
    required this.onCloseModal,
    required this.onInteractionTap,
    required this.onToggleTranscriptExpanded,
    required this.onToggleMute,
    super.key,
  });

  final ExecutionEngineType engineType;
  final SocraticMode initialMode;
  final VoiceGender selectedGender;
  final bool isDesktop;
  final bool isLandscape;
  final bool isCompact;
  final Color stateColor;
  final DialogueState state;
  final ValueNotifier<double> soundLevelNotifier;
  final AnimationController ribbonAnimationController;
  final String liveTranscript;
  final String latestResponse;
  final TextToSpeechHandler ttsHandler;
  final bool isTranscriptExpanded;
  final bool isMuted;
  final VoidCallback onToggleGender;
  final VoidCallback onCloseModal;
  final VoidCallback onInteractionTap;
  final VoidCallback onToggleTranscriptExpanded;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Navigation Header
        VoiceDialogueHeader(
          engineType: engineType,
          initialMode: initialMode,
          selectedGender: selectedGender,
          isDesktop: isDesktop,
          onToggleGender: onToggleGender,
          onCloseModal: onCloseModal,
        ),

        const SizedBox(height: 8),

        // Main Center Workspace (Landscape Split vs Portrait Stack)
        Expanded(
          child: VoiceDialogueWorkspace(
            stateColor: stateColor,
            state: state,
            soundLevelNotifier: soundLevelNotifier,
            ribbonAnimationController: ribbonAnimationController,
            liveTranscript: liveTranscript,
            latestResponse: latestResponse,
            engineType: engineType,
            ttsHandler: ttsHandler,
            isLandscape: isLandscape,
            isCompact: isCompact,
            isDesktop: isDesktop,
            isTranscriptExpanded: isTranscriptExpanded,
            onInteractionTap: onInteractionTap,
            onToggleTranscriptExpanded: onToggleTranscriptExpanded,
          ),
        ),

        const SizedBox(height: 10),

        // Floating Interactive Bottom Action Dock
        VoiceDialogueActionDock(
          stateColor: stateColor,
          isDesktop: isDesktop,
          state: state,
          isMuted: isMuted,
          liveTranscript: liveTranscript,
          onToggleMute: onToggleMute,
          onInteractionTap: onInteractionTap,
          onCloseModal: onCloseModal,
        ),
      ],
    );
  }
}
