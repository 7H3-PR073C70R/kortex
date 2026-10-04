import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/rag_reference_badge.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/rag_source_inspection_sheet.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/syllabot_response_formatter.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

class ChatBubbleWidget extends StatefulWidget {
  const ChatBubbleWidget({
    required this.message,
    this.ttsHandler,
    this.onRetry,
    this.onConvertToCard,
    this.isStreaming = false,
    super.key,
  });

  final ChatMessageEntity message;
  final TextToSpeechHandler? ttsHandler;
  final VoidCallback? onRetry;
  final VoidCallback? onConvertToCard;
  final bool isStreaming;

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
            maxWidth: (MediaQuery.sizeOf(context).width * 0.75).clamp(
              280.0,
              580.0,
            ),
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
              topLeft: Radius.circular(AppRadius.dialog),
              topRight: Radius.circular(AppRadius.micro),
              bottomLeft: Radius.circular(AppRadius.dialog),
              bottomRight: Radius.circular(AppRadius.dialog),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.black.withAlpha(isDark ? 40 : 15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            widget.message.text,
            style: typography.body.medium.copyWith(
              color: colors.white,
              height: 1.4,
            ),
          ),
        ),
      ).animate().fadeIn(duration: 200.ms, curve: Curves.easeOutQuint).slideY(begin: 0.05, end: 0, duration: 200.ms, curve: Curves.easeOutQuint);
    }

    // Bot Bubble with Glassmorphism, Rich Markdown, LaTeX formulas, and Actions
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.sizeOf(context).width * 0.88).clamp(
            320.0,
            720.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SyllabotAvatar(size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceSecondary
                      : colors.surfacePrimary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.micro),
                    topRight: Radius.circular(AppRadius.dialog),
                    bottomLeft: Radius.circular(AppRadius.dialog),
                    bottomRight: Radius.circular(AppRadius.dialog),
                  ),
                  border: Border.all(
                    color: widget.message.isError
                        ? colors.error.withAlpha(120)
                        : colors.primary.withAlpha(isDark ? 50 : 30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.black.withAlpha(isDark ? 30 : 8),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Engine badge tag & Actions (Copy & TTS)
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
                            borderRadius: AppRadius.radiusBadge,
                          ),
                          child: Text(
                            l10n.engineCloudSupabase,
                            style: typography.caption.medium.copyWith(
                              color: colors.syllabotAccent,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        if (widget.isStreaming)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppLogoLoader(
                                size: 14,
                                color: colors.syllabotAccent,
                                showMessage: false,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Typing...',
                                style: typography.caption.medium.copyWith(
                                  color: colors.syllabotAccent,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 1. Read Aloud TTS button
                              if (!widget.message.isError)
                                PlatformHoverBuilder(
                                  builder: (context, isHovered, child) {
                                    return ShrinkableButton(
                                      onTap: _toggleSpeak,
                                      child: AnimatedContainer(
                                        duration: AppMotion.snappy,
                                        curve: AppMotion.snappyCurve,
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: isHovered
                                              ? colors.primary.withAlpha(20)
                                              : context.colors.transparent,
                                          borderRadius: AppRadius.radiusBadge,
                                        ),
                                        child: Tooltip(
                                          message: _isSpeakingThis
                                              ? l10n.syllabotStopReading
                                              : l10n.syllabotReadAloud,
                                          child: Icon(
                                            _isSpeakingThis
                                                ? Icons.stop_circle_rounded
                                                : Icons.volume_up_rounded,
                                            size: 16,
                                            color: _isSpeakingThis
                                                ? colors.syllabotAccent
                                                : (isHovered
                                                      ? colors.primary
                                                      : colors.textSecondary),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              const SizedBox(width: 4),

                              // 2. Convert to Card button
                              if (widget.onConvertToCard != null &&
                                  !widget.message.isError) ...[
                                PlatformHoverBuilder(
                                  builder: (context, isHovered, child) {
                                    return ShrinkableButton(
                                      onTap: widget.onConvertToCard,
                                      child: AnimatedContainer(
                                        duration: AppMotion.snappy,
                                        curve: AppMotion.snappyCurve,
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: isHovered
                                              ? colors.primary.withAlpha(20)
                                              : context.colors.transparent,
                                          borderRadius: AppRadius.radiusBadge,
                                        ),
                                        child: Tooltip(
                                          message: 'Create Flashcards',
                                          child: Icon(
                                            Icons.style_outlined,
                                            size: 15,
                                            color: isHovered
                                                ? colors.primary
                                                : colors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 4),
                              ],

                              // 3. Copy button
                              PlatformHoverBuilder(
                                builder: (context, isHovered, child) {
                                  return ShrinkableButton(
                                    onTap: () {
                                      unawaited(
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: SyllabotResponseFormatter.format(
                                              widget.message.text,
                                            ),
                                          ),
                                        ),
                                      );
                                      context.showSnackBar(
                                        message: context.l10n.copiedToClipboard,
                                      );
                                    },
                                    child: AnimatedContainer(
                                      duration: AppMotion.snappy,
                                      curve: AppMotion.snappyCurve,
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: isHovered
                                            ? colors.primary.withAlpha(20)
                                            : context.colors.transparent,
                                        borderRadius: AppRadius.radiusBadge,
                                      ),
                                      child: Tooltip(
                                        message: l10n.copiedToClipboard,
                                        child: Icon(
                                          Icons.copy_rounded,
                                          size: 15,
                                          color: isHovered
                                              ? colors.primary
                                              : colors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Formatted body with Markdown & LaTeX rendering
                    _FormattedMessageBody(
                      text: widget.message.text,
                      isDark: isDark,
                      isStreaming: widget.isStreaming,
                    ),

                    // RAG Retrieved Context Badges
                    if (widget.message.ragReferences.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: widget.message.ragReferences.map((chunk) {
                          return RagReferenceBadge(
                            chunk: chunk,
                            onTap: () =>
                                RagSourceInspectionSheet.show(context, chunk),
                          );
                        }).toList(),
                      ),
                    ],

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
                            borderRadius: AppRadius.radiusBadge,
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
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms, curve: Curves.easeOutQuint).slideY(begin: 0.05, end: 0, duration: 200.ms, curve: Curves.easeOutQuint);
  }
}

class _FormattedMessageBody extends StatelessWidget {
  const _FormattedMessageBody({
    required this.text,
    required this.isDark,
    this.isStreaming = false,
  });

  final String text;
  final bool isDark;
  final bool isStreaming;

  static final RegExp _markdownTableBlockRegex = RegExp(
    r'(?:^[ \t]*\|[^\n]+\|[ \t]*\r?\n[ \t]*\|[ \t]*:?[-]+:?[ \t]*(?:\|[ \t]*:?[-]+:?[ \t]*)+[ \t]*\|?[ \t]*(?:\r?\n[ \t]*\|[^\n]+\|[ \t]*)*)',
    multiLine: true,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    // Sanitize prompt artifacts, tags, decode HTML entities, and format LaTeX math delimiters
    final formattedText = SyllabotResponseFormatter.format(text);

    if (formattedText.isEmpty) {
      if (isStreaming) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLogoLoader(
                size: 16,
                color: colors.syllabotAccent,
                showMessage: false,
              ),
              const SizedBox(width: 8),
              Text(
                'Thinking...',
                style: typography.caption.medium.copyWith(
                  color: colors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'No content generated. Tap retry.',
          style: typography.caption.medium.copyWith(
            color: colors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // Append blinking/typewriter cursor during active token streaming
    final displayText = isStreaming ? '$formattedText ▌' : formattedText;

    final defaultTextStyle = typography.body.regular.copyWith(
      color: colors.textPrimary,
      height: 1.45,
      fontSize: 14,
    );

    // If the message contains Markdown tables, isolate them for MarkdownBody
    // while rendering all natural language, formulas, lists, and code with LatexRichViewer
    final tableMatches =
        _markdownTableBlockRegex.allMatches(displayText).toList();
    if (tableMatches.isEmpty) {
      return LatexRichViewer(
        text: displayText,
        style: defaultTextStyle,
      );
    }

    final markdownStyleSheet = MarkdownStyleSheet(
      p: defaultTextStyle,
      tableHead: typography.body.bold.copyWith(
        color: isDark ? colors.syllabotAccent : colors.primary,
        fontSize: 13,
      ),
      tableBody: typography.body.regular.copyWith(
        color: colors.textPrimary,
        fontSize: 13,
      ),
      tableBorder: TableBorder.all(
        color: colors.surfaceBorder.withAlpha(isDark ? 80 : 120),
      ),
      tablePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );

    final widgets = <Widget>[];
    var lastIndex = 0;

    for (final match in tableMatches) {
      if (match.start > lastIndex) {
        final precedingText =
            displayText.substring(lastIndex, match.start).trim();
        if (precedingText.isNotEmpty) {
          widgets
            ..add(
              LatexRichViewer(
                text: precedingText,
                style: defaultTextStyle,
              ),
            )
            ..add(const SizedBox(height: 8));
        }
      }

      final tableText = match.group(0)?.trim() ?? '';
      if (tableText.isNotEmpty) {
        widgets
          ..add(
            Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.black.withAlpha(40)
                    : colors.surfaceSecondary,
                borderRadius: AppRadius.radiusCard,
                border: Border.all(
                  color: colors.surfaceBorder.withAlpha(80),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: MarkdownBody(
                    data: tableText,
                    styleSheet: markdownStyleSheet,
                  ),
                ),
              ),
            ),
          )
          ..add(const SizedBox(height: 8));
      }

      lastIndex = match.end;
    }

    if (lastIndex < displayText.length) {
      final remaining = displayText.substring(lastIndex).trim();
      if (remaining.isNotEmpty) {
        widgets.add(
          LatexRichViewer(
            text: remaining,
            style: defaultTextStyle,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }
}
