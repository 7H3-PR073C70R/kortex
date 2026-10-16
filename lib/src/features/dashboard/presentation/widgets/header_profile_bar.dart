import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/navigation/app_tab_navigation.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/header_profile_bar/header_icon_button.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/header_profile_bar/profile_initials_helper.dart' as profile_initials;
import 'package:kortex/src/features/dashboard/presentation/widgets/header_profile_bar/rank_progress_sheet.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/header_profile_bar/uncalibrated_profile_banner.dart';
import 'package:kortex/src/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:kortex/src/features/notifications/presentation/pages/notifications_page.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_animated_entrance.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/app_tour_keys.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

export 'package:kortex/src/features/dashboard/presentation/widgets/header_profile_bar/header_icon_button.dart';
export 'package:kortex/src/features/dashboard/presentation/widgets/header_profile_bar/profile_initials_helper.dart';
export 'package:kortex/src/features/dashboard/presentation/widgets/header_profile_bar/rank_progress_sheet.dart';
export 'package:kortex/src/features/dashboard/presentation/widgets/header_profile_bar/uncalibrated_profile_banner.dart';

class HeaderProfileBar extends StatelessWidget {
  const HeaderProfileBar({
    required this.analytics,
    required this.isProfileUncalibrated,
    this.userName,
    this.userPhotoUrl,
    this.userStorageService,
    this.notificationsCubit,
    super.key,
  });

  final AnalyticsSummaryEntity analytics;
  final bool isProfileUncalibrated;
  final String? userName;
  final String? userPhotoUrl;
  final UserStorageService? userStorageService;
  final NotificationsCubit? notificationsCubit;

  static String extractTwoLetterInitials(String? text) =>
      profile_initials.extractTwoLetterInitials(text);

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;
    final l10n = context.l10n;

    final authState = context.watch<AuthBloc?>()?.state;
    final authProfile = authState?.userProfile;
    final email = authProfile?.email ?? authState?.user?.email ?? '';
    final emailPrefix = email.contains('@') ? email.split('@').first : '';

    final storage = userStorageService ??
        (locator.isRegistered<UserStorageService>()
            ? locator<UserStorageService>()
            : null);

    var candidateName =
        userName ?? authProfile?.displayName ?? authState?.user?.displayName;
    if (candidateName == null ||
        candidateName.trim().isEmpty ||
        (emailPrefix.isNotEmpty && candidateName.trim() == emailPrefix)) {
      if (storage != null) {
        final storedName = storage.getUserDisplayName();
        if (storedName != null &&
            storedName.trim().isNotEmpty &&
            storedName.trim() != emailPrefix) {
          candidateName = storedName;
        }
      }
    }

    final effectiveName = candidateName;
    final effectivePhoto =
        userPhotoUrl ?? authProfile?.photoUrl ?? authState?.user?.photoUrl;

    final displayName =
        (effectiveName != null && effectiveName.trim().isNotEmpty)
        ? effectiveName.trim().split(RegExp(r'\s+')).first
        : l10n.dashboardScholarFallback;

    final trimmedName = effectiveName?.trim() ?? '';
    final initials = extractTwoLetterInitials(
      trimmedName.isNotEmpty ? trimmedName : displayName,
    );

    final unreadCount = () {
      if (notificationsCubit != null) {
        return notificationsCubit!.state.unreadCount;
      }
      try {
        final cubit = context.watch<NotificationsCubit?>();
        if (cubit != null) return cubit.state.unreadCount;
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
      if (locator.isRegistered<NotificationsCubit>()) {
        return locator<NotificationsCubit>().state.unreadCount;
      }
      return 0;
    }();

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
                  AppTabNavigation.navigateTo(context, AppMainTab.profile);
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
                                          name: effectiveName ?? displayName,
                                          borderWidth: 0,
                                          backgroundColor: neural.obsidian850,
                                          foregroundColor: neural.amber300,
                                        )
                                      : Center(
                                          child: Text(
                                            initials,
                                            style: typography.caption.bold
                                                .copyWith(
                                                  color: neural.amber300,
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
                                    key: AppTourKeys.headerStreakKey,
                                    onTap: () {
                                      unawaited(HapticFeedback.lightImpact());
                                      showRankProgressSheet(
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
                                        Flexible(
                                          child: Text(
                                            analytics.academicRank,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: typography.footnote.medium
                                                .copyWith(
                                                  color: neural.slate300,
                                                  fontSize: 11.5,
                                                ),
                                          ),
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
                        // Notifications Shortcut
                        HeaderIconButton(
                          icon: Icons.notifications_outlined,
                          color: neural.amber300,
                          tooltip: 'Notifications',
                          borderHighlightColor: neural.amber,
                          badgeCount: unreadCount,
                          onTap: () {
                            unawaited(HapticFeedback.lightImpact());
                            unawaited(NotificationsPage.show(context));
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
          const UncalibratedProfileBanner(),
        ],
      ],
    );
  }
}
