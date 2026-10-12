import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/notification_service.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/features/planner/domain/repositories/planner_repository.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_state.dart';
import 'package:kortex/src/features/planner/presentation/widgets/manage_exam_modal_sheet.dart';
import 'package:kortex/src/features/planner/presentation/widgets/study_calibration_graph_widget.dart';
import 'package:kortex/src/features/planner/presentation/widgets/timetable/exam_timetable_deck_association_sheet.dart';
import 'package:kortex/src/features/planner/presentation/widgets/timetable/exam_timetable_delete_dialog.dart';
import 'package:kortex/src/features/planner/presentation/widgets/timetable/exam_timetable_empty_state.dart';
import 'package:kortex/src/features/planner/presentation/widgets/timetable/exam_timetable_filter_bar.dart';
import 'package:kortex/src/features/planner/presentation/widgets/timetable/exam_timetable_hero_countdown_card.dart';
import 'package:kortex/src/features/planner/presentation/widgets/timetable/exam_timetable_ical_exporter.dart';
import 'package:kortex/src/features/planner/presentation/widgets/timetable/exam_timetable_notification_preferences_card.dart';
import 'package:kortex/src/features/planner/presentation/widgets/timetable/exam_timetable_row_card.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';

@RoutePage()
class ExamTimetablePage extends StatefulWidget {
  const ExamTimetablePage({
    super.key,
    this.cramPlannerCubit,
    this.localStorageService,
    this.notificationService,
    this.decksBloc,
  });

  final CramPlannerCubit? cramPlannerCubit;
  final LocalStorageService? localStorageService;
  final NotificationService? notificationService;
  final DecksBloc? decksBloc;

  @override
  State<ExamTimetablePage> createState() => _ExamTimetablePageState();
}

class _ExamTimetablePageState extends State<ExamTimetablePage> {
  static const String _dailyReminderKey = '__kortex_daily_exam_reminders__';
  static const String _milestoneAlertsKey = '__kortex_milestone_exam_alerts__';
  static const _calculator = CramWorkloadCalculator();

  late final LocalStorageService? _storageService;
  late final NotificationService? _notificationService;
  late final DecksBloc? _decksBloc;
  late final CramPlannerCubit _cramPlannerCubit;

  bool _dailyReminderEnabled = true;
  bool _milestoneAlertsEnabled = true;
  AssessmentType? _selectedFilterType;
  bool _showCompletedOnly = false;

  @override
  void initState() {
    super.initState();
    _storageService = widget.localStorageService ??
        (locator.isRegistered<LocalStorageService>()
            ? locator<LocalStorageService>()
            : null);
    _notificationService = widget.notificationService ??
        (locator.isRegistered<NotificationService>()
            ? locator<NotificationService>()
            : null);
    _decksBloc = widget.decksBloc ??
        (locator.isRegistered<DecksBloc>()
            ? locator<DecksBloc>()
            : null);
    _cramPlannerCubit = widget.cramPlannerCubit ??
        (locator.isRegistered<CramPlannerCubit>()
            ? locator<CramPlannerCubit>()
            : CramPlannerCubit(
                plannerRepository: locator<PlannerRepository>(),
              ));

    _loadNotificationPreferences();
    unawaited(_cramPlannerCubit.loadExams());
  }

  void _loadNotificationPreferences() {
    try {
      if (_storageService != null) {
        final dailyPref = _storageService.getPreference(key: _dailyReminderKey);
        final milestonePref =
            _storageService.getPreference(key: _milestoneAlertsKey);
        setState(() {
          _dailyReminderEnabled = dailyPref == null || dailyPref == 'true';
          _milestoneAlertsEnabled =
              milestonePref == null || milestonePref == 'true';
        });
      }
    } on Object catch (e, st) {
      AppLogger.recordNonFatal(e, st);
    }
  }

  Future<void> _setDailyReminder(bool enabled) async {
    setState(() => _dailyReminderEnabled = enabled);
    AppFeedback.selection();
    try {
      if (_storageService != null) {
        await _storageService.savePreference(
          key: _dailyReminderKey,
          data: enabled.toString(),
        );
      }
      if (!enabled &&
          !_milestoneAlertsEnabled &&
          _notificationService != null) {
        unawaited(_notificationService.cancelAllNotifications());
      }
    } on Object catch (e, st) {
      AppLogger.recordNonFatal(e, st);
    }
  }

  Future<void> _setMilestoneAlerts(bool enabled) async {
    setState(() => _milestoneAlertsEnabled = enabled);
    AppFeedback.selection();
    try {
      if (_storageService != null) {
        await _storageService.savePreference(
          key: _milestoneAlertsKey,
          data: enabled.toString(),
        );
      }
      if (!enabled &&
          !_dailyReminderEnabled &&
          _notificationService != null) {
        unawaited(_notificationService.cancelAllNotifications());
      }
    } on Object catch (e, st) {
      AppLogger.recordNonFatal(e, st);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ExamEventEntity exam,
  ) async {
    final confirmed = await ExamTimetableDeleteDialog.show(context, exam);
    if (confirmed == true && context.mounted) {
      unawaited(_cramPlannerCubit.deleteExamCountdown(exam.id));
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
    final allDecks = _decksBloc?.state.allDecks ?? const <DeckEntity>[];
    if (allDecks.isEmpty) return null;
    final firstId = exam.scopedDeckIds.first;
    final match = allDecks.where((d) => d.id == firstId).toList();
    if (match.isEmpty) return null;
    final d = match.first;
    final masteryPct = (d.masteryRate * 100).toInt();
    return '${d.title} (${d.totalCards} cards • $masteryPct% mastery)';
  }

  void _openDeckSelector(BuildContext context, ExamEventEntity exam) {
    AppFeedback.selection();
    final allDecks = _decksBloc?.state.allDecks ?? const <DeckEntity>[];
    if (allDecks.isNotEmpty) {
      ExamTimetableDeckAssociationSheet.showDeckPickerModal(
        context: context,
        exam: exam,
        decks: allDecks,
        onSelectDeck: (deck) => _onDeckSelected(context, exam, deck),
      );
    } else {
      ExamTimetableDeckAssociationSheet.showNoDecksModal(context, exam);
    }
  }

  void _onDeckSelected(
    BuildContext context,
    ExamEventEntity exam,
    DeckEntity deck,
  ) {
    unawaited(
      _cramPlannerCubit.updateExamCountdown(
        examId: exam.id,
        examName: exam.examName,
        targetDate: exam.targetDate,
        subjectTrack: exam.subjectTrack,
        assessmentType: exam.assessmentType,
        scopedDeckIds: [deck.id],
        totalCardsCount: deck.totalCards,
        masteredCardsCount: (deck.totalCards * deck.masteryRate).round(),
        totalLapses: deck.dueCards,
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
    final allDecks = _decksBloc?.state.allDecks ?? const <DeckEntity>[];
    if (allDecks.isNotEmpty) {
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
                    d.subject
                        .toLowerCase()
                        .contains(exam.subjectTrack.toLowerCase())));
        return hasCommon || directSubstring;
      }).toList();

      if (matching.isNotEmpty) {
        final chosenDeck = matching.first;
        _onDeckSelected(context, exam, chosenDeck);
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
      _openDeckSelector(context, exam);
      return;
    }

    // 3. Fallback: prompt to create deck or run practice mock
    ExamTimetableDeckAssociationSheet.showNoDecksModal(context, exam);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return BlocProvider<CramPlannerCubit>.value(
      value: _cramPlannerCubit,
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: colors.backgroundPrimary,
            appBar: AppAdaptiveAppBar(
              backgroundColor: colors.backgroundPrimary,
              breadcrumbs: [
                AppBreadcrumbItem(
                  label: 'Dashboard',
                  onTap: () {
                    if (context.router.canPop()) {
                      context.router.pop();
                    }
                  },
                ),
                const AppBreadcrumbItem(
                  label: 'Exam Timetable',
                ),
              ],
              titleText: 'Exam Timetable',
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.calendar_month_outlined,
                    color: colors.primary,
                  ),
                  tooltip: 'Export iCal Timetable (.ics)',
                  onPressed: () {
                    final state = context.read<CramPlannerCubit>().state;
                    ExamTimetableIcalExporter.exportToClipboard(
                      context,
                      state.activeExams,
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.add_circle_outline_rounded,
                    color: colors.primary,
                  ),
                  tooltip: 'Add Assessment',
                  onPressed: () => context.router.push(
                    AddAcademicAssessmentRoute(),
                  ),
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
                    final primaryExam = state.selectedExam ??
                        (allExams.isNotEmpty ? allExams.first : null);

                    if (allExams.isEmpty) {
                      return const ExamTimetableEmptyState();
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
                          ExamTimetableHeroCountdownCard(exam: primaryExam),
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
                        ExamTimetableFilterBar(
                          allExams: allExams,
                          selectedFilterType: _selectedFilterType,
                          showCompletedOnly: _showCompletedOnly,
                          onFilterChanged: ({
                            required selectedFilterType,
                            required showCompletedOnly,
                          }) {
                            setState(() {
                              _selectedFilterType = selectedFilterType;
                              _showCompletedOnly = showCompletedOnly;
                            });
                          },
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
                              onPressed: () => context.router.push(
                                AddAcademicAssessmentRoute(),
                              ),
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
                            (entry) => ExamTimetableRowCard(
                              exam: entry.value,
                              index: entry.key,
                              isSelected: entry.value.id == primaryExam?.id,
                              calculator: _calculator,
                              onSelect: () {
                                _cramPlannerCubit.selectExam(entry.value.id);
                              },
                              onEdit: () => context.router.push(
                                AddAcademicAssessmentRoute(
                                  initialExam: entry.value,
                                ),
                              ),
                              onDelete: () =>
                                  _confirmDelete(context, entry.value),
                              onPrimaryAction: () =>
                                  _onPrimaryAction(context, entry.value),
                            ),
                          ),

                        const SizedBox(height: 28),

                        // Notification Preferences Section
                        ExamTimetableNotificationPreferencesCard(
                          dailyReminderEnabled: _dailyReminderEnabled,
                          milestoneAlertsEnabled: _milestoneAlertsEnabled,
                          onDailyReminderChanged: _setDailyReminder,
                          onMilestoneAlertsChanged: _setMilestoneAlerts,
                        ),

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
}
