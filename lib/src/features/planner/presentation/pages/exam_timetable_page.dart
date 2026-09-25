import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/notification_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_state.dart';
import 'package:kortex/src/features/planner/presentation/widgets/add_exam_modal_sheet.dart';
import 'package:kortex/src/features/planner/presentation/widgets/manage_exam_modal_sheet.dart';
import 'package:kortex/src/features/planner/presentation/widgets/study_calibration_graph_widget.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_back_button.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

@RoutePage()
class ExamTimetablePage extends StatefulWidget {
  const ExamTimetablePage({super.key});

  @override
  State<ExamTimetablePage> createState() => _ExamTimetablePageState();
}

class _ExamTimetablePageState extends State<ExamTimetablePage> {
  static const String _dailyReminderKey = '__kortex_daily_exam_reminders__';
  static const String _milestoneAlertsKey = '__kortex_milestone_exam_alerts__';
  static const _calculator = CramWorkloadCalculator();

  bool _dailyReminderEnabled = true;
  bool _milestoneAlertsEnabled = true;
  AssessmentType? _selectedFilterType;
  bool _showCompletedOnly = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
  }

  void _loadNotificationPreferences() {
    try {
      if (locator.isRegistered<LocalStorageService>()) {
        final storage = locator<LocalStorageService>();
        final dailyPref = storage.getPreference(key: _dailyReminderKey);
        final milestonePref = storage.getPreference(key: _milestoneAlertsKey);
        setState(() {
          _dailyReminderEnabled = dailyPref == null || dailyPref == 'true';
          _milestoneAlertsEnabled =
              milestonePref == null || milestonePref == 'true';
        });
      }
    } on Object catch (_) {}
  }

  Future<void> _setDailyReminder(bool enabled) async {
    setState(() => _dailyReminderEnabled = enabled);
    AppFeedback.selection();
    try {
      if (locator.isRegistered<LocalStorageService>()) {
        await locator<LocalStorageService>().savePreference(
          key: _dailyReminderKey,
          data: enabled.toString(),
        );
      }
      if (!enabled &&
          !_milestoneAlertsEnabled &&
          locator.isRegistered<NotificationService>()) {
        unawaited(locator<NotificationService>().cancelAllNotifications());
      }
    } on Object catch (_) {}
  }

  Future<void> _setMilestoneAlerts(bool enabled) async {
    setState(() => _milestoneAlertsEnabled = enabled);
    AppFeedback.selection();
    try {
      if (locator.isRegistered<LocalStorageService>()) {
        await locator<LocalStorageService>().savePreference(
          key: _milestoneAlertsKey,
          data: enabled.toString(),
        );
      }
      if (!enabled &&
          !_dailyReminderEnabled &&
          locator.isRegistered<NotificationService>()) {
        unawaited(locator<NotificationService>().cancelAllNotifications());
      }
    } on Object catch (_) {}
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ExamEventEntity exam,
  ) async {
    final colors = context.colors;
    final typography = context.typography;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.isDarkMode
            ? colors.surfaceSecondary
            : colors.surfacePrimary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusDialog),
        title: Text(
          'Delete Assessment Countdown?',
          style: typography.headline.bold.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove "${exam.examName}" from your academic timetable? This action cannot be undone.',
          style: typography.body.regular.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: typography.body.bold.copyWith(color: colors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.radiusCard,
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.plannerDeleteAssessment),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      unawaited(context.read<CramPlannerCubit>().deleteExamCountdown(exam.id));
    }
  }

  void _onPrimaryAction(BuildContext context, ExamEventEntity exam) {
    AppFeedback.selection();
    if (exam.assessmentType == AssessmentType.quiz &&
        exam.scopedDeckIds.isNotEmpty) {
      final deckTarget = exam.daysRemaining <= 14 && exam.daysRemaining > 0
          ? 'cram:${exam.daysRemaining}:${exam.scopedDeckIds.first}'
          : exam.scopedDeckIds.first;
      unawaited(
        context.router.push(
          StudySessionRoute(deckId: deckTarget),
        ),
      );
      return;
    }

    unawaited(
      context.router.push(
        MockExamLobbyRoute(
          examId: exam.id,
          examName: exam.examName,
          subjectTrack: exam.subjectTrack,
        ),
      ),
    );
  }

  String? _getLinkedDeckTitle(ExamEventEntity exam) {
    if (exam.scopedDeckIds.isEmpty) return null;
    if (!locator.isRegistered<DecksBloc>()) return null;
    final allDecks = locator<DecksBloc>().state.allDecks;
    final firstId = exam.scopedDeckIds.first;
    final match = allDecks.where((d) => d.id == firstId).toList();
    if (match.isEmpty) return null;
    final d = match.first;
    final masteryPct = (d.masteryRate * 100).toInt();
    return '${d.title} (${d.totalCards} cards • $masteryPct% mastery)';
  }

  void _openDeckSelector(BuildContext context, ExamEventEntity exam) {
    AppFeedback.selection();
    final allDecks = locator.isRegistered<DecksBloc>()
        ? locator<DecksBloc>().state.allDecks
        : const <DeckEntity>[];
    if (allDecks.isNotEmpty) {
      _showDeckPickerModal(context, exam, allDecks);
    } else {
      _showNoDecksModal(context, exam);
    }
  }

  void _showNoDecksModal(BuildContext context, ExamEventEntity exam) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: colors.transparent,
        builder: (sheetCtx) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Flashcard Decks Yet',
                style: typography.headline.bold.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'To calibrate your study pace with real memory mastery, create flashcards for "${exam.examName}" or practice mock questions directly.',
                style: typography.body.regular.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  unawaited(
                    context.navigateTo(
                      const MainRoute(children: [DecksRoute()]),
                    ),
                  );
                },
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: Text(context.l10n.plannerCreateStudyDeck),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  unawaited(
                    context.router.push(
                      MockExamLobbyRoute(
                        examId: exam.id,
                        examName: exam.examName,
                        subjectTrack: exam.subjectTrack,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.school_outlined),
                label: Text(context.l10n.plannerStartDiagnosticMock),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onStartCalibrationStudy(BuildContext context, ExamEventEntity exam) {
    AppFeedback.selection();

    // 1. Direct launch if the exam has scoped decks
    if (exam.scopedDeckIds.isNotEmpty) {
      final deckId = exam.scopedDeckIds.first;
      final deckTarget = exam.daysRemaining <= 14 && exam.daysRemaining > 0
          ? 'cram:${exam.daysRemaining}:$deckId'
          : deckId;
      unawaited(
        context.router.push(
          StudySessionRoute(deckId: deckTarget),
        ),
      );
      return;
    }

    // 2. Check if DecksBloc has matching decks by courseCode, subject, or title
    if (locator.isRegistered<DecksBloc>()) {
      final allDecks = locator<DecksBloc>().state.allDecks;
      final examText = '${exam.subjectTrack} ${exam.examName}'.toLowerCase();
      final examTokens = RegExp('[a-zA-Z0-9]+')
          .allMatches(examText)
          .map((m) => m.group(0)!)
          .where((t) =>
              t.length >= 2 &&
              !const {
                'exam',
                'test',
                'final',
                'midterm',
                'the',
                'and',
                'for',
                'course',
                'academic',
              }.contains(t))
          .toSet();

      final matching = allDecks.where((d) {
        final deckText =
            '${d.courseCode ?? ""} ${d.subject} ${d.title}'.toLowerCase();
        final deckTokens = RegExp('[a-zA-Z0-9]+')
            .allMatches(deckText)
            .map((m) => m.group(0)!)
            .where((t) =>
                t.length >= 2 &&
                !const {
                  'exam',
                  'test',
                  'final',
                  'midterm',
                  'the',
                  'and',
                  'for',
                  'course',
                  'academic',
                }.contains(t))
            .toSet();

        final hasCommon = examTokens.any(deckTokens.contains);
        final directSubstring = (d.courseCode != null &&
                d.courseCode!.isNotEmpty &&
                examText.contains(d.courseCode!.toLowerCase())) ||
            (d.subject.isNotEmpty &&
                (examText.contains(d.subject.toLowerCase()) ||
                    d.subject.toLowerCase().contains(exam.subjectTrack.toLowerCase())));
        return hasCommon || directSubstring;
      }).toList();

      if (matching.isNotEmpty) {
        final chosenDeck = matching.first;
        unawaited(
          context.read<CramPlannerCubit>().updateExamCountdown(
                examId: exam.id,
                examName: exam.examName,
                targetDate: exam.targetDate,
                subjectTrack: exam.subjectTrack,
                assessmentType: exam.assessmentType,
                scopedDeckIds: [chosenDeck.id],
                totalCardsCount: chosenDeck.totalCards,
                masteredCardsCount:
                    (chosenDeck.totalCards * chosenDeck.masteryRate).round(),
                totalLapses: chosenDeck.dueCards,
              ),
        );
        final deckTarget = exam.daysRemaining <= 14 && exam.daysRemaining > 0
            ? 'cram:${exam.daysRemaining}:${chosenDeck.id}'
            : chosenDeck.id;
        unawaited(
          context.router.push(
            StudySessionRoute(deckId: deckTarget),
          ),
        );
        return;
      }

      // If user has other decks, show an interactive picker sheet
      if (allDecks.isNotEmpty) {
        _showDeckPickerModal(context, exam, allDecks);
        return;
      }
    }

    // 3. Fallback: prompt to create deck or run practice mock
    _showNoDecksModal(context, exam);
  }

  void _showDeckPickerModal(
    BuildContext context,
    ExamEventEntity exam,
    List<DeckEntity> decks,
  ) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: colors.transparent,
        builder: (sheetCtx) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7,
              maxWidth: 600,
            ),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: colors.surfaceBorder.withValues(
                  alpha: isDark ? 0.3 : 0.15,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Link Study Deck to ${exam.examName}',
                  style: typography.headline.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a flashcard deck to calibrate your daily study goal and track real mastery.',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: decks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final deck = decks[idx];
                      final isLinked = exam.scopedDeckIds.contains(deck.id);

                      return InkWell(
                        onTap: () {
                          Navigator.of(sheetCtx).pop();
                          AppFeedback.heavy();
                          unawaited(
                            context.read<CramPlannerCubit>().updateExamCountdown(
                                  examId: exam.id,
                                  examName: exam.examName,
                                  targetDate: exam.targetDate,
                                  subjectTrack: exam.subjectTrack,
                                  assessmentType: exam.assessmentType,
                                  scopedDeckIds: [deck.id],
                                  totalCardsCount: deck.totalCards,
                                  masteredCardsCount:
                                      (deck.totalCards * deck.masteryRate).round(),
                                  totalLapses: deck.dueCards,
                                ),
                          );
                          context.showSnackBar(
                            message: 'Linked "${deck.title}" to ${exam.examName}',
                            type: SnackBarType.success,
                          );
                          final deckTarget =
                              exam.daysRemaining <= 14 && exam.daysRemaining > 0
                                  ? 'cram:${exam.daysRemaining}:${deck.id}'
                                  : deck.id;
                          unawaited(
                            context.router.push(
                              StudySessionRoute(deckId: deckTarget),
                            ),
                          );
                        },
                        borderRadius: AppRadius.radiusCard,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isLinked
                                ? colors.primary.withValues(
                                    alpha: isDark ? 0.2 : 0.08,
                                  )
                                : colors.surfaceBorder.withValues(
                                    alpha: isDark ? 0.2 : 0.08,
                                  ),
                            borderRadius: AppRadius.radiusCard,
                            border: Border.all(
                              color: isLinked
                                  ? colors.primary.withValues(
                                      alpha: isDark ? 0.6 : 0.4,
                                    )
                                  : colors.surfaceBorder.withValues(
                                      alpha: isDark ? 0.4 : 0.2,
                                    ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.style_rounded,
                                  color: colors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      deck.title,
                                      style: typography.body.bold.copyWith(
                                        color: colors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${deck.totalCards} cards • ${(deck.masteryRate * 100).toInt()}% mastery',
                                      style: typography.caption.regular.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isLinked)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.success.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: colors.success.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_rounded,
                                        size: 13,
                                        color: colors.success,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Linked',
                                        style: typography.caption.bold.copyWith(
                                          color: colors.success,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: colors.textSecondary,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetCtx).pop();
                      unawaited(
                        context.navigateTo(
                          const MainRoute(children: [DecksRoute()]),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(context.l10n.plannerCreateNewDeck),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusCard,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final cubit = locator<CramPlannerCubit>();
    unawaited(cubit.loadExams());

    return BlocProvider<CramPlannerCubit>.value(
      value: cubit,
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: colors.backgroundPrimary,
            appBar: AppBar(
              backgroundColor: colors.backgroundPrimary,
              elevation: 0,
              leading: const AppBackButton(),
              title: Text(
                'Exam Timetable',
                style: typography.headline.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.add_circle_outline_rounded,
                    color: colors.primary,
                  ),
                  tooltip: 'Add Assessment',
                  onPressed: () => AddExamModalSheet.show(context),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: BlocBuilder<CramPlannerCubit, CramPlannerState>(
                  builder: (context, state) {
                    final allExams = state.activeExams;
                    final primaryExam =
                        state.selectedExam ??
                        (allExams.isNotEmpty ? allExams.first : null);

                    if (allExams.isEmpty) {
                      return _buildEmptyState(context);
                    }

                    // Filter assessments if filter chip selected
                    final filteredExams = _showCompletedOnly
                        ? allExams.where((e) => e.isCompleted).toList()
                        : (_selectedFilterType == null
                            ? allExams.where((e) => !e.isCompleted).toList()
                            : allExams
                                .where(
                                  (e) =>
                                      !e.isCompleted &&
                                      e.assessmentType == _selectedFilterType,
                                )
                                .toList());

                    return ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      children: [
                        // Hero Active Countdown Display
                        if (primaryExam != null) ...[
                          _buildHeroCountdownCard(context, primaryExam),
                          const SizedBox(height: 24),
                          StudyCalibrationGraphWidget(
                            exam: primaryExam,
                            linkedDeckTitle: _getLinkedDeckTitle(primaryExam),
                            onSelectDeck: () =>
                                _openDeckSelector(context, primaryExam),
                            onStartStudySession: () =>
                                _onStartCalibrationStudy(context, primaryExam),
                            onManageExam: () =>
                                ManageExamModalSheet.show(context),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Filter Chips Row
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip(
                                label:
                                    '${l10n.filterAll} (${allExams.where((e) => !e.isCompleted).length})',
                                isSelected:
                                    _selectedFilterType == null &&
                                    !_showCompletedOnly,
                                onSelected: () {
                                  AppFeedback.selection();
                                  setState(() {
                                    _selectedFilterType = null;
                                    _showCompletedOnly = false;
                                  });
                                },
                                colors: colors,
                              ),
                              const SizedBox(width: 6),
                              _buildFilterChip(
                                label:
                                    '${l10n.filterQuizzes} (${allExams.where((e) => !e.isCompleted && e.assessmentType == AssessmentType.quiz).length})',
                                isSelected:
                                    !_showCompletedOnly &&
                                    _selectedFilterType == AssessmentType.quiz,
                                onSelected: () {
                                  AppFeedback.selection();
                                  setState(() {
                                    _selectedFilterType = AssessmentType.quiz;
                                    _showCompletedOnly = false;
                                  });
                                },
                                colors: colors,
                              ),
                              const SizedBox(width: 6),
                              _buildFilterChip(
                                label:
                                    '${l10n.filterTests} (${allExams.where((e) => !e.isCompleted && e.assessmentType == AssessmentType.classTest).length})',
                                isSelected:
                                    !_showCompletedOnly &&
                                    _selectedFilterType ==
                                        AssessmentType.classTest,
                                onSelected: () {
                                  AppFeedback.selection();
                                  setState(() {
                                    _selectedFilterType =
                                        AssessmentType.classTest;
                                    _showCompletedOnly = false;
                                  });
                                },
                                colors: colors,
                              ),
                              const SizedBox(width: 6),
                              _buildFilterChip(
                                label:
                                    '${l10n.filterMidterms} (${allExams.where((e) => !e.isCompleted && e.assessmentType == AssessmentType.midterm).length})',
                                isSelected:
                                    !_showCompletedOnly &&
                                    _selectedFilterType ==
                                        AssessmentType.midterm,
                                onSelected: () {
                                  AppFeedback.selection();
                                  setState(() {
                                    _selectedFilterType =
                                        AssessmentType.midterm;
                                    _showCompletedOnly = false;
                                  });
                                },
                                colors: colors,
                              ),
                              const SizedBox(width: 6),
                              _buildFilterChip(
                                label:
                                    '${l10n.filterFinals} (${allExams.where((e) => !e.isCompleted && (e.assessmentType == AssessmentType.finalExam || e.assessmentType == AssessmentType.mockExam)).length})',
                                isSelected:
                                    !_showCompletedOnly &&
                                    _selectedFilterType ==
                                        AssessmentType.finalExam,
                                onSelected: () {
                                  AppFeedback.selection();
                                  setState(() {
                                    _selectedFilterType =
                                        AssessmentType.finalExam;
                                    _showCompletedOnly = false;
                                  });
                                },
                                colors: colors,
                              ),
                              const SizedBox(width: 6),
                              _buildFilterChip(
                                label:
                                    '${l10n.filterCompleted} (${allExams.where((e) => e.isCompleted).length})',
                                isSelected: _showCompletedOnly,
                                onSelected: () {
                                  AppFeedback.selection();
                                  setState(() {
                                    _showCompletedOnly = true;
                                    _selectedFilterType = null;
                                  });
                                },
                                colors: colors,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Section Heading
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Tracked Exams (${filteredExams.length})',
                                style: typography.title3.bold.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => AddExamModalSheet.show(context),
                              icon: Icon(
                                Icons.add,
                                size: 18,
                                color: colors.primary,
                              ),
                              label: Text(
                                'Add Exam',
                                style: typography.callout.bold.copyWith(
                                  color: colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Chronological Cards
                        if (filteredExams.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 36),
                            alignment: Alignment.center,
                            child: Text(
                              'No assessments found in this category',
                              style: typography.subhead.regular.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          )
                        else
                          ...filteredExams.asMap().entries.map(
                            (entry) => _buildExamRowCard(
                              context,
                              exam: entry.value,
                              index: entry.key,
                              isSelected: entry.value.id == primaryExam?.id,
                            ),
                          ),

                        const SizedBox(height: 28),

                        // Notification Preferences Section
                        _buildNotificationPreferencesCard(context, primaryExam),

                        const SizedBox(height: 40),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    required AppThemeColorsExtension colors,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: colors.primary,
      labelStyle: context.typography.caption.bold.copyWith(
        color: isSelected ? colors.white : colors.textSecondary,
        fontSize: 11.5,
      ),
      backgroundColor: colors.surfaceSecondary.withAlpha(80),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildHeroCountdownCard(BuildContext context, ExamEventEntity exam) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final days = exam.timeRemaining.inDays;
    final hours = exam.hoursRemaining;
    final minutes = exam.minutesRemaining;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            colors.primary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: AppRadius.radiusDialog,
        boxShadow: [
          BoxShadow(
            color: colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.white.withValues(alpha: 0.2),
                    borderRadius: AppRadius.radiusBadge,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(exam.assessmentType.icon, size: 13, color: colors.white),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${exam.assessmentType.displayName.toUpperCase()} • ${exam.subjectTrack.toUpperCase()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.caption.bold.copyWith(
                            color: colors.white,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (exam.weightPercent != null)
                Text(
                  '${(exam.weightPercent! * 100).toInt()}% OF GRADE',
                  style: typography.caption.bold.copyWith(
                    color: colors.white.withValues(alpha: 0.85),
                    letterSpacing: 1,
                  ),
                )
              else
                Text(
                  'ACTIVE TIMETABLE',
                  style: typography.caption.bold.copyWith(
                    color: colors.white.withValues(alpha: 0.8),
                    letterSpacing: 1.1,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            exam.examName,
            style: typography.title2.bold.copyWith(color: colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('EEEE, MMMM d, y • hh:mm a').format(exam.targetDate),
            style: typography.caption.regular.copyWith(
              color: colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 20),

          // Digits row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTimeDigit(days.toString(), 'DAYS', colors),
              Text(
                ':',
                style: typography.title1.bold.copyWith(
                  color: colors.white.withValues(alpha: 0.7),
                ),
              ),
              _buildTimeDigit(
                hours.toString().padLeft(2, '0'),
                'HOURS',
                colors,
              ),
              Text(
                ':',
                style: typography.title1.bold.copyWith(
                  color: colors.white.withValues(alpha: 0.7),
                ),
              ),
              _buildTimeDigit(
                minutes.toString().padLeft(2, '0'),
                'MINUTES',
                colors,
              ),
            ],
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 400.ms, curve: Curves.easeOut)
      .scale(
        begin: const Offset(0.95, 0.95),
        end: const Offset(1, 1),
        duration: 400.ms,
        curve: Curves.easeOutQuint,
      );
  }

  Widget _buildTimeDigit(
    String value,
    String label,
    AppThemeColorsExtension colors,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colors.white.withValues(alpha: 0.2),
            borderRadius: AppRadius.radiusCard,
          ),
          child: Text(
            value,
            style: context.typography.body.regular.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: context.typography.body.regular.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: colors.white.withValues(alpha: 0.7),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildExamRowCard(
    BuildContext context, {
    required ExamEventEntity exam,
    required int index,
    required bool isSelected,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final l10n = context.l10n;

    final formattedDate = DateFormat(
      'EEE, d MMM y • hh:mm a',
    ).format(exam.targetDate);

    final urgency = _calculator.getUrgencyLevel(
      exam.daysRemaining,
      type: exam.assessmentType,
    );
    final urgencyColor = switch (urgency) {
      ExamUrgencyLevel.normal => colors.primary,
      ExamUrgencyLevel.warning => colors.warning,
      ExamUrgencyLevel.critical => colors.error,
    };

    final actionLabel = switch (exam.assessmentType) {
      AssessmentType.quiz => l10n.actionPracticeScopedDecks,
      AssessmentType.classTest => l10n.actionStartTestReview,
      _ => l10n.actionOpenMockLobby,
    };

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return AnimatedContainer(
          duration: 160.ms,
          curve: Curves.easeOutQuint,
          transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: AppRadius.radiusPanel,
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : (isHovered
                        ? colors.primary.withValues(alpha: 0.5)
                        : colors.surfaceBorder.withValues(alpha: 0.6)),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: colors.black.withValues(
                        alpha: isDark ? 0.35 : 0.1,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Primary Selection Radio / Check
              InkWell(
                onTap: () {
                  context.read<CramPlannerCubit>().selectExam(exam.id);
                },
                borderRadius: AppRadius.radiusMicro,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.primary
                        : colors.surfaceSecondary.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? colors.primary : colors.textSecondary,
                    ),
                  ),
                  child: Icon(
                    Icons.check,
                    size: 14,
                    color: isSelected ? colors.white : colors.transparent,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Type Icon
              Icon(
                exam.assessmentType.icon,
                size: 18,
                color: urgencyColor,
              ),
              const SizedBox(width: 8),

              // Title and Subject
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            exam.examName,
                            style: typography.callout.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: urgencyColor.withValues(alpha: 0.12),
                            borderRadius: AppRadius.radiusBadge,
                          ),
                          child: Text(
                            exam.assessmentType.displayName,
                            style: typography.caption.bold.copyWith(
                              color: urgencyColor,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        if (exam.isCompleted) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.success.withValues(alpha: 0.15),
                              borderRadius: AppRadius.radiusBadge,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 10, color: colors.success),
                                const SizedBox(width: 3),
                                Text(
                                  exam.achievedScorePercent != null
                                      ? '${exam.achievedScorePercent!.toInt()}%'
                                      : 'Done',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.success,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Edit & Delete Actions
              PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: isHovered ? colors.primary : colors.textSecondary,
                    ),
                    tooltip: 'Edit Assessment',
                    onPressed: () =>
                        AddExamModalSheet.show(context, initialExam: exam),
                  );
                },
              ),
              PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: isHovered
                          ? colors.error
                          : colors.error.withValues(alpha: 0.7),
                    ),
                    tooltip: 'Delete Assessment',
                    onPressed: () => _confirmDelete(context, exam),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.radiusMicro,
                ),
                child: Text(
                  '${(exam.effectiveWeightPercent * 100).toInt()}% weight',
                  style: typography.caption.semiBold.copyWith(
                    color: colors.primary,
                    fontSize: 10.5,
                  ),
                ),
              ),
              if (exam.scopedTopics.isNotEmpty)
                ...exam.scopedTopics.take(3).map((topic) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.surfaceBorder.withValues(alpha: 0.3),
                        borderRadius: AppRadius.radiusMicro,
                      ),
                      child: Text(
                        topic,
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                    )),
              if (exam.scopedTopics.length > 3)
                Text(
                  '+${exam.scopedTopics.length - 3} more',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
              if (exam.scopedTopics.isEmpty && exam.scopedDeckIds.isNotEmpty)
                Text(
                  '${exam.scopedDeckIds.length} scoped decks',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Progress and Countdown Strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                exam.isCompleted
                    ? 'Completed'
                    : exam.formattedSubDailyCountdown,
                style: typography.caption.bold.copyWith(
                  color: exam.isCompleted
                      ? colors.success
                      : (exam.isPast ? colors.textSecondary : urgencyColor),
                ),
              ),
              Text(
                '${exam.masteredCardsCount}/${exam.totalCardsCount} cards (${(exam.completionProgress * 100).toInt()}%)',
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: AppRadius.radiusMicro,
            child: LinearProgressIndicator(
              value: exam.completionProgress,
              backgroundColor: colors.surfaceBorder.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation<Color>(
                isSelected
                    ? colors.primary
                    : colors.primary.withValues(alpha: 0.7),
              ),
              minHeight: 5,
            ),
          ),

          const SizedBox(height: 12),

          // Primary CTA Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _onPrimaryAction(context, exam),
              icon: Icon(
                exam.assessmentType == AssessmentType.quiz
                    ? Icons.bolt_rounded
                    : Icons.play_arrow_rounded,
                size: 15,
                color: colors.primary,
              ),
              label: Text(actionLabel),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                side: BorderSide(color: colors.primary.withAlpha(120)),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.radiusCard,
                ),
                textStyle: typography.caption.bold.copyWith(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: (index * 60).ms)
      .fadeIn(duration: 250.ms, curve: Curves.easeOut)
      .slideY(begin: 0.05, end: 0, duration: 250.ms, curve: Curves.easeOutQuint);
  }

  Widget _buildNotificationPreferencesCard(
    BuildContext context,
    ExamEventEntity? exam,
  ) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: AppRadius.radiusDialog,
        border: Border.all(
          color: colors.surfaceBorder.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active_rounded,
                color: colors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Timetable & Study Alerts',
                style: typography.callout.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Keep your preparation on track with automated reminders.',
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Daily Prep Reminders',
              style: typography.body.semiBold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Receive daily pacing reminders based on your workload targets.',
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
              ),
            ),
            value: _dailyReminderEnabled,
            activeTrackColor: colors.primary,
            onChanged: _setDailyReminder,
          ),
          const Divider(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Milestone Countdown Alerts',
              style: typography.body.semiBold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Get notified at 30-day, 14-day, 7-day, and 24-hour milestones.',
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
              ),
            ),
            value: _milestoneAlertsEnabled,
            activeTrackColor: colors.primary,
            onChanged: _setMilestoneAlerts,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_note_rounded,
                size: 40,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Exams Scheduled Yet',
              style: typography.title2.bold.copyWith(color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add quizzes, mid-term exams, or final exams to track your deadlines, calculate daily pacing targets, and stay calibrated.',
              style: typography.body.regular.copyWith(
                color: colors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            AppButton(
              text: 'Add First Exam',
              onPressed: () => AddExamModalSheet.show(context),
            ),
          ],
        ),
      ),
    );
  }
}
