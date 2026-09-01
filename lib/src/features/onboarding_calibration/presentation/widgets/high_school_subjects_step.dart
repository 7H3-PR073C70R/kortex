import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_cubit.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/calibration_option_chip.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Question B3: Grouped subject checklist covering Science, Commercial,
/// Arts/Humanities, and Core tracks for universal exam coverage.
class HighSchoolSubjectsStep extends StatelessWidget {
  const HighSchoolSubjectsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final selectedSubjects =
        context.watch<CalibrationCubit>().state.profile.highSchoolSubjects;

    // ── Track groups ──────────────────────────────────────────────────────
    final coreSubjects = [
      (
        l10n.calibrationSubjectCoreMath,
        'Algebra, Geometry, Trigonometry, Statistics',
        Icons.calculate_rounded,
      ),
      (
        l10n.calibrationSubjectEnglish,
        'Comprehension, Grammar, Essay Writing, Oral English',
        Icons.spellcheck_rounded,
      ),
    ];

    final scienceSubjects = [
      (
        l10n.calibrationSubjectPhysics,
        'Mechanics, Optics, Waves, Electromagnetism, Modern Physics',
        Icons.flash_on_rounded,
      ),
      (
        l10n.calibrationSubjectChemistry,
        'Inorganic, Organic Reactions, Stoichiometry, Electrolysis',
        Icons.science_rounded,
      ),
      (
        l10n.calibrationSubjectBiology,
        'Cell Structure, Genetics, Ecology, Human Physiology',
        Icons.biotech_rounded,
      ),
      (
        l10n.calibrationSubjectFurtherMath,
        'Calculus, Vectors, Matrices, Complex Numbers',
        Icons.functions_rounded,
      ),
    ];

    final commercialSubjects = [
      (
        l10n.calibrationSubjectAccounting,
        'Final Accounts, Ledgers, Trial Balance, Ratio Analysis',
        Icons.account_balance_rounded,
      ),
      (
        l10n.calibrationSubjectEconomics,
        'Micro & Macro Economics, Demand & Supply, Trade Theory',
        Icons.trending_up_rounded,
      ),
      (
        l10n.calibrationSubjectCommerce,
        'Trade, Banking, Insurance, Transport, Warehousing',
        Icons.store_rounded,
      ),
    ];

    final artsSubjects = [
      (
        l10n.calibrationSubjectLiterature,
        'Prose, Poetry, Drama — Set Texts & Critical Analysis',
        Icons.menu_book_rounded,
      ),
      (
        l10n.calibrationSubjectGovernment,
        'Constitutions, Political Systems, Electoral Processes',
        Icons.account_balance_wallet_rounded,
      ),
      (
        l10n.calibrationSubjectHistory,
        'West African, Nigerian & World History, Colonialism',
        Icons.history_edu_rounded,
      ),
      (
        l10n.calibrationSubjectCRK,
        'Old & New Testament Studies, Christian Ethics, Church History',
        Icons.church_rounded,
      ),
    ];

    final exam =
        context.watch<CalibrationCubit>().state.profile.highSchoolExam ?? '';
    final isSat = exam.contains('SAT');
    final isIelts = exam.contains('IELTS') || exam.contains('TOEFL');
    final isIgcse = exam.contains('IGCSE') || exam.contains('A-Level');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.calibrationQuestionB3,
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 22,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.calibrationQuestionB3Subtitle,
          style: typography.callout.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),

        if (isSat) ...[
          _TrackHeader(label: 'Reading & Writing', colors: colors),
          const SizedBox(height: 10),
          ..._buildChips(context, [
            (
              'SAT Reading Comprehension',
              'Passage analysis, textual evidence & vocabulary in context',
              Icons.menu_book_rounded,
            ),
            (
              'SAT Writing & Language',
              'Standard English conventions, expression of ideas & rhetoric',
              Icons.spellcheck_rounded,
            ),
          ], selectedSubjects),
          _TrackHeader(label: 'Mathematics', colors: colors),
          const SizedBox(height: 10),
          ..._buildChips(context, [
            (
              'SAT Math: Heart of Algebra',
              'Linear equations, systems, inequalities & function models',
              Icons.calculate_rounded,
            ),
            (
              'SAT Math: Advanced & Problem Solving',
              'Nonlinear functions, data analysis, ratios & geometry',
              Icons.functions_rounded,
            ),
          ], selectedSubjects),
        ] else if (isIelts) ...[
          _TrackHeader(label: 'Exam Modules', colors: colors),
          const SizedBox(height: 10),
          ..._buildChips(context, [
            (
              'Reading Section',
              'Academic passages, inference, skimming & scanning drills',
              Icons.menu_book_rounded,
            ),
            (
              'Listening Section',
              'Conversations, lectures, note-taking & accent recognition',
              Icons.headphones_rounded,
            ),
            (
              'Writing Section (Task 1 & Task 2)',
              'Graph analysis, synthesis reports & formal argument essays',
              Icons.edit_note_rounded,
            ),
            (
              'Speaking Section',
              'Fluency, lexical range, coherence & pronunciation drills',
              Icons.mic_rounded,
            ),
          ], selectedSubjects),
        ] else if (isIgcse) ...[
          _TrackHeader(label: 'Core & Mathematics', colors: colors),
          const SizedBox(height: 10),
          ..._buildChips(context, [
            (
              'Cambridge IGCSE Mathematics',
              'Number, algebra, trigonometry & probability (Core/Ext)',
              Icons.calculate_rounded,
            ),
            (
              'Additional Mathematics',
              'Calculus, coordinate geometry & logarithmic functions',
              Icons.functions_rounded,
            ),
            (
              'English Language & Literature',
              'Comprehension, directed writing & set text analysis',
              Icons.spellcheck_rounded,
            ),
          ], selectedSubjects),
          _TrackHeader(label: 'Sciences & Computing', colors: colors),
          const SizedBox(height: 10),
          ..._buildChips(context, [
            (
              'IGCSE Physics',
              'Mechanics, thermal physics, electricity & nuclear physics',
              Icons.flash_on_rounded,
            ),
            (
              'IGCSE Chemistry',
              'Stoichiometry, organic reactions & periodic table trends',
              Icons.science_rounded,
            ),
            (
              'IGCSE Biology',
              'Cell biology, organ systems, genetics & biotechnology',
              Icons.biotech_rounded,
            ),
            (
              'Computer Science',
              'Algorithms, computational thinking, logic gates & Python',
              Icons.computer_rounded,
            ),
          ], selectedSubjects),
          _TrackHeader(label: 'Business & Humanities', colors: colors),
          const SizedBox(height: 10),
          ..._buildChips(context, [
            (
              'Economics',
              'Microeconomics, macroeconomic policy, trade & price system',
              Icons.trending_up_rounded,
            ),
            (
              'Business Studies',
              'Marketing, finance, operations & business management',
              Icons.business_center_rounded,
            ),
            (
              'Accounting',
              'Double entry bookkeeping, ledger accounts & trial balance',
              Icons.account_balance_rounded,
            ),
          ], selectedSubjects),
        ] else ...[
          // ── Core (WAEC / JAMB / NECO) ──────────────────────────────────
          _TrackHeader(label: l10n.calibrationTrackCore, colors: colors),
          const SizedBox(height: 10),
          ..._buildChips(context, coreSubjects, selectedSubjects),

          // ── Science ───────────────────────────────────────────────────
          _TrackHeader(label: l10n.calibrationTrackScience, colors: colors),
          const SizedBox(height: 10),
          ..._buildChips(context, scienceSubjects, selectedSubjects),

          // ── Commercial ────────────────────────────────────────────────
          _TrackHeader(label: l10n.calibrationTrackCommercial, colors: colors),
          const SizedBox(height: 10),
          ..._buildChips(context, commercialSubjects, selectedSubjects),

          // ── Arts / Humanities ─────────────────────────────────────────
          _TrackHeader(label: l10n.calibrationTrackArts, colors: colors),
          const SizedBox(height: 10),
          ..._buildChips(context, artsSubjects, selectedSubjects),
        ],
      ],
    );
  }

  List<Widget> _buildChips(
    BuildContext context,
    List<(String, String, IconData)> subjects,
    List<String> selected,
  ) {
    return subjects
        .map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CalibrationOptionChip(
              title: s.$1,
              subtitle: s.$2,
              icon: s.$3,
              isMultiSelect: true,
              isSelected: selected.contains(s.$1),
              onTap: () =>
                  context.read<CalibrationCubit>().toggleHighSchoolSubject(
                        s.$1,
                      ),
            ),
          ),
        )
        .toList();
  }
}

/// Thin translucent track separator label.
class _TrackHeader extends StatelessWidget {
  const _TrackHeader({required this.label, required this.colors});

  final String label;
  final dynamic colors;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: typography.caption.semiBold.copyWith(
              color: const Color(0xFF7C3AED),
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
