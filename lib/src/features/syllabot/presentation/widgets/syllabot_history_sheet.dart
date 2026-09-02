import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/syllabot/domain/entities/conversation_session_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/domain/repositories/syllabot_repository.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_bloc.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_event.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Interactive modal sheet displaying previous Syllabot AI conversations.
class SyllabotHistorySheet extends StatefulWidget {
  const SyllabotHistorySheet({
    required this.currentSessionId,
    super.key,
  });

  final String currentSessionId;

  static Future<void> show(
    BuildContext context, {
    required String currentSessionId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SyllabotHistorySheet(
        currentSessionId: currentSessionId,
      ),
    );
  }

  @override
  State<SyllabotHistorySheet> createState() => _SyllabotHistorySheetState();
}

class _SyllabotHistorySheetState extends State<SyllabotHistorySheet> {
  bool _isLoading = true;
  List<ConversationSessionEntity> _sessions = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSessions());
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final repo = locator<SyllabotRepository>();
    final result = await repo.getChatSessions();

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isLoading = false;
          _errorMessage = failure.message;
        });
      },
      (sessions) {
        setState(() {
          _isLoading = false;
          _sessions = sessions;
        });
      },
    );
  }

  Future<void> _deleteSession(String sessionId) async {
    final repo = locator<SyllabotRepository>();
    await repo.deleteChatSession(sessionId: sessionId);
    if (!mounted) return;
    setState(() {
      _sessions.removeWhere((s) => s.id == sessionId);
    });
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    return DateFormat.MMMd().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfacePrimary.withAlpha(245)
            : colors.surfacePrimary.withAlpha(250),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(80),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Top Drag Handle
            Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: colors.surfaceBorder.withAlpha(140),
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            const SizedBox(height: 16),

            // Header Row: Title & Start New Chat Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conversation History',
                        style: typography.title2.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Resume or manage your study sessions',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  ShrinkableButton(
                    onTap: () {
                      unawaited(HapticFeedback.lightImpact());
                      Navigator.pop(context);
                      locator<SyllabotChatBloc>().add(
                        const StartNewSessionEvent(),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(isDark ? 50 : 25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colors.primary.withAlpha(isDark ? 90 : 60),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'New Chat',
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: colors.surfaceBorder.withAlpha(80),
            ),

            // Session List / Loading / Empty State
            Expanded(
              child: _buildBody(colors, typography, l10n, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    AppLocalizations l10n,
    bool isDark,
  ) {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, index) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: ShimmerPlaceholder(
            width: double.infinity,
            height: 72,
            borderRadius: 14,
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 36, color: colors.error),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: typography.body.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              ShrinkableButton(
                onTap: _loadSessions,
                child: Text(
                  'Retry',
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 42,
                color: colors.textSecondary.withAlpha(120),
              ),
              const SizedBox(height: 12),
              Text(
                'No Previous Conversations',
                style: typography.body.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ask questions in Syllabot to build your academic history.',
                textAlign: TextAlign.center,
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        final isCurrent = session.id == widget.currentSessionId;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.lightImpact());
              Navigator.pop(context);
              locator<SyllabotChatBloc>().add(
                LoadChatMessagesEvent(session.id),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isCurrent
                    ? colors.primary.withAlpha(isDark ? 40 : 20)
                    : colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCurrent
                      ? colors.primary.withAlpha(isDark ? 100 : 70)
                      : colors.surfaceBorder.withAlpha(90),
                  width: isCurrent ? 1.4 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getModeIcon(session.socraticMode),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.title.isNotEmpty
                              ? session.title
                              : 'Academic Discussion',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.body.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(session.updatedAt),
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: colors.textSecondary.withAlpha(140),
                    ),
                    onPressed: () => _deleteSession(session.id),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getModeIcon(SocraticMode mode) {
    switch (mode) {
      case SocraticMode.stepByStep:
        return '🪜';
      case SocraticMode.directAnswer:
        return '🎯';
      case SocraticMode.examSim:
        return '📝';
      case SocraticMode.deepResearch:
        return '🔬';
    }
  }
}
