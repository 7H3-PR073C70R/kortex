import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/shared/widgets/app_dialog.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Subpage for managing account identity, data export, cache, and security.
class AccountSecurityPage extends StatelessWidget {
  const AccountSecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final profile = state.userProfile;
        final displayName = profile?.displayName ?? 'Kortexify Scholar';
        final email = profile?.email ?? 'scholar@kortexify.com';

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
              'Account & Security',
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
                          title: 'Export as Anki Deck (.apkg)',
                          subtitle: 'Full spaced repetition schedule preserved',
                          onTap: () {
                            context.showSnackBar(
                              message: 'Preparing Anki deck export...',
                            );
                          },
                          colors: colors,
                          typography: typography,
                        ),
                        const SizedBox(height: 10),
                        _buildExportOption(
                          icon: Icons.table_chart_rounded,
                          title: 'Export Flashcards (CSV)',
                          subtitle: 'Plain spreadsheet with terms and answers',
                          onTap: () {
                            context.showSnackBar(
                              message: 'Exporting cards to CSV...',
                            );
                          },
                          colors: colors,
                          typography: typography,
                        ),
                        const SizedBox(height: 10),
                        _buildExportOption(
                          icon: Icons.picture_as_pdf_rounded,
                          title: 'Export Study Sheets (PDF)',
                          subtitle: 'Printable summary cheat sheets',
                          onTap: () {
                            context.showSnackBar(
                              message: 'Generating high-res study PDF...',
                            );
                          },
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
                              'Syllabot Cache (4.2 MB)',
                              style: typography.body.medium.copyWith(
                                color: colors.textPrimary,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              'Temporary audio & token buffers',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        ShrinkableButton(
                          onTap: () {
                            unawaited(HapticFeedback.mediumImpact());
                            context.showSnackBar(
                              message: 'Local Syllabot cache cleared!',
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
              color: const Color(0xFF10B981).withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  actionLabel,
                  style: typography.caption.bold.copyWith(
                    color: const Color(0xFF10B981),
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

  void _showEditNameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
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
        onPrimaryAction: () {
          final newName = controller.text.trim();
          if (newName.isNotEmpty) {
            Navigator.of(context).pop();
            context.showSnackBar(
              message: 'Name updated to $newName',
              type: SnackBarType.success,
            );
          }
        },
      ),
    );
  }
}
