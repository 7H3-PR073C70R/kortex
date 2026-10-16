import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/curate_courses_cubit.dart';
import 'package:kortex/src/shared/widgets/app_dialog.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

/// Opens dialog to input custom course code, title, and department.
Future<void> showAddCustomCourseDialog({
  required BuildContext context,
  required String initialSearchText,
  required CurateCoursesCubit cubit,
}) async {
  final codeController = TextEditingController(
    text: initialSearchText.trim(),
  );
  final titleController = TextEditingController();
  final deptController = TextEditingController();

  await AppDialog.show<void>(
    context: context,
    title: 'Add Custom Subject',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        AppTextField(
          controller: codeController,
          label: 'Course Code (e.g. CSC 201, MTH 101)',
          hintText: 'Enter course code (e.g. CSC 201)',
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: titleController,
          label: 'Course Title (Optional)',
          hintText: 'e.g. Data Structures & Algorithms',
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: deptController,
          label: 'Department / Faculty (Optional)',
          hintText: 'e.g. Computer Science',
        ),
      ],
    ),
    primaryActionText: 'Add Course',
    onPrimaryAction: () {
      final code = codeController.text.trim();
      final title = titleController.text.trim();
      if (code.isEmpty && title.isEmpty) return;

      cubit.addCustomCourse(
        courseCode: code.isNotEmpty ? code : title,
        title: title.isNotEmpty ? title : code,
        department: deptController.text.trim(),
      );
      Navigator.of(context).pop();
    },
    secondaryActionText: 'Cancel',
    onSecondaryAction: () => Navigator.of(context).pop(),
  );
}
