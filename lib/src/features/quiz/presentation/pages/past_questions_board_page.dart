import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class PastQuestionsBoardPage extends StatelessWidget {
  const PastQuestionsBoardPage({
    @queryParam this.initialExamCode,
    @queryParam this.initialSubject,
    super.key,
  });

  final String? initialExamCode;
  final String? initialSubject;

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
    if (upper.contains('NECO') || upper.contains('SSCE')) {
      return ExamCategory.neco;
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
        ..add(
          LoadPastQuestionsEvent(
            examCategory: initialExam,
            subject: initialSubject,
          ),
        ),
      child: _PastQuestionsBoardView(
        userTrack: userTrack ?? 'WAEC',
        initialSubject: initialSubject,
      ),
    );
  }
}

class _PastQuestionsBoardView extends HookWidget {
  const _PastQuestionsBoardView({
    required this.userTrack,
    this.initialSubject,
  });

  final String userTrack;
  final String? initialSubject;

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
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Q-Bank & CBT Drills',
          style: typography.title2.bold.copyWith(color: colors.textPrimary, fontSize: 18),
        ),
        centerTitle: true,
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
                // 1. Hero Practice Card (Context-Aware, No Redundant Track Switcher)
                _HeroTrackBanner(userTrack: userTrack),

                // 2. Search Field with Year Filter Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: searchController,
                          hintText: 'Search questions, topics...',
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: colors.textSecondary,
                            size: 19,
                          ),
                          onChanged: (query) {
                            context.read<PastQuestionsBloc>().add(
                                  LoadPastQuestionsEvent(searchQuery: query),
                                );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      const _YearFilterButton(),
                    ],
                  ),
                ),

                // 3. Subject Selector Bar
                const _SubjectFilterBar(),
                const SizedBox(height: 8),

                // 4. Questions Feed
                Expanded(
                  child: BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
                    builder: (context, state) {
                      // Only Shimmer Loading (No Double Loader)
                      if (state.status == PastQuestionsStatus.loading) {
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          children: const [
                            ShimmerPlaceholder(height: 150, borderRadius: 18),
                            SizedBox(height: 12),
                            ShimmerPlaceholder(height: 150, borderRadius: 18),
                            SizedBox(height: 12),
                            ShimmerPlaceholder(height: 150, borderRadius: 18),
                          ],
                        );
                      }

                      if (state.questions.isEmpty) {
                        final isSpecificYear = state.selectedYear != null;
                        final targetSubject = state.selectedSubject != 'All'
                            ? state.selectedSubject
                            : (state.availableSubjects.isNotEmpty
                                ? state.availableSubjects.first
                                : 'Mathematics');

                        final syllabotPrompt =
                            'Please generate 5 official-style ${state.selectedExam.displayName} practice questions for $targetSubject right now. '
                            'For each question, provide 4 options labeled A, B, C, and D, clearly indicate the correct answer, and explain the step-by-step solution.';

                        return Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withAlpha(isDark ? 35 : 18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.auto_stories_outlined,
                                    size: 38,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  isSpecificYear
                                      ? 'No ${state.selectedYear} Past Questions Found'
                                      : 'No Past Questions for $targetSubject',
                                  textAlign: TextAlign.center,
                                  style: typography.title3.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 16.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isSpecificYear
                                      ? 'Official ${state.selectedYear} past papers for $targetSubject are currently syncing. You can generate practice questions with Syllabot AI or select all years.'
                                      : 'Verified exam questions for $targetSubject are being loaded. Practice immediately with Syllabot AI or explore other subjects.',
                                  textAlign: TextAlign.center,
                                  style: typography.footnote.regular.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                ShrinkableButton(
                                  onTap: () {
                                    AppFeedback.light();
                                    unawaited(
                                      context.router.push(
                                        SyllabotChatRoute(
                                          initialPrompt: syllabotPrompt,
                                          initialMode: SocraticMode.examSim,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colors.primary.withAlpha(80),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 16,
                                          color: colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Generate AI Practice Questions',
                                          style: typography.caption.bold.copyWith(
                                            color: colors.white,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isSpecificYear) ...[
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: () {
                                      AppFeedback.selection();
                                      context.read<PastQuestionsBloc>().add(
                                            const ChangeYearEvent(null),
                                          );
                                    },
                                    child: Text(
                                      'Switch to Random / All Years',
                                      style: typography.caption.bold.copyWith(
                                        color: colors.primary,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ],
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
        final hasSubject = state.selectedSubject != 'All';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
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
                              hasSubject
                                  ? '${exam.displayName} • ${state.selectedSubject}'
                                  : exam.displayName,
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
                    hasSubject
                        ? '${state.selectedSubject} Question Bank'
                        : '${exam.displayName} Official Question Bank',
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                      letterSpacing: -0.2,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Practice real exam questions, drill by specific year, or simulate timed CBT tests.',
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ShrinkableButton(
                          onTap: () => _showTestConfigSheet(context, state),
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(13),
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
                                    fontSize: 13,
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
}

void _showTestConfigSheet(BuildContext context, PastQuestionsState state) {
  final colors = context.colors;
  final typography = context.typography;
  final isDark = context.isDarkMode;

  final defaultYears = state.availableYears.isNotEmpty
      ? state.availableYears
      : const [2024, 2023, 2022, 2021, 2020, 2019, 2018];

  var isRandomSelection = state.selectedYear == null;
  var selectedYear = state.selectedYear ?? (defaultYears.isNotEmpty ? defaultYears.first : 2024);
  var selectedCount = state.questions.length > 10 ? 10 : (state.questions.isEmpty ? 10 : state.questions.length);
  var isTimedMode = true;

  unawaited(
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: SingleChildScrollView(
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
                      const SizedBox(height: 14),
                      Text(
                        'Configure ${state.selectedExam.displayName} Test',
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Practice a specific past paper year or generate a randomized mock test.',
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 1. Question Source: Random vs Exam Year
                      Text(
                        'Question Selection Mode',
                        style: typography.caption.bold.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _ModeOptionCard(
                              title: 'Random Mock',
                              subtitle: 'Shuffle across all years',
                              icon: Icons.shuffle_rounded,
                              isSelected: isRandomSelection,
                              onTap: () => setSheetState(() => isRandomSelection = true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ModeOptionCard(
                              title: 'Specific Year',
                              subtitle: 'Target an official paper',
                              icon: Icons.calendar_today_rounded,
                              isSelected: !isRandomSelection,
                              onTap: () => setSheetState(() => isRandomSelection = false),
                            ),
                          ),
                        ],
                      ),

                      // If specific year selected, show year pills
                      if (!isRandomSelection) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Select Exam Year',
                          style: typography.caption.bold.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: defaultYears.map((yr) {
                              final isSelected = selectedYear == yr;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text('$yr'),
                                  selected: isSelected,
                                  onSelected: (_) => setSheetState(() => selectedYear = yr),
                                  selectedColor: colors.primary.withAlpha(isDark ? 60 : 35),
                                  backgroundColor: colors.surfaceSecondary.withAlpha(100),
                                  labelStyle: typography.caption.bold.copyWith(
                                    color: isSelected ? colors.primary : colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // 2. Simulation Mode
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
                              subtitle: 'Strict countdown & score',
                              icon: Icons.timer_outlined,
                              isSelected: isTimedMode,
                              onTap: () => setSheetState(() => isTimedMode = true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ModeOptionCard(
                              title: 'Self-Paced Drill',
                              subtitle: 'Instant answer reveal',
                              icon: Icons.school_outlined,
                              isSelected: !isTimedMode,
                              onTap: () => setSheetState(() => isTimedMode = false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3. Question Count Pills
                      Text(
                        'Question Count',
                        style: typography.caption.bold.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [5, 10, 20, 40].map((count) {
                          final isSelected = selectedCount == count;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('$count Qs'),
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
                      const SizedBox(height: 22),

                      // 4. Launch CTA
                      ShrinkableButton(
                        onTap: () {
                          Navigator.pop(bottomSheetContext);

                          // Pool questions
                          var pool = List<PastQuestionEntity>.from(state.questions);
                          if (!isRandomSelection) {
                            final filtered = pool.where((q) => q.year == selectedYear).toList();
                            if (filtered.isNotEmpty) {
                              pool = filtered;
                            }
                          } else {
                            pool.shuffle();
                          }

                          final count = selectedCount > pool.length && pool.isNotEmpty
                              ? pool.length
                              : selectedCount;

                          final testQuestions = pool
                              .take(count)
                              .map(QuizQuestionEntity.fromPastQuestion)
                              .toList();

                          final testTitle = isRandomSelection
                              ? '${state.selectedExam.displayName} Random CBT Mock'
                              : '${state.selectedExam.displayName} $selectedYear Past Paper';

                          unawaited(
                            context.router.push(
                              QuizWorkspaceRoute(
                                deckId: 'cbt_${state.selectedExam.code}_${isRandomSelection ? "random" : selectedYear}',
                                deckTitle: testTitle,
                                subject: state.selectedSubject == 'All'
                                    ? state.selectedExam.displayName
                                    : state.selectedSubject,
                                durationMinutes: isTimedMode
                                    ? (count * 1.5).round().clamp(5, 90)
                                    : null,
                                initialQuestions: testQuestions,
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
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              isRandomSelection
                                  ? 'Start Random CBT ($selectedCount Questions)'
                                  : 'Start $selectedYear Past Paper ($selectedCount Qs)',
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
              ),
            );
          },
        );
      },
    ),
  );
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

class _SubjectFilterBar extends StatelessWidget {
  const _SubjectFilterBar();

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
            children: subjects.map((subj) {
              final isSelected = state.selectedSubject == subj;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  showCheckmark: false,
                  label: Text(subj),
                  selected: isSelected,
                  onSelected: (_) {
                    unawaited(HapticFeedback.selectionClick());
                    context.read<PastQuestionsBloc>().add(
                          ChangeSubjectEvent(subj),
                        );
                  },
                  selectedColor: colors.primary,
                  backgroundColor: isDark
                      ? colors.surfaceSecondary.withAlpha(100)
                      : colors.surfaceSecondary.withAlpha(60),
                  labelStyle: typography.caption.bold.copyWith(
                    color: isSelected ? colors.white : colors.textSecondary,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? colors.primary
                        : colors.surfaceBorder.withAlpha(80),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _YearFilterButton extends StatelessWidget {
  const _YearFilterButton();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
      builder: (context, state) {
        final defaultYears = state.availableYears.isNotEmpty
            ? state.availableYears
            : const [2024, 2023, 2022, 2021, 2020, 2019, 2018];
        final isSpecific = state.selectedYear != null;

        return PopupMenuButton<int?>(
          color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colors.surfaceBorder.withAlpha(isDark ? 80 : 120),
            ),
          ),
          onSelected: (yr) {
            unawaited(HapticFeedback.selectionClick());
            context.read<PastQuestionsBloc>().add(ChangeYearEvent(yr));
          },
          itemBuilder: (context) {
            return [
              const PopupMenuItem<int?>(
                child: Row(
                  children: [
                    Icon(
                      Icons.shuffle_rounded,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text('All Years (Random)'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              ...defaultYears.map(
                (yr) => PopupMenuItem<int?>(
                  value: yr,
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: state.selectedYear == yr
                            ? colors.primary
                            : colors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$yr Exam Paper',
                        style: typography.callout.medium.copyWith(
                          color: state.selectedYear == yr
                              ? colors.primary
                              : colors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ];
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isSpecific
                  ? colors.primary.withAlpha(isDark ? 45 : 20)
                  : (isDark
                      ? colors.surfaceSecondary.withAlpha(120)
                      : colors.surfacePrimary),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSpecific
                    ? colors.primary
                    : colors.surfaceBorder.withAlpha(isDark ? 80 : 120),
                width: isSpecific ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSpecific
                      ? Icons.calendar_today_rounded
                      : Icons.tune_rounded,
                  size: 15,
                  color: isSpecific ? colors.primary : colors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  isSpecific ? '${state.selectedYear}' : 'Year: All',
                  style: typography.caption.bold.copyWith(
                    color: isSpecific ? colors.primary : colors.textPrimary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: isSpecific ? colors.primary : colors.textSecondary,
                ),
              ],
            ),
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
                    onTap: () => _showTestConfigSheet(context, state),
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
