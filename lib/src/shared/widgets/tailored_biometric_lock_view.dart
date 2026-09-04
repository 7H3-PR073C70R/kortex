import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/widgets/breathing_campus_background.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Full-screen tailored Biometric Challenge View with atmospheric campus
/// backdrop, dynamic scholar avatar & name, and Face ID / Touch ID triggers.
class TailoredBiometricLockView extends StatelessWidget {
  const TailoredBiometricLockView({
    required this.onUnlock,
    super.key,
    this.onAlternativeAction,
    this.alternativeActionLabel,
    this.customDisplayName,
    this.customPhotoUrl,
    this.subtitle,
  });

  final VoidCallback onUnlock;
  final VoidCallback? onAlternativeAction;
  final String? alternativeActionLabel;
  final String? customDisplayName;
  final String? customPhotoUrl;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final authState = context.watch<AuthBloc?>()?.state;
    final userProfile = authState?.userProfile;
    final displayName =
        customDisplayName ??
        userProfile?.displayName ??
        authState?.user?.displayName ??
        'Scholar';
    final photoUrl =
        customPhotoUrl ?? userProfile?.photoUrl ?? authState?.user?.photoUrl;

    return Material(
      color: colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Atmospheric Breathing Campus Backdrop
          const BreathingCampusBackground(baseOpacity: 0.82),

          // 2. Center Identity & Unlock Card
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Scholar Avatar with Glowing Aura
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            colors.primary,
                            colors.syllabotAccent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withAlpha(isDark ? 100 : 50),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: AppAvatar(
                        customDimension: 86,
                        imageUrl: photoUrl,
                        name: displayName,
                        borderColor: colors.transparent,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tailored Greeting
                    Text(
                      'Welcome back,',
                      style: typography.subhead.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: typography.title1.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // App Lock Notice
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfacePrimary.withAlpha(
                          isDark ? 180 : 220,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.surfaceBorder.withAlpha(90),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 15,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            subtitle ?? 'Biometric App Lock Enabled',
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Primary Unlock Button
                    ShrinkableButton(
                      onTap: onUnlock,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.primary,
                              colors.syllabotAccent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withAlpha(
                                isDark ? 120 : 60,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fingerprint_rounded,
                              size: 22,
                              color: colors.white,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Unlock with Face ID / Touch ID',
                              style: typography.body.bold.copyWith(
                                color: colors.white,
                                fontSize: 14.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Secondary Alternative Action if available
                    if (onAlternativeAction != null) ...[
                      const SizedBox(height: 16),
                      ShrinkableButton(
                        onTap: onAlternativeAction,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            alternativeActionLabel ?? 'Sign In with Password',
                            style: typography.footnote.bold.copyWith(
                              color: colors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
