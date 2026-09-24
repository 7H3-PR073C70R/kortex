import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
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
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

class AddExamModalSheet extends StatefulWidget {
  const AddExamModalSheet({
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

  static Future<void> show(
    BuildContext context, {
    ExamEventEntity? initialExam,
    String? preselectedCourseCode,
    String? preselectedCourseTitle,
    AssessmentType? preselectedType,
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
            constraints: const BoxConstraints(maxWidth: 640),
            child: AddExamModalSheet(
              initialExam: initialExam,
              preselectedCourseCode: preselectedCourseCode,
              preselectedCourseTitle: preselectedCourseTitle,
              preselectedType: preselectedType,
            ),
          ),
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

  late final TextEditingController _topicController;

  @override
  void initState() {
    super.initState();
    _selectedType =
        widget.initialExam?.assessmentType ??
        widget.preselectedType ??
        AssessmentType.finalExam;
    _nameController = TextEditingController(
      text: widget.initialExam?.examName ?? '',
    );
    _topicController = TextEditingController();
    if (widget.initialExam != null && widget.initialExam!.examName.isNotEmpty) {
      _userCustomizedTitle = true;
    }

    _selectedDate =
        widget.initialExam?.targetDate ??
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
    if (text.isNotEmpty && !_scopedTopics.contains(text)) {
      AppFeedback.selection();
      setState(() {
        _scopedTopics.add(text);
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
      final targetCode =
          widget.preselectedCourseCode ?? widget.initialExam?.subjectTrack;
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

    _syncDefaultTitleAndDecks();
    unawaited(_calculateWorkload());
  }

  void _syncDefaultTitleAndDecks() {
    if (_selectedCourse == null) return;

    // Load available study decks for this course
    if (locator.isRegistered<DecksBloc>()) {
      final all = locator<DecksBloc>().state.allDecks;
      final courseCode = _selectedCourse!.courseCode.toLowerCase();
      final courseTitle = _selectedCourse!.title.toLowerCase();
      _courseDecks = all.where((d) {
        final matchId = d.courseId != null && d.courseId == _selectedCourse!.id;
        final matchCode = d.courseCode != null &&
            d.courseCode!.toLowerCase() == courseCode;
        final matchSubj = d.subject.toLowerCase() == courseTitle ||
            d.subject.toLowerCase() == courseCode;
        return matchId || matchCode || matchSubj;
      }).toList();

      // If no decks were previously selected and we have decks, select all by default
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
      // If user hasn't explicitly customized, keep the title in sync
      if (!_userCustomizedTitle && _selectedCourse != null) {
        _nameController.text =
            type.defaultNameForCourse(_selectedCourse!.courseCode);
      }
      // If creating new assessment, nudge date to suggested horizon
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
      // 1. Sum cards strictly from selected / scoped study decks
      for (final d in _courseDecks) {
        if (_selectedDeckIds.isEmpty || _selectedDeckIds.contains(d.id)) {
          deckCards += d.totalCards;
        }
      }

      // 2. For high-stakes exams (Midterms, Finals, Mocks), include past questions if secondary track
      final isHighStakes =
          _selectedType == AssessmentType.finalExam ||
          _selectedType == AssessmentType.mockExam ||
          _selectedType == AssessmentType.midterm;

      if (isHighStakes) {
        try {
          final authBloc = locator.isRegistered<AuthBloc>()
              ? locator<AuthBloc>()
              : null;
          final track = (authBloc?.state.userProfile?.targetTrack ?? 'WAEC')
              .toUpperCase();
          final isSecondary =
              track.contains('WAEC') ||
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
        : (widget.initialExam?.subjectTrack ?? 'Academic Course');

    final workload = _totalWorkload > 0 ? _totalWorkload : 50;

    if (widget.initialExam != null) {
      unawaited(
        cubit.updateExamCountdown(
          examId: widget.initialExam!.id,
          examName: examName,
          targetDate: targetDateTime,
          subjectTrack: courseIdentifier,
          assessmentType: _selectedType,
          scopedDeckIds: _selectedDeckIds.toList(),
          scopedTopics: _scopedTopics,
          weightPercent: _selectedWeightPercent,
          totalCardsCount: workload,
        ),
      );
    } else {
      unawaited(
        cubit.addExamCountdown(
          examName: examName,
          targetDate: targetDateTime,
          subjectTrack: courseIdentifier,
          assessmentType: _selectedType,
          scopedDeckIds: _selectedDeckIds.toList(),
          scopedTopics: _scopedTopics,
          weightPercent: _selectedWeightPercent,
          totalCardsCount: workload,
        ),
      );
    }

    AppFeedback.heavy();
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag handle indicator
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

                // Sheet Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.initialExam != null
                          ? 'Edit Assessment'
                          : 'Add Academic Assessment',
                      style: typography.title3.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: colors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Assessment Type Selector Chips
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
                              horizontal: 12,
                              vertical: 7,
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
                                  size: 14,
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
                        borderRadius: AppRadius.radiusCard,
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
                          _userCustomizedTitle = false;
                        });
                        _syncDefaultTitleAndDecks();
                        unawaited(_calculateWorkload());
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // Assessment Name Field
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
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // Scoped Topics / Decks Section
                if (_courseDecks.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
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
                                  size: 15,
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
                                    style: typography.caption.semiBold.copyWith(
                                      color: colors.primary,
                                      fontSize: 11,
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
                                    style: typography.caption.semiBold.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _courseDecks.map((deck) {
                            final isSelected =
                                _selectedDeckIds.contains(deck.id);
                            return FilterChip(
                              label: Text('${deck.title} (${deck.totalCards})'),
                              labelStyle: typography.caption.regular.copyWith(
                                color: isSelected
                                    ? colors.primary
                                    : colors.textSecondary,
                                fontSize: 11,
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
                              onSelected: (_) => _toggleDeckSelection(deck.id),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Scoped Topics / Syllabus Chapters Section
                Container(
                  padding: const EdgeInsets.all(12),
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
                            size: 14,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.scopedTopicsTitle,
                            style: typography.caption.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 12,
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
                                fontSize: 12.5,
                              ),
                              decoration: InputDecoration(
                                hintText: l10n.addTopicHint,
                                hintStyle: typography.caption.regular.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
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
                            icon: const Icon(Icons.add_rounded, size: 16),
                            onPressed: _addTopic,
                            style: IconButton.styleFrom(
                              backgroundColor: colors.primary,
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(36, 36),
                            ),
                          ),
                        ],
                      ),
                      if (_scopedTopics.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _scopedTopics.map((topic) {
                            return Chip(
                              label: Text(topic),
                              labelStyle: typography.caption.medium.copyWith(
                                color: colors.textPrimary,
                                fontSize: 11,
                              ),
                              deleteIcon:
                                  const Icon(Icons.close_rounded, size: 13),
                              onDeleted: () => _removeTopic(topic),
                              backgroundColor:
                                  colors.primary.withAlpha(isDark ? 35 : 20),
                              side: BorderSide(
                                color: colors.primary.withAlpha(70),
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Automatic Internal Workload Calculation Card
                Container(
                  padding: const EdgeInsets.all(14),
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
                            size: 16,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.estimatedExamWorkload,
                            style: typography.callout.bold.copyWith(
                              color: colors.primary,
                              fontSize: 12.5,
                            ),
                          ),
                          const Spacer(),
                          if (_isCalculatingWorkload)
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                valueColor: AlwaysStoppedAnimation(
                                  colors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _totalWorkload > 0
                            ? l10n.examTotalStudyItems(_totalWorkload)
                            : l10n.examNoStudyItems,
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _pastQuestionsCount > 0
                            ? '• $_deckCardsCount flashcards in ${_selectedDeckIds.length} scoped topics\n• $_pastQuestionsCount practice questions included'
                            : '• $_deckCardsCount flashcards in ${_selectedDeckIds.length} scoped topics',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          height: 1.35,
                          fontSize: 11.5,
                        ),
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.recommendedDailyPaceLabel,
                            style: typography.footnote.medium.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(isDark ? 60 : 30),
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

                const SizedBox(height: 14),

                // Date & Time Picker Row
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
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? (isHovered
                                            ? colors.surfaceSecondary.withAlpha(
                                                220,
                                              )
                                            : colors.surfaceSecondary)
                                      : (isHovered
                                            ? colors.surfaceSecondary.withAlpha(
                                                120,
                                              )
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
                                  size: 13,
                                  color: colors.textSecondary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  l10n.targetDateLabel,
                                  style: typography.caption.regular.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              formattedDate,
                              style: typography.callout.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

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
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? (isHovered
                                            ? colors.surfaceSecondary.withAlpha(
                                                220,
                                              )
                                            : colors.surfaceSecondary)
                                      : (isHovered
                                            ? colors.surfaceSecondary.withAlpha(
                                                120,
                                              )
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
                                  size: 13,
                                  color: colors.textSecondary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  l10n.timePickerLabel,
                                  style: typography.caption.regular.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              formattedTime,
                              style: typography.callout.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Optional Grade Weighting Row
                Row(
                  children: [
                    Text(
                      l10n.gradeWeightLabel,
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
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
                                      fontSize: 11,
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

                const SizedBox(height: 20),

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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
