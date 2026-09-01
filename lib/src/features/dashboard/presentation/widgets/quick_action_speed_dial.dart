import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class QuickActionSpeedDial extends StatelessWidget {
  const QuickActionSpeedDial({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Semantics(
      container: true,
      label: l10n.dashboardQuickActionsSemantics,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(190)
                  : colors.surfacePrimary.withAlpha(225),
              border: Border.all(
                color: isDark
                    ? colors.surfaceBorderHighlight.withAlpha(80)
                    : colors.surfaceBorder.withAlpha(140),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 50 : 12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionItem(
                    icon: Icons.upload_file_rounded,
                    label: l10n.dashboardUploadNotes,
                    color: colors.primary,
                    onTap: () {
                      unawaited(HapticFeedback.lightImpact());
                      _showUploadBottomSheet(context);
                    },
                  ),
                  _buildDivider(colors, isDark),
                  _ActionItem(
                    icon: Icons.quiz_rounded,
                    label: l10n.dashboardQBankAction,
                    color: const Color(0xFFF59E0B),
                    onTap: () {
                      unawaited(HapticFeedback.lightImpact());
                      unawaited(
                        context.router.push(PastQuestionsBoardRoute()),
                      );
                    },
                  ),
                  _buildDivider(colors, isDark),
                  _ActionItem(
                    icon: Icons.add_to_photos_rounded,
                    label: l10n.dashboardNewDeck,
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                      unawaited(HapticFeedback.lightImpact());
                      unawaited(
                        context.navigateTo(
                          const MainRoute(children: [DecksRoute()]),
                        ),
                      );
                    },
                  ),
                  _buildDivider(colors, isDark),
                  _ActionItem(
                    icon: Icons.auto_awesome_rounded,
                    label: l10n.dashboardAiPartner,
                    color: colors.syllabotAccent,
                    onTap: () {
                      unawaited(HapticFeedback.lightImpact());
                      unawaited(
                        context.navigateTo(
                          MainRoute(children: [SyllabotChatRoute()]),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(AppThemeColorsExtension colors, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 1,
      height: 24,
      color: isDark
          ? colors.surfaceBorderHighlight.withAlpha(60)
          : colors.surfaceBorder.withAlpha(120),
    );
  }

  void _showUploadBottomSheet(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceSecondary.withAlpha(240)
                      : colors.surfacePrimary.withAlpha(245),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(
                    color: isDark
                        ? colors.surfaceBorderHighlight.withAlpha(80)
                        : colors.surfaceBorder.withAlpha(140),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.textMuted.withAlpha(100),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text(
                      l10n.dashboardIngestTitle,
                      style: typography.title3.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.dashboardIngestSubtitle,
                      textAlign: TextAlign.center,
                      style: typography.footnote.regular.copyWith(
                        color: colors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Upload options
                    Row(
                      children: [
                        Expanded(
                          child: _UploadOptionCard(
                            icon: Icons.picture_as_pdf_rounded,
                            title: l10n.dashboardUploadPdf,
                            subtitle: l10n.dashboardLectureSlides,
                            onTap: () {
                              Navigator.of(context).pop();
                              unawaited(
                                context.router.push(
                                  const DocumentIngestionRoute(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _UploadOptionCard(
                            icon: Icons.camera_alt_rounded,
                            title: l10n.dashboardScanNotes,
                            subtitle: l10n.dashboardStemOcr,
                            onTap: () {
                              Navigator.of(context).pop();
                              unawaited(
                                context.router.push(
                                  const DocumentIngestionRoute(),
                                ),
                              );
                            },
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
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Semantics(
      button: true,
      label: label,
      child: ShrinkableButton(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: typography.caption.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadOptionCard extends StatelessWidget {
  const _UploadOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ShrinkableButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfacePrimary.withAlpha(160)
              : colors.surfaceSecondary.withAlpha(160),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 80 : 50),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: colors.primary),
            const SizedBox(height: 8),
            Text(
              title,
              style: typography.caption.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: typography.footnote.regular.copyWith(
                color: colors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
