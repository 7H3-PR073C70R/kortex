import 'dart:async';
import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/quiz/data/data_sources/past_questions_local_data_source.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

@RoutePage()
class AddAcademicAssessmentPage extends StatefulWidget {
  const AddAcademicAssessmentPage({
    this.initialExam,
    this.preselectedCourseCode,
    this.preselectedCourseTitle,
    this.preselectedType,
    super.key,
  });

  final ExamEventEntity? initialExam;
  final String? preselectedCourseCode;
  final String? preselectedCourseTitle;
  final AssessmentType? preselectedType;

  @override
  State<AddAcademicAssessmentPage> createState() =>
      _AddAcademicAssessmentPageState();
}

class _AddAcademicAssessmentPageState
    extends State<AddAcademicAssessmentPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _topicController;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late AssessmentType _selectedType;
  final Set<String> _selectedDeckIds = {};
  final List<String> _scopedTopics = [];
  double? _selectedWeightPercent;

  List<CuratedCourseModel> _registeredCourses = [];
  CuratedCourseModel? _selectedCourse;
  List<DeckEntity> _courseDecks = [];
  int _deckCardsCount = 0;
  int _pastQuestionsCount = 0;
  bool _isCalculatingWorkload = false;
  bool _userCustomizedTitle = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialExam?.assessmentType ??
        widget.preselectedType ??
        AssessmentType.finalExam;

    _nameController = TextEditingController(
      text: widget.initialExam?.examName ?? '',
    );
    _topicController = TextEditingController();

    if (widget.initialExam != null &&
        widget.initialExam!.examName.isNotEmpty) {
      _userCustomizedTitle = true;
    }

    _selectedDate = widget.initialExam?.targetDate ??
        DateTime.now().add(Duration(days: _selectedType.suggestedDaysAhead));

    _selectedTime = widget.initialExam != null
        ? TimeOfDay(
            hour: widget.initialExam!.targetDate.hour,
            minute: widget.initialExam!.targetDate.minute,
          )
        : const TimeOfDay(hour: 9, minute: 0);

    if (widget.initialExam != null &&
        widget.initialExam!.scopedDeckIds.isNotEmpty) {
      _selectedDeckIds.addAll(widget.initialExam!.scopedDeckIds);
    }
    if (widget.initialExam != null &&
        widget.initialExam!.scopedTopics.isNotEmpty) {
      _scopedTopics.addAll(widget.initialExam!.scopedTopics);
    }

    _selectedWeightPercent = widget.initialExam?.weightPercent;

    _loadRegisteredCourses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  void _addTopic() {
    final text = _topicController.text.trim();
    final sanitizedText = _sanitizeString(text);
    if (sanitizedText.isNotEmpty && !_scopedTopics.contains(sanitizedText)) {
      AppFeedback.selection();
      setState(() {
        _scopedTopics.add(sanitizedText);
        _topicController.clear();
      });
    }
  }

  void _removeTopic(String topic) {
    AppFeedback.selection();
    setState(() {
      _scopedTopics.remove(topic);
    });
  }

  String _sanitizeString(String val) {
    // Basic security sanitization: strip script tags & control chars
    return val
        .replaceAll(RegExp('<[^>]*>'), '')
        .replaceAll(RegExp('[\x00-\x1F\x7F]'), '')
        .trim();
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

    if (_registeredCourses.isNotEmpty) {
      final targetCode =
          widget.preselectedCourseCode ?? widget.initialExam?.subjectTrack;
      if (targetCode != null && targetCode.isNotEmpty) {
        _selectedCourse = _registeredCourses.firstWhere(
          (c) {
            final t = targetCode.toLowerCase();
            final code = c.courseCode.toLowerCase();
            final title = c.title.toLowerCase();
            return code == t ||
                title == t ||
                t.contains(code) ||
                t.contains(title);
          },
          orElse: () => _registeredCourses.first,
        );
      } else {
        _selectedCourse = _registeredCourses.first;
      }
    }

    _syncDefaultTitleAndDecks();
    unawaited(_calculateWorkload());
  }

  void _syncDefaultTitleAndDecks() {
    if (_selectedCourse == null) return;

    if (locator.isRegistered<DecksBloc>()) {
      final all = locator<DecksBloc>().state.allDecks;
      final courseCode = _selectedCourse!.courseCode.toLowerCase();
      final courseTitle = _selectedCourse!.title.toLowerCase();
      _courseDecks = all.where((d) {
        final matchId =
            d.courseId != null && d.courseId == _selectedCourse!.id;
        final matchCode = d.courseCode != null &&
            d.courseCode!.toLowerCase() == courseCode;
        final matchSubj = d.subject.toLowerCase() == courseTitle ||
            d.subject.toLowerCase() == courseCode;
        return matchId || matchCode || matchSubj;
      }).toList();

      if (_selectedDeckIds.isEmpty && _courseDecks.isNotEmpty) {
        _selectedDeckIds.addAll(_courseDecks.map((d) => d.id));
      }
    }

    if (!_userCustomizedTitle || _nameController.text.trim().isEmpty) {
      _nameController.text =
          _selectedType.defaultNameForCourse(_selectedCourse!.courseCode);
    }
  }

  void _onTypeChanged(AssessmentType type) {
    if (_selectedType == type) return;
    AppFeedback.selection();
    setState(() {
      _selectedType = type;
      if (!_userCustomizedTitle && _selectedCourse != null) {
        _nameController.text =
            type.defaultNameForCourse(_selectedCourse!.courseCode);
      }
      if (widget.initialExam == null) {
        _selectedDate =
            DateTime.now().add(Duration(days: type.suggestedDaysAhead));
      }
    });
    unawaited(_calculateWorkload());
  }

  void _toggleDeckSelection(String deckId) {
    AppFeedback.selection();
    setState(() {
      if (_selectedDeckIds.contains(deckId)) {
        _selectedDeckIds.remove(deckId);
      } else {
        _selectedDeckIds.add(deckId);
      }
    });
    unawaited(_calculateWorkload());
  }

  void _selectAllDecks() {
    AppFeedback.selection();
    setState(() {
      _selectedDeckIds.addAll(_courseDecks.map((d) => d.id));
    });
    unawaited(_calculateWorkload());
  }

  void _clearAllDecks() {
    AppFeedback.selection();
    setState(_selectedDeckIds.clear);
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
      for (final d in _courseDecks) {
        if (_selectedDeckIds.isEmpty || _selectedDeckIds.contains(d.id)) {
          deckCards += d.totalCards;
        }
      }

      final isHighStakes = _selectedType == AssessmentType.finalExam ||
          _selectedType == AssessmentType.mockExam ||
          _selectedType == AssessmentType.midterm;

      if (isHighStakes) {
        try {
          final authBloc = locator.isRegistered<AuthBloc>()
              ? locator<AuthBloc>()
              : null;
          final track =
              (authBloc?.state.userProfile?.targetTrack ?? 'WAEC')
                  .toUpperCase();
          final isSecondary = track.contains('WAEC') ||
              track.contains('JAMB') ||
              track.contains('NECO');

          if (isSecondary &&
              locator.isRegistered<PastQuestionsLocalDataSource>()) {
            final pds = locator<PastQuestionsLocalDataSource>();
            if (!pds.isInitialized) {
              await pds.initialize();
            }
            final examCategory = track.contains('JAMB')
                ? ExamCategory.jamb
                : (track.contains('NECO')
                    ? ExamCategory.neco
                    : ExamCategory.waec);

            final questions = await pds.getPastQuestions(
              examCategory: examCategory,
              subject: course.title,
              courseCode: course.courseCode,
              limit: _selectedType == AssessmentType.midterm ? 250 : 1000,
            );
            pastQuestions = questions.length;
          }
        } on Object catch (_) {}
      }
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
      unawaited(_calculateWorkload());
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final sanitizedName = _sanitizeString(_nameController.text);
    if (sanitizedName.isEmpty) {
      context.showSnackBar(
        message: 'Please enter a valid assessment title.',
        type: SnackBarType.error,
      );
      return;
    }

    final targetDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final cubit = locator.isRegistered<CramPlannerCubit>()
        ? locator<CramPlannerCubit>()
        : context.read<CramPlannerCubit>();

    final courseIdentifier = _selectedCourse != null
        ? '${_selectedCourse!.courseCode} - ${_selectedCourse!.title}'
        : (widget.initialExam?.subjectTrack ?? 'Academic Course');

    final workload = _totalWorkload > 0 ? _totalWorkload : 50;

    try {
      if (widget.initialExam != null) {
        await cubit.updateExamCountdown(
          examId: widget.initialExam!.id,
          examName: sanitizedName,
          targetDate: targetDateTime,
          subjectTrack: courseIdentifier,
          assessmentType: _selectedType,
          scopedDeckIds: _selectedDeckIds.toList(),
          scopedTopics: _scopedTopics,
          weightPercent: _selectedWeightPercent,
          totalCardsCount: workload,
        );
      } else {
        await cubit.addExamCountdown(
          examName: sanitizedName,
          targetDate: targetDateTime,
          subjectTrack: courseIdentifier,
          assessmentType: _selectedType,
          scopedDeckIds: _selectedDeckIds.toList(),
          scopedTopics: _scopedTopics,
          weightPercent: _selectedWeightPercent,
          totalCardsCount: workload,
        );
      }

      AppFeedback.heavy();
      if (mounted) {
        context.showSnackBar(
          message: widget.initialExam != null
              ? 'Assessment countdown updated successfully!'
              : 'Academic assessment added to your timetable!',
          type: SnackBarType.success,
        );
        context.router.pop();
      }
    } on Object catch (e) {
      if (mounted) {
        context.showSnackBar(
          message: 'Could not save assessment: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final formattedDate = DateFormat('EEE, d MMM y').format(_selectedDate);
    final formattedTime = _selectedTime.format(context);

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppAdaptiveAppBar(
        backgroundColor: colors.backgroundPrimary,
        titleText: widget.initialExam != null
            ? 'Edit Assessment'
            : 'Add Academic Assessment',
        breadcrumbs: [
          AppBreadcrumbItem(
            label: 'Planner',
            onTap: () => context.router.maybePop(),
          ),
          AppBreadcrumbItem(
            label: widget.initialExam != null
                ? 'Edit Assessment'
                : 'Add Assessment',
          ),
        ],
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () => context.router.maybePop(),
              child: Text(
                'Cancel',
                style: typography.subhead.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  // Section 1: Assessment Type Selector
                  Text(
                    l10n.assessmentTypeLabel,
                    style: typography.caption.bold.copyWith(
                      color: colors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        AssessmentType.quiz,
                        AssessmentType.classTest,
                        AssessmentType.midterm,
                        AssessmentType.finalExam,
                        AssessmentType.mockExam,
                      ].map((type) {
                        final isSelected = _selectedType == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => _onTypeChanged(type),
                            borderRadius: AppRadius.radiusBadge,
                            child: AnimatedContainer(
                              duration: AppMotion.snappy,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.primary
                                    : (isDark
                                        ? colors.surfacePrimary.withAlpha(120)
                                        : colors.surfaceSecondary.withAlpha(90)),
                                borderRadius: AppRadius.radiusBadge,
                                border: Border.all(
                                  color: isSelected
                                      ? colors.primary
                                      : colors.surfaceBorder.withAlpha(80),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    type.icon,
                                    size: 15,
                                    color: isSelected
                                        ? colors.white
                                        : colors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    type.displayName,
                                    style: typography.caption.bold.copyWith(
                                      color: isSelected
                                          ? colors.white
                                          : colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section 2: Registered Course / Subject Dropdown
                  if (_registeredCourses.isNotEmpty) ...[
                    _PageSearchableCourseDropdown(
                      courses: _registeredCourses,
                      selectedCourse: _selectedCourse,
                      onCourseSelected: (course) {
                        setState(() {
                          _selectedCourse = course;
                          _userCustomizedTitle = false;
                        });
                        _syncDefaultTitleAndDecks();
                        unawaited(_calculateWorkload());
                      },
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Section 3: Assessment Name Field
                  AppTextField(
                    controller: _nameController,
                    label: l10n.examNameLabel,
                    hintText: l10n.examModalExamTitleHint,
                    prefixIcon: Icon(
                      _selectedType.icon,
                      color: colors.textSecondary,
                      size: 18,
                    ),
                    onChanged: (val) {
                      if (val.trim().isNotEmpty) {
                        _userCustomizedTitle = true;
                      }
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.examNameRequired;
                      }
                      if (value.trim().length > 100) {
                        return 'Assessment name cannot exceed 100 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  // Section 4: Scoped Flashcard Decks Filter
                  if (_courseDecks.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfacePrimary.withAlpha(100)
                            : colors.surfaceSecondary.withAlpha(70),
                        borderRadius: AppRadius.radiusCard,
                        border: Border.all(
                          color: colors.surfaceBorder.withAlpha(80),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.layers_outlined,
                                    size: 16,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.scopedTopicsLabel,
                                    style: typography.caption.bold.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: _selectAllDecks,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: Text(
                                      'Select All',
                                      style:
                                          typography.caption.semiBold.copyWith(
                                        color: colors.primary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: _clearAllDecks,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: Text(
                                      'Clear',
                                      style:
                                          typography.caption.semiBold.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _courseDecks.map((deck) {
                              final isSelected =
                                  _selectedDeckIds.contains(deck.id);
                              return FilterChip(
                                label:
                                    Text('${deck.title} (${deck.totalCards})'),
                                labelStyle: typography.caption.regular.copyWith(
                                  color: isSelected
                                      ? colors.primary
                                      : colors.textSecondary,
                                  fontSize: 12,
                                ),
                                selected: isSelected,
                                showCheckmark: true,
                                checkmarkColor: colors.primary,
                                selectedColor: colors.primary.withAlpha(
                                  isDark ? 40 : 25,
                                ),
                                backgroundColor: colors.transparent,
                                side: BorderSide(
                                  color: isSelected
                                      ? colors.primary
                                      : colors.surfaceBorder,
                                ),
                                onSelected: (_) =>
                                    _toggleDeckSelection(deck.id),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Section 5: Syllabus Topics / Chapters Tagging
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfacePrimary
                          : colors.surfaceSecondary.withAlpha(120),
                      borderRadius: AppRadius.radiusPanel,
                      border: Border.all(color: colors.surfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.topic_outlined,
                              size: 15,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.scopedTopicsTitle,
                              style: typography.caption.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _topicController,
                                style: typography.body.regular.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  hintText: l10n.addTopicHint,
                                  hintStyle:
                                      typography.caption.regular.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 12.5,
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: colors.surfaceBorder,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) => _addTopic(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              icon: const Icon(Icons.add_rounded, size: 18),
                              onPressed: _addTopic,
                              style: IconButton.styleFrom(
                                backgroundColor: colors.primary,
                                padding: const EdgeInsets.all(10),
                                minimumSize: const Size(40, 40),
                              ),
                            ),
                          ],
                        ),
                        if (_scopedTopics.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _scopedTopics.map((topic) {
                              return Chip(
                                label: Text(topic),
                                labelStyle: typography.caption.medium.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 11.5,
                                ),
                                deleteIcon:
                                    const Icon(Icons.close_rounded, size: 14),
                                onDeleted: () => _removeTopic(topic),
                                backgroundColor:
                                    colors.primary.withAlpha(isDark ? 35 : 20),
                                side: BorderSide(
                                  color: colors.primary.withAlpha(70),
                                ),
                                visualDensity: VisualDensity.compact,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Section 6: Workload Calculation Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 30 : 15),
                      borderRadius: AppRadius.radiusPanel,
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
                            const SizedBox(width: 6),
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
                                  valueColor: AlwaysStoppedAnimation(
                                    colors.primary,
                                  ),
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
                          _pastQuestionsCount > 0
                              ? '• $_deckCardsCount flashcards in ${_selectedDeckIds.length} scoped topics\n• $_pastQuestionsCount practice questions included'
                              : '• $_deckCardsCount flashcards in ${_selectedDeckIds.length} scoped topics',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            height: 1.4,
                            fontSize: 12,
                          ),
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.recommendedDailyPaceLabel,
                              style: typography.footnote.medium.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    colors.primary.withAlpha(isDark ? 60 : 30),
                                borderRadius: AppRadius.radiusBadge,
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

                  const SizedBox(height: 18),

                  // Section 7: Target Date & Time Selectors
                  Row(
                    children: [
                      // Date Picker Tile
                      Expanded(
                        flex: 6,
                        child: PlatformHoverBuilder(
                          builder: (context, isHovered, child) {
                            return AnimatedContainer(
                              duration: AppMotion.snappy,
                              curve: Curves.easeOutCubic,
                              child: InkWell(
                                onTap: () => unawaited(_pickDate()),
                                borderRadius: AppRadius.radiusCard,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? (isHovered
                                            ? colors.surfaceSecondary
                                                .withAlpha(220)
                                            : colors.surfaceSecondary)
                                        : (isHovered
                                            ? colors.surfaceSecondary
                                                .withAlpha(120)
                                            : colors.surfacePrimary),
                                    borderRadius: AppRadius.radiusCard,
                                    border: Border.all(
                                      color: isHovered
                                          ? colors.primary.withAlpha(
                                              isDark ? 160 : 100,
                                            )
                                          : colors.surfaceBorder,
                                    ),
                                  ),
                                  child: child,
                                ),
                              ),
                            );
                          },
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
                                  const SizedBox(width: 5),
                                  Text(
                                    l10n.targetDateLabel,
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedDate,
                                style: typography.callout.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Time Picker Tile
                      Expanded(
                        flex: 4,
                        child: PlatformHoverBuilder(
                          builder: (context, isHovered, child) {
                            return AnimatedContainer(
                              duration: AppMotion.snappy,
                              curve: Curves.easeOutCubic,
                              child: InkWell(
                                onTap: () => unawaited(_pickTime()),
                                borderRadius: AppRadius.radiusCard,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? (isHovered
                                            ? colors.surfaceSecondary
                                                .withAlpha(220)
                                            : colors.surfaceSecondary)
                                        : (isHovered
                                            ? colors.surfaceSecondary
                                                .withAlpha(120)
                                            : colors.surfacePrimary),
                                    borderRadius: AppRadius.radiusCard,
                                    border: Border.all(
                                      color: isHovered
                                          ? colors.primary.withAlpha(
                                              isDark ? 160 : 100,
                                            )
                                          : colors.surfaceBorder,
                                    ),
                                  ),
                                  child: child,
                                ),
                              ),
                            );
                          },
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
                                  const SizedBox(width: 5),
                                  Text(
                                    l10n.timePickerLabel,
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedTime,
                                style: typography.callout.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Section 8: Grade Weight Percent
                  Row(
                    children: [
                      Text(
                        l10n.gradeWeightLabel,
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [null, 0.10, 0.20, 0.30, 0.50].map((w) {
                              final isSel = _selectedWeightPercent == w;
                              final label = w == null
                                  ? l10n.optionalWeightHint
                                  : '${(w * 100).toInt()}%';
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(label),
                                  labelStyle: typography.caption.semiBold
                                      .copyWith(
                                    color: isSel
                                        ? colors.white
                                        : colors.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                  selected: isSel,
                                  selectedColor: colors.primary,
                                  backgroundColor: colors.transparent,
                                  visualDensity: VisualDensity.compact,
                                  onSelected: (_) {
                                    AppFeedback.selection();
                                    setState(() => _selectedWeightPercent = w);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Section 9: Persistent Submit & Cancel Buttons
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: l10n.cancelAction,
                          onPressed: () => context.router.pop(),
                          variant: AppButtonVariant.secondary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          text: widget.initialExam != null
                              ? l10n.updateExamCountdown
                              : l10n.saveExamCountdown,
                          isEnabled: _selectedCourse != null,
                          onPressed: () => unawaited(_submit()),
                        ),
                      ),
                    ],
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

class _PageSearchableCourseDropdown extends StatefulWidget {
  const _PageSearchableCourseDropdown({
    required this.courses,
    required this.selectedCourse,
    required this.onCourseSelected,
  });

  final List<CuratedCourseModel> courses;
  final CuratedCourseModel? selectedCourse;
  final ValueChanged<CuratedCourseModel> onCourseSelected;

  @override
  State<_PageSearchableCourseDropdown> createState() =>
      __PageSearchableCourseDropdownState();
}

class __PageSearchableCourseDropdownState
    extends State<_PageSearchableCourseDropdown> {
  bool _isExpanded = false;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  String _searchQuery = '';
  late final ScrollController _dropdownScrollController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _dropdownScrollController = ScrollController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _dropdownScrollController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    AppFeedback.selection();
    setState(() {
      _isExpanded = !_isExpanded;
      if (!_isExpanded) {
        _searchController.clear();
        _searchQuery = '';
      }
    });

    if (_isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final filtered = widget.courses.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.courseCode.toLowerCase().contains(_searchQuery) ||
          c.title.toLowerCase().contains(_searchQuery);
    }).toList();

    return TapRegion(
      onTapOutside: (_) {
        if (_isExpanded) {
          setState(() {
            _isExpanded = false;
            _searchController.clear();
            _searchQuery = '';
          });
        }
      },
      child: AnimatedContainer(
        duration: AppMotion.snappy,
        curve: AppMotion.easeOutCubic,
        decoration: BoxDecoration(
          color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          borderRadius: AppRadius.radiusCard,
          border: Border.all(
            color: _isExpanded
                ? colors.primary
                : colors.surfaceBorder.withAlpha(isDark ? 80 : 40),
            width: _isExpanded ? 1.5 : 1,
          ),
          boxShadow: _isExpanded
              ? [
                  BoxShadow(
                    color: colors.primary.withAlpha(isDark ? 35 : 15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _toggleExpanded,
              borderRadius: _isExpanded
                  ? const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.card),
                    )
                  : AppRadius.radiusCard,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.school_rounded,
                      color: colors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registered Course / Subject',
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.selectedCourse != null
                                ? '${widget.selectedCourse!.courseCode} - ${widget.selectedCourse!.title}'
                                : 'Select a course or subject',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.body.medium.copyWith(
                              color: widget.selectedCourse != null
                                  ? colors.textPrimary
                                  : colors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: AppMotion.snappy,
                      curve: AppMotion.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colors.textSecondary,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isExpanded) ...[
              Divider(
                height: 1,
                color: colors.surfaceBorder.withAlpha(isDark ? 80 : 40),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: typography.body.regular.copyWith(
                    color: colors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search course code or subject...',
                    hintStyle: typography.footnote.regular.copyWith(
                      color: colors.textSecondary.withAlpha(150),
                      fontSize: 12.5,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? colors.surfacePrimary.withAlpha(160)
                        : colors.surfaceSecondary.withAlpha(120),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.radiusPanel,
                      borderSide: BorderSide(
                        color: colors.surfaceBorder.withAlpha(isDark ? 60 : 30),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.radiusPanel,
                      borderSide: BorderSide(
                        color: colors.surfaceBorder.withAlpha(isDark ? 60 : 30),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.radiusPanel,
                      borderSide: BorderSide(
                        color: colors.primary,
                        width: 1.2,
                      ),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim().toLowerCase());
                  },
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 230),
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 16,
                        ),
                        child: Center(
                          child: Text(
                            "No courses match '$_searchQuery'",
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : Scrollbar(
                        controller: _dropdownScrollController,
                        thumbVisibility: filtered.length > 5,
                        child: ListView.builder(
                          controller: _dropdownScrollController,
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final course = filtered[index];
                            final isSelected = course.id ==
                                    widget.selectedCourse?.id ||
                                course.courseCode ==
                                    widget.selectedCourse?.courseCode;

                            return InkWell(
                              onTap: () {
                                AppFeedback.selection();
                                widget.onCourseSelected(course);
                                setState(() {
                                  _isExpanded = false;
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.primary
                                          .withAlpha(isDark ? 40 : 20)
                                      : Colors.transparent,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? colors.primary
                                            : (isDark
                                                ? colors.surfacePrimary
                                                : colors.surfaceSecondary),
                                        borderRadius: AppRadius.radiusBadge,
                                        border: Border.all(
                                          color: isSelected
                                              ? colors.primary
                                              : colors.surfaceBorder.withAlpha(
                                                  isDark ? 60 : 35,
                                                ),
                                        ),
                                      ),
                                      child: Text(
                                        course.courseCode,
                                        style:
                                            typography.caption.bold.copyWith(
                                          color: isSelected
                                              ? colors.white
                                              : colors.textPrimary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        course.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            typography.body.regular.copyWith(
                                          color: isSelected
                                              ? colors.primary
                                              : colors.textPrimary,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color: colors.primary,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}
