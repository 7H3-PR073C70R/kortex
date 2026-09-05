import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/curate_courses_cubit.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/shared/widgets/app_dialog.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class CourseModulePage extends StatelessWidget {
  const CourseModulePage({
    @PathParam('courseId') required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    super.key,
  });

  final String courseId;
  final String courseCode;
  final String courseTitle;

  static String cleanCode(String code) {
    return code.replaceFirst(RegExp('^[WJN]-', caseSensitive: false), '').trim();
  }

  ExamCategory _getExamCategory(String? track) {
    final t = (track ?? '').toUpperCase();
    if (t.contains('JAMB') || t.contains('UTME')) return ExamCategory.jamb;
    if (t.contains('NECO') || t.contains('SSCE')) return ExamCategory.neco;
    if (t.contains('SAT')) return ExamCategory.sat;
    if (t.contains('MEDICINE') || t.contains('HEALTH')) return ExamCategory.medicine;
    if (t.contains('LAW')) return ExamCategory.law;
    if (t.contains('ENGINEERING')) return ExamCategory.engineering;
    if (t.contains('BUSINESS')) return ExamCategory.business;
    return ExamCategory.waec;
  }

  String _mapCourseToSubject(String title, String code) {
    final c = cleanCode(code).toUpperCase();
    final lower = '$title $code'.toLowerCase();
    if (c == 'LIT' || lower.contains('literature')) return 'Literature in English';
    if (c == 'FMTH' || lower.contains('further math')) return 'Further Mathematics';
    if (c == 'MTH' || lower.contains('math')) return 'Mathematics';
    if (c == 'ENG' || lower.contains('english')) return 'English Language';
    if (c == 'BIO' || lower.contains('bio')) return 'Biology';
    if (c == 'CHM' || lower.contains('chem')) return 'Chemistry';
    if (c == 'PHY' || lower.contains('phys')) return 'Physics';
    if (c == 'ECN' || lower.contains('econ')) return 'Economics';
    if (c == 'GOV' || lower.contains('gov')) return 'Government';
    if (c == 'ACC' || lower.contains('acc') || lower.contains('fin')) return 'Accounts - Principles of Accounts';
    if (c == 'COM' || lower.contains('comm')) return 'Commerce';
    if (c == 'GEO' || lower.contains('geo')) return 'Geography';
    if (c == 'AGR' || lower.contains('agric')) return 'Agricultural Science';
    if (c == 'CIV' || lower.contains('civic')) return 'Civic Education';
    if (c == 'DPR' || lower.contains('data processing')) return 'Data Processing';
    if (c == 'CMP' || lower.contains('computer')) return 'Computer Studies';
    if (c == 'CRK' || lower.contains('crk') || lower.contains('christian')) return 'Christian Religious Knowledge (CRK)';
    if (c == 'IRK' || lower.contains('irk') || lower.contains('islamic')) return 'Islamic Religious Knowledge (IRK)';
    return title.split('(').first.trim();
  }

  @override
  Widget build(BuildContext context) {
    final currentProfile = context.read<AuthBloc>().state.userProfile;
    final examCategory = _getExamCategory(currentProfile?.targetTrack);
    final sanitizedCode = cleanCode(courseCode);
    final mappedSubject = _mapCourseToSubject(courseTitle, sanitizedCode);

    return BlocProvider<PastQuestionsBloc>(
      create: (_) => locator<PastQuestionsBloc>()
        ..add(
          LoadPastQuestionsEvent(
            examCategory: examCategory,
            subject: mappedSubject,
          ),
        ),
      child: _CourseModuleView(
        courseId: courseId,
        courseCode: sanitizedCode,
        courseTitle: courseTitle,
        mappedSubject: mappedSubject,
        examCategory: examCategory,
      ),
    );
  }
}

class _CourseModuleView extends StatelessWidget {
  const _CourseModuleView({
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.mappedSubject,
    required this.examCategory,
  });

  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String mappedSubject;
  final ExamCategory examCategory;

  void _confirmDelete(BuildContext context, int deckCount) {
    unawaited(
      AppDialog.show<void>(
        context: context,
        title: 'Delete Curated Course?',
        description:
            'Are you sure you want to remove "$courseCode - $courseTitle"?\n\n'
            'This action is destructive and will delete the course along with its $deckCount associated study deck(s), flashcards, and uploaded documents.',
        primaryActionText: 'Delete Course & Decks',
        isDestructive: true,
        onPrimaryAction: () async {
          AppFeedback.heavy();
          if (locator.isRegistered<CurateCoursesCubit>()) {
            await locator<CurateCoursesCubit>().deleteCourse(
              courseId,
            );
          }
          if (context.mounted) {
            locator<DashboardBloc>().add(const DashboardRefreshed());
            context.router.pop();
          }
        },
        secondaryActionText: 'Cancel',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return BlocBuilder<DecksBloc, DecksState>(
      bloc: locator.isRegistered<DecksBloc>() ? locator<DecksBloc>() : null,
      builder: (context, decksState) {
        final allDecks = decksState.allDecks;
        final associatedDecks = allDecks.where((d) {
          if (d.courseId != null && d.courseId == courseId) return true;
          if (d.courseCode != null &&
              d.courseCode!.isNotEmpty &&
              d.courseCode!.toLowerCase() == courseCode.toLowerCase()) {
            return true;
          }
          if (d.subject.toLowerCase() == courseTitle.toLowerCase() ||
              d.subject.toLowerCase() == mappedSubject.toLowerCase()) {
            return true;
          }
          return false;
        }).toList();

        final totalCards = associatedDecks.fold<int>(
          0,
          (sum, d) => sum + d.totalCards,
        );
        final totalDue = associatedDecks.fold<int>(
          0,
          (sum, d) => sum + d.dueCards,
        );

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: colors.textPrimary,
                size: 18,
              ),
              onPressed: () => context.router.pop(),
            ),
            title: Text(
              courseCode,
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 17.5,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: colors.error.withAlpha(200),
                  size: 22,
                ),
                tooltip: 'Delete Course',
                onPressed: () => _confirmDelete(context, associatedDecks.length),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Hero Course Header Banner
                  _buildHeaderBanner(
                    context,
                    colors,
                    typography,
                    isDark,
                    associatedDecks.length,
                    totalCards,
                    totalDue,
                  ),
                  const SizedBox(height: 24),

                  // 2. Document Ingestion Section (Accurate copy)
                  _buildDocumentIngestionCard(
                    context,
                    colors,
                    typography,
                    isDark,
                  ),
                  const SizedBox(height: 28),

                  // 3. Associated Study Decks Section
                  _buildDecksSection(
                    context,
                    associatedDecks,
                    colors,
                    typography,
                    isDark,
                  ),
                  const SizedBox(height: 28),

                  // 4. Official Past Papers & CBT Questions Section
                  _buildPastQuestionsSection(
                    context,
                    colors,
                    typography,
                    isDark,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderBanner(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
    int deckCount,
    int cardCount,
    int dueCount,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: isDark
                ? colors.surfaceSecondary.withAlpha(160)
                : colors.surfacePrimary.withAlpha(210),
            border: Border.all(
              color: isDark
                  ? colors.surfaceBorderHighlight.withAlpha(70)
                  : colors.surfaceBorder.withAlpha(140),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.black.withAlpha(isDark ? 50 : 12),
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
                      color: colors.primary.withAlpha(isDark ? 50 : 25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      courseCode,
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary.withAlpha(140)
                          : colors.surfacePrimary,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: colors.surfaceBorder.withAlpha(100),
                      ),
                    ),
                    child: Text(
                      examCategory.displayName,
                      style: typography.caption.bold.copyWith(
                        color: colors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                courseTitle,
                style: typography.title2.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 20,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 16),

              // Metrics Row
              Row(
                children: [
                  _buildHeaderMetric(
                    label: 'Study Decks',
                    value: '$deckCount',
                    icon: Icons.layers_outlined,
                    colors: colors,
                    typography: typography,
                  ),
                  const SizedBox(width: 16),
                  _buildHeaderMetric(
                    label: 'Flashcards',
                    value: '$cardCount',
                    icon: Icons.style_outlined,
                    colors: colors,
                    typography: typography,
                  ),
                  const SizedBox(width: 16),
                  _buildHeaderMetric(
                    label: 'Due Today',
                    value: '$dueCount',
                    icon: Icons.alarm_outlined,
                    colors: colors,
                    typography: typography,
                    isAlert: dueCount > 0,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderMetric({
    required String label,
    required String value,
    required IconData icon,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    bool isAlert = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: isAlert ? colors.error : colors.primary,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: typography.callout.bold.copyWith(
                color: isAlert ? colors.error : colors.textPrimary,
                fontSize: 13.5,
              ),
            ),
            Text(
              label,
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDocumentIngestionCard(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Course Materials & Document Processing',
          style: typography.callout.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        ShrinkableButton(
          onTap: () {
            AppFeedback.medium();
            unawaited(
              context.router.push(
                DocumentIngestionRoute(
                  courseId: courseId,
                  courseCode: courseCode,
                  courseTitle: courseTitle,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(isDark ? 28 : 16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 70 : 45),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 55 : 30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.upload_file_rounded,
                    size: 22,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Study Materials / Notes',
                        style: typography.callout.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Upload PDF documents, lecture slides, or camera snapshots to generate flashcards and study decks.',
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: colors.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDecksSection(
    BuildContext context,
    List<DeckEntity> decks,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Associated Study Decks',
              style: typography.callout.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 15,
              ),
            ),
            ShrinkableButton(
              onTap: () {
                AppFeedback.light();
                unawaited(
                  context.router.push(
                    DocumentIngestionRoute(
                      courseId: courseId,
                      courseCode: courseCode,
                      courseTitle: courseTitle,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.primary.withAlpha(40),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 13,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'New Deck',
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (decks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(100)
                  : colors.surfacePrimary.withAlpha(180),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.surfaceBorder.withAlpha(100),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.layers_clear_outlined,
                  size: 32,
                  color: colors.textMuted,
                ),
                const SizedBox(height: 8),
                Text(
                  'No study decks created yet for this course',
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload study materials above to automatically generate flashcards.',
                  textAlign: TextAlign.center,
                  style: typography.footnote.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          )
        else
          ...decks.map((deck) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary.withAlpha(130)
                          : colors.surfacePrimary.withAlpha(200),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: deck.hasDueCards
                            ? colors.primary.withAlpha(isDark ? 90 : 60)
                            : (isDark
                                ? colors.surfaceBorderHighlight.withAlpha(50)
                                : colors.surfaceBorder.withAlpha(120)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                deck.title,
                                style: typography.caption.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '${deck.totalCards} cards',
                                    style: typography.footnote.regular.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  if (deck.dueCards > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.error.withAlpha(30),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${deck.dueCards} due',
                                        style: typography.caption.bold.copyWith(
                                          color: colors.error,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        ShrinkableButton(
                          onTap: () {
                            AppFeedback.light();
                            unawaited(
                              context.router.push(
                                StudySessionRoute(deckId: deck.id),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  size: 15,
                                  color: colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Study',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.white,
                                    fontSize: 11.5,
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
              ),
            );
          }),
      ],
    );
  }

  Widget _buildPastQuestionsSection(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
      builder: (context, pqState) {
        final questions = pqState.questions;
        final hasQuestions = questions.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Official Past Papers & Q-Bank',
                  style: typography.callout.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 15,
                  ),
                ),
                if (hasQuestions)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.success.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${questions.length} Questions',
                      style: typography.caption.bold.copyWith(
                        color: colors.success,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (pqState.status == PastQuestionsStatus.loading)
              Container(
                height: 100,
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceSecondary.withAlpha(100)
                      : colors.surfacePrimary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
              )
            else if (hasQuestions) ...[
              // Practice CBT Drill Card
              _buildCbtPaperCard(
                context: context,
                title: 'Full CBT Mock Examination',
                subtitle:
                    'Timed mock with ${questions.length.clamp(1, 40)} verified past questions',
                badgeText: 'MOCK EXAM',
                icon: Icons.timer_outlined,
                accentColor: colors.primary,
                questions: questions.take(40).toList(),
                isTimed: true,
                colors: colors,
                typography: typography,
                isDark: isDark,
              ),
              const SizedBox(height: 10),

              // Practice Drill Card (Instant feedback)
              _buildCbtPaperCard(
                context: context,
                title: 'Quick Practice Drill',
                subtitle:
                    'Untimed drill with instant step-by-step explanations',
                badgeText: 'DRILL',
                icon: Icons.bolt_rounded,
                accentColor: colors.syllabotAccent,
                questions: questions.take(20).toList(),
                isTimed: false,
                colors: colors,
                typography: typography,
                isDark: isDark,
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary.withAlpha(isDark ? 40 : 18),
                      colors.surfaceSecondary.withAlpha(isDark ? 160 : 210),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.primary.withAlpha(isDark ? 70 : 40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withAlpha(isDark ? 25 : 10),
                      blurRadius: 14,
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
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.primary.withAlpha(isDark ? 50 : 25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 12, color: colors.primary),
                              const SizedBox(width: 4),
                              Text(
                                '${examCategory.displayName} • $mappedSubject',
                                style: typography.caption.bold.copyWith(
                                  color: colors.primary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.menu_book_rounded,
                          size: 20,
                          color: colors.primary.withAlpha(160),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Official $mappedSubject Q-Bank',
                      style: typography.title3.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Practice verified past questions, drill by specific year, or simulate a timed CBT exam.',
                      style: typography.footnote.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ShrinkableButton(
                            onTap: () {
                              AppFeedback.light();
                              unawaited(
                                context.router.push(
                                  PastQuestionsBoardRoute(
                                    initialExamCode: examCategory.code,
                                    initialSubject: mappedSubject,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primary.withAlpha(80),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.play_circle_filled_rounded, size: 16, color: colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Launch Q-Bank & CBT',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.white,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ShrinkableButton(
                          onTap: () {
                            AppFeedback.light();
                            unawaited(
                              context.router.push(
                                SyllabotChatRoute(
                                  initialPrompt:
                                      'Please generate 5 official-style ${examCategory.displayName} practice questions for $mappedSubject right now. '
                                      'For each question, provide 4 options labeled A, B, C, and D, clearly indicate the correct answer, and explain the step-by-step solution.',
                                  initialMode: SocraticMode.examSim,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: colors.syllabotAccent.withAlpha(isDark ? 40 : 20),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colors.syllabotAccent.withAlpha(isDark ? 80 : 50),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome_rounded, size: 15, color: colors.syllabotAccent),
                                const SizedBox(width: 5),
                                Text(
                                  'AI Drill',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.syllabotAccent,
                                    fontSize: 12,
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
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCbtPaperCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String badgeText,
    required IconData icon,
    required Color accentColor,
    required List<PastQuestionEntity> questions,
    required bool isTimed,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    required bool isDark,
  }) {
    return ShrinkableButton(
      onTap: () {
        AppFeedback.medium();
        final quizQuestions = questions
            .map(QuizQuestionEntity.fromPastQuestion)
            .toList();

        unawaited(
          context.router.push(
            QuizWorkspaceRoute(
              deckId: 'cbt_${examCategory.code}_$courseId',
              deckTitle: '$courseCode $title',
              subject: courseTitle,
              durationMinutes: isTimed ? (quizQuestions.length * 1.5).round() : null,
              initialQuestions: quizQuestions,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(140)
                  : colors.surfacePrimary.withAlpha(200),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? colors.surfaceBorderHighlight.withAlpha(60)
                    : colors.surfaceBorder.withAlpha(120),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(isDark ? 40 : 25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: accentColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: typography.caption.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badgeText,
                              style: typography.caption.bold.copyWith(
                                color: accentColor,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.play_circle_outline_rounded,
                  size: 22,
                  color: accentColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
