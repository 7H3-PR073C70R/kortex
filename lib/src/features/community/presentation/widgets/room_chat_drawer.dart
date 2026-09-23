import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/community/presentation/bloc/live_room_cubit.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class RoomChatDrawer extends StatefulWidget {
  const RoomChatDrawer({
    required this.currentUserId,
    super.key,
  });

  final String currentUserId;

  static void show(BuildContext context, {required String currentUserId}) {
    context.read<LiveRoomCubit>().markChatAsRead();
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.colors.transparent,
        builder: (_) => BlocProvider.value(
          value: context.read<LiveRoomCubit>(),
          child: RoomChatDrawer(currentUserId: currentUserId),
        ),
      ),
    );
  }

  @override
  State<RoomChatDrawer> createState() => _RoomChatDrawerState();
}

class _RoomChatDrawerState extends State<RoomChatDrawer> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _hasText = false;

  static const List<String> _quickReactions = [
    '🔥',
    '👏',
    '💡',
    '❓',
    '❤️',
    '📚',
    '✨',
  ];

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() {
          _hasText = hasText;
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage({String? explicitText, bool isReaction = false}) {
    final text = explicitText ?? _textController.text.trim();
    if (text.isEmpty) return;

    AppFeedback.light();
    context.read<LiveRoomCubit>().sendChatMessage(
      text,
      isReaction: isReaction,
    );

    if (explicitText == null) {
      _textController.clear();
    }

    // Scroll to bottom on sending
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        unawaited(
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 60,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final l10n = context.l10n;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 14,
        right: 14,
        bottom: bottomInset + math.max(12.0, safeBottom),
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(100),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 80 : 30),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Header Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 45 : 25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.forum_rounded,
                  color: colors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.liveRoomDiscussionTitle,
                      style: typography.callout.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      l10n.liveRoomDiscussionSubtitle,
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Quick Emoji Tap Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surfaceTertiary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _quickReactions.map((emoji) {
                return ShrinkableButton(
                  onTap: () =>
                      _sendMessage(explicitText: emoji, isReaction: true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      emoji,
                      style: context.typography.body.regular.copyWith(fontSize: 18),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          // Messages Timeline (WhatsApp-styled bubbles)
          Expanded(
            child: BlocBuilder<LiveRoomCubit, LiveRoomState>(
              builder: (context, state) {
                if (state.chatMessages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 36,
                          color: colors.textSecondary.withAlpha(120),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.noChatMessagesPrompt,
                          style: typography.caption.medium.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: state.chatMessages.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final msg = state.chatMessages[index];
                    final isMe = msg.senderId == widget.currentUserId;

                    return _ChatMessageBubble(
                      message: msg,
                      isMe: isMe,
                      colors: colors,
                      typography: typography,
                      isDark: isDark,
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // WhatsApp Style Bottom Input Bar
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceTertiary
                        : colors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: colors.surfaceBorder.withAlpha(isDark ? 90 : 60),
                    ),
                  ),
                  child: TextField(
                    controller: _textController,
                    maxLines: 4,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                    style: context.typography.body.regular.copyWith(
                      fontSize: 13.5,
                      color: colors.textPrimary,
                      height: 1.3,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.chatInputHint,
                      hintStyle: context.typography.body.regular.copyWith(
                        fontSize: 13,
                        color: colors.textSecondary.withAlpha(180),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ShrinkableButton(
                onTap: _sendMessage,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _hasText
                        ? colors.primary
                        : colors.primary.withAlpha(isDark ? 160 : 200),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors.black.withAlpha(isDark ? 40 : 15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.send_rounded,
                      color: colors.white,
                      size: 18,
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

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.message,
    required this.isMe,
    required this.colors,
    required this.typography,
    required this.isDark,
  });

  final RoomChatMessage message;
  final bool isMe;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(message.timestamp);

    // Single Emoji Reaction Pill
    if (message.isReaction && message.text.length <= 4) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surfaceTertiary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.surfaceBorder.withAlpha(isDark ? 60 : 40),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.text,
                style: context.typography.body.regular.copyWith(fontSize: 16),
              ),
              const SizedBox(width: 5),
              Text(
                isMe ? 'You' : message.senderName,
                style: typography.caption.medium.copyWith(
                  fontSize: 11,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                timeStr,
                style: typography.caption.regular.copyWith(
                  fontSize: 9.5,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // WhatsApp-Style Chat Bubble
    final bubbleColor = isMe
        ? colors.primary
        : (isDark ? colors.surfaceTertiary : colors.surfaceSecondary);

    final textColor = isMe ? colors.white : colors.textPrimary;
    final subtextColor = isMe
        ? colors.white.withAlpha(190)
        : colors.textSecondary;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        margin: EdgeInsets.only(
          left: isMe ? 40 : 0,
          right: isMe ? 0 : 40,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: isMe
                ? const Radius.circular(14)
                : const Radius.circular(3),
            bottomRight: isMe
                ? const Radius.circular(3)
                : const Radius.circular(14),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.black.withAlpha(isDark ? 40 : 10),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe && message.senderName.isNotEmpty) ...[
              Text(
                message.senderName,
                style: typography.caption.bold.copyWith(
                  fontSize: 11,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              message.text,
              style: typography.body.regular.copyWith(
                fontSize: 13.5,
                color: textColor,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: typography.caption.regular.copyWith(
                    fontSize: 9.5,
                    color: subtextColor,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all_rounded,
                    size: 13,
                    color: colors.white.withAlpha(200),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
