import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

class PostponeExamModalSheet extends StatefulWidget {
  const PostponeExamModalSheet({
    required this.exam,
    super.key,
  });

  final ExamEventEntity exam;

  static const _calculator = CramWorkloadCalculator();

  static Future<void> show(
    BuildContext context, {
    required ExamEventEntity exam,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<CramPlannerCubit>(),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: PostponeExamModalSheet(exam: exam),
          ),
        ),
      ),
    );
  }

  @override
  State<PostponeExamModalSheet> createState() => _PostponeExamModalSheetState();
}

class _PostponeExamModalSheetState extends State<PostponeExamModalSheet> {
  late DateTime _newDate;
  late TimeOfDay _newTime;
  final _reasonController = TextEditingController();
  int _selectedPresetDays = 7; // Default preset +1 week

  @override
  void initState() {
    super.initState();
    // Default postpone target: +7 days from current target date
    final baseDate = widget.exam.targetDate.isBefore(DateTime.now())
        ? DateTime.now().add(const Duration(days: 7))
        : widget.exam.targetDate.add(const Duration(days: 7));
    _newDate = baseDate;
    _newTime = TimeOfDay(hour: widget.exam.targetDate.hour, minute: widget.exam.targetDate.minute);
    if (widget.exam.postponedReason != null) {
      _reasonController.text = widget.exam.postponedReason!;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _applyPreset(int days) {
    AppFeedback.selection();
    setState(() {
      _selectedPresetDays = days;
      final base = widget.exam.targetDate.isBefore(DateTime.now())
          ? DateTime.now()
          : widget.exam.targetDate;
      _newDate = DateTime(
        base.year,
        base.month,
        base.day + days,
        _newTime.hour,
        _newTime.minute,
      );
    });
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _newDate.isBefore(now) ? now.add(const Duration(days: 1)) : _newDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );

    if (picked != null) {
      setState(() {
        _selectedPresetDays = -1; // Custom date selected
        _newDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _newTime.hour,
          _newTime.minute,
        );
      });
    }
  }

  Future<void> _pickCustomTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _newTime,
    );

    if (picked != null) {
      setState(() {
        _newTime = picked;
        _newDate = DateTime(
          _newDate.year,
          _newDate.month,
          _newDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _submitPostpone() {
    final cubit = context.read<CramPlannerCubit>();
    final reasonText = _reasonController.text.trim();

    AppFeedback.heavy();
    unawaited(
      cubit.postponeAssessment(
        examId: widget.exam.id,
        newTargetDate: DateTime(
          _newDate.year,
          _newDate.month,
          _newDate.day,
          _newTime.hour,
          _newTime.minute,
        ),
        reason: reasonText.isNotEmpty ? reasonText : null,
      ),
    );

    Navigator.of(context).pop();
    context.showSnackBar(
      message: '"${widget.exam.examName}" postponed to ${DateFormat('EEE, d MMM y').format(_newDate)}',
      type: SnackBarType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final today = DateTime.now();
    final newTarget = DateTime(_newDate.year, _newDate.month, _newDate.day);
    final daysRemaining = newTarget.difference(DateTime(today.year, today.month, today.day)).inDays;
    final effDays = daysRemaining < 1 ? 1 : daysRemaining;
    final newDailyPace = (widget.exam.remainingCards / effDays).ceil().clamp(5, 60);

    final originalDateStr = DateFormat('EEE, d MMM y').format(widget.exam.targetDate);
    final newDateStr = DateFormat('EEE, d MMM y').format(_newDate);
    final timeStr = _newTime.format(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        decoration: BoxDecoration(
          color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.dialog),
          ),
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 60 : 30),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.warning.withAlpha(isDark ? 50 : 25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.update_rounded,
                          color: colors.warning,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Postpone Assessment',
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Reschedule "${widget.exam.examName}". Your daily cram study workload will automatically rebalance.',
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 16),

              // Presets Selection Chips
              Text(
                'POSTPONE HORIZON PRESETS',
                style: typography.caption.bold.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPresetChip('+1 Day', 1),
                  _buildPresetChip('+3 Days', 3),
                  _buildPresetChip('+1 Week', 7),
                  _buildPresetChip('+2 Weeks', 14),
                  _buildPresetChip('+1 Month', 30),
                ],
              ),
              const SizedBox(height: 14),

              // Custom Date & Time Picker Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickCustomDate,
                      icon: const Icon(Icons.calendar_month_outlined, size: 16),
                      label: Text(
                        newDateStr,
                        style: typography.caption.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 12.5,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: _selectedPresetDays == -1
                              ? colors.primary
                              : colors.surfaceBorder,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.radiusCard,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _pickCustomTime,
                    icon: const Icon(Icons.access_time_rounded, size: 16),
                    label: Text(
                      timeStr,
                      style: typography.caption.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 12.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      side: BorderSide(color: colors.surfaceBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusCard,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Live Workload & Schedule Impact Preview
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfacePrimary.withAlpha(140)
                      : colors.surfaceSecondary.withAlpha(120),
                  borderRadius: AppRadius.radiusCard,
                  border: Border.all(
                    color: colors.warning.withAlpha(isDark ? 80 : 40),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.insights_rounded,
                          size: 15,
                          color: colors.warning,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Pacing & Target Impact',
                          style: typography.caption.bold.copyWith(
                            color: colors.warning,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Original Scheduled Date',
                              style: typography.caption.medium.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              originalDateStr,
                              style: typography.body.semiBold.copyWith(
                                color: colors.textSecondary,
                                fontSize: 13,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_forward_rounded, size: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'New Scheduled Date',
                              style: typography.caption.medium.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              newDateStr,
                              style: typography.body.bold.copyWith(
                                color: colors.primary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: colors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'New Preparation Horizon',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$daysRemaining ${daysRemaining == 1 ? "day" : "days"} left',
                          style: typography.caption.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_graph_rounded,
                              size: 14,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Recalibrated Daily Pace',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$newDailyPace cards/day',
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Reason Input Field
              AppTextField(
                controller: _reasonController,
                label: 'Reason for Postponement (Optional)',
                hintText: 'e.g. Lecturer moved exam, health, schedule conflict',
                prefixIcon: Icon(
                  Icons.edit_note_rounded,
                  color: colors.textSecondary,
                  size: 18,
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: colors.surfaceBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.radiusCard,
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: typography.callout.bold.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      text: 'Confirm Postponement',
                      onPressed: _submitPostpone,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, int days) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final isSelected = _selectedPresetDays == days;

    return InkWell(
      onTap: () => _applyPreset(days),
      borderRadius: AppRadius.radiusBadge,
      child: AnimatedContainer(
        duration: AppMotion.snappy,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary
              : (isDark
                  ? colors.surfacePrimary.withAlpha(120)
                  : colors.surfaceSecondary.withAlpha(90)),
          borderRadius: AppRadius.radiusBadge,
          border: Border.all(
            color: isSelected ? colors.primary : colors.surfaceBorder.withAlpha(80),
          ),
        ),
        child: Text(
          label,
          style: typography.caption.bold.copyWith(
            color: isSelected ? colors.white : colors.textPrimary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
