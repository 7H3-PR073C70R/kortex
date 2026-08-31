import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/aura_mesh_nebula.dart';
import 'package:kortex/src/features/onboarding_utility/presentation/bloc/permissions_cubit.dart';
import 'package:kortex/src/features/onboarding_utility/presentation/widgets/permissions_chat_view.dart';
import 'package:kortex/src/l10n/l10n.dart';

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
    final l10n = context.l10n;
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
          child: SafeArea(
            child: isChatMode
                ? const PermissionsChatView()
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 32,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 24),
                            _PermissionsHeader(l10n: l10n),
                            const SizedBox(height: 32),
                            _NotificationPermissionCard(l10n: l10n),
                            const SizedBox(height: 16),
                            _StoragePermissionCard(l10n: l10n),
                            const SizedBox(height: 36),
                            _PermissionsFooter(l10n: l10n),
                          ],
                        ),
                      ),
                    ),
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
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withAlpha(100),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.lock_open_rounded,
            color: Colors.white,
            size: 38,
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(
            l10n.permissionsTitle,
            textAlign: TextAlign.center,
            style: typography.title1.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 26,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.permissionsSubtitle,
          textAlign: TextAlign.center,
          style: typography.callout.regular.copyWith(
            color: colors.textSecondary,
            height: 1.5,
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surfacePrimary.withAlpha(60),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isGranted
                  ? const Color(0xFF34D399).withAlpha(120)
                  : Colors.white.withAlpha(40),
              width: isGranted ? 1.5 : 1,
            ),
            boxShadow: isGranted
                ? [
                    BoxShadow(
                      color: const Color(0xFF34D399).withAlpha(40),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Icon badge
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isGranted
                      ? const Color(0xFF34D399).withAlpha(40)
                      : const Color(0xFF6366F1).withAlpha(40),
                ),
                child: Icon(
                  isGranted ? Icons.check_circle_rounded : icon,
                  color: isGranted
                      ? const Color(0xFF34D399)
                      : const Color(0xFF6366F1),
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typography.callout.semiBold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (!isGranted)
                Semantics(
                  button: true,
                  label: semanticsLabel,
                  child: TextButton(
                    onPressed: isRequesting ? null : onAllow,
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1).withAlpha(40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    child: isRequesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF6366F1),
                            ),
                          )
                        : Text(
                            allowLabel,
                            style: typography.caption.semiBold.copyWith(
                              color: const Color(0xFF6366F1),
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
    final typography = context.typography;
    return BlocBuilder<PermissionsCubit, PermissionsState>(
      builder: (context, state) {
        final allGranted = state.notificationsGranted && state.storageGranted;
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: allGranted
                    ? () => context.read<PermissionsCubit>().finishPermissions()
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(
                    0xFF6366F1,
                  ).withAlpha(80),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  l10n.permissionsContinue,
                  style: typography.callout.semiBold.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: l10n.permissionsSkipSemantics,
              child: TextButton(
                onPressed: () =>
                    context.read<PermissionsCubit>().skipPermissions(),
                child: Text(
                  l10n.permissionsSkip,
                  style: typography.callout.regular.copyWith(
                    color: Colors.white60,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
