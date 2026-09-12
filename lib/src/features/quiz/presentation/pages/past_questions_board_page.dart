import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/add_past_question_modal_sheet.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_question_card.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_questions_filter_bar.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_questions_test_config_sheet.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_duel_matchmaking_sheet.dart';
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

    return MultiBlocProvider(
      providers: [
        BlocProvider<PastQuestionsBloc>(
          create: (_) => locator<PastQuestionsBloc>()
            ..add(
              LoadPastQuestionsEvent(
                examCategory: initialExam,
                subject: initialSubject,
              ),
            ),
        ),
        BlocProvider<QuizDuelCubit>(
          create: (_) => locator<QuizDuelCubit>(),
        ),
      ],
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
    final debounceTimer = useRef<Timer?>(null);
    useEffect(() => () => debounceTimer.value?.cancel(), const []);

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
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: colors.primary, size: 22),
            tooltip: 'Add Past Question',
            onPressed: () {
              AppFeedback.light();
              final state = context.read<PastQuestionsBloc>().state;
              unawaited(
                AddPastQuestionModalSheet.show(
                  context,
                  defaultSubject: state.selectedSubject.isNotEmpty
                      ? state.selectedSubject
                      : initialSubject,
                  onAdded: (newQuestions) {
                    context.read<PastQuestionsBloc>().add(
                          AddPastQuestionsEvent(newQuestions),
                        );
                  },
                ),
              );
            },
          ),
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
                            debounceTimer.value?.cancel();
                            debounceTimer.value = Timer(
                              const Duration(milliseconds: 300),
                              () {
                                if (context.mounted) {
                                  context.read<PastQuestionsBloc>().add(
                                        LoadPastQuestionsEvent(searchQuery: query),
                                      );
                                }
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      const YearFilterButton(),
                    ],
                  ),
                ),

                // 3. Subject Selector Bar
                const SubjectFilterBar(),
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
                          return PastQuestionCard(
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
                          onTap: () => showPastQuestionsTestConfigSheet(context, state),
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
                                const SizedBox(width: 6),
                                Text(
                                  'CBT Test',
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: ShrinkableButton(
                          onTap: () {
                            AppFeedback.light();
                            QuizDuelMatchmakingSheet.show(
                              context,
                              initialSubject: state.selectedSubject != 'All'
                                  ? state.selectedSubject
                                  : 'Physics',
                              initialExamBoard: state.selectedExam.displayName,
                            );
                          },
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [colors.secondary, colors.primary],
                              ),
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.secondary.withAlpha(90),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.flash_on_rounded,
                                  color: colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '1v1 Duel ⚡',
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
                    onTap: () => showPastQuestionsTestConfigSheet(context, state),
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
