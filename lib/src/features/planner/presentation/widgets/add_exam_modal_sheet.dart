import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/notification_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

class AddExamModalSheet extends StatefulWidget {
  const AddExamModalSheet({this.initialExam, super.key});

  final ExamEventEntity? initialExam;

  static Future<void> show(
    BuildContext context, {
    ExamEventEntity? initialExam,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<CramPlannerCubit>(),
        child: AddExamModalSheet(initialExam: initialExam),
      ),
    );
  }

  @override
  State<AddExamModalSheet> createState() => _AddExamModalSheetState();
}

class _AddExamModalSheetState extends State<AddExamModalSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _cardsController;
  late String _selectedTrack;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialExam?.examName ?? '',
    );
    _cardsController = TextEditingController(
      text: (widget.initialExam?.totalCardsCount ?? 150).toString(),
    );
    _selectedTrack = widget.initialExam?.subjectTrack ?? 'WAEC';
    _selectedDate =
        widget.initialExam?.targetDate ??
        DateTime.now().add(const Duration(days: 30));
    _selectedTime = widget.initialExam != null
        ? TimeOfDay(
            hour: widget.initialExam!.targetDate.hour,
            minute: widget.initialExam!.targetDate.minute,
          )
        : const TimeOfDay(hour: 9, minute: 0);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cardsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now)
          ? now.add(const Duration(days: 1))
          : _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final targetDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final totalCards = int.tryParse(_cardsController.text.trim()) ?? 150;
    final cubit = context.read<CramPlannerCubit>();
    final examName = _nameController.text.trim();

    if (widget.initialExam != null) {
      unawaited(
        cubit.updateExamCountdown(
          examId: widget.initialExam!.id,
          examName: examName,
          targetDate: targetDateTime,
          subjectTrack: _selectedTrack,
          totalCardsCount: totalCards,
        ),
      );
    } else {
      unawaited(
        cubit.addExamCountdown(
          examName: examName,
          targetDate: targetDateTime,
          subjectTrack: _selectedTrack,
          totalCardsCount: totalCards,
        ),
      );
    }

    try {
      if (locator.isRegistered<NotificationService>()) {
        final days = targetDateTime.difference(DateTime.now()).inDays;
        unawaited(
          locator<NotificationService>().sendExamCalibrationNotification(
            examName: examName,
            daysRemaining: days < 0 ? 0 : days,
            dailyTarget: (totalCards / (days < 1 ? 1 : days)).ceil(),
          ),
        );
      }
    } on Object catch (_) {}

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final formattedDate = DateFormat('EEE, d MMM y').format(_selectedDate);
    final formattedTime = _selectedTime.format(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 60 : 30),
          ),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sheet Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.initialExam != null
                        ? 'Edit Exam Timetable'
                        : l10n.addExamTitle,
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Exam Name Field
              AppTextField(
                controller: _nameController,
                label: l10n.examNameLabel,
                hintText: l10n.examModalExamTitleHint,
                prefixIcon: Icon(
                  Icons.school_rounded,
                  color: colors.textSecondary,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter exam name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Subject Track Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedTrack,
                dropdownColor: isDark
                    ? colors.surfaceSecondary
                    : colors.surfacePrimary,
                style: typography.body.regular.copyWith(
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: l10n.examSubjectLabel,
                  labelStyle: typography.subhead.regular.copyWith(
                    color: colors.textSecondary,
                  ),
                  prefixIcon: Icon(
                    Icons.category_rounded,
                    color: colors.textSecondary,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? colors.surfaceSecondary
                      : colors.surfacePrimary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colors.surfaceBorder,
                    ),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'WAEC',
                    child: Text(l10n.examTrackWaecStem),
                  ),
                  DropdownMenuItem(
                    value: 'JAMB',
                    child: Text(l10n.examTrackJambUtme),
                  ),
                  DropdownMenuItem(
                    value: 'SAT',
                    child: Text(l10n.examTrackSatDigital),
                  ),
                  DropdownMenuItem(
                    value: 'University',
                    child: Text(l10n.examTrackUniversityStem),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedTrack = val;
                    });
                  }
                },
              ),

              const SizedBox(height: 14),

              // Total Cards Target
              AppTextField(
                controller: _cardsController,
                label: 'Total Flashcards to Complete',
                hintText: 'e.g. 150',
                keyboardType: TextInputType.number,
                prefixIcon: Icon(
                  Icons.style_rounded,
                  color: colors.textSecondary,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter total cards to complete';
                  }
                  final count = int.tryParse(value.trim());
                  if (count == null || count <= 0) {
                    return 'Enter a valid positive number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Date & Time Picker Row
              Row(
                children: [
                  // Date Picker Tile
                  Expanded(
                    flex: 6,
                    child: InkWell(
                      onTap: () => unawaited(_pickDate()),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary
                              : colors.surfacePrimary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.surfaceBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Exam Date',
                                  style: typography.caption.regular.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formattedDate,
                              style: typography.callout.bold.copyWith(
                                color: colors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Time Picker Tile
                  Expanded(
                    flex: 4,
                    child: InkWell(
                      onTap: () => unawaited(_pickTime()),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary
                              : colors.surfacePrimary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.surfaceBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 16,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Start Time',
                                  style: typography.caption.regular.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formattedTime,
                              style: typography.callout.bold.copyWith(
                                color: colors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Save Button
              AppButton(
                text: widget.initialExam != null
                    ? 'Update Exam Timetable'
                    : l10n.saveExamCountdown,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
