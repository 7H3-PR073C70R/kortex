import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/pages/add_academic_assessment_page.dart';

/// Legacy modal sheet wrapper delegating to [AddAcademicAssessmentPage].
///
/// Retained for backwards compatibility across legacy routes and callers.
class AddExamModalSheet extends StatelessWidget {
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
    CramPlannerCubit? cubit,
  }) {
    return context.router.push(
      AddAcademicAssessmentRoute(
        initialExam: initialExam,
        preselectedCourseCode: preselectedCourseCode,
        preselectedCourseTitle: preselectedCourseTitle,
        preselectedType: preselectedType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AddAcademicAssessmentPage(
      initialExam: initialExam,
      preselectedCourseCode: preselectedCourseCode,
      preselectedCourseTitle: preselectedCourseTitle,
      preselectedType: preselectedType,
    );
  }
}
