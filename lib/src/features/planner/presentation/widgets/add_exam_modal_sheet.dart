import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/quiz/data/data_sources/past_questions_local_data_source.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

class AddExamModalSheet extends StatefulWidget {
  const AddExamModalSheet({
    this.initialExam,
    this.preselectedCourseCode,
    this.preselectedCourseTitle,
    super.key,
  });

  final ExamEventEntity? initialExam;
  final String? preselectedCourseCode;
  final String? preselectedCourseTitle;

  static Future<void> show(
    BuildContext context, {
    ExamEventEntity? initialExam,
    String? preselectedCourseCode,
    String? preselectedCourseTitle,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<CramPlannerCubit>(),
        child: AddExamModalSheet(
          initialExam: initialExam,
          preselectedCourseCode: preselectedCourseCode,
          preselectedCourseTitle: preselectedCourseTitle,
        ),
      ),
    );
  }

  @override
  State<AddExamModalSheet> createState() => _AddExamModalSheetState();
}

class _AddExamModalSheetState extends State<AddExamModalSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  List<CuratedCourseModel> _registeredCourses = [];
  CuratedCourseModel? _selectedCourse;
  int _deckCardsCount = 0;
  int _pastQuestionsCount = 0;
  bool _isCalculatingWorkload = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialExam?.examName ?? '',
    );
    _selectedDate =
        widget.initialExam?.targetDate ??
        DateTime.now().add(const Duration(days: 30));
    _selectedTime = widget.initialExam != null
        ? TimeOfDay(
            hour: widget.initialExam!.targetDate.hour,
            minute: widget.initialExam!.targetDate.minute,
          )
        : const TimeOfDay(hour: 9, minute: 0);

    _loadRegisteredCourses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _loadRegisteredCourses() {
    try {
      final storage = locator.isRegistered<LocalStorageService>()
          ? locator<LocalStorageService>()
          : null;
      final raw = storage?.getPreference(key: PrefKeys.userCuratedCourses);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _registeredCourses = list
            .whereType<Map<String, dynamic>>()
            .map(CuratedCourseModel.fromJson)
            .toList();
      }
    } on Object catch (_) {}

    // Preselect course if matching code/title or initialExam
    if (_registeredCourses.isNotEmpty) {
      final targetCode = widget.preselectedCourseCode ??
          widget.initialExam?.subjectTrack;
      if (targetCode != null && targetCode.isNotEmpty) {
        _selectedCourse = _registeredCourses.firstWhere(
          (c) =>
              c.courseCode.toLowerCase() == targetCode.toLowerCase() ||
              c.title.toLowerCase() == targetCode.toLowerCase(),
          orElse: () => _registeredCourses.first,
        );
      } else {
        _selectedCourse = _registeredCourses.first;
      }
    }

    if (_nameController.text.trim().isEmpty && _selectedCourse != null) {
      _nameController.text = '${_selectedCourse!.courseCode} Final Exam';
    }

    unawaited(_calculateWorkload());
  }

  Future<void> _calculateWorkload() async {
    if (!mounted) return;
    setState(() {
      _isCalculatingWorkload = true;
    });

    var deckCards = 0;
    var pastQuestions = 0;

    final course = _selectedCourse;
    if (course != null) {
      // 1. Sum cards in study decks available under this course
      try {
        if (locator.isRegistered<DecksBloc>()) {
          final decks = locator<DecksBloc>().state.allDecks;
          for (final d in decks) {
            final matchCourse = (d.courseId != null && d.courseId == course.id) ||
                (d.courseCode != null &&
                    d.courseCode!.toLowerCase() ==
                        course.courseCode.toLowerCase()) ||
                d.subject.toLowerCase() == course.title.toLowerCase();
            if (matchCourse) {
              deckCards += d.totalCards;
            }
          }
        }
      } on Object catch (_) {}

      // 2. For secondary school exams (WAEC, JAMB, NECO), take past questions into account
      try {
        final authBloc = locator.isRegistered<AuthBloc>() ? locator<AuthBloc>() : null;
        final track = (authBloc?.state.userProfile?.targetTrack ?? 'WAEC').toUpperCase();
        final isSecondary = track.contains('WAEC') ||
            track.contains('JAMB') ||
            track.contains('NECO');

        if (isSecondary && locator.isRegistered<PastQuestionsLocalDataSource>()) {
          final pds = locator<PastQuestionsLocalDataSource>();
          if (!pds.isInitialized) {
            await pds.initialize();
          }
          final examCategory = track.contains('JAMB')
              ? ExamCategory.jamb
              : (track.contains('NECO') ? ExamCategory.neco : ExamCategory.waec);

          final questions = await pds.getPastQuestions(
            examCategory: examCategory,
            subject: course.title,
            courseCode: course.courseCode,
            limit: 1000,
          );
          pastQuestions = questions.length;
        }
      } on Object catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _deckCardsCount = deckCards;
      _pastQuestionsCount = pastQuestions;
      _isCalculatingWorkload = false;
    });
  }

  int get _totalWorkload => _deckCardsCount + _pastQuestionsCount;

  int get _daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final diff = target.difference(today).inDays;
    return diff < 1 ? 1 : diff;
  }

  int get _dailyTarget => (_totalWorkload / _daysRemaining).ceil();

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

    final cubit = context.read<CramPlannerCubit>();
    final examName = _nameController.text.trim();
    final courseIdentifier = _selectedCourse != null
        ? '${_selectedCourse!.courseCode} - ${_selectedCourse!.title}'
        : (widget.initialExam?.subjectTrack ?? 'Registered Course');

    final workload = _totalWorkload > 0 ? _totalWorkload : 100;

    if (widget.initialExam != null) {
      unawaited(
        cubit.updateExamCountdown(
          examId: widget.initialExam!.id,
          examName: examName,
          targetDate: targetDateTime,
          subjectTrack: courseIdentifier,
          totalCardsCount: workload,
        ),
      );
    } else {
      unawaited(
        cubit.addExamCountdown(
          examName: examName,
          targetDate: targetDateTime,
          subjectTrack: courseIdentifier,
          totalCardsCount: workload,
        ),
      );
    }

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
                        ? 'Edit Exam Countdown'
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

              // Registered Course Dropdown
              if (_registeredCourses.isNotEmpty) ...[
                DropdownButtonFormField<CuratedCourseModel>(
                  initialValue: _selectedCourse,
                  dropdownColor: isDark
                      ? colors.surfaceSecondary
                      : colors.surfacePrimary,
                  style: typography.body.regular.copyWith(
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Registered Course / Subject',
                    labelStyle: typography.subhead.regular.copyWith(
                      color: colors.textSecondary,
                    ),
                    prefixIcon: Icon(
                      Icons.school_rounded,
                      color: colors.primary,
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
                  items: _registeredCourses.map((c) {
                    return DropdownMenuItem<CuratedCourseModel>(
                      value: c,
                      child: Text(
                        '${c.courseCode} - ${c.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (course) {
                    if (course != null) {
                      setState(() {
                        _selectedCourse = course;
                        if (_nameController.text.isEmpty ||
                            _nameController.text.endsWith('Final Exam')) {
                          _nameController.text = '${course.courseCode} Final Exam';
                        }
                      });
                      unawaited(_calculateWorkload());
                    }
                  },
                ),
                const SizedBox(height: 14),
              ],

              // Exam Name Field
              AppTextField(
                controller: _nameController,
                label: l10n.examNameLabel,
                hintText: l10n.examModalExamTitleHint,
                prefixIcon: Icon(
                  Icons.assignment_outlined,
                  color: colors.textSecondary,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.examNameRequired;
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Automatic Internal Workload Calculation Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 30 : 15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.primary.withAlpha(isDark ? 80 : 40),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_graph_rounded,
                          size: 18,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.estimatedExamWorkload,
                          style: typography.callout.bold.copyWith(
                            color: colors.primary,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        if (_isCalculatingWorkload)
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(colors.primary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _totalWorkload > 0
                          ? l10n.examTotalStudyItems(_totalWorkload)
                          : l10n.examNoStudyItems,
                      style: typography.title3.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.examWorkloadBreakdown(
                        _deckCardsCount,
                        _pastQuestionsCount,
                      ),
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.recommendedDailyPaceLabel,
                          style: typography.footnote.medium.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withAlpha(isDark ? 60 : 30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n.dailyTargetPace(_dailyTarget),
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
                                  size: 14,
                                  color: colors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.targetDateLabel,
                                  style: typography.caption.regular.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formattedDate,
                              style: typography.callout.bold.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

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
                                  size: 14,
                                  color: colors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.timePickerLabel,
                                  style: typography.caption.regular.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formattedTime,
                              style: typography.callout.bold.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: l10n.cancelAction,
                      onPressed: () => Navigator.of(context).pop(),
                      variant: AppButtonVariant.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      text: widget.initialExam != null
                          ? l10n.updateExamCountdown
                          : l10n.saveExamCountdown,
                      isEnabled: _selectedCourse != null,
                      onPressed: _submit,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
