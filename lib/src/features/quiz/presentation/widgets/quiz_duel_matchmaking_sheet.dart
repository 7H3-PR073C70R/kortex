import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_state.dart';
import 'package:kortex/src/features/quiz/presentation/pages/quiz_duel_arena_page.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_invite_friend_tab.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_join_code_tab.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_matchmaking_actions_dock.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_matchmaking_header.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_quick_match_tab.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_searching_radar_view.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_duel_missing_questions_sheet.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/app_liquid_glass_tab_bar.dart';

/// Modal bottom sheet for searching, creating rooms, entering codes, and joining 1v1 Quiz Duels (QZ-13).
class QuizDuelMatchmakingSheet extends HookWidget {
  const QuizDuelMatchmakingSheet({
    super.key,
    this.initialSubject = 'Physics',
    this.initialExamBoard = 'WAEC',
    this.authBlocOverride,
    this.dashboardBlocOverride,
    this.decksBlocOverride,
    this.quizDuelCubitOverride,
  });

  final String initialSubject;
  final String initialExamBoard;
  final AuthBloc? authBlocOverride;
  final DashboardBloc? dashboardBlocOverride;
  final DecksBloc? decksBlocOverride;
  final QuizDuelCubit? quizDuelCubitOverride;

  static Future<void> show(
    BuildContext context, {
    String initialSubject = 'Physics',
    String initialExamBoard = 'WAEC',
    AuthBloc? authBlocOverride,
    DashboardBloc? dashboardBlocOverride,
    DecksBloc? decksBlocOverride,
    QuizDuelCubit? quizDuelCubitOverride,
  }) {
    final cubit = quizDuelCubitOverride ?? locator<QuizDuelCubit>();
    return AppAdaptiveSheet.showModal<void>(
      context: context,
      maxWidth: 640,
      builder: (_) => BlocProvider<QuizDuelCubit>.value(
        value: cubit,
        child: QuizDuelMatchmakingSheet(
          initialSubject: initialSubject,
          initialExamBoard: initialExamBoard,
          authBlocOverride: authBlocOverride,
          dashboardBlocOverride: dashboardBlocOverride,
          decksBlocOverride: decksBlocOverride,
          quizDuelCubitOverride: cubit,
        ),
      ),
    );
  }

  AuthBloc? _resolveAuthBloc(BuildContext context) {
    if (authBlocOverride != null) return authBlocOverride;
    try {
      return context.read<AuthBloc>();
    } on Object catch (_) {
      return locator.isRegistered<AuthBloc>() ? locator<AuthBloc>() : null;
    }
  }

  DashboardBloc? _resolveDashboardBloc(BuildContext context) {
    if (dashboardBlocOverride != null) return dashboardBlocOverride;
    try {
      return context.read<DashboardBloc>();
    } on Object catch (_) {
      return locator.isRegistered<DashboardBloc>()
          ? locator<DashboardBloc>()
          : null;
    }
  }

  DecksBloc? _resolveDecksBloc(BuildContext context) {
    if (decksBlocOverride != null) return decksBlocOverride;
    try {
      return context.read<DecksBloc>();
    } on Object catch (_) {
      return locator.isRegistered<DecksBloc>() ? locator<DecksBloc>() : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    final activeTab = useState<int>(0);
    final selectedSubject = useState<String>(initialSubject);
    final selectedQuestionCount = useState<int>(10);
    final isSearching = useState<bool>(false);
    final searchSeconds = useState<int>(0);
    final activeRoomCode = useState<String?>(null);

    final generatedCode = useState<String>(QuizDuelMatch.generateRoomCode());
    final enteredCodeController = useTextEditingController();

    useEffect(() {
      Timer? timer;
      if (isSearching.value) {
        searchSeconds.value = 0;
        timer = Timer.periodic(const Duration(seconds: 1), (_) {
          searchSeconds.value++;
        });
      }
      return () => timer?.cancel();
    }, [isSearching.value]);

    final authBloc = _resolveAuthBloc(context);
    final userTrack = authBloc?.state.userProfile?.targetTrack;
    final resolvedExamBoard = (userTrack != null && userTrack.isNotEmpty)
        ? userTrack
        : initialExamBoard;

    final dashboardBloc = _resolveDashboardBloc(context);
    final curatedCourses = dashboardBloc?.state.feed?.curatedCourses
            .map((c) => c.title.trim())
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList() ??
        [];

    final decksBloc = _resolveDecksBloc(context);
    final deckSubjects = decksBloc?.state.allDecks
            .map((d) => d.subject.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList() ??
        [];

    final userRegisteredCourses = {...curatedCourses, ...deckSubjects}.toList();
    final hasCustomCourses = userRegisteredCourses.isNotEmpty;

    final subjects = hasCustomCourses
        ? userRegisteredCourses
        : const [
            'Mathematics',
            'English',
            'Biology',
            'Physics',
            'Chemistry',
            'Economics',
          ];

    if (!subjects.contains(selectedSubject.value) && subjects.isNotEmpty) {
      selectedSubject.value = subjects.first;
    }

    final pulseController = useAnimationController(
      duration: const Duration(milliseconds: 1400),
    );

    useEffect(() {
      unawaited(pulseController.repeat(reverse: true));
      return null;
    }, [pulseController]);

    Future<void> executeMatchmaking({String? roomCode}) async {
      AppFeedback.selection();
      isSearching.value = true;
      activeRoomCode.value = roomCode;

      final profile = authBloc?.state.userProfile;
      final resolvedUserId = profile?.id ??
          authBloc?.state.user?.id ??
          'user_${DateTime.now().millisecondsSinceEpoch}';
      final resolvedDisplayName = (profile?.displayName != null &&
              profile!.displayName!.trim().isNotEmpty)
          ? profile.displayName!.trim()
          : 'Scholar';
      final resolvedAvatarUrl = profile?.photoUrl ?? '';

      await context.read<QuizDuelCubit>().startMatchmaking(
        subject: selectedSubject.value,
        examBoard: resolvedExamBoard,
        userId: resolvedUserId,
        displayName: resolvedDisplayName,
        avatarUrl: resolvedAvatarUrl,
        questionCount: selectedQuestionCount.value,
        roomCode: roomCode,
      );
    }

    Future<void> copyCodeToClipboard(String code) async {
      AppFeedback.light();
      await Clipboard.setData(ClipboardData(text: code));
      if (context.mounted) {
        context.showSnackBar(
          message: 'Room code $code copied to clipboard!',
          type: SnackBarType.success,
        );
      }
    }

    Future<void> shareInviteWithFriend(String code) async {
      AppFeedback.light();
      final shareText = '⚔️ Challenge me to a 1v1 ${selectedSubject.value} Duel on Kortex!\n'
          'Room Code: $code\n'
          'Open Kortex > 1v1 Duel > Enter Code "$code" to play!';

      await Clipboard.setData(ClipboardData(text: shareText));
      if (context.mounted) {
        context.showSnackBar(
          message: 'Duel invite copied! Send it to your friend on WhatsApp or chat.',
          type: SnackBarType.success,
        );
      }
    }

    final userProfile = authBloc?.state.userProfile;
    final userElo = userProfile?.eloRating ?? 1250;

    return BlocListener<QuizDuelCubit, QuizDuelState>(
      listener: (context, state) {
        if (state.status == QuizDuelStatus.countdown ||
            state.status == QuizDuelStatus.inRound) {
          final cubit = context.read<QuizDuelCubit>();
          Navigator.of(context).pop();
          unawaited(
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider<QuizDuelCubit>.value(
                  value: cubit,
                  child: const QuizDuelArenaPage(),
                ),
              ),
            ),
          );
        } else if (state.status == QuizDuelStatus.cancelled ||
            state.errorMessage != null) {
          isSearching.value = false;
          if (state.isQuestionsUnavailable ||
              state.failure is NoQuizQuestionsFailure) {
            final targetSubject =
                state.missingQuestionsSubject ?? selectedSubject.value;
            unawaited(
              QuizDuelMissingQuestionsSheet.show(
                context,
                subject: targetSubject,
                onRetry: () =>
                    executeMatchmaking(roomCode: activeRoomCode.value),
              ),
            );
          } else if (state.errorMessage != null &&
              state.errorMessage!.isNotEmpty) {
            context.showSnackBar(
              message: state.errorMessage!,
              type: SnackBarType.error,
            );
          }
        }
      },
      child: Align(
        alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 640,
            maxHeight: MediaQuery.sizeOf(context).height *
                (isDesktop ? 0.85 : 0.90),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              borderRadius: isDesktop
                  ? BorderRadius.circular(AppRadius.dialog)
                  : const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.dialog),
                    ),
              border: Border.all(
                color: colors.surfaceBorder.withValues(alpha: 0.5),
              ),
              boxShadow: isDesktop
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ]
                  : null,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  QuizDuelMatchmakingHeader(
                    userElo: userElo,
                    isDesktop: isDesktop,
                  ),

                  // Mode Segment Switcher (only when not actively searching)
                  if (!isSearching.value) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AppLiquidGlassTabBar(
                        tabs: const [
                          'Quick Match',
                          'Invite Friend',
                          'Enter Code'
                        ],
                        icons: const [
                          Icons.radar_rounded,
                          Icons.share_rounded,
                          Icons.pin_rounded,
                        ],
                        selectedIndex: activeTab.value,
                        isCompact: true,
                        onTabSelected: (index) {
                          AppFeedback.selection();
                          activeTab.value = index;
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colors.surfaceBorder.withValues(alpha: 0.2),
                  ),

                  // Scrollable Body Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isSearching.value) ...[
                            QuizDuelSearchingRadarView(
                              pulseController: pulseController,
                              activeRoomCode: activeRoomCode.value,
                              searchSeconds: searchSeconds.value,
                              selectedSubject: selectedSubject.value,
                              resolvedExamBoard: resolvedExamBoard,
                              selectedQuestionCount:
                                  selectedQuestionCount.value,
                              onCopyCode: copyCodeToClipboard,
                              onShareInvite: shareInviteWithFriend,
                            ),
                          ] else if (activeTab.value == 0) ...[
                            QuizDuelQuickMatchTab(
                              subjects: subjects,
                              selectedSubject: selectedSubject.value,
                              selectedQuestionCount:
                                  selectedQuestionCount.value,
                              hasCustomCourses: hasCustomCourses,
                              onSelectSubject: (sub) =>
                                  selectedSubject.value = sub,
                              onSelectQuestionCount: (c) =>
                                  selectedQuestionCount.value = c,
                              dashboardBloc: dashboardBloc,
                            ),
                          ] else if (activeTab.value == 1) ...[
                            QuizDuelInviteFriendTab(
                              generatedCode: generatedCode.value,
                              subjects: subjects,
                              selectedSubject: selectedSubject.value,
                              hasCustomCourses: hasCustomCourses,
                              onCopyCode: copyCodeToClipboard,
                              onGenerateNewCode: () {
                                generatedCode.value =
                                    QuizDuelMatch.generateRoomCode();
                              },
                              onShareInvite: shareInviteWithFriend,
                              onSelectSubject: (sub) =>
                                  selectedSubject.value = sub,
                              dashboardBloc: dashboardBloc,
                            ),
                          ] else ...[
                            QuizDuelJoinCodeTab(
                              enteredCodeController: enteredCodeController,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  QuizDuelMatchmakingActionsDock(
                    isSearching: isSearching.value,
                    activeTab: activeTab.value,
                    generatedCode: generatedCode.value,
                    onMatchWithAiImmediately: () async {
                      AppFeedback.light();
                      await context
                          .read<QuizDuelCubit>()
                          .matchWithAiImmediately();
                    },
                    onCancelSearch: () async {
                      isSearching.value = false;
                      activeRoomCode.value = null;
                      await context.read<QuizDuelCubit>().leaveMatch();
                    },
                    onQuickMatch: executeMatchmaking,
                    onQuickMatchWithAi: () async {
                      await executeMatchmaking();
                      if (context.mounted) {
                        await context
                            .read<QuizDuelCubit>()
                            .matchWithAiImmediately();
                      }
                    },
                    onStartRoomLobby: () => executeMatchmaking(
                      roomCode: generatedCode.value,
                    ),
                    onJoinRoomWithCode: () {
                      final code = enteredCodeController.text
                          .trim()
                          .toUpperCase();
                      if (code.isEmpty || code.length < 4) {
                        context.showSnackBar(
                          message: 'Please enter a valid room code.',
                        );
                        return;
                      }
                      unawaited(executeMatchmaking(roomCode: code));
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
