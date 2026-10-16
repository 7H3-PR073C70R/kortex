import 'package:flutter/material.dart';

/// Pure helper utilities for High School Subject presentation.
class HighSchoolSubjectHelpers {
  const HighSchoolSubjectHelpers._();

  /// Standardizes academic department strings into concise stream labels.
  static String cleanStream(String department) {
    if (department.contains('Core')) return 'Core';
    if (department.contains('Science')) return 'Sciences';
    if (department.contains('Commercial')) return 'Commercial';
    if (department.contains('Art')) return 'Arts';
    if (department.contains('SAT')) return 'SAT Prep';
    final parts = department.split('-');
    return parts.last.trim();
  }

  /// Parses hex color strings safely into [Color] with a fallback.
  static Color parseHexColor(String hex, Color fallback) {
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } on Object catch (_) {
      return fallback;
    }
  }
}
