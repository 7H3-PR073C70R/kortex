import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Glassmorphic banner alerting candidates of an in-flight, unexpired or expired CBT exam.
/// Ticking continuously every second to display monotonic remaining time and allow 1-tap resumption.
class ResumeActiveCbtExamBanner extends StatefulWidget {
  const ResumeActiveCbtExamBanner({
    this.margin = const EdgeInsets.only(bottom: 16),
    super.key,
  });

  final EdgeInsetsGeometry margin;

  @override
  State<ResumeActiveCbtExamBanner> createState() =>
      _ResumeActiveCbtExamBannerState();
}

class _ResumeActiveCbtExamBannerState extends State<ResumeActiveCbtExamBanner> {
  Timer? _ticker;
  Map<String, dynamic>? _snapshot;
  bool _isDiscarded = false;

  @override
  void initState() {
    super.initState();
    _checkActiveSession();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _checkActiveSession();
      }
    });
  }

  void _checkActiveSession() {
    if (_isDiscarded) return;
    final snap = QuizSessionCubit.getSavedActiveSessionSnapshot();
    if (snap != _snapshot) {
      setState(() {
        _snapshot = snap;
      });
    } else {
      // Force tick rebuild to re-evaluate monotonic deadline difference
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDiscarded || _snapshot == null) {
      return const SizedBox.shrink();
    }

    final questionsRaw = _snapshot!['questions'] as List<dynamic>? ?? [];
    if (questionsRaw.isEmpty) {
      return const SizedBox.shrink();
    }

    final quizTitle =
        _snapshot!['quizTitle'] as String? ?? 'CBT Practice Test';
    final deadlineStr = _snapshot!['deadline'] as String?;
    final deadline =
        deadlineStr != null ? DateTime.tryParse(deadlineStr) : null;
    final now = DateTime.now();
    final isExpired = deadline != null && now.isAfter(deadline);
    final remainingSecs = deadline?.difference(now).inSeconds;

    final neural = context.neural;
    final typography = context.typography;
    final colors = context.colors;

    final answeredCount = questionsRaw.where((q) {
      if (q is Map) {
        final ans = q['user_selected_answer'] ?? q['userSelectedAnswer'];
        return ans != null && ans.toString().trim().isNotEmpty;
      }
      return false;
    }).length;

    final totalCount = questionsRaw.length;

    String timerLabel;
    if (deadline == null) {
      timerLabel = 'Untimed Practice';
    } else if (isExpired) {
      timerLabel = 'Time Expired';
    } else {
      final m = ((remainingSecs ?? 0) ~/ 60).toString().padLeft(2, '0');
      final s = ((remainingSecs ?? 0) % 60).toString().padLeft(2, '0');
      timerLabel = '$m:$s remaining';
    }

    final bannerColor = isExpired ? colors.error : neural.amber;

    return Padding(
      padding: widget.margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: neural.glassPanel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: bannerColor.withAlpha(120),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: bannerColor.withAlpha(30),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: bannerColor.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isExpired
                          ? Icons.alarm_off_rounded
                          : Icons.alarm_on_rounded,
                      color: bannerColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isExpired
                              ? 'Active CBT Exam • Time Expired'
                              : 'Active CBT Exam in Progress',
                          style: typography.caption.bold.copyWith(
                            color: bannerColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          quizTitle,
                          style: typography.body.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: colors.textSecondary.withAlpha(150),
                    ),
                    tooltip: 'Discard Exam Session',
                    onPressed: () async {
                      AppFeedback.selection();
                      setState(() {
                        _isDiscarded = true;
                      });
                      final cubit = locator.isRegistered<QuizSessionCubit>()
                          ? locator<QuizSessionCubit>()
                          : null;
                      await cubit?.clearActiveSession();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: bannerColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: bannerColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timerLabel,
                          style: typography.caption.bold.copyWith(
                            color: bannerColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$answeredCount/$totalCount answered',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  ShrinkableButton(
                    onTap: () async {
                      AppFeedback.selection();
                      final router = context.router;
                      final cubit = locator.isRegistered<QuizSessionCubit>()
                          ? locator<QuizSessionCubit>()
                          : null;
                      if (cubit != null) {
                        final restored = await cubit.restoreActiveSession();
                        if (mounted) {
                          if (restored) {
                            unawaited(
                              router.push(
                                QuizWorkspaceRoute(
                                  deckId: 'active-session',
                                  deckTitle: quizTitle,
                                  assessmentMode:
                                      AssessmentMode.examSimulationMode,
                                ),
                              ),
                            );
                          } else {
                            // If expired and submitted, refresh banner state
                            _checkActiveSession();
                          }
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: bannerColor,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: bannerColor.withAlpha(60),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        isExpired ? 'Submit Exam' : 'Resume Exam',
                        style: typography.caption.bold.copyWith(
                          color: Colors.white,
                        ),
                      ),
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
