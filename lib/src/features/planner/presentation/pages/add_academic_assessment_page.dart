import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/widgets/assessment/assessment_action_buttons.dart';
import 'package:kortex/src/features/planner/presentation/widgets/assessment/assessment_date_time_pickers_section.dart';
import 'package:kortex/src/features/planner/presentation/widgets/assessment/assessment_decks_selector_section.dart';
import 'package:kortex/src/features/planner/presentation/widgets/assessment/assessment_form_coordinator.dart';
import 'package:kortex/src/features/planner/presentation/widgets/assessment/assessment_name_field.dart';
import 'package:kortex/src/features/planner/presentation/widgets/assessment/assessment_searchable_course_dropdown.dart';
import 'package:kortex/src/features/planner/presentation/widgets/assessment/assessment_topics_tagging_section.dart';
import 'package:kortex/src/features/planner/presentation/widgets/assessment/assessment_type_selector.dart';
import 'package:kortex/src/features/planner/presentation/widgets/assessment/assessment_weight_selector_section.dart';
import 'package:kortex/src/features/planner/presentation/widgets/assessment/assessment_workload_calculation_card.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';

@RoutePage()
class AddAcademicAssessmentPage extends StatefulWidget {
  const AddAcademicAssessmentPage({
    this.initialExam,
    this.preselectedCourseCode,
    this.preselectedCourseTitle,
    this.preselectedType,
    this.localStorageService,
    this.decksBloc,
    this.authBloc,
    this.cramPlannerCubit,
    this.pastQuestionsRepository,
    super.key,
  });

  final ExamEventEntity? initialExam;
  final String? preselectedCourseCode;
  final String? preselectedCourseTitle;
  final AssessmentType? preselectedType;

  final LocalStorageService? localStorageService;
  final DecksBloc? decksBloc;
  final AuthBloc? authBloc;
  final CramPlannerCubit? cramPlannerCubit;
  final PastQuestionsRepository? pastQuestionsRepository;

  @override
  State<AddAcademicAssessmentPage> createState() =>
      _AddAcademicAssessmentPageState();
}

class _AddAcademicAssessmentPageState
    extends State<AddAcademicAssessmentPage> {
  final _formKey = GlobalKey<FormState>();
  late final AssessmentFormCoordinator _coordinator;

  @override
  void initState() {
    super.initState();
    _coordinator = AssessmentFormCoordinator(
      initialExam: widget.initialExam,
      preselectedCourseCode: widget.preselectedCourseCode,
      preselectedCourseTitle: widget.preselectedCourseTitle,
      preselectedType: widget.preselectedType,
      localStorageService: widget.localStorageService,
      decksBloc: widget.decksBloc,
      authBloc: widget.authBloc,
      cramPlannerCubit: widget.cramPlannerCubit ??
          (locator.isRegistered<CramPlannerCubit>()
              ? locator<CramPlannerCubit>()
              : null),
      pastQuestionsRepository: widget.pastQuestionsRepository,
    );
  }

  @override
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return ListenableBuilder(
      listenable: _coordinator,
      builder: (context, _) {
        final title = widget.initialExam != null
            ? 'Edit Assessment'
            : 'Add Academic Assessment';

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppAdaptiveAppBar(
            backgroundColor: colors.backgroundPrimary,
            titleText: title,
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
                      AssessmentTypeSelector(
                        selectedType: _coordinator.selectedType,
                        onTypeChanged: _coordinator.onTypeChanged,
                      ),
                      const SizedBox(height: 20),

                      // Section 2: Registered Course / Subject Dropdown
                      if (_coordinator.registeredCourses.isNotEmpty) ...[
                        AssessmentSearchableCourseDropdown(
                          courses: _coordinator.registeredCourses,
                          selectedCourse: _coordinator.selectedCourse,
                          onCourseSelected: _coordinator.onCourseSelected,
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Section 3: Assessment Name Field
                      AssessmentNameField(
                        controller: _coordinator.nameController,
                        selectedType: _coordinator.selectedType,
                        onChanged: _coordinator.onNameChanged,
                      ),
                      const SizedBox(height: 18),

                      // Section 4: Scoped Flashcard Decks Filter
                      if (_coordinator.courseDecks.isNotEmpty) ...[
                        AssessmentDecksSelectorSection(
                          courseDecks: _coordinator.courseDecks,
                          selectedDeckIds: _coordinator.selectedDeckIds,
                          onToggleDeck: _coordinator.toggleDeckSelection,
                          onSelectAll: _coordinator.selectAllDecks,
                          onClearAll: _coordinator.clearAllDecks,
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Section 5: Syllabus Topics / Chapters Tagging
                      AssessmentTopicsTaggingSection(
                        topicController: _coordinator.topicController,
                        scopedTopics: _coordinator.scopedTopics,
                        onAddTopic: _coordinator.addTopic,
                        onRemoveTopic: _coordinator.removeTopic,
                      ),
                      const SizedBox(height: 18),

                      // Section 6: Workload Calculation Card
                      AssessmentWorkloadCalculationCard(
                        isCalculatingWorkload: _coordinator.isCalculatingWorkload,
                        totalWorkload: _coordinator.totalWorkload,
                        deckCardsCount: _coordinator.deckCardsCount,
                        scopedDecksCount: _coordinator.selectedDeckIds.length,
                        pastQuestionsCount: _coordinator.pastQuestionsCount,
                        dailyTarget: _coordinator.dailyTarget,
                      ),
                      const SizedBox(height: 18),

                      // Section 7: Target Date & Time Selectors
                      AssessmentDateTimePickersSection(
                        selectedDate: _coordinator.selectedDate,
                        selectedTime: _coordinator.selectedTime,
                        onPickDate: () => unawaited(_coordinator.pickDate(context)),
                        onPickTime: () => unawaited(_coordinator.pickTime(context)),
                      ),
                      const SizedBox(height: 18),

                      // Section 8: Grade Weight Percent
                      AssessmentWeightSelectorSection(
                        selectedWeightPercent: _coordinator.selectedWeightPercent,
                        onWeightSelected: _coordinator.onWeightSelected,
                      ),
                      const SizedBox(height: 32),

                      // Section 9: Persistent Submit & Cancel Buttons
                      AssessmentActionButtons(
                        isEditing: widget.initialExam != null,
                        isEnabled: _coordinator.selectedCourse != null,
                        onCancel: () => context.router.pop(),
                        onSubmit: () => unawaited(
                          _coordinator.submit(
                            context: context,
                            formKey: _formKey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
