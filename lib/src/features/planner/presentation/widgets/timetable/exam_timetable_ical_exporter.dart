import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';

/// Helper utility for serializing exam events to iCalendar (.ics) format
/// and copying to system clipboard.
class ExamTimetableIcalExporter {
  static void exportToClipboard(
    BuildContext context,
    List<ExamEventEntity> exams,
  ) {
    AppFeedback.light();
    final buffer = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//Kortexify//Exam Timetable//EN');

    for (final exam in exams) {
      final dt = exam.targetDate.toUtc();
      final dtStr = DateFormat("yyyyMMdd'T'HHmmss'Z'").format(dt);
      final weight = (exam.effectiveWeightPercent > 1.0
              ? exam.effectiveWeightPercent
              : exam.effectiveWeightPercent * 100)
          .toInt();
      buffer
        ..writeln('BEGIN:VEVENT')
        ..writeln('SUMMARY:${exam.examName} (${exam.subjectTrack})')
        ..writeln(
          'DESCRIPTION:Assessment (${exam.assessmentType.displayName}) - Weight: $weight%',
        )
        ..writeln('DTSTART:$dtStr')
        ..writeln('DTEND:$dtStr')
        ..writeln('STATUS:CONFIRMED')
        ..writeln('END:VEVENT');
    }
    buffer.writeln('END:VCALENDAR');

    unawaited(Clipboard.setData(ClipboardData(text: buffer.toString())));
    context.showSnackBar(
      message:
          'iCal timetable (.ics) copied to clipboard! Ready for Google Calendar.',
      type: SnackBarType.success,
    );
  }
}
