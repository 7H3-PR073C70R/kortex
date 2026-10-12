import 'package:flutter/material.dart';
import 'package:kortex/src/features/profile/presentation/widgets/active_sessions_list_widget.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_biometrics_and_mfa_section.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_danger_zone_card.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_password_section.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_section_container.dart';

/// The 'Security & Access' tab content in SecuritySettingsPage.
class SecurityAccessTab extends StatelessWidget {
  const SecurityAccessTab({
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.hasMinLength,
    required this.hasNumber,
    required this.hasSpecial,
    required this.isUpdatingPassword,
    required this.biometricLockEnabled,
    required this.backgroundLockTimeoutSeconds,
    required this.twoFactorEnabled,
    required this.onUpdatePassword,
    required this.onSendResetEmail,
    required this.onBiometricLockChanged,
    required this.onTimeoutChanged,
    required this.onTwoFactorChanged,
    required this.onRevokeAllOthers,
    required this.onDeleteAccount,
    super.key,
  });

  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final bool hasMinLength;
  final bool hasNumber;
  final bool hasSpecial;
  final bool isUpdatingPassword;
  final bool biometricLockEnabled;
  final int backgroundLockTimeoutSeconds;
  final bool twoFactorEnabled;
  final VoidCallback onUpdatePassword;
  final VoidCallback onSendResetEmail;
  final ValueChanged<bool> onBiometricLockChanged;
  final ValueChanged<int?> onTimeoutChanged;
  final ValueChanged<bool> onTwoFactorChanged;
  final VoidCallback onRevokeAllOthers;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('security_tab'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Password Change Card
          SecurityPasswordSection(
            currentPasswordController: currentPasswordController,
            newPasswordController: newPasswordController,
            confirmPasswordController: confirmPasswordController,
            hasMinLength: hasMinLength,
            hasNumber: hasNumber,
            hasSpecial: hasSpecial,
            isUpdatingPassword: isUpdatingPassword,
            onUpdatePassword: onUpdatePassword,
            onSendResetEmail: onSendResetEmail,
          ),
          const SizedBox(height: 20),

          // 2. Biometric Lock & 2FA
          SecurityBiometricsAndMfaSection(
            biometricLockEnabled: biometricLockEnabled,
            backgroundLockTimeoutSeconds: backgroundLockTimeoutSeconds,
            twoFactorEnabled: twoFactorEnabled,
            onBiometricLockChanged: onBiometricLockChanged,
            onTimeoutChanged: onTimeoutChanged,
            onTwoFactorChanged: onTwoFactorChanged,
          ),
          const SizedBox(height: 20),

          // 3. Active Sessions & Device Management
          SecuritySectionContainer(
            title: 'Active Sessions & Device Management',
            subtitle: 'Review authorized devices connected to your account',
            child: ActiveSessionsListWidget(
              sessions: [
                DeviceSession(
                  id: 'current_session',
                  deviceName: Theme.of(context).platform == TargetPlatform.macOS
                      ? 'MacBook Pro / Desktop Workstation'
                      : Theme.of(context).platform == TargetPlatform.iOS
                      ? 'iPhone Scholar Workstation'
                      : Theme.of(context).platform == TargetPlatform.android
                      ? 'Android Scholar Device'
                      : 'Kortexify Web Client',
                  osType: Theme.of(context).platform == TargetPlatform.macOS
                      ? 'macos'
                      : Theme.of(context).platform == TargetPlatform.iOS
                      ? 'ios'
                      : Theme.of(context).platform == TargetPlatform.android
                      ? 'android'
                      : 'web',
                  ipAddress: '127.0.0.1 (Encrypted TLS)',
                  location: 'Current Device • Primary Session',
                  lastActive: DateTime.now(),
                  isCurrentDevice: true,
                ),
              ],
              onRevokeAllOthers: onRevokeAllOthers,
            ),
          ),
          const SizedBox(height: 20),

          // 4. Danger Zone: Delete Account
          SecurityDangerZoneCard(
            onDeleteAccount: onDeleteAccount,
          ),
        ],
      ),
    );
  }
}
