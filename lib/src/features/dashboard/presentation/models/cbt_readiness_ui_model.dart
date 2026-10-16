import 'package:flutter/material.dart';
import 'package:kortex/src/features/quiz/domain/services/cbt_readiness_service.dart';

export 'package:kortex/src/features/quiz/domain/services/cbt_readiness_service.dart';

/// Presentation layer extension on CbtReadinessResult providing Flutter UI types
extension CbtReadinessResultUiExtension on CbtReadinessResult {
  /// Resolves the presentation Color corresponding to statusColorValue
  Color get statusColor => Color(statusColorValue);

  /// Presentation icon representing the diagnostic tier
  IconData get statusIcon {
    switch (statusTier) {
      case CbtReadinessStatusTier.diagnosticPending:
        return Icons.pending_actions_rounded;
      case CbtReadinessStatusTier.onTrack:
        return Icons.check_circle_rounded;
      case CbtReadinessStatusTier.acceleratePrep:
        return Icons.bolt_rounded;
      case CbtReadinessStatusTier.needsTriage:
        return Icons.warning_amber_rounded;
    }
  }
}

/// Presentation layer extension on SubjectReadinessBreakdown providing Flutter UI types
extension SubjectReadinessBreakdownUiExtension on SubjectReadinessBreakdown {
  /// Resolves the presentation Color corresponding to statusColorValue
  Color? get statusColor =>
      statusColorValue != null ? Color(statusColorValue!) : null;
}
