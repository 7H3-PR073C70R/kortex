import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/widgets/mode_switch_button.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/aura_mesh_nebula.dart';
import 'package:kortex/src/features/onboarding_utility/presentation/bloc/permissions_cubit.dart';
import 'package:kortex/src/features/onboarding_utility/presentation/widgets/permissions_chat_view.dart';
import 'package:kortex/src/gen/assets.gen.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class PermissionsPage extends StatelessWidget {
  const PermissionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: locator<AuthModeCubit>()),
        BlocProvider<PermissionsCubit>(
          create: (_) => PermissionsCubit(),
        ),
      ],
      child: const _PermissionsView(),
    );
  }
}

class _PermissionsView extends StatelessWidget {
  const _PermissionsView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final isChatMode = context.watch<AuthModeCubit>().state.isChat;

    return BlocListener<PermissionsCubit, PermissionsState>(
      listener: (context, state) {
        if (state.isDone && !isChatMode) {
          unawaited(
            // ignore: deprecated_member_use, backward-compatible a11y announcement
            SemanticsService.announce(
              l10n.permissionsCompleteAnnouncement,
              TextDirection.ltr,
            ),
          );
          unawaited(
            context.router.replaceAll([const MainRoute()]),
          );
        }
      },
      child: Scaffold(
        body: AuraMeshNebula(
          showBackgroundImage: true,
          child: SafeArea(
            child: Column(
              children: [
                // Top Bar with Logo, Mode Switch, and Skip button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppAssets.svgs.kortexLogo.svg(
                            width: 24,
                            height: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.appName,
                            style: typography.caption.bold.copyWith(
                              letterSpacing: 1.5,
                              fontSize: 13,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ModeSwitchButton(
                            isChatMode: isChatMode,
                            onToggle: () {
                              context.read<AuthModeCubit>().toggleMode();
                            },
                          ),
                          const SizedBox(width: 10),
                          ShrinkableButton(
                            onTap: () {
                              unawaited(HapticFeedback.lightImpact());
                              context
                                  .read<PermissionsCubit>()
                                  .skipPermissions();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colors.surfaceSecondary.withAlpha(180)
                                    : colors.surfacePrimary.withAlpha(240),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? colors.surfaceBorder.withAlpha(100)
                                      : colors.surfaceBorder,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withAlpha(isDark ? 30 : 12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                l10n.permissionsSkip,
                                style: typography.callout.bold.copyWith(
                                  color: colors.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: isChatMode
                      ? const PermissionsChatView()
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 12),
                                  _PermissionsHeader(l10n: l10n),
                                  const SizedBox(height: 28),
                                  _NotificationPermissionCard(l10n: l10n),
                                  const SizedBox(height: 14),
                                  _StoragePermissionCard(l10n: l10n),
                                  const SizedBox(height: 32),
                                  _PermissionsFooter(l10n: l10n),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionsHeader extends StatelessWidget {
  const _PermissionsHeader({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                colors.primary,
                colors.syllabotAccent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withAlpha(isDark ? 80 : 60),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.lock_open_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            l10n.permissionsTitle,
            textAlign: TextAlign.center,
            style: typography.title1.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 25,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.permissionsSubtitle,
          textAlign: TextAlign.center,
          style: typography.callout.semiBold.copyWith(
            color: colors.textPrimary,
            height: 1.45,
            fontSize: 14.5,
          ),
        ),
      ],
    );
  }
}

/// Glassmorphic card for a single permission.
class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onAllow,
    required this.isGranted,
    required this.isRequesting,
    required this.allowLabel,
    required this.semanticsLabel,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onAllow;
  final bool isGranted;
  final bool isRequesting;
  final String allowLabel;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceSecondary.withAlpha(160)
                : colors.surfacePrimary.withAlpha(230),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isGranted
                  ? colors.success
                  : (isDark
                      ? colors.surfaceBorderHighlight.withAlpha(70)
                      : colors.surfaceBorder),
              width: isGranted ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isGranted
                    ? colors.success.withAlpha(isDark ? 30 : 20)
                    : Colors.black.withAlpha(isDark ? 30 : 10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isGranted
                      ? colors.success.withAlpha(isDark ? 40 : 25)
                      : colors.primary.withAlpha(isDark ? 40 : 20),
                ),
                child: Icon(
                  isGranted ? Icons.check_circle_rounded : icon,
                  color: isGranted
                      ? colors.success
                      : colors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typography.callout.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: typography.caption.medium.copyWith(
                        color: isDark
                            ? colors.textSecondary
                            : colors.textPrimary.withAlpha(210),
                        height: 1.35,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (!isGranted)
                Semantics(
                  button: true,
                  label: semanticsLabel,
                  child: ShrinkableButton(
                    onTap: isRequesting ? () {} : onAllow,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(isDark ? 50 : 25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.primary.withAlpha(isDark ? 90 : 50),
                        ),
                      ),
                      child: isRequesting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.primary,
                              ),
                            )
                          : Text(
                              allowLabel,
                              style: typography.caption.semiBold.copyWith(
                                color: colors.primary,
                                fontSize: 13,
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
  }
}

class _NotificationPermissionCard extends StatelessWidget {
  const _NotificationPermissionCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PermissionsCubit, PermissionsState>(
      builder: (context, state) {
        return _PermissionCard(
          icon: Icons.notifications_active_rounded,
          title: l10n.permissionsNotifTitle,
          description: l10n.permissionsNotifDescription,
          isGranted: state.notificationsGranted,
          isRequesting: state.status == PermissionsStatus.requesting,
          allowLabel: l10n.permissionsAllow,
          semanticsLabel: l10n.permissionsNotifSemantics,
          onAllow: () => unawaited(
            context.read<PermissionsCubit>().requestNotificationPermission(),
          ),
        );
      },
    );
  }
}

class _StoragePermissionCard extends StatelessWidget {
  const _StoragePermissionCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PermissionsCubit, PermissionsState>(
      builder: (context, state) {
        return _PermissionCard(
          icon: Icons.folder_open_rounded,
          title: l10n.permissionsStorageTitle,
          description: l10n.permissionsStorageDescription,
          isGranted: state.storageGranted,
          isRequesting: state.status == PermissionsStatus.requesting,
          allowLabel: l10n.permissionsAllow,
          semanticsLabel: l10n.permissionsStorageSemantics,
          onAllow: () => unawaited(
            context.read<PermissionsCubit>().requestStoragePermission(),
          ),
        );
      },
    );
  }
}

class _PermissionsFooter extends StatelessWidget {
  const _PermissionsFooter({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Column(
      children: [
        AppButton(
          text: l10n.permissionsContinue,
          onPressed: () =>
              context.read<PermissionsCubit>().finishPermissions(),
        ),
        const SizedBox(height: 14),
        Semantics(
          button: true,
          label: l10n.permissionsSkipSemantics,
          child: ShrinkableButton(
            onTap: () =>
                context.read<PermissionsCubit>().skipPermissions(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Text(
                l10n.permissionsSkip,
                style: typography.callout.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 14.5,
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.solid,
                  decorationColor: isDark
                      ? colors.textPrimary.withAlpha(160)
                      : colors.textPrimary.withAlpha(160),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
