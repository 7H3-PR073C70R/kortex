import 'dart:async';
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/auth/presentation/widgets/profile_navigation_menu.dart';
import 'package:kortex/src/features/auth/presentation/widgets/scholar_hub_card.dart';
import 'package:kortex/src/features/profile/domain/use_cases/update_display_name_use_case.dart';
import 'package:kortex/src/features/profile/presentation/pages/about_support_page.dart';
import 'package:kortex/src/features/profile/presentation/pages/academic_track_settings_page.dart';
import 'package:kortex/src/features/profile/presentation/pages/app_preferences_page.dart';
import 'package:kortex/src/features/profile/presentation/pages/deck_pace_settings_page.dart';
import 'package:kortex/src/features/profile/presentation/pages/security_settings_page.dart';
import 'package:kortex/src/features/profile/presentation/pages/syllabot_ai_settings_page.dart';
import 'package:kortex/src/features/profile/presentation/widgets/study_statistics_summary_card.dart';
import 'package:kortex/src/shared/widgets/app_back_button.dart';
import 'package:kortex/src/shared/widgets/app_dialog.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/app_tour_keys.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:package_info_plus/package_info_plus.dart';

@RoutePage()
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: locator<AuthBloc>(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends HookWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    useEffect(() {
      context.read<AuthBloc>().add(const AuthProfileFetchRequested());
      return null;
    }, const []);

    final packageInfoMemo = useMemoized(PackageInfo.fromPlatform);
    final packageInfoSnapshot = useFuture(packageInfoMemo);
    final appVersionText = useMemoized(() {
      if (!packageInfoSnapshot.hasData) return '';
      final info = packageInfoSnapshot.data!;
      final version = info.version;
      final buildNumber = info.buildNumber;
      return buildNumber.isNotEmpty ? '$version+$buildNumber' : version;
    }, [packageInfoSnapshot.data]);

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.sessionStatus == AuthSessionStatus.unauthenticated ||
            state.status == AuthStatus.unauthenticated) {
          locator<AuthModeCubit>().resetToAiChat();
          unawaited(context.router.root.replaceAll([const AuthRoute()]));
        }
      },
      builder: (context, state) {
        final profile = state.userProfile;
        final targetTrack = profile?.targetTrack ?? 'WAEC';
        final dailyTarget = profile?.dailyCardTarget ?? 20;

        final isDesktopMasterDetail =
            MediaQuery.sizeOf(context).width >= AppBackButton.desktopBreakpoint;
        final activeSection = useState<ProfileSettingsSection>(
          ProfileSettingsSection.academicTrack,
        );

        if (isDesktopMasterDetail) {
          return Scaffold(
            backgroundColor: colors.backgroundPrimary,
            body: Row(
              children: [
                SizedBox(
                  width: 380,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: isDark
                              ? colors.surfaceBorder.withValues(alpha: 0.4)
                              : colors.surfaceBorder.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Profile & Settings',
                                style: typography.title2.bold.copyWith(
                                  color: colors.textPrimary,
                                  letterSpacing: -0.5,
                                  fontSize: 20,
                                ),
                              ),
                              _buildProPill(
                                context,
                                profile,
                                colors,
                                typography,
                                isDark,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                            child: _buildProfileContent(
                              context,
                              state,
                              profile,
                              targetTrack,
                              dailyTarget,
                              appVersionText,
                              colors,
                              typography,
                              isDark,
                              selectedSection: activeSection.value,
                              onSectionSelected: (sec) =>
                                  activeSection.value = sec,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppMotion.snappy,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _buildDetailPanel(activeSection.value),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          body: Stack(
            children: [
              // Subtle ambient mesh glows
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 400,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.7),
                      radius: 0.8,
                      colors: [
                        if (isDark)
                          const Color.fromRGBO(200, 160, 90, 0.08)
                        else
                          colors.primary.withValues(alpha: 0.04),
                        colors.transparent,
                      ],
                      stops: const [0.0, 0.9],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 100,
                left: -150,
                width: 400,
                height: 400,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.8,
                      colors: [
                        if (isDark)
                          const Color.fromRGBO(56, 189, 248, 0.04)
                        else
                          const Color.fromRGBO(56, 189, 248, 0.03),
                        colors.transparent,
                      ],
                      stops: const [0.0, 0.9],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 400,
                right: -100,
                width: 400,
                height: 400,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.8,
                      colors: [
                        if (isDark)
                          const Color.fromRGBO(139, 92, 246, 0.05)
                        else
                          const Color.fromRGBO(139, 92, 246, 0.03),
                        colors.transparent,
                      ],
                      stops: const [0.0, 0.9],
                    ),
                  ),
                ),
              ),
              // Glassmorphism Blur Layer
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: const SizedBox(),
                ),
              ),

              // 2. Main Scroll Content
              CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                slivers: [
                  SliverAppBar(
                    backgroundColor: colors.backgroundPrimary,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    pinned: true,
                    centerTitle: false,
                    title: Text(
                      'Profile & Settings',
                      style: typography.title2.bold.copyWith(
                        color: colors.textPrimary,
                        letterSpacing: -0.5,
                        fontSize: 22,
                      ),
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _buildProPill(
                          context,
                          profile,
                          colors,
                          typography,
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: _buildProfileContent(
                            context,
                            state,
                            profile,
                            targetTrack,
                            dailyTarget,
                            appVersionText,
                            colors,
                            typography,
                            isDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailPanel(ProfileSettingsSection section) {
    switch (section) {
      case ProfileSettingsSection.academicTrack:
        return const KeyedSubtree(
          key: ValueKey('academic_track'),
          child: AcademicTrackSettingsPage(),
        );
      case ProfileSettingsSection.deckPace:
        return const KeyedSubtree(
          key: ValueKey('deck_pace'),
          child: DeckPaceSettingsPage(),
        );
      case ProfileSettingsSection.syllabotAi:
        return const KeyedSubtree(
          key: ValueKey('syllabot_ai'),
          child: SyllabotAiSettingsPage(),
        );
      case ProfileSettingsSection.security:
        return const KeyedSubtree(
          key: ValueKey('security'),
          child: SecuritySettingsPage(),
        );
      case ProfileSettingsSection.appPreferences:
        return const KeyedSubtree(
          key: ValueKey('preferences'),
          child: AppPreferencesPage(),
        );
      case ProfileSettingsSection.aboutSupport:
        return const KeyedSubtree(
          key: ValueKey('about'),
          child: AboutSupportPage(),
        );
    }
  }

  Widget _buildProPill(
    BuildContext context,
    UserProfileEntity? profile,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return AnimatedScale(
          scale: isHovered ? 1.03 : 1.0,
          duration: AppMotion.snappy,
          curve: Curves.easeOutCubic,
          child: child,
        );
      },
      child: ShrinkableButton(
        onTap: () {
          AppFeedback.selection();
          unawaited(
            context.router.push(PaywallRoute()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [
                      Color.fromRGBO(217, 119, 6, 0.3),
                      Color.fromRGBO(234, 179, 8, 0.2),
                    ]
                  : const [
                      Color.fromRGBO(245, 158, 11, 0.14),
                      Color.fromRGBO(253, 230, 138, 0.2),
                    ],
            ),
            borderRadius: AppRadius.radiusDialog,
            border: Border.all(
              color: isDark
                  ? const Color.fromRGBO(245, 158, 11, 0.4)
                  : const Color.fromRGBO(
                      245,
                      158,
                      11,
                      0.35,
                    ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                profile?.isPro == true
                    ? Icons.verified_rounded
                    : Icons.auto_awesome_rounded,
                color: isDark
                    ? const Color.fromRGBO(252, 211, 77, 1)
                    : const Color.fromRGBO(180, 83, 9, 1),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                profile?.isPro == true ? 'Pro Active' : 'Go Pro',
                style: typography.caption.bold.copyWith(
                  color: isDark
                      ? const Color.fromRGBO(252, 211, 77, 1)
                      : const Color.fromRGBO(180, 83, 9, 1),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    AuthState state,
    UserProfileEntity? profile,
    String targetTrack,
    int dailyTarget,
    String appVersionText,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark, {
    ProfileSettingsSection? selectedSection,
    ValueChanged<ProfileSettingsSection>? onSectionSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScholarHubCard(
          state: state,
          profile: profile,
          onEditName: () {
            final email = profile?.email ?? state.user?.email ?? '';
            final emailPrefix =
                email.contains('@') ? email.split('@').first : '';
            var initialName =
                profile?.displayName ?? state.user?.displayName ?? '';
            if (initialName.isEmpty ||
                (emailPrefix.isNotEmpty && initialName == emailPrefix)) {
              if (locator.isRegistered<UserStorageService>()) {
                final stored =
                    locator<UserStorageService>().getUserDisplayName();
                if (stored != null &&
                    stored.trim().isNotEmpty &&
                    stored.trim() != emailPrefix) {
                  initialName = stored.trim();
                }
              }
            }
            _showEditProfileDialog(
              context,
              initialName,
            );
          },
        ),
        const SizedBox(height: 20),
        StudyStatisticsSummaryCard(
          profile: profile,
        ),
        const SizedBox(height: 20),
        ProfileNavigationMenu(
          key: AppTourKeys.profileCardKey = AppTourKeys.safeKey(
            AppTourKeys.profileCardKey,
            'tour_profile_card',
          ),
          targetTrack: targetTrack,
          dailyTarget: dailyTarget,
          selectedSection: selectedSection,
          onSectionSelected: onSectionSelected,
        ),
        const SizedBox(height: 28),
        ShrinkableButton(
          onTap: () => _confirmSignOut(
            context,
            colors,
            typography,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color.fromRGBO(18, 21, 28, 0.9)
                  : colors.error.withValues(alpha: 0.05),
              borderRadius: AppRadius.radiusPanel,
              border: Border.all(
                color: isDark
                    ? const Color.fromRGBO(136, 19, 55, 0.4)
                    : colors.error.withValues(alpha: 0.22),
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: colors.error.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  color: isDark
                      ? const Color.fromRGBO(251, 113, 133, 1)
                      : colors.error,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sign Out',
                  style: typography.body.bold.copyWith(
                    color: isDark
                        ? const Color.fromRGBO(251, 113, 133, 1)
                        : colors.error,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            appVersionText.isNotEmpty
                ? 'Kortexify v$appVersionText • Neural Study AI'
                : 'Kortexify • Neural Study AI',
            style: typography.caption.bold.copyWith(
              color: colors.textMuted,
              fontSize: 11,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

  void _showEditProfileDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    AppFeedback.selection();
    unawaited(
      AppDialog.show(
        context: context,
        title: 'Edit Scholar Profile',
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: AppTextField(
            controller: controller,
            hintText: 'Enter your name or alias',
          ),
        ),
        primaryActionText: 'Save',
        onPrimaryAction: () async {
          final newName = controller.text.trim();
          if (newName.isNotEmpty) {
            Navigator.of(context).pop();
            context.read<AuthBloc>().add(AuthDisplayNameUpdated(newName));
            if (locator.isRegistered<UserStorageService>()) {
              unawaited(
                locator<UserStorageService>().saveUserDisplayName(newName),
              );
            }
            final result = await locator<UpdateDisplayNameUseCase>()(newName);
            result.fold(
              (failure) {
                if (context.mounted) {
                  context.showSnackBar(
                    message: 'Could not sync name: ${failure.message}',
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
                    message: 'Profile updated: $newName',
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

  void _confirmSignOut(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
  ) {
    AppFeedback.selection();
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: colors.surfaceSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.radiusDialog,
          ),
          title: Text(
            'Sign Out of Kortexify?',
            style: typography.title3.bold.copyWith(
              color: colors.textPrimary,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out? Your study progress is '
            'securely synced to cloud.',
            style: typography.body.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: context.typography.body.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                AppFeedback.medium();
                Navigator.of(ctx).pop();
                locator<AuthModeCubit>().resetToAiChat();
                context.read<AuthBloc>().add(const AuthSignOutRequested());
                unawaited(
                  context.router.root.replaceAll([const AuthRoute()]),
                );
              },
              child: Text(
                'Sign Out',
                style: context.typography.body.regular.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
