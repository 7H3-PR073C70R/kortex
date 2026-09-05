import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class PastQuestionsBoardPage extends StatelessWidget {
  const PastQuestionsBoardPage({
    @queryParam this.initialExamCode,
    super.key,
  });

  final String? initialExamCode;

  static ExamCategory resolveExamCategory(String? code, String? userTrack) {
    final target = (code != null && code.isNotEmpty)
        ? code
        : (userTrack != null && userTrack.isNotEmpty ? userTrack : 'WAEC');
    final upper = target.toUpperCase();
    if (upper.contains('WAEC') || upper.contains('WASSCE')) {
      return ExamCategory.waec;
    }
    if (upper.contains('JAMB') || upper.contains('UTME')) {
      return ExamCategory.jamb;
    }
    if (upper.contains('SAT')) return ExamCategory.sat;
    if (upper.contains('TOEFL')) return ExamCategory.toefl;
    if (upper.contains('IELTS')) return ExamCategory.ielts;
    if (upper.contains('MED')) return ExamCategory.medicine;
    if (upper.contains('LAW')) return ExamCategory.law;
    if (upper.contains('ENG')) return ExamCategory.engineering;
    if (upper.contains('BUS') || upper.contains('ACC')) {
      return ExamCategory.business;
    }
    if (upper.contains('CS') || upper.contains('COMP')) {
      return ExamCategory.computerScience;
    }
    return ExamCategory.waec;
  }

  @override
  Widget build(BuildContext context) {
    final userTrack = context.read<AuthBloc?>()?.state.userProfile?.targetTrack;
    final initialExam = resolveExamCategory(initialExamCode, userTrack);

    return BlocProvider<PastQuestionsBloc>(
      create: (_) => locator<PastQuestionsBloc>()
        ..add(LoadPastQuestionsEvent(examCategory: initialExam)),
      child: _PastQuestionsBoardView(userTrack: userTrack ?? 'WAEC'),
    );
  }
}

class _PastQuestionsBoardView extends HookWidget {
  const _PastQuestionsBoardView({required this.userTrack});

  final String userTrack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final l10n = context.l10n;
    final searchController = useTextEditingController();

    return Scaffold(
      backgroundColor: isDark ? colors.backgroundPrimary : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Q-Bank & CBT Drills',
          style: typography.title2.bold.copyWith(color: colors.textPrimary),
        ),
        actions: [
          BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
            builder: (context, state) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 50 : 25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.primary.withAlpha(isDark ? 80 : 50),
                      ),
                    ),
                    child: Text(
                      l10n.pastQuestionsProgressDone(
                        state.answeredQuestions,
                        state.totalQuestions,
                      ),
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 1. Hero Track & Practice Card
                _HeroTrackBanner(userTrack: userTrack),

                // 2. Tailored Exam Category Filter
                _TailoredExamCategoryBar(userTrack: userTrack),

                // 3. Search & Subject Filter Row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: AppTextField(
                    controller: searchController,
                    hintText: 'Search topic, keyword or formula...',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                    onChanged: (query) {
                      context.read<PastQuestionsBloc>().add(
                            LoadPastQuestionsEvent(searchQuery: query),
                          );
                    },
                  ),
                ),

                // 4. Subject & Year Pills
                const _SubjectAndYearFilterRow(),
                const SizedBox(height: 6),

                // 5. Questions Feed
                Expanded(
                  child: BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
                    builder: (context, state) {
                      if (state.status == PastQuestionsStatus.loading) {
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: const [
                            Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: AppLogoLoader(
                                  size: 56,
                                  message: 'Loading official past questions...',
                                ),
                              ),
                            ),
                            ShimmerPlaceholder(height: 160, borderRadius: 20),
                            SizedBox(height: 14),
                            ShimmerPlaceholder(height: 160, borderRadius: 20),
                          ],
                        );
                      }

                      if (state.questions.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: 48,
                                  color: colors.textSecondary.withAlpha(120),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No Past Questions Found',
                                  style: typography.title3.bold.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Try selecting a different subject or clearing your search filters.',
                                  textAlign: TextAlign.center,
                                  style: typography.footnote.regular.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        physics: const BouncingScrollPhysics(),
                        itemCount: state.questions.length,
                        itemBuilder: (context, index) {
                          final question = state.questions[index];
                          return _PastQuestionCard(
                            question: question,
                            isInstantFeedback: state.isInstantFeedbackMode,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

            // 6. Floating Bottom Quick Test Dock
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: _FloatingTestDock(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroTrackBanner extends StatelessWidget {
  const _HeroTrackBanner({required this.userTrack});

  final String userTrack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
      builder: (context, state) {
        final exam = state.selectedExam;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary.withAlpha(isDark ? 55 : 30),
                    colors.surfaceSecondary.withAlpha(isDark ? 180 : 230),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 80 : 45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withAlpha(isDark ? 30 : 15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 60 : 30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 13,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              exam.displayName,
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${state.totalQuestions} Questions Available',
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${exam.displayName} Official Question Bank',
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Practice real exam questions or simulate high-pressure CBT tests with instant analytics.',
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ShrinkableButton(
                          onTap: () => _showTestConfigSheet(context, state),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary.withAlpha(90),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_circle_filled_rounded,
                                  color: colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Take CBT Practice Test',
                                  style: typography.callout.bold.copyWith(
                                    color: colors.white,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
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
        );
      },
    );
  }

  void _showTestConfigSheet(BuildContext context, PastQuestionsState state) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    var selectedCount = state.questions.length > 10 ? 10 : state.questions.length;
    var isTimedMode = true;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final availableTotal = state.questions.length;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.surfaceBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Configure ${state.selectedExam.displayName} Test',
                      style: typography.title3.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select question count and test mode for this session.',
                      style: typography.footnote.regular.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Mode Selection
                    Text(
                      'Test Simulation Mode',
                      style: typography.caption.bold.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ModeOptionCard(
                            title: 'Timed CBT Exam',
                            subtitle: 'Strict timer & scoring',
                            icon: Icons.timer_outlined,
                            isSelected: isTimedMode,
                            onTap: () => setSheetState(() => isTimedMode = true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ModeOptionCard(
                            title: 'Self-Paced Drill',
                            subtitle: 'Instant explanations',
                            icon: Icons.school_outlined,
                            isSelected: !isTimedMode,
                            onTap: () => setSheetState(() => isTimedMode = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Question Count Pills
                    Text(
                      'Question Count',
                      style: typography.caption.bold.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [5, 10, 20, availableTotal].map((count) {
                        if (count > availableTotal && count != availableTotal) {
                          return const SizedBox.shrink();
                        }
                        final label = count == availableTotal ? 'All ($count)' : '$count Qs';
                        final isSelected = selectedCount == count;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (_) => setSheetState(() => selectedCount = count),
                            selectedColor: colors.primary.withAlpha(isDark ? 60 : 35),
                            backgroundColor: colors.surfaceSecondary.withAlpha(100),
                            labelStyle: typography.caption.bold.copyWith(
                              color: isSelected ? colors.primary : colors.textSecondary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Launch CTA
                    ShrinkableButton(
                      onTap: availableTotal == 0
                          ? null
                          : () {
                              Navigator.pop(bottomSheetContext);
                              final testQuestions = state.questions
                                  .take(selectedCount)
                                  .map(QuizQuestionEntity.fromPastQuestion)
                                  .toList();

                              unawaited(
                                context.router.push(
                                  QuizWorkspaceRoute(
                                    deckId: 'cbt_${state.selectedExam.code}',
                                    deckTitle:
                                        '${state.selectedExam.displayName} (${state.selectedSubject == 'All' ? 'General' : state.selectedSubject})',
                                    subject: state.selectedSubject == 'All'
                                        ? state.selectedExam.displayName
                                        : state.selectedSubject,
                                    durationMinutes: isTimedMode
                                        ? (selectedCount * 1.5).round().clamp(5, 60)
                                        : null,
                                    initialQuestions: testQuestions,
                                  ),
                                ),
                              );
                            },
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withAlpha(90),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'Start Test ($selectedCount Questions)',
                            style: typography.callout.bold.copyWith(
                              color: colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
}

class _ModeOptionCard extends StatelessWidget {
  const _ModeOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ShrinkableButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withAlpha(isDark ? 40 : 20)
              : colors.surfaceSecondary.withAlpha(80),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.surfaceBorder.withAlpha(80),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? colors.primary : colors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: typography.caption.bold.copyWith(
                      color: isSelected ? colors.primary : colors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TailoredExamCategoryBar extends StatelessWidget {
  const _TailoredExamCategoryBar({required this.userTrack});

  final String userTrack;

  List<ExamCategory> _getTailoredCategories(String track) {
    final upper = track.toUpperCase();
    if (upper.contains('WAEC') || upper.contains('WASSCE')) {
      return const [ExamCategory.waec, ExamCategory.jamb];
    }
    if (upper.contains('JAMB') || upper.contains('UTME')) {
      return const [ExamCategory.jamb, ExamCategory.waec];
    }
    if (upper.contains('SAT')) {
      return const [ExamCategory.sat, ExamCategory.toefl, ExamCategory.ielts];
    }
    return const [
      ExamCategory.computerScience,
      ExamCategory.medicine,
      ExamCategory.law,
      ExamCategory.engineering,
      ExamCategory.business,
      ExamCategory.waec,
      ExamCategory.jamb,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final tailored = _getTailoredCategories(userTrack);

    return BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
      builder: (context, state) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              ...tailored.map((exam) {
                final isSelected = state.selectedExam == exam;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ShrinkableButton(
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      context.read<PastQuestionsBloc>().add(
                            ChangeExamCategoryEvent(exam),
                          );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primary
                            : (isDark
                                ? colors.surfaceSecondary
                                : colors.surfaceSecondary.withAlpha(90)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? colors.primary
                              : colors.surfaceBorder.withAlpha(100),
                        ),
                      ),
                      child: Text(
                        exam.displayName,
                        style: typography.caption.bold.copyWith(
                          color: isSelected ? colors.white : colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Switch category popup / dropdown
              PopupMenuButton<ExamCategory>(
                color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (cat) {
                  context.read<PastQuestionsBloc>().add(
                        ChangeExamCategoryEvent(cat),
                      );
                },
                itemBuilder: (context) {
                  return ExamCategory.values.map((cat) {
                    return PopupMenuItem(
                      value: cat,
                      child: Text(
                        cat.displayName,
                        style: typography.callout.regular.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    );
                  }).toList();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary.withAlpha(80),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.surfaceBorder.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Other Tracks',
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SubjectAndYearFilterRow extends StatelessWidget {
  const _SubjectAndYearFilterRow();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
      builder: (context, state) {
        final subjects = ['All', ...state.availableSubjects];

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              ...subjects.map((subj) {
                final isSelected = state.selectedSubject == subj;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(subj),
                    selected: isSelected,
                    onSelected: (_) {
                      context.read<PastQuestionsBloc>().add(
                            ChangeSubjectEvent(subj),
                          );
                    },
                    selectedColor: colors.primary.withAlpha(isDark ? 60 : 35),
                    backgroundColor: isDark
                        ? colors.surfaceSecondary
                        : colors.surfaceSecondary.withAlpha(60),
                    labelStyle: typography.caption.bold.copyWith(
                      color: isSelected ? colors.primary : colors.textSecondary,
                      fontSize: 11.5,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? colors.primary
                          : colors.surfaceBorder.withAlpha(80),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }),
              if (state.availableYears.isNotEmpty) ...[
                Container(
                  width: 1,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: colors.surfaceBorder.withAlpha(120),
                ),
                ...state.availableYears.map((yr) {
                  final isSelected = state.selectedYear == yr;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text('$yr'),
                      selected: isSelected,
                      onSelected: (val) {
                        context.read<PastQuestionsBloc>().add(
                              ChangeYearEvent(val ? yr : null),
                            );
                      },
                      selectedColor: colors.syllabotAccent.withAlpha(
                        isDark ? 60 : 35,
                      ),
                      backgroundColor: isDark
                          ? colors.surfaceSecondary
                          : colors.surfaceSecondary.withAlpha(60),
                      labelStyle: typography.caption.bold.copyWith(
                        color: isSelected
                            ? colors.syllabotAccent
                            : colors.textSecondary,
                        fontSize: 11.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PastQuestionCard extends StatelessWidget {
  const _PastQuestionCard({
    required this.question,
    required this.isInstantFeedback,
  });

  final PastQuestionEntity question;
  final bool isInstantFeedback;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final optionLetters = ['A', 'B', 'C', 'D', 'E'];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(60)
              : colors.surfaceBorder.withAlpha(120),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 40 : 8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 40 : 20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${question.subject} • ${question.year} • Q${question.questionNumber}',
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      question.topic,
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  question.isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  color: question.isBookmarked
                      ? colors.syllabotAccent
                      : colors.textSecondary,
                  size: 20,
                ),
                onPressed: () {
                  context.read<PastQuestionsBloc>().add(
                        ToggleBookmarkEvent(question.id),
                      );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reading Passage (if present)
          if (question.passage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary.withAlpha(isDark ? 100 : 40),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.surfaceBorder.withAlpha(80),
                ),
              ),
              child: Text(
                question.passage!,
                style: typography.subhead.regular.copyWith(
                  color: colors.textSecondary,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Question Prompt
          Text(
            question.prompt,
            style: typography.body.bold.copyWith(
              color: colors.textPrimary,
              height: 1.4,
            ),
          ),
          if (question.imageUrl != null && question.imageUrl!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                question.imageUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Multiple Choice Options
          ...question.options.asMap().entries.map((entry) {
            final idx = entry.key;
            final optionText = entry.value;
            final letter = idx < optionLetters.length
                ? optionLetters[idx]
                : '$idx';
            final isSelected = question.userSelectedOptionIndex == idx;
            final isCorrect = idx == question.correctOptionIndex;

            var optionBgColor = isDark
                ? colors.backgroundPrimary
                : colors.surfaceSecondary.withAlpha(50);
            var optionBorderColor = colors.surfaceBorder.withAlpha(90);
            var optionTextColor = colors.textPrimary;

            if (question.isAnswered && isInstantFeedback) {
              if (isCorrect) {
                optionBgColor = colors.success.withAlpha(isDark ? 50 : 25);
                optionBorderColor = colors.success.withAlpha(180);
                optionTextColor = colors.success;
              } else if (isSelected) {
                optionBgColor = colors.error.withAlpha(isDark ? 50 : 25);
                optionBorderColor = colors.error.withAlpha(180);
                optionTextColor = colors.error;
              }
            } else if (isSelected) {
              optionBgColor = colors.primary.withAlpha(isDark ? 50 : 25);
              optionBorderColor = colors.primary;
              optionTextColor = colors.primary;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ShrinkableButton(
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  context.read<PastQuestionsBloc>().add(
                        SelectOptionEvent(
                          questionId: question.id,
                          optionIndex: idx,
                        ),
                      );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: optionBgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: optionBorderColor, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? colors.primary
                              : colors.surfaceSecondary,
                        ),
                        child: Center(
                          child: Text(
                            letter,
                            style: typography.caption.bold.copyWith(
                              color: isSelected
                                  ? colors.white
                                  : colors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          optionText,
                          style: typography.subhead.medium.copyWith(
                            color: optionTextColor,
                          ),
                        ),
                      ),
                      if (question.isAnswered && isInstantFeedback) ...[
                        if (isCorrect)
                          Icon(
                            Icons.check_circle_rounded,
                            color: colors.success,
                            size: 20,
                          )
                        else if (isSelected)
                          Icon(
                            Icons.cancel_rounded,
                            color: colors.error,
                            size: 20,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),

          // Explanation Box (shown once answered)
          if (question.isAnswered && isInstantFeedback) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(isDark ? 30 : 15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 70 : 40),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_rounded,
                        color: colors.syllabotAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Explanation & Concept',
                        style: typography.footnote.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    question.explanation,
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Syllabot AI Explainer Action
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ShrinkableButton(
                onTap: () {
                  unawaited(
                    context.router.push(
                      SyllabotChatRoute(
                        initialPrompt:
                            'Explain this ${question.subject} question '
                            'step-by-step:\n"${question.prompt}"',
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: colors.syllabotAccent.withAlpha(isDark ? 45 : 25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.syllabotAccent.withAlpha(isDark ? 90 : 50),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: colors.syllabotAccent,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ask Syllabot AI',
                        style: typography.caption.bold.copyWith(
                          color: colors.syllabotAccent,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FloatingTestDock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
      builder: (context, state) {
        if (state.questions.isEmpty) return const SizedBox.shrink();

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceSecondary.withAlpha(220)
                    : colors.surfacePrimary.withAlpha(235),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 80 : 50),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.black.withAlpha(isDark ? 70 : 20),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withAlpha(isDark ? 50 : 25),
                    ),
                    child: Icon(
                      Icons.checklist_rounded,
                      color: colors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${state.questions.length} Questions in View',
                          style: typography.callout.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${state.selectedExam.displayName} • ${state.selectedSubject == "All" ? "All Subjects" : state.selectedSubject}',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ShrinkableButton(
                    onTap: () {
                      final testQuestions = state.questions
                          .take(10)
                          .map(QuizQuestionEntity.fromPastQuestion)
                          .toList();

                      unawaited(
                        context.router.push(
                          QuizWorkspaceRoute(
                            deckId: 'cbt_${state.selectedExam.code}',
                            deckTitle:
                                '${state.selectedExam.displayName} CBT Test',
                            subject: state.selectedSubject == 'All'
                                ? state.selectedExam.displayName
                                : state.selectedSubject,
                            durationMinutes: 15,
                            initialQuestions: testQuestions,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 15,
                            color: colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Quick CBT',
                            style: typography.caption.bold.copyWith(
                              color: colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
