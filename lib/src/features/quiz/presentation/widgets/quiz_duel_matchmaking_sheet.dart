import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/quiz/data/client/quiz_duel_websocket_client.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_state.dart';
import 'package:kortex/src/features/quiz/presentation/pages/quiz_duel_arena_page.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_duel_elo_tier_badge.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_duel_leaderboard_sheet.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_liquid_glass_tab_bar.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

/// Modal bottom sheet for searching, creating rooms, entering codes, and joining 1v1 Quiz Duels (QZ-13).
class QuizDuelMatchmakingSheet extends HookWidget {
  const QuizDuelMatchmakingSheet({
    super.key,
    this.initialSubject = 'Physics',
    this.initialExamBoard = 'WAEC',
  });

  final String initialSubject;
  final String initialExamBoard;

  static Future<void> show(
    BuildContext context, {
    String initialSubject = 'Physics',
    String initialExamBoard = 'WAEC',
  }) {
    final colors = context.colors;
    final cubit = locator<QuizDuelCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.transparent,
      builder: (_) => BlocProvider<QuizDuelCubit>.value(
        value: cubit,
        child: QuizDuelMatchmakingSheet(
          initialSubject: initialSubject,
          initialExamBoard: initialExamBoard,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final activeTab = useState<int>(0); // 0: Quick Match, 1: Invite with Code, 2: Join with Code
    final selectedSubject = useState<String>(initialSubject);
    final selectedQuestionCount = useState<int>(10);
    final isSearching = useState<bool>(false);
    final searchSeconds = useState<int>(0);
    final activeRoomCode = useState<String?>(null);

    final generatedCode = useState<String>(QuizDuelWebSocketClient.generateRoomCode());
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

    // Resolve exam board / standard directly from user's active profile track
    final authBloc = locator.isRegistered<AuthBloc>()
        ? locator<AuthBloc>()
        : null;
    final userTrack = authBloc?.state.userProfile?.targetTrack;
    final resolvedExamBoard = (userTrack != null && userTrack.isNotEmpty)
        ? userTrack
        : initialExamBoard;

    // Resolve subjects strictly from user's registered courses and active study decks
    final dashboardBloc = locator.isRegistered<DashboardBloc>()
        ? locator<DashboardBloc>()
        : null;
    final curatedCourses =
        dashboardBloc?.state.feed?.curatedCourses
            .map((c) => c.title.trim())
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList() ??
        [];

    final decksBloc = locator.isRegistered<DecksBloc>()
        ? locator<DecksBloc>()
        : null;
    final deckSubjects =
        decksBloc?.state.allDecks
            .map((d) => d.subject.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList() ??
        [];

    final userRegisteredCourses = {...curatedCourses, ...deckSubjects}.toList();

    final subjects = userRegisteredCourses.isNotEmpty
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

    final questionCounts = [5, 10, 15];

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
        }
      },
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 640,
            maxHeight: MediaQuery.sizeOf(context).height * 0.90,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.dialog),
              ),
              border: Border.all(
                color: colors.surfaceBorder.withValues(alpha: 0.5),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header section (Drag handle + Title + ELO Badge)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colors.textSecondary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(AppRadius.micro),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Title & ELO Banner Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [colors.primary, colors.secondary],
                                ),
                                borderRadius: BorderRadius.circular(AppRadius.card),
                              ),
                              child: Icon(
                                Icons.flash_on_rounded,
                                color: colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '1v1 Academic Duel',
                                          style: typography.title2.bold.copyWith(
                                            color: colors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () => QuizDuelLeaderboardSheet.show(context),
                                        child: QuizDuelEloTierBadge(
                                          elo: userElo,
                                          compact: true,
                                          showXpBonus: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Real-time battle of speed and academic mastery.',
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Mode Segment Switcher (only when not actively searching)
                  if (!isSearching.value) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AppLiquidGlassTabBar(
                        tabs: const ['Quick Match', 'Invite Friend', 'Enter Code'],
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isSearching.value) ...[
                            // Active Matchmaking Radar View
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Column(
                                  children: [
                                    AnimatedBuilder(
                                      animation: pulseController,
                                      builder: (context, child) {
                                        return Container(
                                          width: 96 + (pulseController.value * 18),
                                          height: 96 + (pulseController.value * 18),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: colors.primary.withValues(
                                              alpha: (0.12 - (pulseController.value * 0.08)).clamp(0.0, 1.0),
                                            ),
                                            border: Border.all(
                                              color: colors.primary.withValues(
                                                alpha: (0.4 + (pulseController.value * 0.4)).clamp(0.0, 1.0),
                                              ),
                                              width: 2.5,
                                            ),
                                          ),
                                          child: Center(
                                            child: Container(
                                              width: 62,
                                              height: 62,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: colors.primary,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: colors.black.withValues(
                                                      alpha: isDark ? 0.4 : 0.15,
                                                    ),
                                                    blurRadius: 16,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  activeRoomCode.value != null
                                                      ? Icons.vpn_key_rounded
                                                      : Icons.radar_rounded,
                                                  color: colors.white,
                                                  size: 30,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    if (activeRoomCode.value != null) ...[
                                      // Private Room Active Display
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(AppRadius.card),
                                          border: Border.all(
                                            color: colors.primary.withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'ROOM CODE: ',
                                              style: typography.caption.bold.copyWith(
                                                color: colors.textSecondary,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                            Text(
                                              activeRoomCode.value!,
                                              style: typography.title2.bold.copyWith(
                                                color: colors.primary,
                                                letterSpacing: 3,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () => copyCodeToClipboard(activeRoomCode.value!),
                                              child: Icon(
                                                Icons.copy_rounded,
                                                color: colors.primary,
                                                size: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Waiting for friend to join with code...',
                                        style: typography.body.bold.copyWith(
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Share this 6-character code with your study partner to connect!',
                                        textAlign: TextAlign.center,
                                        style: typography.caption.regular.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: () => shareInviteWithFriend(activeRoomCode.value!),
                                        icon: const Icon(Icons.share_rounded, size: 16),
                                        label: const Text('Share Code & Invite'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: colors.primary,
                                          side: BorderSide(color: colors.primary.withValues(alpha: 0.5)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(AppRadius.badge),
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      // Public Quick Match Active Display
                                      Text(
                                        searchSeconds.value < 4
                                            ? 'Scanning online scholars in ${selectedSubject.value}…'
                                            : searchSeconds.value < 8
                                                ? 'Expanding campus matchmaking radius…'
                                                : searchSeconds.value < 12
                                                    ? 'Rival found! Synchronizing exam room…'
                                                    : 'Connecting with AI study-buddy…',
                                        style: typography.title3.bold.copyWith(
                                          color: colors.textPrimary,
                                          fontSize: 15,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${selectedSubject.value} ($resolvedExamBoard) • ${selectedQuestionCount.value} Questions\nInstant match in ~12 seconds',
                                        textAlign: TextAlign.center,
                                        style: typography.caption.regular.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ] else if (activeTab.value == 0) ...[
                            // TAB 0: QUICK MATCH
                            Text(
                              'Subject',
                              style: typography.caption.bold.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: subjects.map((sub) {
                                final isSelected = selectedSubject.value == sub;
                                return ChoiceChip(
                                  label: Text(sub),
                                  selected: isSelected,
                                  selectedColor: colors.primary.withValues(alpha: 0.2),
                                  backgroundColor: colors.surfaceSecondary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.badge),
                                    side: BorderSide(
                                      color: isSelected
                                          ? colors.primary.withValues(alpha: 0.4)
                                          : colors.surfaceBorder.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  labelStyle: context.typography.body.regular.copyWith(
                                    color: isSelected ? colors.primary : colors.textPrimary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  onSelected: (val) {
                                    if (val) {
                                      AppFeedback.selection();
                                      selectedSubject.value = sub;
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            Text(
                              'Questions',
                              style: typography.caption.bold.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: questionCounts.map((count) {
                                final isSelected = selectedQuestionCount.value == count;
                                return ChoiceChip(
                                  label: Text('$count questions${count == 10 ? ' (standard)' : ''}'),
                                  selected: isSelected,
                                  selectedColor: colors.primary.withValues(alpha: 0.2),
                                  backgroundColor: colors.surfaceSecondary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.badge),
                                    side: BorderSide(
                                      color: isSelected
                                          ? colors.primary.withValues(alpha: 0.4)
                                          : colors.surfaceBorder.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  labelStyle: context.typography.body.regular.copyWith(
                                    color: isSelected ? colors.primary : colors.textPrimary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  onSelected: (val) {
                                    if (val) {
                                      AppFeedback.selection();
                                      selectedQuestionCount.value = count;
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            // Match Rule Highlight
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.surfaceSecondary.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(AppRadius.card),
                                border: Border.all(
                                  color: colors.surfaceBorder.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.bolt_rounded,
                                    size: 20,
                                    color: colors.warning,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${selectedQuestionCount.value} questions • 15s adaptive timer • Faster answers earn up to +50 speed bonus.',
                                      style: typography.caption.regular.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (activeTab.value == 1) ...[
                            // TAB 1: INVITE FRIEND (DISPLAY ROOM CODE)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                                    colors.secondary.withValues(alpha: isDark ? 0.15 : 0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(AppRadius.panel),
                                border: Border.all(
                                  color: colors.primary.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.vpn_key_rounded,
                                        color: colors.primary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'YOUR PRIVATE DUEL CODE',
                                        style: typography.caption.bold.copyWith(
                                          color: colors.primary,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Big Room Code Display
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark ? colors.surfacePrimary : colors.white,
                                      borderRadius: BorderRadius.circular(AppRadius.card),
                                      border: Border.all(
                                        color: colors.primary.withValues(alpha: 0.5),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colors.primary.withValues(alpha: 0.15),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          generatedCode.value,
                                          style: typography.largeTitle.bold.copyWith(
                                            color: colors.primary,
                                            letterSpacing: 4.5,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        IconButton(
                                          icon: const Icon(Icons.copy_rounded),
                                          color: colors.primary,
                                          tooltip: 'Copy Code',
                                          onPressed: () => copyCodeToClipboard(generatedCode.value),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Tell your classmate to open "Enter Code" and type this code.',
                                    textAlign: TextAlign.center,
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () {
                                          AppFeedback.light();
                                          generatedCode.value =
                                              QuizDuelWebSocketClient.generateRoomCode();
                                        },
                                        icon: const Icon(Icons.refresh_rounded, size: 16),
                                        label: const Text('Generate New Code'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () => shareInviteWithFriend(generatedCode.value),
                                        icon: const Icon(Icons.share_rounded, size: 16),
                                        label: const Text('Share Code'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: colors.primary,
                                          foregroundColor: colors.white,
                                          elevation: 0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Subject Selection for Room
                            Text(
                              'Room Subject: ${selectedSubject.value}',
                              style: typography.caption.bold.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: subjects.map((sub) {
                                final isSelected = selectedSubject.value == sub;
                                return ChoiceChip(
                                  label: Text(sub),
                                  selected: isSelected,
                                  selectedColor: colors.primary.withValues(alpha: 0.2),
                                  backgroundColor: colors.surfaceSecondary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.badge),
                                    side: BorderSide(
                                      color: isSelected
                                          ? colors.primary.withValues(alpha: 0.4)
                                          : colors.surfaceBorder.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  onSelected: (val) {
                                    if (val) {
                                      AppFeedback.selection();
                                      selectedSubject.value = sub;
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                          ] else ...[
                            // TAB 2: ENTER ROOM CODE (JOIN WITH CODE)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colors.surfaceSecondary.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(AppRadius.panel),
                                border: Border.all(
                                  color: colors.surfaceBorder.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.pin_rounded,
                                        color: colors.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'ENTER 6-DIGIT ROOM CODE',
                                        style: typography.caption.bold.copyWith(
                                          color: colors.primary,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  AppTextField(
                                    controller: enteredCodeController,
                                    hintText: 'e.g. K9X7P2',
                                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                                    textCapitalization: TextCapitalization.characters,
                                    maxLength: 6,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Enter the code your friend shared to jump directly into their duel arena.',
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Fixed Bottom Action Bar
                  Padding(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 10,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                    ),
                    child: isSearching.value
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppButton(
                                text: 'Practice with AI now',
                                onPressed: () async {
                                  AppFeedback.light();
                                  await context
                                      .read<QuizDuelCubit>()
                                      .matchWithAiImmediately();
                                },
                              ),
                              const SizedBox(height: 8),
                              AppButton(
                                text: 'Cancel search',
                                variant: AppButtonVariant.secondary,
                                onPressed: () async {
                                  isSearching.value = false;
                                  activeRoomCode.value = null;
                                  await context.read<QuizDuelCubit>().leaveMatch();
                                },
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (activeTab.value == 0) ...[
                                AppButton(
                                  text: 'Find a classmate',
                                  onPressed: executeMatchmaking,
                                ),
                                const SizedBox(height: 8),
                                AppButton(
                                  text: 'Practice Solo with AI',
                                  variant: AppButtonVariant.secondary,
                                  onPressed: () async {
                                    await executeMatchmaking();
                                    if (context.mounted) {
                                      await context
                                          .read<QuizDuelCubit>()
                                          .matchWithAiImmediately();
                                    }
                                  },
                                ),
                              ] else if (activeTab.value == 1) ...[
                                AppButton(
                                  text: 'Start Room Lobby (${generatedCode.value})',
                                  onPressed: () => executeMatchmaking(
                                    roomCode: generatedCode.value,
                                  ),
                                ),
                              ] else ...[
                                AppButton(
                                  text: 'Join Duel Room',
                                  onPressed: () {
                                    final code = enteredCodeController.text.trim().toUpperCase();
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
                            ],
                          ),
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
