import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/track_selection_modal_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_animated_entrance.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

class HeaderProfileBar extends StatelessWidget {
  const HeaderProfileBar({
    required this.analytics,
    required this.isProfileUncalibrated,
    this.userName,
    this.userPhotoUrl,
    super.key,
  });

  final AnalyticsSummaryEntity analytics;
  final bool isProfileUncalibrated;
  final String? userName;
  final String? userPhotoUrl;

  static String extractTwoLetterInitials(String? text) {
    if (text == null) return 'KO';
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'KO';

    // 1. If multi-word (e.g. "John Doe"), take the first letter of the first two words
    final parts = trimmed
        .split(RegExp(r'[\s_.\-]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      final first = parts[0].characters.isNotEmpty
          ? parts[0].characters.first
          : '';
      final second = parts[1].characters.isNotEmpty
          ? parts[1].characters.first
          : '';
      final combined = '$first$second'.toUpperCase();
      if (combined.isNotEmpty) return combined;
    }

    // 2. If single word/username (e.g. "toxicbishop01"), strip non-alphanumeric and take first 2 chars
    final clean = trimmed.replaceAll(RegExp('[^a-zA-Z0-9]'), '');
    if (clean.characters.length >= 2) {
      return clean.characters.take(2).toString().toUpperCase();
    }
    if (clean.characters.length == 1) {
      return clean.toUpperCase();
    }

    // 3. Fallback to raw characters if only unicode/emojis or special symbols
    if (trimmed.characters.length >= 2) {
      return trimmed.characters.take(2).toString().toUpperCase();
    }
    if (trimmed.characters.length == 1) {
      return trimmed.toUpperCase();
    }

    return 'KO';
  }

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final authState = context.watch<AuthBloc?>()?.state;
    final authProfile = authState?.userProfile;
    final effectiveName =
        userName ?? authProfile?.displayName ?? authState?.user?.displayName;
    final effectivePhoto =
        userPhotoUrl ?? authProfile?.photoUrl ?? authState?.user?.photoUrl;

    final displayName =
        (effectiveName != null && effectiveName.trim().isNotEmpty)
        ? effectiveName.trim().split(' ').first
        : l10n.dashboardScholarFallback;

    final trimmedName = effectiveName?.trim() ?? '';
    final initials = extractTwoLetterInitials(
      trimmedName.isNotEmpty ? trimmedName : displayName,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Top Bar with Identity Chip, Greeting & Quick Status Metrics
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: User Greeting & Rank
            Expanded(
              child: ShrinkableButton(
                onTap: () {
                  unawaited(HapticFeedback.lightImpact());
                  unawaited(
                    context.navigateTo(
                      const MainRoute(children: [ProfileRoute()]),
                    ),
                  );
                },
                child: Row(
                  children:
                      <Widget>[
                            Semantics(
                              label: l10n.dashboardHeyUser(displayName),
                              image: true,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: neural.obsidian850,
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: neural.hairlineStrong,
                                    width: 1.1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: effectivePhoto != null
                                      ? AppAvatar(
                                          customDimension: 40,
                                          imageUrl: effectivePhoto,
                                          name:
                                              effectiveName ??
                                              displayName,
                                          borderWidth: 0,
                                          backgroundColor:
                                              neural.obsidian850,
                                          foregroundColor:
                                              neural.amber300,
                                        )
                                      : Center(
                                          child: Text(
                                            initials,
                                            style: typography
                                                .caption
                                                .bold
                                                .copyWith(
                                                  color:
                                                      neural.amber300,
                                                  fontSize: 13,
                                                  letterSpacing: 0.5,
                                                ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          l10n.dashboardHeyUser(displayName),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: typography.headline.bold
                                              .copyWith(
                                                color: neural.slate100,
                                                fontSize: 15,
                                                letterSpacing: -0.2,
                                                height: 1.2,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 12,
                                        color: neural.amber400,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  GestureDetector(
                                    onTap: () {
                                      unawaited(HapticFeedback.lightImpact());
                                      _showRankProgressSheet(
                                        context,
                                        analytics,
                                        authProfile,
                                      );
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AppPulsingBeacon(
                                          color: neural.emerald400,
                                          size: 5,
                                          pulseSpread: 2,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          analytics.academicRank,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: typography.footnote.medium
                                              .copyWith(
                                                color: neural.slate300,
                                                fontSize: 11.5,
                                              ),
                                        ),
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: neural.emerald400.withAlpha(22),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: neural.emerald400.withAlpha(50),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            'LVL ${authProfile?.level ?? 1}',
                                            style: typography.caption.bold
                                                .copyWith(
                                                  color: neural.emerald400,
                                                  fontSize: 10,
                                                  letterSpacing: 0.2,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 12,
                                          color: neural.slate400,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]
                          .animate(interval: 60.ms)
                          .fadeIn(duration: 350.ms, curve: Curves.easeOutCubic)
                          .slideX(begin: -0.05, end: 0),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Right: Compact Action Cluster
            Row(
              mainAxisSize: MainAxisSize.min,
              children:
                  <Widget>[
                        // Academic Track Chip / Quick Switcher
                        Semantics(
                          label: 'Academic Track: ${authProfile?.targetTrack.isNotEmpty == true ? authProfile!.targetTrack : "Select Track"}',
                          button: true,
                          child: PlatformHoverBuilder(
                            builder: (context, isHovered, child) {
                              final track = authProfile?.targetTrack;
                              final hasTrack =
                                  track != null && track.trim().isNotEmpty;
                              return ShrinkableButton(
                                onTap: () {
                                  unawaited(HapticFeedback.lightImpact());
                                  unawaited(
                                    TrackSelectionModalSheet.show(
                                      context,
                                      currentTrackId: track,
                                    ),
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: AppMotion.snappy,
                                  curve: AppMotion.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: hasTrack
                                        ? neural.obsidian850.withAlpha(
                                            isHovered ? 255 : 220,
                                          )
                                        : colors.primary.withAlpha(
                                            isDark ? 60 : 30,
                                          ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: hasTrack
                                          ? neural.emerald400.withAlpha(
                                              isHovered ? 150 : 80,
                                            )
                                          : colors.primary.withAlpha(
                                              isHovered ? 200 : 120,
                                            ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        hasTrack
                                            ? Icons.school_rounded
                                            : Icons.track_changes_rounded,
                                        size: 13,
                                        color: hasTrack
                                            ? neural.emerald400
                                            : colors.primary,
                                      ),
                                      const SizedBox(width: 3),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 55,
                                        ),
                                        child: Text(
                                          hasTrack ? track : 'Track',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: typography.caption.bold
                                              .copyWith(
                                                color: hasTrack
                                                    ? neural.slate200
                                                    : colors.primary,
                                                fontSize: 11,
                                                letterSpacing: 0.1,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 1),
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 13,
                                        color: hasTrack
                                            ? neural.slate400
                                            : colors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Notifications Shortcut
                        _HeaderIconButton(
                          icon: Icons.notifications_outlined,
                          color: neural.amber300,
                          tooltip: 'Notifications',
                          borderHighlightColor: neural.amber,
                          onTap: () {
                            unawaited(HapticFeedback.lightImpact());
                            unawaited(
                              context.router.push(const NotificationsRoute()),
                            );
                          },
                        ),
                      ]
                      .animate(interval: 50.ms)
                      .fadeIn(duration: 300.ms)
                      .scaleXY(
                        begin: 0.9,
                        end: 1,
                        curve: Curves.easeOutCubic,
                      ),
            ),
          ],
        ),

        // 2. Sticky Uncalibrated Profile Banner (If user skipped calibration)
        if (isProfileUncalibrated) ...[
          const SizedBox(height: 14),
          Semantics(
            container: true,
            label: l10n.dashboardUncalibratedSemantics,
            child:
                ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.panel),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppRadius.panel,
                            ),
                            gradient: LinearGradient(
                              colors: [
                                colors.primary.withAlpha(isDark ? 55 : 30),
                                colors.syllabotAccent.withAlpha(
                                  isDark ? 35 : 18,
                                ),
                              ],
                            ),
                            border: Border.all(
                              color: colors.primary.withAlpha(
                                isDark ? 100 : 70,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const SyllabotAvatar(size: 36),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.dashboardUncalibratedTitle,
                                      style: typography.caption.bold.copyWith(
                                        color: colors.textPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n.dashboardUncalibratedSubtitle,
                                      style: typography.footnote.regular
                                          .copyWith(
                                            color: colors.textSecondary,
                                            fontSize: 11.5,
                                            height: 1.3,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ShrinkableButton(
                                onTap: () {
                                  unawaited(HapticFeedback.lightImpact());
                                  unawaited(
                                    context.router.push(
                                      const OnboardingCalibrationRoute(),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.badge,
                                    ),
                                  ),
                                  child: Text(
                                    l10n.dashboardCalibrateButton,
                                    style: typography.caption.bold.copyWith(
                                      color: colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.1, end: 0, curve: Curves.easeOutQuint),
          ),
        ],
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.borderHighlightColor,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final Color? borderHighlightColor;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            return ShrinkableButton(
              onTap: onTap,
              child: AnimatedContainer(
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: neural.obsidian850.withAlpha(
                    isHovered ? 255 : 230,
                  ),
                  border: Border.all(
                    color: isHovered
                        ? (borderHighlightColor ?? neural.emerald).withAlpha(
                            110,
                          )
                        : neural.hairlineStrong,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: color,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}void _showRankProgressSheet(
  BuildContext context,
  AnalyticsSummaryEntity analytics,
  dynamic authProfile,
) {
  final neural = context.neural;
  final typography = context.typography;

  final currentXp = analytics.xpPoints > 0 ? analytics.xpPoints : 3400;
  const targetXp = 5000;
  final progressRatio = (currentXp / targetXp).clamp(0.0, 1.0);
  final userLevel = (authProfile as dynamic)?.level ?? 1;

  unawaited(
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.dialog),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: neural.obsidian900.withAlpha(245),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.dialog),
                ),
                border: Border.all(
                  color: neural.amber.withAlpha(80),
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
                      color: neural.slate400.withAlpha(120),
                      borderRadius: BorderRadius.circular(AppRadius.micro),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Rank Badge Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          neural.amber400,
                          neural.amber,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: neural.amber.withAlpha(120),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        size: 36,
                        color: neural.obsidian950,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    analytics.academicRank,
                    style: typography.title2.bold.copyWith(
                      color: neural.slate100,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: neural.emerald.withAlpha(30),
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                      border: Border.all(color: neural.emerald400.withAlpha(100)),
                    ),
                    child: Text(
                      'LEVEL $userLevel SCHOLAR',
                      style: typography.caption.bold.copyWith(
                        color: neural.emerald400,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Progress Bar Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: neural.obsidian850,
                      borderRadius: BorderRadius.circular(AppRadius.panel),
                      border: Border.all(color: neural.hairlineStrong),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Next Rank: Master Scholar',
                              style: typography.footnote.bold.copyWith(
                                color: neural.slate200,
                              ),
                            ),
                            Text(
                              '$currentXp / $targetXp XP',
                              style: typography.footnote.bold.copyWith(
                                color: neural.amber300,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.micro),
                          child: LinearProgressIndicator(
                            value: progressRatio,
                            minHeight: 8,
                            backgroundColor: neural.obsidian800,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              neural.amber400,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Earn ${(targetXp - currentXp).clamp(0, targetXp)} more XP to rank up and unlock Advanced Socratic Drills!',
                          style: typography.caption.regular.copyWith(
                            color: neural.slate400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Multipliers & Active Perks
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: neural.obsidian850,
                            borderRadius: BorderRadius.circular(AppRadius.badge),
                            border: Border.all(color: neural.amber.withAlpha(40)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.bolt_rounded, size: 18, color: neural.amber400),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '+15% XP Active Recall Multiplier',
                                  style: typography.caption.bold.copyWith(
                                    color: neural.slate200,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ShrinkableButton(
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(
                          context.router.push(
                            const AnalyticsDetailRoute(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [neural.amber400, neural.amber],
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.badge),
                        ),
                        child: Center(
                          child: Text(
                            'View Full Analytics & Rank Badges',
                            style: typography.callout.bold.copyWith(
                              color: neural.obsidian950,
                            ),
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
    ),
  );
}
