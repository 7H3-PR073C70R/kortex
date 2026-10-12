import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_bloc.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_event.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_state.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat_bubble_widget.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/streaming_text_typing_indicator.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';

/// Active message stream list view for Syllabot conversations.
class SyllabotMessageListView extends StatelessWidget {
  const SyllabotMessageListView({
    required this.state,
    required this.scrollController,
    required this.ttsHandler,
    this.onUserAtBottomChanged,
    super.key,
  });

  final SyllabotChatState state;
  final ScrollController scrollController;
  final TextToSpeechHandler ttsHandler;
  final ValueChanged<bool>? onUserAtBottomChanged;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (scrollController.hasClients &&
            scrollController.position.hasContentDimensions) {
          final maxExtent = scrollController.position.maxScrollExtent;
          final isAtBottom = (maxExtent - scrollController.offset) < 90;
          onUserAtBottomChanged?.call(isAtBottom);
        }
        return false;
      },
      child: ListView.builder(
        controller: scrollController,
        physics: const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount:
            state.messages.length +
            (state.status == SyllabotStatus.streaming ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < state.messages.length) {
            final message = state.messages[index];
            return ChatBubbleWidget(
              message: message,
              ttsHandler: ttsHandler,
              onRetry: message.sender == MessageSender.syllabot
                  ? () {
                      context.read<SyllabotChatBloc>().add(
                        const RetryLastMessageEvent(),
                      );
                    }
                  : null,
            );
          }

          // Live typing typewriter stream indicator
          if (state.streamingText.isEmpty) {
            return const StreamingTextTypingIndicator();
          }

          final streamingMessage = ChatMessageEntity(
            id: 'msg_bot_streaming',
            sessionId: state.sessionId,
            sender: MessageSender.syllabot,
            text: state.streamingText,
            timestamp: DateTime.now(),
            engineType: state.engineType,
          );

          return ChatBubbleWidget(
            message: streamingMessage,
            isStreaming: true,
          );
        },
      ),
    );
  }
}
