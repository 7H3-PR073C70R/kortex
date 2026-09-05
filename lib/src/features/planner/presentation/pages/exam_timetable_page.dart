import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/notification_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_state.dart';
import 'package:kortex/src/features/planner/presentation/widgets/add_exam_modal_sheet.dart';
import 'package:kortex/src/features/planner/presentation/widgets/study_calibration_graph_widget.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

@RoutePage()
class ExamTimetablePage extends StatefulWidget {
  const ExamTimetablePage({super.key});

  @override
  State<ExamTimetablePage> createState() => _ExamTimetablePageState();
}

class _ExamTimetablePageState extends State<ExamTimetablePage> {
  bool _dailyReminderEnabled = true;
  bool _milestoneAlertsEnabled = true;

  void _testNotification(ExamEventEntity? exam) {
    if (exam == null) return;
    try {
      if (locator.isRegistered<NotificationService>()) {
        unawaited(
          locator<NotificationService>().sendExamCalibrationNotification(
            examName: exam.examName,
            daysRemaining: exam.daysRemaining,
            dailyTarget: exam.dailyTarget,
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test alert sent for "${exam.examName}"!'),
            backgroundColor: context.colors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on Object catch (_) {}
  }

  Future<void> _confirmDelete(BuildContext context, ExamEventEntity exam) async {
    final colors = context.colors;
    final typography = context.typography;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.isDarkMode
            ? colors.surfaceSecondary
            : colors.surfacePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Exam Countdown?',
          style: typography.headline.bold.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove "${exam.examName}" from your exam timetable? This action cannot be undone.',
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
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Exam'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      unawaited(context.read<CramPlannerCubit>().deleteExamCountdown(exam.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Exam Timetable',
          style: typography.headline.bold.copyWith(color: colors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: colors.primary),
            tooltip: 'Add Exam',
            onPressed: () => AddExamModalSheet.show(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocBuilder<CramPlannerCubit, CramPlannerState>(
        builder: (context, state) {
          final exams = state.activeExams;
          final primaryExam = state.selectedExam ??
              (exams.isNotEmpty ? exams.first : null);

          if (exams.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // Hero Active Countdown Display
              if (primaryExam != null) ...[
                _buildHeroCountdownCard(context, primaryExam),
                const SizedBox(height: 24),
                StudyCalibrationGraphWidget(
                  exam: primaryExam,
                  onStartStudySession: () {
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 28),
              ],

              // Timetable Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Scheduled Exams (${exams.length})',
                    style: typography.callout.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => AddExamModalSheet.show(context),
                    icon: Icon(Icons.add, size: 18, color: colors.primary),
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

              // Chronological Exam Cards
              ...exams.map(
                (exam) => _buildExamRowCard(
                  context,
                  exam: exam,
                  isSelected: exam.id == primaryExam?.id,
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
    );
  }

  Widget _buildHeroCountdownCard(BuildContext context, ExamEventEntity exam) {
    final colors = context.colors;
    final typography = context.typography;

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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.3),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  exam.subjectTrack.toUpperCase(),
                  style: typography.caption.bold.copyWith(color: Colors.white),
                ),
              ),
              Text(
                'ACTIVE TIMETABLE',
                style: typography.caption.bold.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            exam.examName,
            style: typography.title2.bold.copyWith(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('EEEE, MMMM d, y • hh:mm a').format(exam.targetDate),
            style: typography.caption.regular.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 20),

          // Digits row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTimeDigit(days.toString(), 'DAYS'),
              Text(
                ':',
                style: typography.title1.bold.copyWith(color: Colors.white70),
              ),
              _buildTimeDigit(hours.toString().padLeft(2, '0'), 'HOURS'),
              Text(
                ':',
                style: typography.title1.bold.copyWith(color: Colors.white70),
              ),
              _buildTimeDigit(minutes.toString().padLeft(2, '0'), 'MINUTES'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDigit(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildExamRowCard(
    BuildContext context, {
    required ExamEventEntity exam,
    required bool isSelected,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final formattedDate =
        DateFormat('EEE, d MMM y • hh:mm a').format(exam.targetDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? colors.primary
              : colors.surfaceBorder.withValues(alpha: 0.6),
          width: isSelected ? 2 : 1,
        ),
      ),
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
                borderRadius: BorderRadius.circular(12),
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
                    color: isSelected ? Colors.white : Colors.transparent,
                  ),
                ),
              ),
              const SizedBox(width: 12),

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
                            color: colors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            exam.subjectTrack,
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Edit & Delete Actions
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 20, color: colors.textSecondary),
                tooltip: 'Edit Exam',
                onPressed: () => AddExamModalSheet.show(context, initialExam: exam),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                tooltip: 'Delete Exam',
                onPressed: () => _confirmDelete(context, exam),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress and Countdown Strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                exam.formattedCountdown,
                style: typography.caption.bold.copyWith(
                  color: exam.isPast ? colors.textSecondary : colors.primary,
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
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: exam.completionProgress,
              backgroundColor: colors.surfaceBorder.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation<Color>(
                isSelected ? colors.primary : colors.primary.withValues(alpha: 0.7),
              ),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.surfaceBorder.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_rounded, color: colors.primary, size: 20),
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
            'Keep your study pacing calibrated with timely reminders.',
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Daily Reminder Switch
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _dailyReminderEnabled,
            title: Text(
              'Daily Study Pace Reminders',
              style: typography.body.bold.copyWith(color: colors.textPrimary),
            ),
            subtitle: Text(
              'Receive a morning nudge with your daily card target',
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
              ),
            ),
            activeThumbColor: colors.primary,
            activeTrackColor: colors.primary.withValues(alpha: 0.5),
            onChanged: (val) {
              setState(() => _dailyReminderEnabled = val);
            },
          ),
          const Divider(),

          // Milestone Alerts Switch
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _milestoneAlertsEnabled,
            title: Text(
              'Exam Milestone Alerts',
              style: typography.body.bold.copyWith(color: colors.textPrimary),
            ),
            subtitle: Text(
              'Alerts at 7 days, 3 days, and 24 hours prior to exam',
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
              ),
            ),
            activeThumbColor: colors.primary,
            activeTrackColor: colors.primary.withValues(alpha: 0.5),
            onChanged: (val) {
              setState(() => _milestoneAlertsEnabled = val);
            },
          ),

          if (exam != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: () => _testNotification(exam),
              icon: Icon(Icons.send_rounded, size: 16, color: colors.primary),
              label: Text(
                'Send Test Notification',
                style: typography.callout.bold.copyWith(color: colors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_note_rounded,
                size: 64,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Exams Scheduled Yet',
              style: typography.title3.bold.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your upcoming exams to build a personalized study timetable with calibrated daily flashcard targets.',
              textAlign: TextAlign.center,
              style: typography.body.regular.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
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
