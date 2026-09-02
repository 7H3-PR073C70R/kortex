import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/presentation/bloc/live_room_cubit.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class LiveStudyRoomPage extends StatelessWidget {
  const LiveStudyRoomPage({
    required this.room,
    super.key,
  });

  final StudyRoomEntity room;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LiveRoomCubit>(
      create: (_) => LiveRoomCubit(
        initialRoom: room,
        repository: locator<CommunityRepository>(),
      ),
      child: const _LiveStudyRoomView(),
    );
  }
}

class _LiveStudyRoomView extends StatelessWidget {
  const _LiveStudyRoomView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return BlocBuilder<LiveRoomCubit, LiveRoomState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor:
              isDark ? colors.backgroundPrimary : colors.surfacePrimary,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              state.room.title,
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: colors.textPrimary,
              ),
              onPressed: () => unawaited(context.router.maybePop()),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              child: Column(
                children: [
                  // State Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: state.room.isFocusing
                          ? colors.primary.withAlpha(30)
                          : Colors.orangeAccent.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: state.room.isFocusing
                            ? colors.primary
                            : Colors.orangeAccent,
                      ),
                    ),
                    child: Text(
                      state.room.isFocusing
                          ? l10n.pomodoroFocus.toUpperCase()
                          : l10n.pomodoroBreak.toUpperCase(),
                      style: typography.footnote.bold.copyWith(
                        color: state.room.isFocusing
                            ? colors.primary
                            : Colors.orangeAccent,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Circular Synced Timer Indicator
                  Expanded(
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 260,
                            height: 260,
                            child: CircularProgressIndicator(
                              value: state.progress,
                              strokeWidth: 12,
                              backgroundColor: colors.surfaceSecondary,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                state.room.isFocusing
                                    ? colors.primary
                                    : Colors.orangeAccent,
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                state.formattedTimer,
                                style: typography.largeTitle.bold.copyWith(
                                  fontSize: 48,
                                  color: colors.textPrimary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                state.room.subject,
                                textAlign: TextAlign.center,
                                style: typography.footnote.medium.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Active Participant Avatars Row
                  Text(
                    l10n.activeParticipantsCount(state.participants.length),
                    style: typography.footnote.bold.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      itemCount: state.participants.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final name = state.participants[index];
                        return AppAvatar(
                          customDimension: 48,
                          name: name,
                          backgroundColor: colors.primary.withAlpha(50),
                          foregroundColor: colors.primary,
                          borderColor: colors.primary.withAlpha(100),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Bottom Action Buttons: Pause & Leave
                  Row(
                    children: [
                      Expanded(
                        child: ShrinkableButton(
                          onTap: () {
                            context
                                .read<LiveRoomCubit>()
                                .toggleTimerPause();
                          },
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: colors.surfaceSecondary,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colors.primary.withAlpha(60),
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    state.room.isPaused
                                        ? Icons.play_arrow_rounded
                                        : Icons.pause_rounded,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    state.room.isPaused ? 'Resume' : 'Pause',
                                    style: typography.footnote.bold.copyWith(
                                      color: colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ShrinkableButton(
                          onTap: () => unawaited(context.router.maybePop()),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withAlpha(30),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.redAccent.withAlpha(80),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                l10n.leaveRoomButton,
                                style: typography.footnote.bold.copyWith(
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
