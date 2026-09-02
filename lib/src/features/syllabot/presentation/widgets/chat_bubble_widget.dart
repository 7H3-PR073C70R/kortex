import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

class ChatBubbleWidget extends StatefulWidget {
  const ChatBubbleWidget({
    required this.message,
    this.ttsHandler,
    this.onRetry,
    super.key,
  });

  final ChatMessageEntity message;
  final TextToSpeechHandler? ttsHandler;
  final VoidCallback? onRetry;

  @override
  State<ChatBubbleWidget> createState() => _ChatBubbleWidgetState();
}

class _ChatBubbleWidgetState extends State<ChatBubbleWidget> {
  bool _isSpeakingThis = false;

  bool get isUser => widget.message.sender == MessageSender.user;

  void _toggleSpeak() {
    final tts = widget.ttsHandler;
    if (tts == null) return;

    if (_isSpeakingThis) {
      unawaited(tts.stop());
      setState(() {
        _isSpeakingThis = false;
      });
    } else {
      setState(() {
        _isSpeakingThis = true;
      });
      unawaited(
        tts.speak(widget.message.text).then((_) {
          if (mounted) {
            setState(() {
              _isSpeakingThis = false;
            });
          }
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.primary,
                colors.primary.withAlpha(220),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(6),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withAlpha(isDark ? 80 : 40),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            widget.message.text,
            style: typography.body.medium.copyWith(
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    // Bot Bubble with Glassmorphism, LaTeX formulas, TTS read aloud, and retry
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SyllabotAvatar(size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary.withAlpha(200)
                          : colors.surfacePrimary.withAlpha(220),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border.all(
                        color: widget.message.isError
                            ? colors.error.withAlpha(120)
                            : colors.primary.withAlpha(isDark ? 50 : 30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Engine badge tag & Actions (Copy & Read Aloud TTS)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.syllabotAccent.withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.message.engineType ==
                                        ExecutionEngineType.cloudSupabase
                                    ? l10n.engineCloudSupabase
                                    : l10n.engineLocalOnDevice,
                                style: typography.caption.medium.copyWith(
                                  color: colors.syllabotAccent,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 1. Read Aloud TTS button
                                if (!widget.message.isError)
                                  IconButton(
                                    tooltip: _isSpeakingThis
                                        ? l10n.syllabotStopReading
                                        : l10n.syllabotReadAloud,
                                    icon: Icon(
                                      _isSpeakingThis
                                          ? Icons.stop_circle_rounded
                                          : Icons.volume_up_rounded,
                                      size: 17,
                                      color: _isSpeakingThis
                                          ? colors.syllabotAccent
                                          : colors.textSecondary,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: _toggleSpeak,
                                  ),
                                const SizedBox(width: 8),

                                // 2. Copy button
                                IconButton(
                                  tooltip: l10n.copiedToClipboard,
                                  icon: Icon(
                                    Icons.copy_rounded,
                                    size: 15,
                                    color: colors.textSecondary,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    unawaited(
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: widget.message.text,
                                        ),
                                      ),
                                    );
                                    context.showSnackBar(
                                      message: context.l10n.copiedToClipboard,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Formatted message content with LaTeX rendering
                        _FormattedMessageBody(
                          text: widget.message.text,
                          isDark: isDark,
                        ),

                        // Retry Button for error state
                        if (widget.message.isError) ...[
                          const SizedBox(height: 12),
                          ShrinkableButton(
                            onTap: widget.onRetry ?? widget.message.onRetry,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colors.error.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colors.error.withAlpha(100),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    size: 14,
                                    color: colors.error,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.retryFailedMessage,
                                    style: typography.footnote.medium.copyWith(
                                      color: colors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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

class _FormattedMessageBody extends StatelessWidget {
  const _FormattedMessageBody({
    required this.text,
    required this.isDark,
  });

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    // Parse $$math$$ or regular text chunks
    final parts = text.split(r'$$');

    if (parts.length <= 1) {
      return Text(
        text,
        style: typography.body.regular.copyWith(
          color: colors.textPrimary,
          height: 1.45,
        ),
      );
    }

    final children = <Widget>[];

    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.trim().isEmpty) continue;

      if (i.isOdd) {
        // LaTeX Math Block
        children.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withAlpha(80)
                  : colors.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 60 : 30),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                part.trim(),
                textStyle: typography.body.bold.copyWith(
                  color: isDark ? colors.syllabotAccent : colors.primary,
                  fontSize: 15,
                ),
                onErrorFallback: (err) => Text(
                  part,
                  style: typography.caption.medium.copyWith(
                    color: colors.error,
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        // Plain text block
        children.add(
          Text(
            part,
            style: typography.body.regular.copyWith(
              color: colors.textPrimary,
              height: 1.45,
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
