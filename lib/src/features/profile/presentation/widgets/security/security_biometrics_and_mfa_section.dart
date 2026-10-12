import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_section_container.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// App Lock & Two-Factor Authentication (TOTP) management section.
class SecurityBiometricsAndMfaSection extends StatelessWidget {
  const SecurityBiometricsAndMfaSection({
    required this.biometricLockEnabled,
    required this.backgroundLockTimeoutSeconds,
    required this.twoFactorEnabled,
    required this.onBiometricLockChanged,
    required this.onTimeoutChanged,
    required this.onTwoFactorChanged,
    super.key,
  });

  final bool biometricLockEnabled;
  final int backgroundLockTimeoutSeconds;
  final bool twoFactorEnabled;
  final ValueChanged<bool> onBiometricLockChanged;
  final ValueChanged<int?> onTimeoutChanged;
  final ValueChanged<bool> onTwoFactorChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return SecuritySectionContainer(
      title: 'App Lock & Two-Factor Authentication',
      subtitle: 'Protect your study notes with biometrics & Authenticator App (TOTP)',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Biometric App Lock',
                    style: typography.body.medium.copyWith(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    'Require Face ID / Fingerprint on launch',
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Switch.adaptive(
                value: biometricLockEnabled,
                activeTrackColor: colors.primary,
                onChanged: onBiometricLockChanged,
              ),
            ],
          ),
          if (biometricLockEnabled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: colors.surfacePrimary,
                borderRadius: AppRadius.radiusCard,
                border: Border.all(
                  color: colors.surfaceBorder.withAlpha(70),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-Lock Timeout',
                        style: typography.body.medium.copyWith(
                          color: colors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Re-arm lock when backgrounded',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  DropdownButton<int>(
                    value: const [0, 15, 30, 60, 300].contains(backgroundLockTimeoutSeconds)
                        ? backgroundLockTimeoutSeconds
                        : 30,
                    underline: const SizedBox.shrink(),
                    dropdownColor: colors.surfacePrimary,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colors.textSecondary,
                      size: 18,
                    ),
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 12,
                    ),
                    onChanged: onTimeoutChanged,
                    items: [
                      DropdownMenuItem(
                        value: 0,
                        child: Text(l10n.securityTimeoutImmediately),
                      ),
                      DropdownMenuItem(
                        value: 15,
                        child: Text(l10n.securityTimeout15s),
                      ),
                      DropdownMenuItem(
                        value: 30,
                        child: Text(l10n.securityTimeout30sDefault),
                      ),
                      DropdownMenuItem(
                        value: 60,
                        child: Text(l10n.securityTimeout1m),
                      ),
                      DropdownMenuItem(
                        value: 300,
                        child: Text(l10n.securityTimeout5m),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Two-Factor Auth (TOTP)',
                    style: typography.body.medium.copyWith(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    twoFactorEnabled
                        ? 'Active • Authenticator linked'
                        : 'Require 6-digit TOTP code on login',
                    style: typography.caption.regular.copyWith(
                      color: twoFactorEnabled
                          ? colors.success
                          : colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Switch.adaptive(
                value: twoFactorEnabled,
                activeTrackColor: colors.primary,
                onChanged: onTwoFactorChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
