import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_duel_matchmaking_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
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
        borderRadius: BorderRadius.circular(AppRadius.dialog),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.dialog),
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(190)
                  : colors.surfacePrimary.withAlpha(225),
              border: Border.all(
                color: colors.surfaceBorder.withAlpha(isDark ? 60 : 35),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    <Widget>[
                          _ActionItem(
                            icon: Icons.upload_file_rounded,
                            label: l10n.dashboardUploadNotes,
                            color: colors.primary,
                            onTap: () {
                              AppFeedback.light();
                              _showUploadBottomSheet(context);
                            },
                          ),
                          _buildDivider(colors, isDark),
                          _ActionItem(
                            icon: Icons.quiz_rounded,
                            label: l10n.dashboardQBankAction,
                            color: colors.warning,
                            onTap: () {
                              AppFeedback.light();
                              String? trackCode;
                              try {
                                final track = context
                                    .read<AuthBloc>()
                                    .state
                                    .userProfile
                                    ?.targetTrack;
                                if (track != null && track.isNotEmpty) {
                                  trackCode = track;
                                }
                              } on Object catch (_) {}
                              unawaited(
                                context.router.push(
                                  PastQuestionsBoardRoute(
                                    initialExamCode: trackCode,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildDivider(colors, isDark),
                          _ActionItem(
                            icon: Icons.flash_on_rounded,
                            label: '1v1 Duel',
                            color: colors.primary,
                            onTap: () {
                              AppFeedback.light();
                              unawaited(QuizDuelMatchmakingSheet.show(context));
                            },
                          ),
                          _buildDivider(colors, isDark),
                          _ActionItem(
                            icon: Icons.groups_rounded,
                            label: 'Study Hub',
                            color: colors.success,
                            onTap: () {
                              AppFeedback.light();
                              unawaited(
                                context.navigateTo(
                                  const MainRoute(children: [CommunityHubRoute()]),
                                ),
                              );
                            },
                          ),
                          _buildDivider(colors, isDark),
                          _ActionItem(
                            icon: Icons.add_to_photos_rounded,
                            label: l10n.dashboardNewDeck,
                            color: colors.secondary,
                            onTap: () {
                              AppFeedback.light();
                              unawaited(
                                context.navigateTo(
                                  const MainRoute(children: [DecksRoute()]),
                                ),
                              );
                            },
                          ),
                        ]
                        .animate(interval: 30.ms)
                        .fadeIn(duration: 250.ms)
                        .scaleXY(
                          begin: 0.8,
                          end: 1,
                          curve: Curves.easeOutCubic,
                        ),
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
      height: 20,
      color: colors.surfaceBorder.withAlpha(isDark ? 50 : 30),
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
        backgroundColor: colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.dialog),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceSecondary.withAlpha(240)
                      : colors.surfacePrimary.withAlpha(245),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.dialog),
                  ),
                  border: Border.all(
                    color: colors.surfaceBorder.withAlpha(isDark ? 60 : 35),
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
                        borderRadius: BorderRadius.circular(AppRadius.micro),
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
                                  DocumentIngestionRoute(),
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
                                  DocumentIngestionRoute(),
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
    final isDark = context.isDarkMode;

    return Semantics(
      button: true,
      label: label,
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return ShrinkableButton(
            onTap: onTap,
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.badge),
                color: isHovered
                    ? (isDark
                          ? colors.surfaceBorder.withAlpha(40)
                          : colors.surfaceBorder.withAlpha(25))
                    : colors.transparent,
              ),
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
          );
        },
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

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return ShrinkableButton(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            curve: AppMotion.easeOutCubic,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? (isHovered
                        ? colors.surfacePrimary.withAlpha(200)
                        : colors.surfacePrimary.withAlpha(160))
                  : (isHovered
                        ? colors.surfaceSecondary.withAlpha(210)
                        : colors.surfaceSecondary.withAlpha(160)),
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(
                color: isHovered
                    ? colors.primary.withAlpha(isDark ? 110 : 80)
                    : colors.surfaceBorder.withAlpha(isDark ? 50 : 30),
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
      },
    );
  }
}
