import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_course_chips.dart';

/// Tab view for hosting a private room and sharing invite code with a friend.
class QuizDuelInviteFriendTab extends StatelessWidget {
  const QuizDuelInviteFriendTab({
    required this.generatedCode,
    required this.subjects,
    required this.selectedSubject,
    required this.hasCustomCourses,
    required this.onCopyCode,
    required this.onGenerateNewCode,
    required this.onShareInvite,
    required this.onSelectSubject,
    this.dashboardBloc,
    super.key,
  });

  final String generatedCode;
  final List<String> subjects;
  final String selectedSubject;
  final bool hasCustomCourses;
  final void Function(String) onCopyCode;
  final VoidCallback onGenerateNewCode;
  final void Function(String) onShareInvite;
  final void Function(String) onSelectSubject;
  final DashboardBloc? dashboardBloc;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                colors.secondary.withValues(alpha: isDark ? 0.15 : 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.panel),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.vpn_key_rounded,
                    color: colors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'YOUR PRIVATE DUEL CODE',
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Big Room Code Display
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? colors.surfacePrimary : colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      generatedCode,
                      style: typography.largeTitle.bold.copyWith(
                        color: colors.primary,
                        letterSpacing: 4.5,
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      color: colors.primary,
                      tooltip: 'Copy Code',
                      onPressed: () => onCopyCode(generatedCode),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tell your classmate to open "Enter Code" and type this code.',
                textAlign: TextAlign.center,
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      AppFeedback.light();
                      onGenerateNewCode();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Generate New Code'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => onShareInvite(generatedCode),
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Share Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.white,
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Subject Selection for Room
        if (!hasCustomCourses)
          DefaultSubjectsBanner(dashboardBloc: dashboardBloc),
        Text(
          'Room Subject: $selectedSubject',
          style: typography.caption.bold.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...subjects.map((sub) {
              final isSelected = selectedSubject == sub;
              return ChoiceChip(
                label: Text(sub),
                selected: isSelected,
                selectedColor: colors.primary.withValues(alpha: 0.2),
                backgroundColor: colors.surfaceSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                  side: BorderSide(
                    color: isSelected
                        ? colors.primary.withValues(alpha: 0.4)
                        : colors.surfaceBorder.withValues(alpha: 0.3),
                  ),
                ),
                onSelected: (val) {
                  if (val) {
                    AppFeedback.selection();
                    onSelectSubject(sub);
                  }
                },
              );
            }),
            AddCourseChip(dashboardBloc: dashboardBloc),
          ],
        ),
      ],
    );
  }
}
