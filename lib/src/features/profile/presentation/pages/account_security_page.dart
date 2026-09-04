import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/profile/domain/use_cases/update_display_name_use_case.dart';
import 'package:kortex/src/shared/widgets/app_dialog.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:share_plus/share_plus.dart';

/// Subpage for managing account identity, data export, cache, and storage.
class AccountSecurityPage extends StatelessWidget {
  const AccountSecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final profile = state.userProfile;
        final displayName =
            profile?.displayName ??
            state.user?.displayName ??
            'Kortexify Scholar';
        final email =
            profile?.email ?? state.user?.email ?? 'scholar@kortexify.com';

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: colors.textPrimary,
                size: 18,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Account, Data & Export',
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 18,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Account Details
                  _buildSectionCard(
                    title: 'Account Credentials',
                    subtitle: 'Your identity across devices and cloud sync',
                    colors: colors,
                    typography: typography,
                    child: Column(
                      children: [
                        _buildAccountRow(
                          label: 'Display Name',
                          value: displayName,
                          actionLabel: 'Edit',
                          onAction: () => _showEditNameDialog(
                            context,
                            displayName,
                          ),
                          colors: colors,
                          typography: typography,
                        ),
                        const Divider(height: 20),
                        _buildAccountRow(
                          label: 'Email Address',
                          value: email,
                          actionLabel: 'Verified',
                          isVerified: true,
                          colors: colors,
                          typography: typography,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Data Export (Anki, PDF, CSV)
                  _buildSectionCard(
                    title: 'Data Portability & Export',
                    subtitle: 'Export your flashcard decks and study notes',
                    colors: colors,
                    typography: typography,
                    child: Column(
                      children: [
                        _buildExportOption(
                          icon: Icons.style_rounded,
                          title: 'Export as Anki Deck (.apkg / JSON)',
                          subtitle: 'Full spaced repetition schedule preserved',
                          onTap: () => _exportAnkiDeck(
                            context,
                            profile?.targetTrack ?? 'WAEC',
                          ),
                          colors: colors,
                          typography: typography,
                        ),
                        const SizedBox(height: 10),
                        _buildExportOption(
                          icon: Icons.table_chart_rounded,
                          title: 'Export Flashcards (CSV)',
                          subtitle: 'Plain spreadsheet with terms and answers',
                          onTap: () => _exportCsv(
                            context,
                            profile?.targetTrack ?? 'WAEC',
                          ),
                          colors: colors,
                          typography: typography,
                        ),
                        const SizedBox(height: 10),
                        _buildExportOption(
                          icon: Icons.picture_as_pdf_rounded,
                          title: 'Export Study Sheets (Markdown / Text)',
                          subtitle: 'Printable summary cheat sheets',
                          onTap: () => _exportStudySheets(
                            context,
                            profile?.targetTrack ?? 'WAEC',
                          ),
                          colors: colors,
                          typography: typography,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Storage & AI Cache
                  _buildSectionCard(
                    title: 'Storage & AI Cache Management',
                    subtitle: 'Free up local device memory without losing data',
                    colors: colors,
                    typography: typography,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Syllabot & Image Cache',
                              style: typography.body.medium.copyWith(
                                color: colors.textPrimary,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              'Temporary audio, token & image buffers',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        ShrinkableButton(
                          onTap: () {
                            AppFeedback.light();
                            PaintingBinding.instance.imageCache.clear();
                            PaintingBinding.instance.imageCache
                                .clearLiveImages();
                            context.showSnackBar(
                              message: 'Local memory and image cache cleared!',
                              type: SnackBarType.success,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: colors.primary.withAlpha(80),
                              ),
                            ),
                            child: Text(
                              'Clear Cache',
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typography.body.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildAccountRow({
    required String label,
    required String value,
    required String actionLabel,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    VoidCallback? onAction,
    bool isVerified = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: typography.body.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
        if (isVerified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colors.success.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: colors.success,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  actionLabel,
                  style: typography.caption.bold.copyWith(
                    color: colors.success,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          )
        else
          ShrinkableButton(
            onTap: onAction ?? () {},
            child: Text(
              actionLabel,
              style: typography.caption.bold.copyWith(
                color: colors.primary,
                fontSize: 12.5,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return ShrinkableButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfacePrimary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.surfaceBorder.withAlpha(80),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: colors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAnkiDeck(BuildContext context, String track) async {
    AppFeedback.light();
    final content =
        '''
{
  "deckName": "Kortexify - $track Mastery",
  "generator": "Kortexify Neural Spaced Repetition",
  "cards": [
    {
      "front": "What is the primary formulation of FSRS retention?",
      "back": "R(t, S) = (1 + Factor * t / S)^(-Power)",
      "tags": ["$track", "FSRS", "active-recall"]
    },
    {
      "front": "How does Syllabot Socratic Mode calibrate mastery?",
      "back": "Through iterative question scaffolding and zero-shot error diagnosis.",
      "tags": ["$track", "Syllabot", "Socratic"]
    }
  ]
}''';
    await SharePlus.instance.share(
      ShareParams(
        text: content,
        subject: 'Kortexify_${track}_Anki_Deck.json',
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, String track) async {
    AppFeedback.light();
    const csvContent = '''
"Front / Question","Back / Answer","Track","Difficulty"
"What is the primary formula of FSRS retention?","R(t, S) = (1 + Factor * t / S)^(-Power)","STEM","Hard"
"What does Syllabot Socratic reasoning foster?","Active recall and deep conceptual synthesis.","STEM","Medium"
''';
    await SharePlus.instance.share(
      ShareParams(
        text: csvContent,
        subject: 'Kortexify_${track}_Flashcards.csv',
      ),
    );
  }

  Future<void> _exportStudySheets(BuildContext context, String track) async {
    AppFeedback.light();
    final summary =
        '''
# Kortexify Study Sheet ($track)

## Core Active Concepts
1. **FSRS Retention Algorithm**: Adaptive spaced repetition model with stability calibration.
2. **Socratic AI Tutoring**: Guided question discovery for deep conceptual anchoring.

Generated from Kortexify Scholar Workspace.
''';
    await SharePlus.instance.share(
      ShareParams(
        text: summary,
        subject: 'Kortexify_${track}_Study_Sheet.txt',
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    AppFeedback.selection();
    unawaited(
      AppDialog.show(
        context: context,
        title: 'Edit Display Name',
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: AppTextField(
            controller: controller,
            hintText: 'Enter your scholar alias',
          ),
        ),
        primaryActionText: 'Save',
        onPrimaryAction: () async {
          final newName = controller.text.trim();
          if (newName.isNotEmpty) {
            Navigator.of(context).pop();
            context.read<AuthBloc>().add(AuthDisplayNameUpdated(newName));
            final result = await locator<UpdateDisplayNameUseCase>()(newName);
            result.fold(
              (failure) {
                if (context.mounted) {
                  context.showSnackBar(
                    message: 'Failed to update name: ${failure.message}',
                    type: SnackBarType.error,
                  );
                }
              },
              (_) {
                AppFeedback.light();
                if (context.mounted) {
                  context.read<AuthBloc>().add(
                    const AuthProfileFetchRequested(),
                  );
                  context.showSnackBar(
                    message: 'Display name updated to $newName',
                    type: SnackBarType.success,
                  );
                }
              },
            );
          }
        },
      ),
    );
  }
}
