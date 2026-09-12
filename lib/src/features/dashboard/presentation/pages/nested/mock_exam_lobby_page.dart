import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class MockExamLobbyPage extends HookWidget {
  const MockExamLobbyPage({
    @PathParam('examId') required this.examId,
    required this.examName,
    super.key,
  });

  final String examId;
  final String examName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final selectedModeIndex = useState<int>(0);
    final isStarting = useState<bool>(false);

    final simulationModes = [
      (
        title: l10n.mockExamModeStandardTitle,
        subtitle: l10n.mockExamModeStandardSubtitle,
        icon: Icons.timer_rounded,
      ),
      (
        title: l10n.mockExamModeSocraticTitle,
        subtitle: l10n.mockExamModeSocraticSubtitle,
        icon: Icons.psychology_rounded,
      ),
      (
        title: l10n.mockExamModeDrillTitle,
        subtitle: l10n.mockExamModeDrillSubtitle,
        icon: Icons.track_changes_rounded,
      ),
      (
        title: 'Millionaire Arcade',
        subtitle: '12-rung gamified dopamine ascent with safe checkpoints & lifelines',
        icon: Icons.military_tech_rounded,
      ),
    ];

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
          onPressed: () => context.router.pop(),
        ),
        title: Text(
          l10n.mockExamLobbyTitle,
          style: typography.title3.bold.copyWith(color: colors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Exam Banner
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          colors.primary.withAlpha(isDark ? 60 : 35),
                          colors.syllabotAccent.withAlpha(isDark ? 40 : 20),
                        ],
                      ),
                      border: Border.all(
                        color: colors.primary.withAlpha(isDark ? 120 : 80),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          examName,
                          style: typography.title3.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.mockExamLobbyDescription,
                          style: typography.footnote.regular.copyWith(
                            color: colors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                l10n.mockExamSelectMode,
                style: typography.callout.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),

              // Simulation Modes Selection
              ...List.generate(simulationModes.length, (index) {
                final mode = simulationModes[index];
                final isSelected = selectedModeIndex.value == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ShrinkableButton(
                    onTap: () {
                      unawaited(HapticFeedback.lightImpact());
                      selectedModeIndex.value = index;
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isSelected
                              ? colors.primary.withAlpha(isDark ? 50 : 25)
                              : (isDark
                                    ? colors.surfaceSecondary.withAlpha(140)
                                    : colors.surfacePrimary.withAlpha(200)),
                          border: Border.all(
                            color: isSelected
                                ? colors.primary
                                : (isDark
                                      ? colors.surfaceBorderHighlight.withAlpha(
                                          60,
                                        )
                                      : colors.surfaceBorder.withAlpha(120)),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              mode.icon,
                              size: 22,
                              color: isSelected
                                  ? colors.primary
                                  : colors.textMuted,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mode.title,
                                    style: typography.caption.bold.copyWith(
                                      color: colors.textPrimary,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    mode.subtitle,
                                    style: typography.footnote.regular.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                size: 20,
                                color: colors.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),

              const Spacer(),

              // Start Simulation Button
              ShrinkableButton(
                onTap: isStarting.value
                    ? null
                    : () async {
                        unawaited(HapticFeedback.lightImpact());
                        isStarting.value = true;
                        final selectedMode =
                            simulationModes[selectedModeIndex.value];
                        final AssessmentMode assessmentMode;
                        final int? duration;
                        final int questionCount;

                        if (selectedModeIndex.value == 0) {
                          assessmentMode = AssessmentMode.examSimulationMode;
                          duration = 45;
                          questionCount = 20;
                        } else if (selectedModeIndex.value == 1) {
                          assessmentMode = AssessmentMode.discoveryMode;
                          duration = 30;
                          questionCount = 15;
                        } else if (selectedModeIndex.value == 2) {
                          assessmentMode = AssessmentMode.discoveryMode;
                          duration = null;
                          questionCount = 10;
                        } else {
                          assessmentMode = AssessmentMode.millionaireMode;
                          duration = null;
                          questionCount = 12;
                        }

                        locator<DashboardBloc>().add(
                          DashboardExamStarted(
                            examId: examId,
                            subject: examName,
                          ),
                        );

                        List<QuizQuestionEntity>? initialQuestions;
                        if (locator.isRegistered<PastQuestionsRepository>()) {
                          try {
                            ExamCategory? category;
                            final query = '$examName $examId'.toLowerCase();
                            for (final cat in ExamCategory.values) {
                              if (query.contains(cat.name.toLowerCase()) ||
                                  query.contains(cat.code.toLowerCase())) {
                                category = cat;
                                break;
                              }
                            }
                            final result = await locator<PastQuestionsRepository>()
                                .getPastQuestions(
                              examCategory: category,
                              searchQuery: category == null ? examName : null,
                            );
                            final questions = result.fold(
                              (f) => <PastQuestionEntity>[],
                              (list) => list,
                            );
                            if (questions.isNotEmpty) {
                              final shuffled =
                                  List<PastQuestionEntity>.from(questions)
                                    ..shuffle();
                              initialQuestions = shuffled
                                  .take(questionCount)
                                  .map(QuizQuestionEntity.fromPastQuestion)
                                  .toList();
                            }
                          } on Object catch (_) {
                            // Fallback handled by QuizRepositoryImpl or QuizWorkspace
                          }
                        }

                        if (!context.mounted) return;
                        isStarting.value = false;

                        unawaited(
                          context.router.push(
                            QuizWorkspaceRoute(
                              deckId: examId,
                              deckTitle: '$examName (${selectedMode.title})',
                              subject: examName,
                              durationMinutes: duration,
                              assessmentMode: assessmentMode,
                              initialQuestions: initialQuestions,
                            ),
                          ),
                        );
                      },
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withAlpha(90),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: isStarting.value
                      ? AppLogoLoader(
                          size: 20,
                          color: colors.white,
                          showMessage: false,
                        )
                      : Text(
                          l10n.mockExamBeginButton,
                          style: typography.callout.bold.copyWith(
                            color: colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
