import 'package:flutter/material.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat_bubble_widget.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';

/// Syllabot AI Response Viewer for Voice Dialogue Modal.
class VoiceDialogueResponseViewer extends StatelessWidget {
  const VoiceDialogueResponseViewer({
    required this.latestResponse,
    required this.engineType,
    required this.ttsHandler,
    required this.isDesktop,
    super.key,
  });

  final String latestResponse;
  final ExecutionEngineType engineType;
  final TextToSpeechHandler ttsHandler;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: isDesktop ? 620 : 540,
      ),
      child: ShaderMask(
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.05, 0.95, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ChatBubbleWidget(
            message: ChatMessageEntity(
              id: 'dialogue_response',
              sessionId: 'dialogue_session',
              text: latestResponse,
              sender: MessageSender.syllabot,
              timestamp: DateTime.now(),
              engineType: engineType,
            ),
            ttsHandler: ttsHandler,
            showSpeakButton: false,
          ),
        ),
      ),
    );
  }
}
