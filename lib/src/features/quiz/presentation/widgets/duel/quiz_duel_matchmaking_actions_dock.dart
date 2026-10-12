import 'package:flutter/material.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

/// Fixed bottom action dock for matchmaking search triggers and cancel actions.
class QuizDuelMatchmakingActionsDock extends StatelessWidget {
  const QuizDuelMatchmakingActionsDock({
    required this.isSearching,
    required this.activeTab,
    required this.generatedCode,
    required this.onMatchWithAiImmediately,
    required this.onCancelSearch,
    required this.onQuickMatch,
    required this.onQuickMatchWithAi,
    required this.onStartRoomLobby,
    required this.onJoinRoomWithCode,
    super.key,
  });

  final bool isSearching;
  final int activeTab;
  final String generatedCode;
  final VoidCallback onMatchWithAiImmediately;
  final VoidCallback onCancelSearch;
  final VoidCallback onQuickMatch;
  final VoidCallback onQuickMatchWithAi;
  final VoidCallback onStartRoomLobby;
  final VoidCallback onJoinRoomWithCode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: isSearching
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppButton(
                  text: 'Practice with AI now',
                  onPressed: onMatchWithAiImmediately,
                ),
                const SizedBox(height: 8),
                AppButton(
                  text: 'Cancel search',
                  variant: AppButtonVariant.secondary,
                  onPressed: onCancelSearch,
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (activeTab == 0) ...[
                  AppButton(
                    text: 'Find a classmate',
                    onPressed: onQuickMatch,
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    text: 'Practice Solo with AI',
                    variant: AppButtonVariant.secondary,
                    onPressed: onQuickMatchWithAi,
                  ),
                ] else if (activeTab == 1) ...[
                  AppButton(
                    text: 'Start Room Lobby ($generatedCode)',
                    onPressed: onStartRoomLobby,
                  ),
                ] else ...[
                  AppButton(
                    text: 'Join Duel Room',
                    onPressed: onJoinRoomWithCode,
                  ),
                ],
              ],
            ),
    );
  }
}
